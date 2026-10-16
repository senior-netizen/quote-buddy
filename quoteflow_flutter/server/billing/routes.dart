import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'ledger.dart';
import 'paynow.dart';
import 'service.dart';

Future<BillingService?> loadBilling({Map<String, String>? environment}) async {
  final env = environment ?? Platform.environment;
  final keyFile = env['PAYNOW_KEY_FILE'];
  final businessesFile = env['BILLING_BUSINESSES_FILE'];
  if (keyFile == null ||
      businessesFile == null ||
      env['BILLING_PUBLIC_URL'] == null) {
    return null;
  }
  final publicUrl = Uri.parse(env['BILLING_PUBLIC_URL']!);
  final live = env['PAYNOW_MODE'] == 'live';
  if (publicUrl.scheme != 'https' &&
      !(publicUrl.scheme == 'http' && publicUrl.host == 'localhost' && !live)) {
    throw StateError(
      'BILLING_PUBLIC_URL must use HTTPS (localhost HTTP is allowed only for testing).',
    );
  }
  if (publicUrl.userInfo.isNotEmpty ||
      publicUrl.hasQuery ||
      publicUrl.hasFragment) {
    throw StateError('Invalid billing public URL.');
  }
  final config = jsonDecode(await File(businessesFile).readAsString()) as List;
  final businesses = <VerifiedBusiness>[];
  final tins = <String>{};
  final devices = <int>{};
  for (final row in config.cast<Map>()) {
    if (row['testOnly'] == true && live) continue;
    if (row['verified'] != true && !(row['testOnly'] == true && !live)) {
      continue;
    }
    final tin = row['tin'] as String;
    final digest = row['tokenSha256'] as String;
    final ids = (row['deviceIds'] as List).cast<int>();
    if (!RegExp(r'^\d{10}$').hasMatch(tin) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest) ||
        !tins.add(tin) ||
        ids.isEmpty ||
        ids.any((id) => id <= 0 || !devices.add(id))) {
      throw StateError(
        'Billing business configuration contains invalid or duplicated identities.',
      );
    }
    businesses.add(VerifiedBusiness(tin, digest, ids));
  }
  final directory = Directory(env['BILLING_DATA_DIR'] ?? 'server/private/data');
  await directory.create(recursive: true);
  // Hive holds a file lock. Deploy one server process per ledger, with persistent storage.
  Hive.init(directory.absolute.path);
  final box = await Hive.openBox('billing_${live ? 'live' : 'test'}');
  final key = (await File(keyFile).readAsString()).trim();
  if (key.isEmpty) throw StateError('Paynow key file is empty.');
  return BillingService(
    ledger: CreditLedger(box),
    paynow: PaynowClient(
      key: key,
      integrationId: env['PAYNOW_INTEGRATION_ID'] ?? '27422',
    ),
    publicBaseUrl: publicUrl,
    businesses: businesses,
    live: live,
  );
}

Future<String> readLimited(
  HttpRequest request, {
  int limit = 1024 * 1024,
}) async {
  final bytes = <int>[];
  await for (final chunk in request.timeout(const Duration(seconds: 30))) {
    if (bytes.length + chunk.length > limit) {
      throw const BillingError(413, 'Request is too large.');
    }
    bytes.addAll(chunk);
  }
  return utf8.decode(bytes);
}

Future<void> billingJson(
  HttpResponse response,
  int status,
  Map<String, dynamic> body,
) async {
  response.statusCode = status;
  response.headers.contentType = ContentType.json;
  response.headers.set('Cache-Control', 'no-store');
  response.write(jsonEncode(body));
  await response.close();
}

Future<void> handleBilling(HttpRequest request, BillingService? service) async {
  try {
    if (service == null) {
      throw const BillingError(
        503,
        'Credit payments are not configured on this server yet.',
      );
    }
    final origin = request.headers.value('origin');
    if (origin != null && origin != service.publicBaseUrl.origin) {
      throw const BillingError(403, 'Origin is not allowed.');
    }
    if (origin != null) {
      request.response.headers.set('Access-Control-Allow-Origin', origin);
      request.response.headers.set('Vary', 'Origin');
      request.response.headers.set(
        'Access-Control-Allow-Headers',
        'Content-Type, Authorization',
      );
      request.response.headers.set(
        'Access-Control-Allow-Methods',
        'POST, GET, OPTIONS',
      );
    }
    if (request.method == 'OPTIONS') {
      request.response.statusCode = 204;
      await request.response.close();
      return;
    }
    if (request.uri.path == '/api/billing/return' && request.method == 'GET') {
      try {
        await service.returned(request.uri.queryParameters['reference'] ?? '');
      } catch (_) {
        // A failed lookup never turns the browser return into a paid result.
      }
      request.response.headers.contentType = ContentType.html;
      request.response.headers.set('Cache-Control', 'no-store');
      request.response.write(
        '<!doctype html><meta name="viewport" content="width=device-width"><title>QuoteFlow payment</title><h1>Return to QuoteFlow</h1><p>Refresh your credit balance in the app to view the verified payment result. This page does not confirm that payment succeeded.</p>',
      );
      await request.response.close();
      return;
    }
    if (request.method != 'POST') {
      throw const BillingError(405, 'POST required.');
    }
    final raw = await readLimited(request, limit: 32768);
    if (request.uri.path == '/api/paynow/result' ||
        request.uri.path == '/api/paynow/results') {
      await service.notification(raw);
      await billingJson(request.response, 200, {'received': true});
      return;
    }
    final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final business = service.authenticate(
      data['businessTin'] as String? ?? '',
      request.headers.value('authorization'),
    );
    Map<String, dynamic> result;
    switch (request.uri.path) {
      case '/api/billing/balance':
        result = await service.balance(business);
      case '/api/billing/topups':
        result = await service.createTopup(
          business,
          data['requestId'] as String? ?? '',
          method: data['method'] as String? ?? 'bank',
          phone: data['phone'] as String? ?? '',
          email: data['email'] as String? ?? '',
        );
      case '/api/billing/payment':
        result = data['completed'] == true
            ? await service.verifyPayment(
                business,
                data['reference'] as String? ?? '',
              )
            : service.paymentStatus(
                business,
                data['reference'] as String? ?? '',
              );
      default:
        throw const BillingError(404, 'Billing route was not found.');
    }
    await billingJson(request.response, 200, result);
  } on BillingError catch (error) {
    await billingJson(request.response, error.status, {'error': error.message});
  } on FormatException {
    await billingJson(request.response, 400, {'error': 'Invalid request.'});
  } on TypeError {
    await billingJson(request.response, 400, {
      'error': 'Invalid request fields.',
    });
  } catch (_) {
    await billingJson(request.response, 503, {
      'error':
          'Payment verification is temporarily unavailable. No unverified credits have been added.',
    });
  }
}
