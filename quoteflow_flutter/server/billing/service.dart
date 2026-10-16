import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'ledger.dart';
import 'paynow.dart';

class VerifiedBusiness {
  final String tin;
  final String tokenHash;
  final List<int> deviceIds;
  const VerifiedBusiness(this.tin, this.tokenHash, this.deviceIds);
}

class BillingService {
  final CreditLedger ledger;
  final PaynowGateway paynow;
  final Uri publicBaseUrl;
  final bool live;
  final List<VerifiedBusiness> businesses;
  final Map<String, Future<void>> _paymentOperations = {};
  BillingService({
    required this.ledger,
    required this.paynow,
    required this.publicBaseUrl,
    required this.businesses,
    this.live = false,
  });

  VerifiedBusiness authenticate(String tin, String? authorization) {
    final token = authorization?.startsWith('Bearer ') == true
        ? authorization!.substring(7)
        : '';
    final digest = sha256.convert(utf8.encode(token)).toString();
    for (final business in businesses) {
      if (business.tin == tin &&
          token.isNotEmpty &&
          constantTimeEqual(digest, business.tokenHash)) {
        return business;
      }
    }
    throw const BillingError(
      401,
      'Business access code is invalid or has been revoked.',
    );
  }

  Future<Map<String, dynamic>> balance(VerifiedBusiness business) async {
    await ledger.ensureTrial(business.tin);
    final orders =
        ledger.box.keys
            .whereType<String>()
            .where((key) => key.startsWith('order:'))
            .map((key) => Map<String, dynamic>.from(ledger.box.get(key) as Map))
            .where((order) => order['tin'] == business.tin)
            .toList()
          ..sort(
            (a, b) =>
                (b['createdAt'] as String).compareTo(a['createdAt'] as String),
          );
    return {
      ...ledger.totals(business.tin),
      'mode': live ? 'live' : 'test',
      'deviceIds': business.deviceIds,
      'payments': orders.take(50).map(publicOrder).toList(),
    };
  }

  Map<String, dynamic> publicOrder(Map<String, dynamic> order) => {
    'reference': order['reference'],
    'status': order['status'],
    'amount': '5.00',
    'currency': 'USD',
    'credits': 500,
    'createdAt': order['createdAt'],
    'method': order['method'] ?? 'bank',
    if (order['checkoutUrl'] != null) 'checkoutUrl': order['checkoutUrl'],
  };

  Map<String, dynamic> order(String reference) {
    final data = ledger.box.get('order:$reference');
    if (data is! Map) throw const BillingError(404, 'Payment was not found.');
    return Map<String, dynamic>.from(data);
  }

  Future<void> _saveOrder(Map<String, dynamic> order) async {
    await ledger.box.put('order:${order['reference']}', order);
    await ledger.box.flush();
  }

