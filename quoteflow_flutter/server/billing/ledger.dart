import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'paynow.dart';

class FiscalReply {
  final int statusCode;
  final String rawBody;
  final bool uncertain;
  const FiscalReply(this.statusCode, this.rawBody, {this.uncertain = false});
  Map<String, dynamic> toJson() => {
    'statusCode': statusCode,
    'rawBody': rawBody,
    if (uncertain) 'uncertain': true,
  };
}

Object? _canonicalJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final key in keys) key: _canonicalJson(value[key])};
  }
  if (value is List) return value.map(_canonicalJson).toList();
  return value;
}

class CreditLedger {
  final Box box;
  Future<void> _operations = Future.value();
  CreditLedger(this.box);

  Future<T> locked<T>(Future<T> Function() action) {
    final result = _operations.then((_) => action());
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Map<String, dynamic> wallet(String tin) => box.get('wallet:$tin') == null
      ? {
          'trial': 20,
          'payments': <String, dynamic>{},
          'receipts': <String, dynamic>{},
        }
      : Map<String, dynamic>.from(
          jsonDecode(jsonEncode(box.get('wallet:$tin'))) as Map,
        );

  Future<void> saveWallet(String tin, Map<String, dynamic> data) async {
    await box.put('wallet:$tin', data);
    await box.flush();
  }

  Map<String, dynamic> totals(String tin) {
    final data = wallet(tin);
    final payments = data['payments'] as Map;
    final receipts = (data['receipts'] as Map).values.cast<Map>();
    final purchased = payments.values.cast<Map>().fold<int>(
      0,
      (total, item) =>
          total + (item['active'] == true ? item['credits'] as int : 0),
    );
    final reserved = receipts.where((r) => r['state'] == 'pending').length;
    final used = receipts.where((r) => r['state'] == 'accepted').length;
    return {
      'businessTin': tin,
      'available': (data['trial'] as int) + purchased - reserved - used,
      'trialGranted': data['trial'],
      'purchased': purchased,
      'used': used,
      'reserved': reserved,
    };
  }

  Future<void> ensureTrial(String tin) => locked(() async {
    if (!box.containsKey('wallet:$tin')) await saveWallet(tin, wallet(tin));
  });

  Future<void> payment(
    String tin,
    String reference,
    String paynowReference,
    String status,
  ) => locked(() async {
    final data = wallet(tin);
    final payments = data['payments'] as Map;
    final existing = payments[reference] as Map?;
    if (existing != null && existing['paynowReference'] != paynowReference) {
      throw const BillingError(409, 'Payment reference changed.');
    }
    for (final key in box.keys.whereType<String>().where(
      (key) => key.startsWith('wallet:'),
    )) {
      final otherPayments = (box.get(key) as Map)['payments'] as Map;
      for (final entry in otherPayments.entries) {
        if (key == 'wallet:$tin' && entry.key == reference) continue;
        if ((entry.value as Map)['paynowReference'] == paynowReference) {
          throw const BillingError(
            409,
            'This Paynow payment already belongs to another credit purchase.',
          );
        }
      }
    }
    final paid = const {
      'paid',
      'awaiting delivery',
      'delivered',
    }.contains(status.toLowerCase());
    final reversed = const {
      'cancelled',
      'refunded',
      'disputed',
      'reversed',
      'chargeback',
    }.contains(status.toLowerCase());
    final revoked =
        reversed ||
        existing?['revoked'] == true ||
        existing?['active'] == false;
    if (paid || reversed) {
      payments[reference] = {
        'credits': 500,
        'paynowReference': paynowReference,
        'active': paid && !revoked,
        'revoked': revoked,
      };
      await saveWallet(tin, data);
    }
  });

  Future<FiscalReply> fiscalise({
    required String tin,
    required int deviceId,
    required Map<String, dynamic> payload,
    required Future<FiscalReply> Function() send,
  }) => locked(() async {
    final receipt = Map<String, dynamic>.from(payload['receipt'] as Map);
    final signature = Map<String, dynamic>.from(
      receipt['receiptDeviceSignature'] as Map,
    );
    final number = receipt['receiptGlobalNo'];
    final hash = signature['hash'];
    if (number is! int || number <= 0 || hash is! String || hash.isEmpty) {
      throw const BillingError(400, 'Signed receipt identity is required.');
    }
    signature.remove('signature');
    receipt['receiptDeviceSignature'] = signature;
    final fingerprint = sha256
        .convert(utf8.encode(jsonEncode(_canonicalJson(receipt))))
        .toString();
    final id = '$deviceId:$number';
    var data = wallet(tin);
    var receipts = data['receipts'] as Map;
    final old = receipts[id] as Map?;
    if (old != null &&
        old['state'] != 'rejected' &&
        old['fingerprint'] != fingerprint) {
      throw const BillingError(
        409,
        'A different receipt already uses this fiscal number.',
      );
    }
    if (old != null &&
        old['fingerprint'] == fingerprint &&
        old['reply'] is Map) {
      final reply = old['reply'] as Map;
      return FiscalReply(
        reply['statusCode'] as int,
        reply['rawBody'] as String,
      );
    }
    final retry = old != null && old['state'] == 'pending';
    if (!retry && (totals(tin)['available'] as int) <= 0) {
      throw const BillingError(
        402,
        'No fiscalisation credits available. Top up your business balance.',
      );
    }
    receipts[id] = {
      'state': 'pending',
      'fingerprint': fingerprint,
      'uncertain': retry,
      'createdAt':
          old?['createdAt'] ?? DateTime.now().toUtc().toIso8601String(),
    };
    await saveWallet(tin, data);
    FiscalReply reply;
    try {
      reply = await send();
    } catch (_) {
      // Keep the reservation: FDMS may have accepted the receipt before the connection failed.
      return const FiscalReply(
        503,
        '{"title":"Fiscal submission outcome is unknown; retry the same signed receipt."}',
        uncertain: true,
      );
    }
    Map<String, dynamic> body = {};
    try {
      body = Map<String, dynamic>.from(jsonDecode(reply.rawBody) as Map);
    } catch (_) {}
    final accepted =
        reply.statusCode >= 200 &&
        reply.statusCode < 300 &&
        body['receiptID'] is num;
    final red = (body['validationErrors'] as List? ?? []).whereType<Map>().any(
      (e) => e['validationErrorColor']?.toString().toLowerCase() == 'red',
    );
    final definiteRejection =
        !retry && reply.statusCode >= 400 && reply.statusCode < 500;
    // Re-read so future changes to locking cannot overwrite a top-up.
    data = wallet(tin);
    receipts = data['receipts'] as Map;
    final entry = receipts[id] as Map;
    if (accepted || definiteRejection) {
      entry['state'] = accepted
          ? (red ? 'accepted_free' : 'accepted')
          : 'rejected';
      // Accepted receipts (including red responses) are never sent twice.
      if (accepted) entry['reply'] = reply.toJson();
      await saveWallet(tin, data);
      return reply;
    }
    return FiscalReply(reply.statusCode, reply.rawBody, uncertain: true);
  });
}
