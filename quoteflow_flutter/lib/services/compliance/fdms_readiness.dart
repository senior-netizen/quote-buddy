import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../zimra/zimra.dart';

const fdmsRegions = {
  'SCO': 'SCOfdmssupport@zimra.co.zw',
  'MCO': 'MCOfdmssupport@zimra.co.zw',
  'LCO': 'LCOfdmssupport@zimra.co.zw',
  'Region 2': 'Region2fdmssupport@zimra.co.zw',
  'Region 3': 'Region3fdmssupport@zimra.co.zw',
};
Object? _canonical(Object? v) {
  if (v is Map) {
    final keys = v.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in keys) k: _canonical(v[k])};
  }
  if (v is List) return v.map(_canonical).toList();
  return v;
}

String evidenceDigest(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(_canonical(value)))).toString();
String evidenceFileDigest(List<int> bytes) => sha256.convert(bytes).toString();
Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : {};
List<Map<String, dynamic>> _rows(Object? v) => v is List
    ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
    : [];
// Never retain authentication material, even if a malformed provider response contains it.
Object? _safe(Object? v) {
  if (v is Map)
    return {
      for (final e in v.entries)
        if (!RegExp(
          r'privatekey|activationkey|authorization|password|token|certificatepem|csr',
          caseSensitive: false,
        ).hasMatch(e.key.toString()))
          e.key.toString(): _safe(e.value),
    };
  if (v is List) return v.map(_safe).toList();
  return v;
}

