import 'package:flutter_test/flutter_test.dart';
import 'package:quoteflow/services/billing/billing_http_common.dart';

void main() {
  test('undeployed onboarding reports the unavailable account service', () {
    for (final status in [404, 405]) {
      expect(
        () => decodeBillingResponse(
          status,
          '<html>Not found</html>',
          path: '/api/onboarding',
        ),
        throwsA(
          isA<BillingClientException>()
              .having((e) => e.status, 'status', status)
              .having(
                (e) => e.message,
                'message',
                contains('not available on the server yet'),
              ),
        ),
      );
    }
  });
  test(
    'non-JSON server failures retain their status and safe recovery message',
    () {
      expect(
        () => decodeBillingResponse(503, '<html>Unavailable</html>'),
        throwsA(
          isA<BillingClientException>()
              .having((e) => e.status, 'status', 503)
              .having(
                (e) => e.message,
                'message',
                contains('temporarily unavailable'),
              ),
        ),
      );
    },
  );
  test(
    'malformed success is rejected and structured errors remain readable',
    () {
      expect(
        () => decodeBillingResponse(200, '<html>Login</html>'),
        throwsA(
          isA<BillingClientException>().having((e) => e.status, 'status', 502),
        ),
      );
      expect(
        () => decodeBillingResponse(400, '{"error":{"internal":"private"}}'),
        throwsA(
          isA<BillingClientException>().having(
            (e) => e.message,
            'message',
            'The credit request failed.',
          ),
        ),
      );
      expect(
        () => decodeBillingResponse(401, '{"error":"Sign in again."}'),
        throwsA(
          isA<BillingClientException>().having(
            (e) => e.message,
            'message',
            'Sign in again.',
          ),
        ),
      );
      expect(decodeBillingResponse(200, '{"saved":true}'), {'saved': true});
    },
  );
}
