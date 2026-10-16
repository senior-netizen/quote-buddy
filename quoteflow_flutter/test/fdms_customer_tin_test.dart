// End-to-end customer fiscal-details mapping tests.
//
// Traces: Client (Hive model) -> FiscalBuyerMapper -> BuyerData ->
// ZimraFiscalDevice.submitReceipt -> final serialized SubmitReceipt JSON
// captured by a scripted transport (no network, no live FDMS).
//
// Contract source: ZIMRA Device-v1 BuyerDto — buyerRegisterName (required,
// max 250), buyerTIN (required, exactly 10 digits), buyerTradeName (optional),
// vatNumber (lowercase, 9 digits), buyerAddress{}, buyerContacts{}.
// TIN and VAT number are independent fields and always strings.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quoteflow/models/client.dart';
import 'package:quoteflow/services/zimra/zimra.dart';
import 'package:quoteflow/services/fiscal_buyer_mapper.dart'
    show FiscalBuyerException, FiscalBuyerMapper;

/// Scripted FDMS transport — records the final wire JSON of every request.
class _RecordingApi implements ZimraApi {
  final List<Map<String, dynamic>> bodies = [];
  Object? failWith;

  @override
  Future<ZimraHttpResponse> post(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    bodies.add(jsonDecode(jsonEncode(body)) as Map<String, dynamic>);
    final failure = failWith;
    if (failure != null) throw failure;
    return const ZimraHttpResponse(statusCode: 200, body: {}, rawBody: '{}');
  }

  /// The receipt DTO of the last SubmitReceipt request (null if none yet).
  Map<String, dynamic>? get lastSubmitReceipt {
    for (final body in bodies.reversed) {
      if (body['receipt'] is Map) {
        return body['receipt'] as Map<String, dynamic>;
      }
    }
    return null;
  }

  @override
  Future<ZimraHttpResponse> get(String path, {Map<String, String>? headers}) {
    if (path.endsWith('/GetConfig')) {
      bodies.add({});
      return Future.value(
        ZimraHttpResponse(
          statusCode: 200,
          body: _configJson,
          rawBody: jsonEncode(_configJson),
        ),
      );
    }
    return post(path, body: const {});
  }

  @override
  void close() {}
}

const _configJson = {
  'qrUrl': 'https://verify.zimra.example/',
  'applicableTaxes': [
    {'taxId': 101, 'taxCode': '15', 'taxName': '15%', 'taxPercent': 15},
    {'taxId': 103, 'taxName': 'exempt', 'isExempt': true},
  ],
};

const taxableLines = [
  ReceiptLineInput(
    name: 'Goods',
    price: 100,
    quantity: 1,
    taxId: 101,
    taxPercent: 15,
    taxCode: '15',
  ),
];

/// The report's critical customer: TIN "2002367529", VAT "200236752".
Client criticalCustomer() => Client(
  id: 'c-124',
  companyName: 'ABC Hardware',
  customerType: 'business',
  registeredName: 'ABC Hardware Ltd',
  tin: '2002367529',
  vatRegistered: true,
  vatNumber: '200236752',
);