class FdmsReadiness {
  final Map<String, dynamic> identity;
  Map<String, dynamic> metadata;
  final List<Map<String, dynamic>> events;
  FdmsReadiness({
    required this.identity,
    Map<String, dynamic>? metadata,
    List<Map<String, dynamic>>? events,
  }) : metadata = metadata ?? {},
       events = events ?? [];
  factory FdmsReadiness.fromJson(Map value) {
    if (value['schemaVersion'] != 1 ||
        value['identity'] is! Map ||
        value['events'] is! List)
      throw const FormatException(
        'Approval evidence could not be read. Preserve the stored data and recover it before proceeding.',
      );
    return FdmsReadiness(
      identity: _map(value['identity']),
      metadata: _map(value['metadata']),
      events: _rows(value['events']),
    );
  }
  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'identity': identity,
    'metadata': metadata,
    'events': events,
  };
  void record(
    String method,
    String path,
    Map<String, dynamic>? request,
    ZimraHttpResponse response,
    int? dayNo,
  ) {
    if (!path.startsWith('/Device/v1/${identity['deviceId']}/'))
      throw const FormatException('Evidence device mismatch.');
    final operation = path.split('/').last;
    if (!{
      'GetConfig',
      'OpenDay',
      'CloseDay',
      'GetStatus',
      'SubmitReceipt',
    }.contains(operation))
      return;
    final safeRequest = _map(_safe(request ?? {})),
        safeResponse = _map(_safe(response.body));
    final event = {
      'operation': operation,
      'method': method,
      'status': response.statusCode,
      'fiscalDayNo': operation == 'OpenDay'
          ? safeResponse['fiscalDayNo']
          : safeRequest['fiscalDayNo'] ?? dayNo,
      'request': safeRequest,
      'response': safeResponse,
    };
    final stable = {
      ...event,
      'response': {...safeResponse}
        ..remove('serverDate')
        ..remove('operationID'),
    };
    final fingerprint = evidenceDigest(stable);
    if ((operation == 'SubmitReceipt' &&
            events.any((e) => e['fingerprint'] == fingerprint)) ||
        (operation != 'OpenDay' &&
            operation != 'CloseDay' &&
            events.isNotEmpty &&
            events.last['fingerprint'] == fingerprint))
      return;
    final next = {
      ...event,
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
      'fingerprint': fingerprint,
    };
    if (events.length >= 250 ||
        utf8.encode(jsonEncode([...events, next])).length > 5 * 1024 * 1024)
      throw const FormatException(
        'Evidence capture is full. Export and archive this case before collecting more.',
      );
    events.add(next);
  }

  bool get metadataComplete =>
      RegExp(r'^[1-9]\d{9}$').hasMatch('${metadata['tin'] ?? ''}') &&
      [
        'businessName',
        'branch',
        'supplier',
        'orderNumber',
      ].every((k) => '${metadata[k] ?? ''}'.trim().isNotEmpty) &&
      fdmsRegions.containsKey(metadata['region']);
  bool _success(Map e) =>
      e['status'] is int &&
      (e['status'] as int) >= 200 &&
      (e['status'] as int) < 300;
  List<({int day, int start, int end})> get _closedRanges {
    final opened = <int, int>{}, requested = <int>{};
    final ranges = <({int day, int start, int end})>[];
    for (var i = 0; i < events.length; i++) {
      final e = events[i];
      if (!_success(e)) continue;
      final day = parseNullableInt(e['fiscalDayNo']);
      if (day == null || day <= 0) continue;
      if (e['operation'] == 'OpenDay') {
        opened[day] = i;
        requested.remove(day);
      }
      if (e['operation'] == 'CloseDay' && opened.containsKey(day))
        requested.add(day);
      if (e['operation'] == 'GetStatus' &&
          _map(e['response'])['fiscalDayStatus'] == 'FiscalDayClosed' &&
          requested.contains(day) &&
          opened.containsKey(day)) {
        ranges.add((day: day, start: opened.remove(day)!, end: i));
        requested.remove(day);
      }
    }
    return ranges;
  }

  Set<int> get completedDays => _closedRanges.map((r) => r.day).toSet();
  List<Map<String, dynamic>> get samples {
    final ranges = _closedRanges;
    return [
      for (var i = 0; i < events.length; i++)
        if (_sampleAccepted(events[i]) &&
            ranges.any(
              (r) =>
                  r.day == parseNullableInt(events[i]['fiscalDayNo']) &&
                  i > r.start &&
                  i < r.end,
            ))
          events[i],
    ];
  }

  bool _sampleAccepted(Map<String, dynamic> e) {
    final response = _map(e['response']);
    return e['operation'] == 'SubmitReceipt' &&
        _success(e) &&
        (parseNullableInt(response['receiptID']) ?? 0) > 0 &&
        (response['validationErrors'] == null ||
            (response['validationErrors'] is List &&
                (response['validationErrors'] as List).isEmpty));
  }

  String _taxKey(Map row) =>
      '${row['taxID'] ?? row['taxId']}:${row['isExempt'] == true || row['taxPercent'] == null ? 'exempt' : parseNullableDouble(row['taxPercent'])?.toStringAsFixed(4)}';
  Map<String, bool> get checks {
    final receipts = samples
        .map((e) => _map(_map(e['request'])['receipt']))
        .toList();
    final configs = events
        .where((e) => e['operation'] == 'GetConfig' && _success(e))
        .toList();
    final today = DateTime.now();
    List<Map<String, dynamic>> configuredTaxes = [];
    if (configs.isNotEmpty) {
      try {
        final taxes = _map(configs.last['response'])['applicableTaxes'];
        if (taxes is! List || taxes.isEmpty || taxes.any((t) => t is! Map))
          throw const FormatException('Invalid FDMS taxes.');
        configuredTaxes = ZimraConfig.fromJson(
          _map(configs.last['response']),
        ).applicableTaxes.map((t) => t.toJson()).toList();
      } catch (_) {
        /* Invalid FDMS configuration cannot satisfy tax coverage. */
      }
    }
    final expected = configs.isEmpty
        ? <String>{}
        : configuredTaxes
              .where((t) {
                if (t['isManual'] == true ||
                    t['source'] == 'local' ||
                    t['active'] == false)
                  return false;
                final from = DateTime.tryParse(
                  '${t['validFrom'] ?? t['taxValidFrom'] ?? ''}',
                );
                final until = DateTime.tryParse(
                  '${t['validTill'] ?? t['taxValidTill'] ?? ''}',
                );
                return (from == null || !from.isAfter(today)) &&
                    (until == null ||
                        !until.isBefore(
                          DateTime(today.year, today.month, today.day),
                        ));
              })
              .map(_taxKey)
              .toSet();
    final covered = receipts
        .expand((r) => _rows(r['receiptTaxes']))
        .map(_taxKey)
        .toSet();
    return {
      'Order, branch, taxpayer and regional support details': metadataComplete,
      'Confirmed opening and closing of a Test fiscal day':
          completedDays.isNotEmpty,
      'Accepted Fiscal Tax Invoice': receipts.any(
        (r) => r['receiptType'] == 'FiscalInvoice',
      ),
      'Accepted Credit Note with original receipt reference': receipts.any(
        (r) =>
            r['receiptType'] == 'CreditNote' &&
            _map(r['creditDebitNote']).isNotEmpty,
      ),
      'Accepted Debit Note with original receipt reference': receipts.any(
        (r) =>
            r['receiptType'] == 'DebitNote' &&
            _map(r['creditDebitNote']).isNotEmpty,
      ),
      'Multiple sale line items on an accepted invoice': receipts.any(
        (r) =>
            r['receiptType'] == 'FiscalInvoice' &&
            _rows(
                  r['receiptLines'],
                ).where((l) => l['receiptLineType'] == 'Sale').length >=
                2,
      ),
      'Accepted USD and ZiG (ZWG) transactions':
          receipts.any((r) => r['receiptCurrency'] == 'USD') &&
          receipts.any((r) => r['receiptCurrency'] == 'ZWG'),
      'Every applicable configured tax rate demonstrated':
          expected.isNotEmpty && expected.difference(covered).isEmpty,
      'Complete buyer name, TIN and address transmitted': receipts.any((r) {
        final b = _map(r['buyerData']), address = _map(b['buyerAddress']);
        return '${b['buyerRegisterName'] ?? ''}'.trim().isNotEmpty &&
            RegExp(r'^[1-9]\d{9}$').hasMatch('${b['buyerTIN'] ?? ''}') &&
            '${address['street'] ?? ''}'.trim().isNotEmpty &&
            '${address['city'] ?? ''}'.trim().isNotEmpty &&
            (b['vatNumber'] == null ||
                RegExp(r'^\d{9}$').hasMatch('${b['vatNumber']}'));
      }),
    };
  }

  bool get ready => checks.values.every((v) => v);
  bool get approvalRecorded =>
      ready && '${metadata['approvalReference'] ?? ''}'.trim().length >= 4;
  Map<String, dynamic> report() {
    final payload = {
      'guide':
          'FDMS Guide to Ordering and Registration of Fiscal Devices using FDMS Portals - Step 9',
      'environment': 'test',
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'submissionReady': ready,
      'zimraApproval':
          'External decision required; local checks and user-recorded references are not ZIMRA approval.',
      'checks': checks,
      'case': toJson(),
      'integrityNote':
          'Checksum detects file changes; it is not a ZIMRA signature or proof of official approval.',
    };
    return {...payload, 'sha256': evidenceDigest(payload)};
  }
}

class EvidenceTransport implements ZimraApi {
  final ZimraApi delegate;
  final Future<void> Function(
    String,
    String,
    Map<String, dynamic>?,
    ZimraHttpResponse,
  )
  record;
  final void Function(Object) onCaptureError;
  EvidenceTransport(this.delegate, this.record, this.onCaptureError);
  Future<ZimraHttpResponse> _call(
    String method,
    String path,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  ) async {
    final response = method == 'GET'
        ? await delegate.get(path, headers: headers)
        : await delegate.post(path, body: body ?? {}, headers: headers);
    try {
      await record(method, path, body, response);
    } catch (e) {
      try {
        onCaptureError(e);
      } catch (_) {
        /* Fiscal acknowledgements must survive diagnostic failures. */
      }
    }
    // Capturing evidence must never turn an accepted FDMS receipt into an apparent network failure.
    return response;
  }

  @override
  Future<ZimraHttpResponse> get(String path, {Map<String, String>? headers}) =>
      _call('GET', path, null, headers);
  @override
  Future<ZimraHttpResponse> post(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) => _call('POST', path, body, headers);
  @override
  void close() => delegate.close();
}
