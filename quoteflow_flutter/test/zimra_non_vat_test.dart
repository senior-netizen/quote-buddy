import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:quoteflow/providers/zimra_provider.dart';
import 'package:quoteflow/screens/settings/zimra_settings_screen.dart';
import 'package:quoteflow/models/adapters.dart';
import 'package:quoteflow/models/document.dart';
import 'package:quoteflow/models/organization.dart';
import 'package:quoteflow/services/fiscalisation.dart';
import 'package:quoteflow/services/tax_engine.dart';
import 'package:quoteflow/services/tax_resolver.dart';
import 'package:quoteflow/services/zimra/zimra.dart';

class FakeFdms implements ZimraApi {
  int taxId = 513;
  final posts = <Map<String, dynamic>>[];
  @override
  Future<ZimraHttpResponse> get(
    String path, {
    Map<String, String>? headers,
  }) async => ZimraHttpResponse(
    statusCode: 200,
    rawBody: '{}',
    body: {
      'qrUrl': 'https://example.com/',
      'applicableTaxes': [
        {'taxID': taxId, 'taxName': 'Non-VAT 0%', 'taxPercent': 0},
      ],
    },
  );
  @override
  Future<ZimraHttpResponse> post(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    posts.add(body);
    return const ZimraHttpResponse(
      statusCode: 200,
      rawBody: '{}',
      body: {
        'receiptID': 11798797,
        'serverDate': '2026-09-29T12:00:00',
        'validationErrors': [
          {
            'validationErrorCode': 'TEST_RED',
            'validationErrorColor': 'Red',
            'validationErrorDescription': 'Test diagnostic',
          },
          {
            'validationErrorCode': 'TEST_YELLOW',
            'validationErrorColor': 'Yellow',
            'validationErrorDescription': 'Test warning',
          },
        ],
      },
    );
  }

  @override
  void close() {}
}

