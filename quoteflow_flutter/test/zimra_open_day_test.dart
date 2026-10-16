import 'package:flutter_test/flutter_test.dart';
import 'package:quoteflow/services/zimra/zimra_service.dart';

void main() {
  // Contract from /swagger/Device-v1/swagger.json: fiscalDayOpened is
  // mandatory, local time without a zone; fiscalDayNo is optional.
  test('default open-day request always supplies the required timestamp', () {
    final before = DateTime.now().subtract(const Duration(seconds: 1));
    final body = ZimraFiscalDevice.buildOpenDayRequest();
    expect(body.keys, unorderedEquals(['fiscalDayOpened']));
    final value = body['fiscalDayOpened'] as String;
    expect(value, matches(RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$')));
    final opened = DateTime.parse(value);
    expect(opened.isBefore(before), isFalse);
    expect(opened.isAfter(DateTime.now()), isFalse);
  });

  test('explicit day retains its number and complete local opening time', () {
    expect(
      ZimraFiscalDevice.buildOpenDayRequest(
        requestedDayNo: 1,
        openedAt: DateTime(2026, 9, 25, 8, 9, 10),
      ),
      {'fiscalDayNo': 1, 'fiscalDayOpened': '2026-09-25T08:09:10'},
    );
  });
}
