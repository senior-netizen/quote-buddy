// ZimraConfig / ZimraTax parsing tests — regression coverage for the
// "type 'Null' is not a subtype of type 'int' in type cast" crash when
// tapping "Fiscalise with ZIMRA".
//
// Wire contract: FDMS GetConfigResponse (Device-v1 swagger). Tax rows use
// `taxID` (capital ID); the app previously cast `taxId`, which is null on
// every wire row, throwing in ZimraTax.fromJson.
import 'package:flutter_test/flutter_test.dart';
import 'package:quoteflow/services/fiscalisation.dart';
import 'package:quoteflow/services/zimra/zimra_models.dart';

/// Real FDMS TEST-env GetConfigResponse shape (relevant fields), per
/// TaxDefinition/GetConfigResponse in the zimra-fdms 0.4.0 SDK types.
Map<String, dynamic> wireConfig({
  List<Map<String, dynamic>>? taxes,
  String? taxIdKey,
}) => {
  'operationID': 'OP-1',
  'taxPayerName': 'Acme (Pvt) Ltd',
  'taxPayerTIN': '2000123456',
  'deviceSerialNo': 'FDMS-DEV-1',
  'deviceBranchName': 'Harare HQ',
  'deviceOperatingMode': 'Online',
  'taxPayerDayMaxHrs': 24,
  'certificateValidTill': '2027-01-01T00:00:00',
  'qrUrl': 'https://fdmsapitest.zimra.co.zw/',
  'taxpayerDayEndNotificationHrs': 2,
  'applicableTaxes':
      taxes ??
      [
        if (taxIdKey != null)
          {
            taxIdKey: 1,
            'taxName': 'Standard rate',
            'taxPercent': 15,
            'validFrom': '2024-01-01T00:00:00',
          }
        else ...[
          {
            'taxID': 1,
            'taxName': 'Standard rate',
            'taxPercent': 15,
            'validFrom': '2024-01-01T00:00:00',
          },
          {
            'taxID': 2,
            'taxName': 'Zero rate',
            'taxPercent': 0,
            'validFrom': '2024-01-01T00:00:00',
          },
        ],
      ],
};

