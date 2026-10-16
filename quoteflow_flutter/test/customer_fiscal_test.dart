import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quoteflow/models/adapters.dart';
import 'package:quoteflow/models/client.dart';
import 'package:quoteflow/models/document.dart';
import 'package:quoteflow/models/organization.dart';
import 'package:quoteflow/services/fiscal_buyer_mapper.dart';
import 'package:quoteflow/services/zimra/buyer_contract.dart';
import 'package:quoteflow/services/tax_engine.dart';

class _LegacyClientAdapter extends TypeAdapter<Client> {
  @override
  int get typeId => 2;
  @override
  Client read(BinaryReader reader) => throw UnimplementedError();
  @override
  void write(BinaryWriter writer, Client obj) {
    final fields = [
      obj.id,
      obj.companyName,
      obj.address,
      obj.email,
      obj.phone,
      obj.orgId,
    ];
    writer.writeByte(fields.length);
    for (var i = 0; i < fields.length; i++) {
      writer.writeByte(i);
      writer.write(fields[i]);
    }
  }
}

void main() {
  Client business({bool vat = false}) => Client(
    id: 'c',
    companyName: 'ABC Hardware',
    customerType: 'business',
    registeredName: 'ABC Hardware Ltd',
    tin: '1234567890',
    vatRegistered: vat,
    vatNumber: vat ? '123456789' : null,
  );

  test(
    'ordinary individual can be saved and round-tripped without tax details',
    () {
      final c = Client.fromJson(Client(id: 'i', companyName: 'Jane').toJson());
      expect(c.customerType, 'individual');
      expect(c.tin, isNull);
      expect(FiscalBuyerMapper.map(c, include: false), isNull);
    },
  );
  test('business without VAT registration needs no VAT number', () {
    final c = business();
    final buyer = FiscalBuyerMapper.map(c, include: true)!.toJson();
    expect(buyer, {
      'buyerRegisterName': 'ABC Hardware Ltd',
      'buyerTIN': '1234567890',
    });
    c.vatNumber = 'stale';
    expect(
      FiscalBuyerMapper.map(
        c,
        include: true,
      )!.toJson().containsKey('vatNumber'),
      false,
    );
  });
  test(
    'VAT registered business maps exact case and optional nested fields',
    () {
      final c = business(vat: true)
        ..houseNo = '10'
        ..street = 'Example Road'
        ..city = 'Harare'
        ..province = 'Harare'
        ..suburb = 'Central'
        ..country = 'Zimbabwe'
        ..phone = '+263771234567'
        ..email = 'accounts@example.test'
        ..tradeName = 'ABC';
      final buyer = FiscalBuyerMapper.map(c, include: true)!.toJson();
      expect(buyer['vatNumber'], '123456789');
      expect(buyer.containsKey('VATNumber'), false);
      expect(buyer['buyerAddress'], {
        'houseNo': '10',
        'street': 'Example Road',
        'city': 'Harare',
        'province': 'Harare',
      });
      expect(buyer['buyerContacts'], {
        'phoneNo': '+263771234567',
        'email': 'accounts@example.test',
      });
      expect(FiscalBuyerMapper.problems(c), isEmpty);
    },
  );
  test(
    'requested incomplete buyer blocks; ordinary customer creation remains possible',
    () {
      final c = Client.fromJson({'id': 'c', 'company_name': 'Old customer'});
      expect(
        FiscalBuyerMapper.problems(c),
        containsAll(['Registered name', 'TIN']),
      );
      expect(
        () => FiscalBuyerMapper.map(c, include: true),
        throwsA(isA<FiscalBuyerException>()),
      );
      expect(FiscalBuyerMapper.map(c, include: false), isNull);
    },
  );
  test('TIN placeholders, whitespace and invalid length cannot reach FDMS', () {
    for (final tin in [
      '',
      'N/A',
      '0000000000',
      'CASH',
      'UNKNOWN',
      '123',
      'abcdefghij',
    ]) {
      final c = business()..tin = tin;
      expect(
        () => FiscalBuyerMapper.map(c, include: true),
        throwsA(isA<FiscalBuyerException>()),
        reason: tin,
      );
    }
    final c = business()..tin = ' 1234567890 ';
    expect(FiscalBuyerMapper.map(c, include: true)!.tin, '1234567890');
  });
  test('VAT number validated only for a requested VAT registered buyer', () {
    final c = business(vat: true)..vatNumber = null;
    expect(FiscalBuyerMapper.problems(c), contains('VAT registration number'));
    expect(FiscalBuyerMapper.map(c, include: false), isNull);
    c.vatNumber = '123';
    expect(
      () => FiscalBuyerMapper.map(c, include: true),
      throwsA(isA<FiscalBuyerException>()),
    );
  });
  test(
    'wire boundary rejects null, empty and partial objects including retries',
    () {
      validateReceiptBuyer({});
      for (final buyer in [
        null,
        {},
        {'buyerRegisterName': 'ABC'},
        {'buyerTIN': '1234567890'},
        {'buyerRegisterName': '', 'buyerTIN': null},
      ]) {
        expect(
          () => validateReceiptBuyer({'buyerData': buyer}),
          throwsA(isA<FiscalBuyerException>()),
        );
      }
      validateReceiptBuyer({
        'buyerData': FiscalBuyerMapper.map(business(), include: true)!.toJson(),
      });
    },
  );
  test('customer fields round-trip and are searchable', () {
    final c = business(vat: true)
      ..useFiscalDetails = true
      ..country = 'Zimbabwe'
      ..suburb = 'Avondale'
      ..tradeName = 'Tools'
      ..phone = '0771234567'
      ..email = 'abc@example.test';
    final restored = Client.fromJson(c.toJson());
    expect(restored.toJson(), c.toJson());
    for (final q in ['abc', 'TOOLS', '1234567890', '0771', 'example']) {
      expect(restored.matchesSearch(q), true);
    }
  });
  test(
    'legacy Hive rows survive adapter migration and subsequent saves',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'quoteflow-customer-migration',
      );
      Hive.init(dir.path);
      Hive.registerAdapter<Client>(_LegacyClientAdapter(), override: true);
      var box = await Hive.openBox<Client>('customers');
      await box.put(
        'old',
        Client(
          id: 'old',
          companyName: 'Legacy',
          address: 'Old address',
          orgId: 'org',
        ),
      );
      await box.close();
      Hive.registerAdapter<Client>(ClientAdapter(), override: true);
      box = await Hive.openBox<Client>('customers');
      final c = box.get('old')!;
      expect(c.companyName, 'Legacy');
      expect(c.address, 'Old address');
      expect(c.orgId, 'org');
      expect(c.useFiscalDetails, false);
      expect(c.vatRegistered, false);
      expect(c.tin, isNull);
      c.registeredName = 'Legacy Ltd';
      c.tin = '1234567890';
      c.country = 'Zimbabwe';
      await box.put('old', c);
      await box.close();
      box = await Hive.openBox<Client>('customers');
      expect(box.get('old')!.tin, '1234567890');
      expect(box.length, 1);
      await Hive.close();
      await dir.delete(recursive: true);
    },
  );
  test('RCPT043 keeps diagnostic code and explains buyer correction', () {
    final doc = QuoteflowDocument.fromJson({
      'fiscal_status': 'fiscalised',
      'fiscal_record': {
        'response': {
          'validationErrors': [
            {
              'code': 'RCPT043',
              'color': 'Red',
              'description': 'Mandatory buyer data fields are not provided',
            },
          ],
        },
      },
    });
    expect(doc.fiscalValidationLabel, contains('validation error'));
    expect(doc.fiscalValidationDetails.single, contains('RCPT043'));
    expect(
      doc.fiscalValidationDetails.single,
      contains('registered name and TIN'),
    );
    expect(QuoteflowDocument.fromJson(doc.toJson()).includeBuyerDetails, false);
  });
  test('buyer VAT status never changes seller tax calculations', () {
    final org = Organization(
      id: 'o',
      name: 'Non-VAT seller',
      currency: 'USD',
      taxEnabled: false,
    );
    final items = [LineItem(description: 'Goods', quantity: 1, unitPrice: 100)];
    for (final vat in [false, true]) {
      FiscalBuyerMapper.map(business(vat: vat), include: true);
      final totals = computeTotalsV2(items: items, org: org, discount: 0);
      expect(totals.taxAmount, 0);
      expect(totals.total, 100);
    }
  });
}