QuoteflowDocument document() => QuoteflowDocument(
  id: 'd',
  docType: 'invoice',
  docNumber: 'INV-1',
  issueDate: '2026-09-29',
  lineItems: [LineItem(description: 'Service', quantity: 1, unitPrice: 247.5)],
  taxRate: 0,
  discount: 0,
  subtotal: 247.5,
  taxAmount: 0,
  total: 247.5,
  clientId: 'c',
  createdAt: '2026-09-29',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final date = DateTime(2026, 9, 29);
  ZimraTax tax(
    int id, {
    String name = 'Non-VAT 0%',
    double rate = 0,
    bool manual = false,
  }) => ZimraTax(
    taxId: id,
    taxCode: '',
    taxName: name,
    taxPercent: rate,
    isManual: manual,
  );
  FdmsTaxResolution resolve(
    List<ZimraTax> taxes, {
    TaxTreatment treatment = TaxTreatment.noTax,
    double? rate,
  }) => resolveFdmsTax(
    treatment: treatment,
    documentDate: date,
    applicableTaxes: taxes,
    rate: rate,
  );

  test('non-VAT resolves only an explicit current FDMS treatment', () {
    expect(resolve([tax(513)]).tax!.taxId, 513);
    expect(resolve([tax(927)]).tax!.taxId, 927);
    expect(
      resolve([tax(22, name: 'Zero rated')]).problem,
      contains('No compatible ZIMRA tax configuration'),
    );
    expect(resolve([tax(101, manual: true)]).ok, isFalse);
    expect(resolve([tax(10), tax(11)]).ok, isFalse);
    expect(resolve([tax(10)], treatment: TaxTreatment.zeroRated).ok, isFalse);
    expect(
      resolve(
        [tax(22, name: 'VAT', rate: 15)],
        treatment: TaxTreatment.standard,
        rate: 15,
      ).tax!.taxId,
      22,
    );
  });

  test(
    'wire null percent means exempt; malformed rates cannot become zero',
    () {
      expect(
        ZimraTax.fromJson({'taxID': 42, 'taxName': 'Exempt'}).isExempt,
        isTrue,
      );
      expect(
        () => ZimraTax.fromJson({'taxID': 42, 'taxPercent': 'bad'}),
        throwsFormatException,
      );
      final current = ZimraTax.fromJson({
        'taxID': 43,
        'taxName': 'Non-VAT 0%',
        'taxPercent': 0,
        'validTill': '2026-09-29',
      });
      expect(current.isValidOn(DateTime(2026, 9, 29, 23, 59)), isTrue);
      expect(current.isValidOn(DateTime(2026, 9, 30)), isFalse);
      expect(
        resolve([
          ZimraTax.fromJson({
            'taxID': 44,
            'taxName': 'Non-VAT 0%',
            'taxPercent': 0,
            'active': false,
          }),
        ]).ok,
        isFalse,
      );
    },
  );

  test(
    'low-level submission validator rejects absent/manual IDs and rate mismatch',
    () {
      final config = ZimraConfig(
        applicableTaxes: [tax(927)],
        qrUrl: '',
        deviceId: 7,
      );
      void validate(int id, double? rate) =>
          ZimraFiscalDevice.validateReceiptInputs(
            config: config,
            deviceId: 7,
            date: date,
            currency: 'USD',
            lines: [
              ReceiptLineInput(
                name: 'Service',
                price: 247.5,
                quantity: 1,
                taxId: id,
                taxPercent: rate,
              ),
            ],
          );
      expect(() => validate(101, 0), throwsA(isA<ZimraException>()));
      expect(() => validate(927, 15), throwsA(isA<ZimraException>()));
      expect(() => validate(927, null), throwsA(isA<ZimraException>()));
      expect(() => validate(927, 0), returnsNormally);
    },
  );

  for (final id in [513, 927]) {
    test(
      'GetConfig ID $id reaches lines and receiptTaxes; total remains 247.50',
      () async {
        final api = FakeFdms()..taxId = id;
        final pair = generateKeyPair();
        final device = ZimraFiscalDevice(
          identity: const ZimraDeviceIdentity(
            deviceId: 7,
            serialNumber: 'TEST',
          ),
          credentials: ZimraCredentials(
            privateKeyPem: encodePrivateKeyPem(pair.privateKey),
            certificatePem: '',
          ),
          transport: api,
          dayState: FiscalDayState(
            fiscalDayNo: 6,
            fiscalDayDate: '2026-09-29',
            status: FiscalDayStatus.fiscalDayOpened,
          ),
        );
        final config = await device.getConfig();
        final doc = document();
        final lines = buildFiscalLines(
          doc: doc,
          config: config,
          org: Organization(id: 'o', name: 'Non-VAT', taxEnabled: false),
        );
        expect(lines.ok, isTrue, reason: lines.problem);
        expect(fiscalTotalCents(lines.lines), 24750);
        final result = await device.submitReceipt(
          currency: 'USD',
          invoiceNo: doc.docNumber,
          lines: lines.lines,
          linesTaxInclusive: false,
          payments: [ReceiptPayment(moneyType: 'Cash', amount: 24750)],
        );
        final receipt = api.posts.single['receipt'] as Map;
        expect((receipt['receiptLines'] as List).single['taxID'], id);
        expect((receipt['receiptTaxes'] as List).single['taxID'], id);
        expect((receipt['receiptTaxes'] as List).single['taxPercent'], 0);
        expect((receipt['receiptTaxes'] as List).single['taxAmount'], 0);
        expect(
          (receipt['receiptTaxes'] as List).single['salesAmountWithTax'],
          247.5,
        );
        expect(receipt['receiptTotal'], 247.5);
        for (final field in ['receiptTotal', 'receiptTaxes', 'receiptLines']) {
          final malformed =
              jsonDecode(jsonEncode(result.receipt)) as Map<String, dynamic>;
          final r = malformed['receipt'] as Map;
          if (field == 'receiptTotal') {
            r[field] = 248;
          } else if (field == 'receiptTaxes') {
            (r[field] as List).single['taxAmount'] = 1;
          } else {
            (r[field] as List).single['taxPercent'] = 15;
          }
          expect(
            () => device.validateReceiptPayload(malformed),
            throwsA(isA<ZimraException>()),
          );
        }
        applyFiscalisation(
          doc,
          deviceId: 7,
          fiscalDayNo: 6,
          result: result,
          qrPayload: result.qrData,
          taxSnapshot: buildFiscalTaxSnapshot(
            treatments: [TaxTreatment.noTax],
            rates: [null],
            lines: lines.lines,
          ),
        );
        expect(doc.fiscalValidationLabel, 'Fiscalised — validation error');
        expect(doc.fiscalValidationDetails, hasLength(2));
        expect(
          doc.fiscalRecord!['response']['serverResponse']['receiptID'],
          11798797,
        );
        expect(guardDoubleFiscalisation(doc), isNotNull);
        doc.fiscalStatus =
            'pending'; // A receipt ID still prevents resubmission.
        expect(guardDoubleFiscalisation(doc), isNotNull);
        final before = jsonEncode(doc.toJson());
        api.taxId = id + 100;
        await device.getConfig();
        expect(jsonEncode(doc.toJson()), before);
        final restored = QuoteflowDocument.fromJson(
          jsonDecode(before) as Map<String, dynamic>,
        );
        expect(restored.fiscalRecord, doc.fiscalRecord);
        expect(restored.fiscalTaxSnapshot, doc.fiscalTaxSnapshot);
        await expectLater(
          device.closeDay(),
          throwsA(
            isA<ZimraException>().having((e) => e.code, 'code', 'DAY010'),
          ),
        );
        await expectLater(
          device.closeDay(force: true),
          throwsA(
            isA<ZimraException>().having((e) => e.code, 'code', 'DAY012'),
          ),
        );
        expect(
          api.posts,
          hasLength(1),
        ); // Neither closure path silently posts force.
      },
    );
  }

  test('validation warnings and snapshots survive Hive persistence', () async {
    final temp = await Directory.systemTemp.createTemp('fdms-validation-');
    Hive.init(temp.path);
    registerAdapters();
    var box = await Hive.openBox<QuoteflowDocument>('receipts');
    final doc = document()
      ..fiscalRecord = {
        'response': {
          'validationErrors': [
            {'code': 'W1', 'color': 'Yellow', 'description': 'Review'},
          ],
        },
      }
      ..fiscalTaxSnapshot = [
        {'zimra_tax_id': 927},
      ];
    await box.put('d', doc);
    await box.close();
    box = await Hive.openBox<QuoteflowDocument>('receipts');
    expect(
      box.get('d')!.fiscalValidationLabel,
      'Fiscalised — validation warning',
    );
    expect(box.get('d')!.fiscalTaxSnapshot!.single['zimra_tax_id'], 927);
    await box.close();
    await temp.delete(recursive: true);
  });

  testWidgets(
    'configuration is read-only and returned receipt errors are visible',
    (tester) async {
      late Directory temp;
      late Box box;
      late ZimraProvider provider;
      await tester.runAsync(() async {
        temp = await Directory.systemTemp.createTemp('fdms-ui-');
        Hive.init(temp.path);
        box = await Hive.openBox('fdms-ui');
        await box.putAll({
          'zimra_identity': const ZimraDeviceIdentity(
            deviceId: 7,
            serialNumber: 'TEST',
          ).toJson(),
          'zimra_credentials': const ZimraCredentials(
            privateKeyPem: '',
            certificatePem: '',
          ).toJson(),
          'zimra_config': ZimraConfig(
            applicableTaxes: [tax(927)],
            qrUrl: 'https://example.com/',
          ).toJson(),
          'zimra_manual_taxes': [tax(101, manual: true).toJson()],
          'zimra_receipt_history': [
            {
              'receipt': {},
              'response': const FiscalisedReceiptResponse(
                receiptId: 11798797,
                validationErrors: [
                  ValidationError(
                    code: 'TEST_RED',
                    color: 'Red',
                    description: 'Review this receipt',
                  ),
                ],
              ).toJson(),
            },
          ],
        });
        provider = ZimraProvider(box, transportFactory: () => FakeFdms());
        await provider.init();
      });
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: ZimraSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('taxID 927'), findsOneWidget);
      expect(find.text('FDMS'), findsOneWidget);
      expect(find.text('Local (not FDMS)'), findsOneWidget);
      expect(find.text('Add tax'), findsNothing);
      expect(find.byTooltip('Edit tax'), findsNothing);
      expect(
        find.textContaining('TEST_RED (Red): Review this receipt'),
        findsOneWidget,
      );
      expect(find.textContaining('Force close'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
      await tester.runAsync(() async {
        await box.close();
        await temp.delete(recursive: true);
      });
    },
  );
}