void main() {
  group('ZimraConfig.fromJson — complete config', () {
    test('parses the real FDMS wire shape (taxID) fully', () {
      final cfg = ZimraConfig.fromJson(wireConfig());
      expect(cfg.qrUrl, 'https://fdmsapitest.zimra.co.zw/');
      expect(cfg.applicableTaxes, hasLength(2));
      expect(cfg.applicableTaxes[0].taxId, 1);
      expect(cfg.applicableTaxes[0].taxName, 'Standard rate');
      expect(cfg.applicableTaxes[0].taxPercent, 15.0);
      expect(cfg.applicableTaxes[0].isExempt, isFalse);
    });

    test('passes fiscalConfigProblem when complete', () {
      expect(fiscalConfigProblem(ZimraConfig.fromJson(wireConfig())), isNull);
    });
  });

  group('missing required integer field', () {
    test('tax row without any id spelling throws naming the field', () {
      expect(
        () => ZimraTax.fromJson({
          'taxName': 'Broken tax',
          'taxPercent': 15,
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('taxID'),
          ),
        ),
      );
    });

    test('config surfaces the missing taxID as a human-readable problem', () {
      final broken = wireConfig(
        taxes: [
          {'taxName': 'Broken tax', 'taxPercent': 15},
        ],
      );
      // Parsing itself must not fabricate a taxId — it must throw.
      expect(() => ZimraConfig.fromJson(broken), throwsFormatException);
    });
  });

  group('optional null / absent fields', () {
    test('absent taxPercent on an exempt tax parses to 0', () {
      final t = ZimraTax.fromJson({
        'taxID': 5,
        'taxName': 'Exempt',
        'isExempt': true,
      });
      expect(t.taxId, 5);
      expect(t.taxPercent, 0);
      expect(t.isExempt, isTrue);
    });

    test('explicit null taxPercent parses to 0 (exempt contract)', () {
      final t = ZimraTax.fromJson({
        'taxID': 6,
        'taxName': 'Exempt null percent',
        'taxPercent': null,
        'isExempt': true,
      });
      expect(t.taxId, 6);
      expect(t.taxPercent, 0);
    });

    test('missing qrUrl yields empty string, config is then rejected by '
        'the pre-flight validation instead of crashing', () {
      final cfg = ZimraConfig.fromJson({
        'applicableTaxes': [
          {'taxID': 1, 'taxName': 'Standard', 'taxPercent': 15},
        ],
      });
      expect(cfg.qrUrl, isEmpty);
      expect(fiscalConfigProblem(cfg), contains('QR URL'));
    });

    test('missing applicableTaxes yields an empty, validated-away config',
        () {
      final cfg = ZimraConfig.fromJson({'qrUrl': 'https://x.example/'});
      expect(cfg.applicableTaxes, isEmpty);
      expect(fiscalConfigProblem(cfg), contains('no applicable taxes'));
    });
  });

  group('integer representations', () {
    test('integer represented as JSON number', () {
      final t = ZimraTax.fromJson({
        'taxID': 9,
        'taxName': 'Num int',
        'taxPercent': 15,
      });
      expect(t.taxId, 9);
    });

    test('integer represented as a double on the wire (e.g. 9.0)', () {
      final t = ZimraTax.fromJson({
        'taxID': 9.0,
        'taxName': 'Num double',
        'taxPercent': 15.0,
      });
      expect(t.taxId, 9);
    });

    test('integer represented as numeric string', () {
      final t = ZimraTax.fromJson({
        'taxID': '9',
        'taxName': 'Str int',
        'taxPercent': '15',
      });
      expect(t.taxId, 9);
      expect(t.taxPercent, 15.0);
    });

    test('legacy locally-persisted taxId spelling still accepted', () {
      final t = ZimraTax.fromJson({
        'taxId': 42,
        'taxName': 'Legacy',
        'taxPercent': 15,
      });
      expect(t.taxId, 42);
    });

    test('non-numeric garbage id throws instead of defaulting to 0', () {
      expect(
        () => ZimraTax.fromJson({
          'taxID': 'abc',
          'taxName': 'Garbage',
          'taxPercent': 15,
        }),
        throwsFormatException,
      );
    });
  });

  group('parseNullableInt', () {
    test('null, int, num, numeric string, garbage', () {
      expect(parseNullableInt(null), isNull);
      expect(parseNullableInt(7), 7);
      expect(parseNullableInt(7.0), 7);
      expect(parseNullableInt('42'), 42);
      expect(parseNullableInt(' 7 '), 7); // int.tryParse trims spaces
      expect(parseNullableInt('x'), isNull);
      expect(parseNullableInt(true), isNull);
    });
  });

  group('device identity parsing', () {
    test('required deviceId missing throws naming the field', () {
      expect(
        () => ZimraDeviceIdentity.fromJson({'serialNumber': 'SN-1'}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('deviceId'),
          ),
        ),
      );
    });

    test('deviceId as numeric string accepted', () {
      final id = ZimraDeviceIdentity.fromJson({
        'deviceId': '123',
        'serialNumber': 'SN-1',
      });
      expect(id.deviceId, 123);
      expect(
        id.commonName,
        'ZIMRA-SN-1-0000000123',
      );
    });

    test('device_id snake_case alias accepted', () {
      final id = ZimraDeviceIdentity.fromJson({
        'device_id': 7,
        'serialNumber': 'SN-1',
      });
      expect(id.deviceId, 7);
    });
  });

  group('offline receipt (PendingReceipt) parsing', () {
    Map<String, dynamic> pending({
      Object? fiscalDayNo,
      Object? receiptGlobalNo,
    }) => {
      'id': 'p1',
      'receiptPayload': <String, dynamic>{'receipt': <String, dynamic>{}},
      'createdAt': '2026-09-25T10:00:00',
      'fiscalDayNo': fiscalDayNo,
      'receiptGlobalNo': receiptGlobalNo,
    };

    test('valid payload parses', () {
      final p = PendingReceipt.fromJson(pending(fiscalDayNo: 5, receiptGlobalNo: 7));
      expect(p.fiscalDayNo, 5);
      expect(p.receiptGlobalNo, 7);
    });

    test('missing fiscalDayNo throws naming the field, never 0', () {
      expect(
        () => PendingReceipt.fromJson(pending(receiptGlobalNo: 7)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('fiscalDayNo'),
          ),
        ),
      );
    });

    test('missing receiptGlobalNo throws naming the field, never 0', () {
      expect(
        () => PendingReceipt.fromJson(pending(fiscalDayNo: 5)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('receiptGlobalNo'),
          ),
        ),
      );
    });
  });
}