void main() {
  late ZimraCredentials credentials;
  late _RecordingApi api;

  setUp(() {
    final pair = generateKeyPair();
    credentials = ZimraCredentials(
      privateKeyPem: encodePrivateKeyPem(pair.privateKey),
      certificatePem: '',
    );
    api = _RecordingApi();
    ZimraFiscalDevice.logTraffic = false;
    ZimraFiscalDevice.trafficLogger = null;
  });

  /// Open device + config, then submit a receipt for [buyer]. Returns the
  /// receipt portion of the FINAL serialized request the device produced
  /// (null when the device never built one).
  Future<Map<String, dynamic>?> submitWith(
    BuyerData? buyer, {
    bool offline = false,
  }) async {
    final device = ZimraFiscalDevice(
      identity: const ZimraDeviceIdentity(
        deviceId: 38513,
        serialNumber: '2002367692-026',
      ),
      credentials: credentials,
      environment: ZimraEnvironment.test,
      dayState: FiscalDayState(
        fiscalDayNo: 1,
        fiscalDayDate: '2026-09-25',
        status: FiscalDayStatus.fiscalDayOpened,
      ),
      transport: api,
    );
    api.failWith = offline ? StateError('network down') : null;
    await device.getConfig();
    try {
      await device.submitReceipt(
        currency: 'USD',
        invoiceNo: 'INV-2026-0124',
        lines: taxableLines,
        payments: const [ReceiptPayment(moneyType: 'Cash', amount: 11500)],
        linesTaxInclusive: false,
        buyer: buyer,
      );
    } catch (_) {
      // Failures are asserted by callers via the captured request list.
    }
    return api.lastSubmitReceipt;
  }

  group('A/B — valid TIN (+ VAT) mapped verbatim onto the wire', () {
    test('critical case: final JSON carries TIN 2002367529 unchanged',
        () async {
      final buyer = FiscalBuyerMapper.map(criticalCustomer(), include: true);
      expect(buyer, isNotNull, reason: 'valid customer must map');

      final receipt = (await submitWith(buyer))!;
      final buyerData = receipt['buyerData'] as Map<String, dynamic>;

      // The critical assertion: the serialized wire JSON contains the
      // complete TIN exactly as stored.
      expect(jsonEncode(receipt), contains('"2002367529"'));
      expect(buyerData['buyerTIN'], '2002367529');
      expect(buyerData['buyerTIN'], isA<String>(),
          reason: 'TIN must stay a string, never an int');
      // VAT is its own independent field, also a string, never derived
      // from (or truncating) the TIN.
      expect(buyerData['vatNumber'], '200236752');
      expect(buyerData['vatNumber'], isA<String>());
      expect(buyerData['buyerRegisterName'], 'ABC Hardware Ltd');
      expect(buyerData.containsKey('VATNumber'), isFalse,
          reason: 'FDMS spells it vatNumber');
    });

    test('TIN-only customer (no VAT) never gains a vatNumber field', () async {
      final customer = criticalCustomer()
        ..vatRegistered = false
        ..vatNumber = null;
      final receipt = (await submitWith(
        FiscalBuyerMapper.map(customer, include: true),
      ))!;
      final buyerData = receipt['buyerData'] as Map<String, dynamic>;
      expect(buyerData['buyerTIN'], '2002367529');
      expect(buyerData.containsKey('vatNumber'), isFalse,
          reason: 'non-VAT buyers never send vatNumber');
    });
  });

  group('C — non-VAT customer with valid TIN (incl. stale vatNumber)', () {
    test('stale VAT number is dropped, TIN preserved', () {
      final customer = criticalCustomer()
        ..vatRegistered = false
        ..vatNumber = 'stale999';
      final buyer = FiscalBuyerMapper.map(customer, include: true)!.toJson();
      expect(buyer['buyerTIN'], '2002367529');
      expect(buyer.containsKey('vatNumber'), isFalse);
    });
  });

  group('D — customer without TIN is blocked locally, pre-HTTP', () {
    test('missing TIN raises the precise requirement-8 error', () {
      final customer = criticalCustomer()..tin = null;
      expect(
        FiscalBuyerMapper.problems(customer),
        contains('TIN'),
      );
      expect(
        () => FiscalBuyerMapper.map(customer, include: true),
        throwsA(
          isA<FiscalBuyerException>().having(
            (e) => e.toString(),
            'message',
            contains('Customer TIN is required for fiscalisation.'),
          ),
        ),
      );
    });

    test('whitespace-only TIN is normalized to missing and blocked', () {
      final customer = criticalCustomer()..tin = '   ';
      expect(() => FiscalBuyerMapper.map(customer, include: true),
          throwsA(isA<FiscalBuyerException>()));
    });

    test('nothing reaches the transport when validation fails', () async {
      final customer = criticalCustomer()..tin = null;
      // The UI path: problems() gate before any submission is attempted.
      expect(FiscalBuyerMapper.problems(customer), contains('TIN'));
      // And a caller that ignores the gate is still stopped pre-transport.
      expect(
        () => FiscalBuyerMapper.map(customer, include: true),
        throwsA(isA<FiscalBuyerException>()),
      );
      expect(api.bodies, isEmpty,
          reason: 'validation failure means no FDMS HTTP request');
    });
  });

  group('E/F — fiscal-details toggle', () {
    test('OFF: buyer is omitted from the request entirely', () async {
      final buyer = FiscalBuyerMapper.map(criticalCustomer(), include: false);
      expect(buyer, isNull);
      final receipt = (await submitWith(buyer))!;
      expect(receipt.containsKey('buyerData'), isFalse);
    });

    test('ON: buyer rides on the request with the saved TIN', () async {
      final buyer = FiscalBuyerMapper.map(criticalCustomer(), include: true);
      final receipt = (await submitWith(buyer))!;
      expect((receipt['buyerData'] as Map)['buyerTIN'], '2002367529');
    });
  });

  group('G — customers created before fiscal fields existed', () {
    test('legacy JSON client maps only what it has; still needs a TIN', () {
      final legacy = Client.fromJson({
        'id': 'old-1',
        'company_name': 'Old Customer',
        'address': '12 Old Street',
      });
      expect(legacy.tin, isNull);
      expect(legacy.useFiscalDetails, isFalse);
      expect(FiscalBuyerMapper.map(legacy, include: false), isNull);
      expect(
        FiscalBuyerMapper.problems(legacy),
        containsAll(['Registered name', 'TIN']),
      );
    });

    test('backfilled legacy client fiscalises with exactly what was saved',
        () async {
      final legacy = Client.fromJson({
        'id': 'old-2',
        'company_name': 'Backfilled Co',
        'registered_name': 'Backfilled Co Ltd',
        'tin': '2002367529',
      });
      final receipt = (await submitWith(
        FiscalBuyerMapper.map(legacy, include: true),
      ))!;
      final buyerData = receipt['buyerData'] as Map<String, dynamic>;
      expect(buyerData, {
        'buyerRegisterName': 'Backfilled Co Ltd',
        'buyerTIN': '2002367529',
      });
    });
  });

  group('H — TIN survives JSON serialization unchanged', () {
    test('BuyerData.toJson round-trips TIN and VAT as strings', () {
      final buyer = FiscalBuyerMapper.map(criticalCustomer(), include: true)!;
      final restored = jsonDecode(jsonEncode(buyer.toJson()))
          as Map<String, dynamic>;
      expect(restored['buyerTIN'], '2002367529');
      expect(restored['buyerTIN'], isA<String>());
      expect(restored['vatNumber'], '200236752');
      expect(restored['vatNumber'], isA<String>());
    });

    test('TIN is not mangled by int parsing anywhere on the path', () {
      // A leading-zero or all-digit TIN must never be coerced to num.
      final customer = criticalCustomer()..tin = '0123456789';
      final buyer = FiscalBuyerMapper.map(customer, include: true)!.toJson();
      expect(buyer['buyerTIN'], '0123456789');
      expect(buyer['buyerTIN'], isA<String>());
    });

    test('Client normalizes whitespace at the model boundary itself', () {
      // Whitespace is trimmed on construction so the UI ("TIN: …") and
      // the FDMS buyer mapping can never disagree about presence.
      final customer = criticalCustomer()
        ..tin = ' 2002367529 '
        ..vatNumber = ' 200236752 ';
      expect(customer.tin, '2002367529');
      expect(customer.vatNumber, '200236752');
      final restored = Client.fromJson(customer.toJson());
      expect(restored.tin, '2002367529');
      expect(restored.vatNumber, '200236752');
    });

    test('blank or non-string TIN/VAT collapse to null, never fake presence',
        () {
      for (final bad in ['', '   ']) {
        expect(Client(id: 'x', companyName: 'X', tin: bad).tin, isNull,
            reason: 'blank tin -> null');
        expect(Client(id: 'x', companyName: 'X', vatNumber: bad).vatNumber,
            isNull, reason: 'blank vat -> null');
      }
      final fromBadJson = Client.fromJson(
        {'id': 'x', 'company_name': 'X', 'tin': 2002367529},
      );
      expect(fromBadJson.tin, isNull,
          reason: 'a numeric TIN in stored JSON must not crash or fake '
              'presence; the validator reports it as a type problem when '
              'a raw map reaches it');
    });
  });

  group('normalization at the FDMS boundary', () {
    test('trimmed but never truncated', () {
      final customer = criticalCustomer()
        ..tin = ' 2002367529 '
        ..vatNumber = ' 200236752 '
        ..registeredName = '  ABC Hardware Ltd  ';
      final buyer = FiscalBuyerMapper.map(customer, include: true)!.toJson();
      expect(buyer['buyerTIN'], '2002367529');
      expect(buyer['vatNumber'], '200236752');
      expect(buyer['buyerRegisterName'], 'ABC Hardware Ltd');
    });

    test('empty strings become absent optional fields', () {
      final customer = criticalCustomer()
        ..vatRegistered = true
        ..vatNumber = ''
        ..tradeName = '';
      // VAT registered with an empty number is a validation problem, not a
      // silent omission.
      expect(FiscalBuyerMapper.problems(customer),
          contains('VAT registration number'));
    });

    test('invalid TIN shapes stay blocked (no weakening)', () {
      for (final tin in ['200236752', '20023675291', '0000000000', 'CASH']) {
        final customer = criticalCustomer()..tin = tin;
        expect(() => FiscalBuyerMapper.map(customer, include: true),
            throwsA(isA<FiscalBuyerException>()), reason: tin);
      }
    });
  });

  test('offline signing preserves buyerData for the queued retry', () async {
    final buyer = FiscalBuyerMapper.map(criticalCustomer(), include: true);
    final receipt = (await submitWith(buyer, offline: true))!;
    expect((receipt['buyerData'] as Map)['buyerTIN'], '2002367529');
  });
}