  Future<Map<String, dynamic>> createTopup(
    VerifiedBusiness business,
    String requestId, {
    String method = 'bank',
    String phone = '',
    String email = '',
  }) async {
    if (!const {'ecocash', 'telecash', 'bank'}.contains(method)) {
      throw const BillingError(400, 'Choose a supported payment method.');
    }
    phone = phone.replaceAll(RegExp(r'[\s()-]'), '');
    if (phone.startsWith('+263')) phone = '0${phone.substring(4)}';
    if (method == 'ecocash' &&
        (!RegExp(r'^07[78]\d{7}$').hasMatch(phone) ||
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email))) {
      throw const BillingError(
        400,
        'Enter a valid EcoCash number and email address.',
      );
    }
    if (!RegExp(r'^[a-zA-Z0-9-]{16,64}$').hasMatch(requestId)) {
      throw const BillingError(400, 'Invalid top-up request identifier.');
    }
    // Persist before contacting Paynow. A timed-out initiation is not automatically retried.
    final payment = await ledger.locked(() async {
      final old =
          ledger.box.get('request:${business.tin}:$requestId') as String?;
      if (old != null) return order(old);
      for (final key in ledger.box.keys.whereType<String>().where(
        (key) => key.startsWith('order:'),
      )) {
        final existing = Map<String, dynamic>.from(ledger.box.get(key) as Map);
        if (existing['tin'] == business.tin &&
            const {
              'Initiating',
              'InitiationUnknown',
              'Pending',
              'Ok',
              'Created',
              'Sent',
            }.contains(existing['status'])) {
          return existing;
        }
      }
      final reference = const Uuid().v4();
      final data = <String, dynamic>{
        'reference': reference,
        'tin': business.tin,
        'status': 'Initiating',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'requestId': requestId,
        'method': method,
      };
      await _saveOrder(data);
      await ledger.box.put('request:${business.tin}:$requestId', reference);
      await ledger.box.flush();
      return {...data, '_new': true};
    });
    if (payment.remove('_new') != true) return publicOrder(payment);
    final reference = payment['reference'] as String;
    try {
      final result = await paynow.initiate({
        if (method == 'ecocash') ...{
          'method': 'ecocash',
          'phone': phone,
          'authemail': email.trim(),
        },
        'reference': reference,
        'amount': '5.00',
        'additionalinfo':
            '${live ? '' : 'TEST — '}QuoteFlow: 500 fiscalisation credits',
        'returnurl': publicBaseUrl
            .resolve('/api/billing/return?reference=$reference')
            .toString(),
        'resulturl': publicBaseUrl.resolve('/api/paynow/results').toString(),
      });
      if (result['status']?.toLowerCase() != 'ok') {
        throw const BillingError(
          502,
          'Paynow could not start checkout. Contact support before starting another payment.',
        );
      }
      final checkout = method == 'ecocash'
          ? null
          : trustedPaynowUrl(result['browserurl'] ?? '').toString();
      final poll = trustedPaynowUrl(result['pollurl'] ?? '').toString();
      await _serialPayment(reference, () async {
        final current = order(reference);
        if (current['pollUrl'] != null && current['pollUrl'] != poll) {
          throw const BillingError(409, 'Payment status URL changed.');
        }
        current['pollUrl'] = poll;
        if (checkout != null) current['checkoutUrl'] = checkout;
        if (current['status'] == 'Initiating' ||
            current['status'] == 'InitiationUnknown') {
          current['status'] = 'Pending';
        }
        await _saveOrder(current);
      });
    } catch (_) {
      await _serialPayment(reference, () async {
        final current = order(reference);
        if (current['status'] == 'Initiating') {
          current['status'] = 'InitiationUnknown';
          await _saveOrder(current);
        }
      });
    }
    return publicOrder(order(reference));
  }

  Future<T> _serialPayment<T>(String reference, Future<T> Function() action) {
    final previous = _paymentOperations[reference] ?? Future<void>.value();
    final result = previous.then((_) => action());
    _paymentOperations[reference] = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  void _validateMessage(
    Map<String, String> message,
    Map<String, dynamic> data,
  ) {
    if (message['currency'] != null &&
        message['currency']!.toUpperCase() != 'USD') {
      throw const BillingError(400, 'The credit purchase must be paid in USD.');
    }
    if (message['reference'] != data['reference'] ||
        !RegExp(r'^5(?:\.0{1,2})?$').hasMatch(message['amount'] ?? '') ||
        (message['paynowreference'] ?? '').isEmpty) {
      throw const BillingError(
        400,
        'Payment details do not match the credit purchase.',
      );
    }
    if (data['paynowReference'] != null &&
        data['paynowReference'] != message['paynowreference']) {
      throw const BillingError(409, 'Payment provider reference changed.');
    }
  }

  Future<void> notification(String raw) async {
    final message = paynow.decode(
      raw,
    ); // Authenticates before using any URL or reference.
    final reference = message['reference'] ?? '';
    await _serialPayment(reference, () async {
      final data = order(reference);
      _validateMessage(message, data);
      final poll = trustedPaynowUrl(message['pollurl'] ?? '').toString();
      if (data['pollUrl'] != null && data['pollUrl'] != poll) {
        throw const BillingError(409, 'Payment status URL changed.');
      }
      data['pollUrl'] = poll;
      await _saveOrder(data);
      await _verify(data); // Callback alone never issues credits.
    });
  }

  Future<void> _verify(Map<String, dynamic> data) async {
    if (data['pollUrl'] == null) return;
    final result = await paynow.poll(data['pollUrl'] as String);
    _validateMessage(result, data);
    if (result['pollurl'] != data['pollUrl']) {
      throw const BillingError(409, 'Payment status URL changed.');
    }
    final status = result['status'] ?? '';
    await ledger.payment(
      data['tin'] as String,
      data['reference'] as String,
      result['paynowreference']!,
      status,
    );
    final reversed = const {
      'cancelled',
      'refunded',
      'disputed',
      'reversed',
      'chargeback',
    };
    if (!reversed.contains((data['status'] as String).toLowerCase()) ||
        reversed.contains(status.toLowerCase())) {
      data['status'] = status;
    }
    data['paynowReference'] = result['paynowreference'];
    await _saveOrder(data);
  }

  Future<void> returned(
    String reference,
  ) => _serialPayment(reference, () async {
    // A return is only a signal to check Paynow; it is never proof of payment.
    await _verify(order(reference));
  });

  Map<String, dynamic> paymentStatus(
    VerifiedBusiness business,
    String reference,
  ) {
    final data = order(reference);
    if (data['tin'] != business.tin) {
      throw const BillingError(404, 'Payment was not found.');
    }
    return publicOrder(data);
  }

  Future<Map<String, dynamic>> verifyPayment(
    VerifiedBusiness business,
    String reference,
  ) async {
    paymentStatus(
      business,
      reference,
    ); // Ownership check before any network call.
    await _serialPayment(reference, () => _verify(order(reference)));
    return paymentStatus(business, reference);
  }

  Future<FiscalReply> fiscalise(
    VerifiedBusiness business,
    int deviceId,
    Map<String, dynamic> payload,
    Future<FiscalReply> Function() send,
  ) {
    if (!live) {
      throw const BillingError(
        403,
        'Paynow is in testing. Test credits cannot fund production fiscalisation.',
      );
    }
    if (!business.deviceIds.contains(deviceId)) {
      throw const BillingError(
        403,
        'This fiscal device is not registered to the connected business.',
      );
    }
    return ledger.fiscalise(
      tin: business.tin,
      deviceId: deviceId,
      payload: payload,
      send: send,
    );
  }
}
