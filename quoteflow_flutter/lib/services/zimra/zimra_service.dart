/// Core fiscal device logic for ZIMRA FDMS.
library;

///
/// Ported from zimra-fdms TypeScript SDK v0.4.0.
/// Implements: canonical signing string, hash chain, counter accumulation,
/// receipt submission, fiscal day lifecycle, offline queue, and QR data.
///
/// See https://zimrasdk.com/docs for the full protocol specification.
import 'dart:convert';
import 'buyer_contract.dart';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'zimra_api.dart';
import 'zimra_crypto.dart';
import 'zimra_models.dart';
import 'zimra_transport.dart';

/// Thrown when a ZIMRA FDMS operation fails.
class ZimraException implements Exception {
  final String code;
  final String message;
  final bool isRed;

  /// For RCP030 (offline queueing): the signed request that was journaled,
  /// so callers can persist it for a later retry.
  final Map<String, dynamic>? receiptPayload;

  const ZimraException(
    this.code,
    this.message, {
    this.isRed = false,
    this.receiptPayload,
  });

  @override
  String toString() => 'ZIMRA $code: $message';
}

/// Main fiscal device — handles registration, receipts, days, and offline queue.
class ZimraFiscalDevice {
  final ZimraDeviceIdentity identity;
  final ZimraCredentials credentials;
  final ZimraEnvironment environment;

  late final ZimraApi _transport;
  ZimraConfig? _config;
  FiscalDayState _dayState;

  /// Pending receipts for offline queue.
  final List<PendingReceipt> offlineQueue;

  ZimraFiscalDevice({
    required this.identity,
    required this.credentials,
    this.environment = ZimraEnvironment.test,
    FiscalDayState? dayState,
    List<PendingReceipt>? offlineQueue,
    ZimraApi? transport,
    ZimraConfig? config,
  }) : _dayState = dayState ?? FiscalDayState(),
       offlineQueue = offlineQueue ?? [] {
    // Seed the cached FDMS configuration so receipt signing/verification
    // work without a fresh GetConfig round-trip (submitReceipt requires
    // it — RCP002). A device that fetches its own config replaces this.
    _config = config;
    _transport =
        transport ??
        ZimraTransport(
          baseUrl: environment.baseUrl,
          certificatePem: credentials.certificatePem,
          privateKeyPem: credentials.privateKeyPem,
          defaultHeaders: identity.requestHeaders,
        );
  }

  ZimraConfig? get config => _config;
  FiscalDayState get dayState => _dayState;
  bool get isOpen => _dayState.isOpen;

  // ---------------------------------------------------------------------------
  // TEST/debug traffic diagnostics
  // ---------------------------------------------------------------------------

  /// Master switch for request/response logging. Only ever active in debug
  /// builds against the TEST environment — release builds never log.
  static bool logTraffic = kDebugMode;

  /// Optional sink for traffic diagnostics (tests capture output here).
  /// When null, messages go to [debugPrint].
  static void Function(String message)? trafficLogger;

  /// Key fragments whose values must never reach the log. Private keys,
  /// certificates and credentials live in headers/TLS, not in request
  /// bodies — this is belt-and-braces in case that ever changes.
  static const List<String> _sensitiveKeyFragments = [
    'privatekey',
    'secret',
    'password',
    'passphrase',
    'token',
    'authorization',
    'credential',
    'activationkey',
    'certificatepem',
    'publickeypem',
    'csrpem',
  ];

  /// Deep-copy a value, redacting anything that looks like key material.
  static Object? _sanitized(Object? value) {
    if (value is Map) {
      return {
        for (final e in value.entries)
          e.key.toString():
              _sensitiveKeyFragments.contains(e.key.toString().toLowerCase())
              ? '***'
              : _sanitized(e.value),
      };
    }
    if (value is List) return value.map(_sanitized).toList();
    if (value is String && value.contains('PRIVATE KEY')) return '***';
    return value;
  }

  static Object? _buyerShape(Object? value) {
    if (value is Map)
      return {
        for (final e in value.entries) e.key.toString(): _buyerShape(e.value),
      };
    return value is String
        ? '<redacted: ' + value.length.toString() + ' characters>'
        : value;
  }

  static String _pretty(Object? value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(_sanitized(value));
    } catch (_) {
      return '$value';
    }
  }

  void _logRequest(String op, String path, Map<String, dynamic> body) {
    if (!kDebugMode || !logTraffic || environment != ZimraEnvironment.test)
      return;
    final receipt = body['receipt'] as Map?;
    final safeBody = op == 'SubmitReceipt' && receipt != null
        ? {
            'deviceId': identity.deviceId,
            'fiscalDayNo': _dayState.fiscalDayNo,
            'receiptGlobalNo': receipt['receiptGlobalNo'],
            'receiptTotal': receipt['receiptTotal'],
            'receiptTaxes': receipt['receiptTaxes'],
            if (receipt.containsKey('buyerData'))
              'buyerData': _buyerShape(receipt['buyerData']),
          }
        : body;
    final msg =
        'ZIMRA $op Request:\n'
        'POST ${environment.baseUrl}$path\n'
        '${_pretty(safeBody)}';
    final sink = trafficLogger;
    if (sink != null) {
      sink(msg);
    } else {
      debugPrint(msg);
    }
  }

  void _logResponse(String op, ZimraHttpResponse response) {
    if (!kDebugMode || !logTraffic || environment != ZimraEnvironment.test)
      return;
    final msg =
        'ZIMRA $op Response:\n'
        'HTTP ${response.statusCode}\n'
        '${_pretty(response.body.isNotEmpty ? response.body : response.rawBody)}';
    final sink = trafficLogger;
    if (sink != null) {
      sink(msg);
    } else {
      debugPrint(msg);
    }
  }

  /// Development-only trace of the final customer portion of an FDMS
  /// receipt request. Test debug builds only; customer values are redacted.
  void _logCustomerPayload(Map<String, dynamic> payload) {
    if (!kDebugMode || !logTraffic || environment != ZimraEnvironment.test)
      return;
    final receipt = payload['receipt'] as Map?;
    final buyer = receipt?['buyerData'];
    if (buyer is! Map) return;
    debugPrint('FDMS customer payload: ${_pretty(_buyerShape(buyer))}');
  }

  /// Readable rendering of an FDMS `ValidationProblemDetails` 400 so failures
  /// can be diagnosed from a snackbar/log without raw-JSON spelunking.
  static String describeProblem(ZimraHttpResponse response) {
    final body = response.body;
    if (jsonEncode(body).toUpperCase().contains('RCPT043') ||
        response.rawBody.toUpperCase().contains('RCPT043')) {
      return 'RCPT043: ${fiscalValidationMessage('RCPT043', '')}';
    }
    if (body.isEmpty) return response.rawBody;
    final errors = body['errors'];
    if (errors is Map) {
      final parts = <String>[];
      errors.forEach((key, value) {
        final msgs = value is List ? value.join(' ') : '$value';
        parts.add('$key: $msgs');
      });
      if (parts.isNotEmpty) {
        final title = body['title'] as String? ?? 'Bad Request';
        return '$title — ${parts.join('; ')}';
      }
    }
    return _pretty(body);
  }

  /// Release the HTTP connections when this device is no longer needed.
  void close() => _transport.close();

  /// Restore persisted state from Hive.
  void restoreState(FiscalDayState saved) {
    _dayState = saved.clone();
  }

  /// Get a deep clone of the current state for persistence.
  FiscalDayState getState() => _dayState.clone();

  // ---------------------------------------------------------------------------
  // Device registration (one-time, unauthenticated)
  // ---------------------------------------------------------------------------

  /// Register this device with FDMS using the activation key.
  ///
  /// Returns the issued certificate and generated key pair.
  /// Must be called once per device before any other operation.
  static Future<({ZimraCredentials credentials, String operationId})>
  registerDevice({
    required ZimraDeviceIdentity device,
    required String activationKey,
    ZimraEnvironment environment = ZimraEnvironment.test,
  }) async {
    final keyPair = generateKeyPair();
    final privateKeyPem = encodePrivateKeyPem(keyPair.privateKey);
    final publicKeyPem = encodePublicKeyPem(keyPair.publicKey);
    final csrPem = buildCsrPem(
      privateKey: keyPair.privateKey,
      publicKey: keyPair.publicKey,
      commonName: device.commonName,
    );

    final transport = ZimraPublicTransport(baseUrl: environment.baseUrl);

    // FDMS API: body has certificateRequest + activationKey,
    // device model info goes in HTTP headers (PascalCase).
    final response = await transport.post(
      '/Public/v1/${device.deviceId}/RegisterDevice',
      body: {'activationKey': activationKey, 'certificateRequest': csrPem},
      headers: device.requestHeaders,
    );

    if (!response.isSuccess) {
      throw ZimraException(
        'REG001',
        'Device registration failed (${response.statusCode}): ${response.rawBody}',
      );
    }

    final certPem =
        response.body['certificatePem'] as String? ??
        response.body['certificate'] as String? ??
        '';

    return (
      credentials: ZimraCredentials(
        privateKeyPem: privateKeyPem,
        certificatePem: certPem,
        publicKeyPem: publicKeyPem,
        csrPem: csrPem,
      ),
      operationId:
          response.body['operationID'] as String? ??
          response.body['operationId'] as String? ??
          '',
    );
  }

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Fetch tax tables and QR base URL from FDMS. Call once at startup.
  Future<ZimraConfig> getConfig() async {
    debugPrint('[FISCAL] Loading configuration');
    final response = await _transport.get(
      '/Device/v1/${identity.deviceId}/GetConfig',
    );

    debugPrint('[FISCAL] Config HTTP status: ${response.statusCode}');
    if (logTraffic && environment == ZimraEnvironment.test) {
      // Sanitized body keys (never key material — GetConfig carries none,
      // but the sanitizer is applied anyway).
      debugPrint(
        '[FISCAL] Config response keys: ${response.body.keys.toList()} | '
        'raw: ${response.rawBody.length} bytes',
      );
    }

    if (!response.isSuccess) {
      throw ZimraException(
        'CFG001',
        'Failed to get config (${response.statusCode}): '
            '${describeProblem(response)}',
      );
    }

    try {
      _config = ZimraConfig.fromJson(response.body).stamp(
        deviceId: identity.deviceId,
        fetchedAt: DateTime.now().toUtc(),
        rawTaxes:
            (response.body['applicableTaxes'] as List<dynamic>? ?? const [])
                .whereType<Map>()
                .map((t) => Map<String, dynamic>.from(t))
                .toList(),
      );
    } on FormatException catch (e) {
      // A required field is missing from the response — name it instead of
      // sending an invalid FDMS request built from fabricated defaults.
      debugPrint('[FISCAL] Missing required field: ${e.message}');
      throw ZimraException(
        'CFG002',
        'Invalid GetConfig response: ${e.message}',
      );
    } on TypeError catch (e) {
      debugPrint('[FISCAL] Missing required field: $e');
      throw ZimraException('CFG002', 'Invalid GetConfig response: $e');
    }
    debugPrint(
      '[FISCAL] Configuration validated '
      '(${_config!.applicableTaxes.length} applicable taxes, '
      'qrUrl ${_config!.qrUrl.isEmpty ? 'missing' : 'present'})',
    );
    return _config!;
  }

  // ---------------------------------------------------------------------------
  // Fiscal day lifecycle
  // ---------------------------------------------------------------------------

  /// Get the current fiscal day status from FDMS.
  Future<FiscalDayStatus> getStatus() async {
    final response = await _transport.get(
      '/Device/v1/${identity.deviceId}/GetStatus',
    );

    if (!response.isSuccess) {
      throw ZimraException(
        'DAY001',
        'Failed to get day status (${response.statusCode}): ${response.rawBody}',
      );
    }

    final statusStr = response.body['fiscalDayStatus'] as String? ?? '';
    if (!const {
      'FiscalDayOpened',
      'FiscalDayClosed',
      'FiscalDayCloseInitiated',
      'FiscalDayCloseFailed',
    }.contains(statusStr)) {
      throw const ZimraException(
        'DAY001',
        'Invalid fiscal day status from FDMS.',
      );
    }
    final status = FiscalDayStatus.fromString(statusStr);

    // Update local state
    _dayState.status = status;

    // If a day is open, update global number from server
    if (response.body['lastReceiptGlobalNo'] != null) {
      final serverGlobalNo = (response.body['lastReceiptGlobalNo'] as num)
          .toInt();
      if (serverGlobalNo > _dayState.receiptGlobalNo) {
        _dayState.receiptGlobalNo = serverGlobalNo;
      }
    }

    // Sync counters from server if available (`fiscalDayCounter` is the
    // GetStatusResponse field name; items are FiscalDayCounterDto).
    if (offlineQueue.isEmpty && response.body['fiscalDayCounter'] is List) {
      _dayState.counters = FiscalDayCounter.mergeAll(
        (response.body['fiscalDayCounter'] as List)
            .expand((c) => FiscalDayCounter.parsePersisted(c))
            .toList(),
      );
    }

    if (status == FiscalDayStatus.fiscalDayClosed) {
      _dayState = FiscalDayState(receiptGlobalNo: _dayState.receiptGlobalNo);
    }
    return status;
  }

  /// Open a new fiscal day.
  ///
  /// Must be called from FiscalDayClosed state. Seeds the global receipt
  /// number from the server to keep numbering continuous across days.
  Future<void> openDay([int? requestedDayNo, DateTime? openedAt]) async {
    if (!_dayState.isClosed) {
      throw const ZimraException(
        'DAY002',
        'Cannot open day: a day is already open',
      );
    }

    final body = buildOpenDayRequest(
      requestedDayNo: requestedDayNo,
      openedAt: openedAt,
    );

    const op = 'OpenDay';
    final path = '/Device/v1/${identity.deviceId}/OpenDay';
    _logRequest(op, path, body);
    final response = await _transport.post(path, body: body);
    _logResponse(op, response);

    if (!response.isSuccess) {
      throw ZimraException(
        'DAY003',
        'Failed to open day (${response.statusCode}): '
            '${describeProblem(response)}',
      );
    }

    _dayState.fiscalDayNo = response.body['fiscalDayNo'] as int?;
    _dayState.fiscalDayDate =
        response.body['fiscalDayDate'] as String? ??
        (body['fiscalDayOpened'] as String).substring(0, 10);
    _dayState.receiptCounter = 0;
    _dayState.receiptGlobalNo =
        (response.body['lastReceiptGlobalNo'] as num?)?.toInt() ??
        _dayState.receiptGlobalNo;
    _dayState.previousReceiptHash = null;
    _dayState.counters = [];
    _dayState.status = FiscalDayStatus.fiscalDayOpened;
    _dayState.redErrors = [];
  }

  /// FDMS requires a local timestamp even when it assigns the day number.
  static Map<String, dynamic> buildOpenDayRequest({
    int? requestedDayNo,
    DateTime? openedAt,
  }) => {
    'fiscalDayOpened': _formatDateTime((openedAt ?? DateTime.now()).toLocal()),
    if (requestedDayNo != null) 'fiscalDayNo': requestedDayNo,
  };

  /// Close the current fiscal day.
  ///
  /// Builds the canonical day-close string from accumulated counters,
  /// signs it, and submits the FDMS `CloseDayRequest`. The close is
  /// asynchronous on the server side — poll [getStatus] for
  /// `FiscalDayClosed` afterwards.
  ///
  /// Local state is cleared ONLY after GetStatus confirms closure: a
  /// rejection leaves the open day, its counters and receipt numbers
  /// untouched so the close can be retried.
  Future<void> closeDay({bool force = false}) async {
    if (force) {
      throw const ZimraException(
        'DAY012',
        'The FDMS CloseDay API does not support force closing. Review receipt validation errors and contact the ZIMRA administrator.',
      );
    }
    if (offlineQueue.isNotEmpty) {
      throw const ZimraException(
        'DAY011',
        'Submit all pending offline receipts before closing the fiscal day.',
      );
    }
    if (_dayState.isOpen ||
        _dayState.status == FiscalDayStatus.fiscalDayCloseFailed) {
      if (_dayState.hasRedErrors) {
        throw const ZimraException(
          'DAY010',
          'Day has red validation errors and cannot be closed. '
              'Review the affected receipts before contacting the ZIMRA administrator.',
          isRed: true,
        );
      }

      // Catch a malformed day locally instead of sending a request FDMS
      // will answer with a 400.
      validateCloseDayState(_dayState);

      final body = buildCloseDayRequest(
        deviceId: identity.deviceId,
        state: _dayState,
        privateKeyPem: credentials.privateKeyPem,
      );

      const op = 'CloseDay';
      final path = '/Device/v1/${identity.deviceId}/CloseDay';
      _logRequest(op, path, body);
      final response = await _transport.post(path, body: body);
      _logResponse(op, response);

      if (!response.isSuccess) {
        final problem = describeProblem(response);
        final isDay010 =
            response.body['errorCode'] == 'DAY010' ||
            response.body['code'] == 'DAY010' ||
            problem.contains('DAY010');
        throw ZimraException(
          isDay010 ? 'DAY010' : 'DAY004',
          'Failed to close day (${response.statusCode}): $problem',
          isRed: isDay010,
        );
      }
      _dayState.status = FiscalDayStatus.fiscalDayCloseInitiated;
    }
  }

  /// Validate a day state locally before a CloseDay request is built.
  /// Throws [ZimraException] — never sends anything.
  static void validateCloseDayState(FiscalDayState state) {
    final dayNo = state.fiscalDayNo;
    if (dayNo == null || dayNo <= 0) {
      throw const ZimraException(
        'DAY005',
        'Cannot close day: no fiscal day number is recorded locally. '
            'Refresh the day status from FDMS first.',
      );
    }
    if (state.fiscalDayDate == null || state.fiscalDayDate!.isEmpty) {
      throw const ZimraException(
        'DAY005',
        'Cannot close day: the fiscal day opening date is missing locally.',
      );
    }
    if (state.receiptCounter < 0) {
      throw ZimraException(
        'DAY006',
        'Cannot close day: receipt counter is invalid '
            '(${state.receiptCounter}).',
      );
    }

    const validTypes = {
      'SaleByTax',
      'SaleTaxByTax',
      'CreditNoteByTax',
      'CreditNoteTaxByTax',
      'DebitNoteByTax',
      'DebitNoteTaxByTax',
      'BalanceByMoneyType',
      'PayoutByTax',
      'PayoutTaxByTax',
    };
    for (final c in state.counters) {
      if (!validTypes.contains(c.type)) {
        throw ZimraException(
          'DAY006',
          'Cannot close day: unknown fiscal counter type "${c.type}".',
        );
      }
      if (c.currency.length != 3) {
        throw ZimraException(
          'DAY006',
          'Cannot close day: counter currency "${c.currency}" is not a '
              '3-letter ISO code.',
        );
      }
      if (c.value.isNaN || c.value.isInfinite) {
        throw ZimraException(
          'DAY006',
          'Cannot close day: counter ${c.type} holds an invalid value.',
        );
      }
      if (c.type == 'BalanceByMoneyType' &&
          (c.moneyType == null || c.moneyType!.isEmpty)) {
        throw const ZimraException(
          'DAY006',
          'Cannot close day: a balance counter is missing its money type.',
        );
      }
      if (c.type != 'BalanceByMoneyType' && c.taxId == null) {
        throw ZimraException(
          'DAY006',
          'Cannot close day: ${c.type} counter is missing its tax id.',
        );
      }
    }
  }

  /// `FiscalCounterTypeEnum` wire order — used when sorting counters for
  /// the canonical day-close string (port of the reference SDK).
  static const Map<String, int> _counterTypeOrder = {
    'SaleByTax': 1,
    'SaleTaxByTax': 2,
    'CreditNoteByTax': 3,
    'CreditNoteTaxByTax': 4,
    'DebitNoteByTax': 5,
    'DebitNoteTaxByTax': 6,
    'BalanceByMoneyType': 7,
    'PayoutByTax': 8,
    'PayoutTaxByTax': 9,
  };

  /// `MoneyTypeEnum` wire order — balance counters sort by this.
  static const Map<String, int> _moneyTypeOrderMap = {
    'Cash': 0,
    'Card': 1,
    'MobileWallet': 2,
    'Coupon': 3,
    'Credit': 4,
    'BankTransfer': 5,
    'Other': 6,
  };

  /// Deterministic FDMS counter ordering for signing strings.
  static int compareFiscalCounters(FiscalDayCounter a, FiscalDayCounter b) {
    final pa = _counterTypeOrder[a.type] ?? 99;
    final pb = _counterTypeOrder[b.type] ?? 99;
    if (pa != pb) return pa.compareTo(pb);
    final cur = a.currency.compareTo(b.currency);
    if (cur != 0) return cur;
    final ta = a.taxId ?? -1;
    final tb = b.taxId ?? -1;
    if (ta != tb) return ta.compareTo(tb);
    final ma = _moneyTypeOrderMap[a.moneyType ?? ''] ?? 99;
    final mb = _moneyTypeOrderMap[b.moneyType ?? ''] ?? 99;
    return ma.compareTo(mb);
  }

  static List<FiscalDayCounter> _nonZeroCounters(
    List<FiscalDayCounter> counters,
  ) => counters.where((c) => _toCents(c.value) != 0).toList();

  /// Canonical CloseDay signing string:
  /// `deviceId + fiscalDayNo + fiscalDayDate + counter blocks`, counters
  /// filtered to non-zero and sorted by (type order, currency, tax id,
  /// money-type order) exactly as FDMS recomputes it server-side.
  static String buildCloseDaySigningString(int deviceId, FiscalDayState state) {
    final counters = _nonZeroCounters(state.counters)
      ..sort(compareFiscalCounters);
    final sb = StringBuffer()
      ..write(deviceId)
      ..write(state.fiscalDayNo)
      ..write(state.fiscalDayDate);
    for (final c in counters) {
      sb.write(c.type.toUpperCase());
      sb.write(c.currency.toUpperCase());
      if (c.taxPercent != null) {
        sb.write(c.taxPercent!.toStringAsFixed(2));
      }
      if (c.moneyType != null) sb.write(c.moneyType!.toUpperCase());
      sb.write(_toCents(c.value));
    }
    return sb.toString();
  }

  /// Build the exact FDMS `CloseDayRequest` body — contract from
  /// `/swagger/Device-v1/swagger.json` (`additionalProperties: false`):
  ///
  /// ```json
  /// {
  ///   "fiscalDayNo": 1,
  ///   "fiscalDayCounters": [FiscalDayCounterDto…],
  ///   "fiscalDayDeviceSignature": {"hash": "…", "signature": "…"},
  ///   "receiptCounter": 0
  /// }
  /// ```
  ///
  /// `receiptCounter` is required even on a day with zero receipts — it is
  /// the receipt counter of the last receipt of the day, i.e. `0` here.
  /// `fiscalDayDeviceSignature` is `{hash, signature}` where hash is the
  /// base64 SHA-256 of the canonical string and signature the DER ECDSA
  /// signature over that same string.
  static Map<String, dynamic> buildCloseDayRequest({
    required int deviceId,
    required FiscalDayState state,
    required String privateKeyPem,
  }) {
    validateCloseDayState(state);
    final canonical = buildCloseDaySigningString(deviceId, state);
    final hash = sha256.convert(utf8.encode(canonical));
    final signature = signDer(canonical, decodePrivateKeyPem(privateKeyPem));

    return {
      'fiscalDayNo': state.fiscalDayNo,
      'fiscalDayCounters': _nonZeroCounters(
        state.counters,
      ).map((c) => c.toJson()).toList(),
      'fiscalDayDeviceSignature': {
        'hash': base64Encode(hash.bytes),
        'signature': base64Encode(signature),
      },
      'receiptCounter': state.receiptCounter,
    };
  }

  // ---------------------------------------------------------------------------
  // Receipt submission
  // ---------------------------------------------------------------------------

  /// Build, sign, and submit a receipt to FDMS.
  ///
  /// Handles: FDMS line/tax math (every line rounds its own tax), global
  /// numbering, canonical signing string, DER signature, hash chain and
  /// verification QR data. Local state advances only on acceptance — or at
  /// signing time when a network failure journals the receipt into the
  /// offline queue (FDMS numbers receipts at sale time and de-duplicates
  /// identical resubmissions within its grace window).
  Future<FiscalisedReceipt> submitReceipt({
    required String currency,
    required String invoiceNo,
    required List<ReceiptLineInput> lines,
    required List<ReceiptPayment> payments,
    ReceiptType receiptType = ReceiptType.fiscalInvoice,
    bool linesTaxInclusive = true,
    DateTime? receiptDate,
    String? notes,
    BuyerData? buyer,
    CreditDebitNoteRef? creditDebitNote,
    String receiptPrintForm = 'Receipt48',
  }) async {
    if (!isOpen) {
      throw const ZimraException(
        'RCP001',
        'No fiscal day is open. Open a day first.',
      );
    }
    if (_config == null) {
      throw const ZimraException(
        'RCP002',
        'Config not loaded. Call getConfig() first.',
      );
    }

    if (receiptType == ReceiptType.creditNote ||
        receiptType == ReceiptType.debitNote) {
      final ref = creditDebitNote;
      if (ref == null ||
          !((ref.receiptId ?? 0) > 0 ||
              ((ref.deviceId ?? 0) > 0 &&
                  (ref.receiptGlobalNo ?? 0) > 0 &&
                  (ref.fiscalDayNo ?? 0) > 0))) {
        throw const ZimraException(
          'RCP_REFERENCE',
          'Select the original fiscalised invoice before fiscalising this credit or debit note.',
        );
      }
    }
    if (buyer != null) validateFiscalBuyer(buyer.toJson());
    final date = receiptDate ?? DateTime.now();
    validateReceiptInputs(
      config: _config!,
      deviceId: identity.deviceId,
      date: date,
      currency: currency,
      lines: lines,
    );
    if (_dayState.fiscalDayNo == null || _dayState.fiscalDayNo! <= 0) {
      throw const ZimraException(
        'RCP003',
        'Fiscal day number is missing. Refresh status.',
      );
    }
    final globalNo = _dayState.receiptGlobalNo + 1;
    final receiptNo = _dayState.receiptCounter + 1;

    final plan = _planTaxes(lines, linesTaxInclusive);
    final totalCents = plan.totalCents;
    assert(() {
      debugPrint(
        '[FISCAL] device=${identity.deviceId} day=${_dayState.fiscalDayNo} '
        'taxes=${lines.map((l) => "${l.taxId}:${l.taxPercent}").join(",")} '
        'source=FDMS totalCents=$totalCents taxCents=${plan.groups.fold<int>(0, (s, g) => s + g.taxAmount)}',
      );
      return true;
    }());

    // Verify payments match total
    final paymentTotal = payments.fold<int>(0, (s, p) => s + p.amount);
    if (paymentTotal != totalCents) {
      throw ZimraException(
        'RCP010',
        'Payments (${_fromCents(paymentTotal)}) do not equal '
            'receipt total (${_fromCents(totalCents)})',
      );
    }

    // Sort tax groups by taxId (FDMS signing order)
    final sortedGroups = plan.groups.toList()
      ..sort((a, b) => a.taxId.compareTo(b.taxId));

    // Build canonical signing string
    final canonical = _buildReceiptSigningString(
      deviceId: identity.deviceId,
      receiptType: receiptType,
      currency: currency,
      globalNo: globalNo,
      date: date,
      totalCents: totalCents,
      taxGroups: sortedGroups,
      previousHash: _dayState.previousReceiptHash,
    );

    final hash = sha256.convert(utf8.encode(canonical));
    final hashB64 = base64Encode(hash.bytes);
    final signatureB64 = base64Encode(
      signDer(canonical, decodePrivateKeyPem(credentials.privateKeyPem)),
    );

    // Build the ReceiptDto payload for FDMS
    final receiptPayload = _buildReceiptPayload(
      currency: currency,
      invoiceNo: invoiceNo,
      lineDtos: plan.lineDtos,
      payments: payments,
      receiptType: receiptType,
      linesTaxInclusive: linesTaxInclusive,
      date: date,
      globalNo: globalNo,
      receiptNo: receiptNo,
      totalCents: totalCents,
      taxGroups: sortedGroups,
      signature: signatureB64,
      hash: hashB64,
      notes: notes,
      buyer: buyer,
      creditDebitNote: creditDebitNote,
      receiptPrintForm: receiptPrintForm,
    );

    validateReceiptPayload(receiptPayload);
    const op = 'SubmitReceipt';
    final path = '/Device/v1/${identity.deviceId}/SubmitReceipt';
    _logRequest(op, path, receiptPayload);
    _logCustomerPayload(receiptPayload);

    ZimraHttpResponse response;
    try {
      response = await _transport.post(path, body: receiptPayload);
    } catch (e) {
      if (e is ZimraException) rethrow;
      // Network-level failure — no HTTP answer from FDMS. The FDMS offline
      // flow applies: the signed receipt is journaled for the 72-hour grace
      // window and local state advances so the hash chain continues from it.
      _advanceDayState(
        receiptNo: receiptNo,
        globalNo: globalNo,
        hashB64: hashB64,
        taxGroups: sortedGroups,
        payments: payments,
        receiptType: receiptType,
        currency: currency,
      );
      queueOfflineReceipt(
        receiptPayload: receiptPayload,
        fiscalDayNo: _dayState.fiscalDayNo ?? 0,
        receiptGlobalNo: globalNo,
      );
      throw ZimraException(
        'RCP030',
        'Network unavailable — receipt $receiptNo signed and queued for '
            'submission (FDMS 72-hour grace window). Original error: $e',
        receiptPayload: receiptPayload,
      );
    }
    _logResponse(op, response);

    if (!response.isSuccess) {
      // State does NOT advance on rejection — safe to retry
      throw ZimraException(
        'RCP020',
        'Receipt rejected (${response.statusCode}): '
            '${describeProblem(response)}',
      );
    }

    final result = _parseSubmitResponse(response, receiptPayload);

    // Record red validation errors on the day (blocks CloseDay unless forced)
    final reds = result.response.validationErrors.where((e) => e.isRed);
    for (final err in reds) {
      _dayState.redErrors.add(err.code);
    }

    // Advance state ONLY after acceptance
    _advanceDayState(
      receiptNo: receiptNo,
      globalNo: globalNo,
      hashB64: hashB64,
      taxGroups: sortedGroups,
      payments: payments,
      receiptType: receiptType,
      currency: currency,
    );

    return FiscalisedReceipt(
      receipt: receiptPayload,
      response: result.response,
      qrData: qrDataForPayload(receiptPayload),
    );
  }

  /// Advance local day state past a receipt that was signed (and either
  /// accepted or journaled for the offline grace window).
  void _advanceDayState({
    required int receiptNo,
    required int globalNo,
    required String hashB64,
    required List<_TaxGroup> taxGroups,
    required List<ReceiptPayment> payments,
    required ReceiptType receiptType,
    required String currency,
  }) {
    _dayState.receiptCounter = receiptNo;
    _dayState.receiptGlobalNo = globalNo;
    _dayState.previousReceiptHash = hashB64;
    _accumulateCounters(
      receiptType: receiptType,
      currency: currency,
      taxGroups: taxGroups,
      payments: payments,
    );
  }

  /// Parse a successful SubmitReceipt response (contract:
  /// `receiptID`, `serverDate`, `receiptServerSignature`, `operationID`,
  /// `validationErrors`).
  FiscalisedReceipt _parseSubmitResponse(
    ZimraHttpResponse response,
    Map<String, dynamic> receiptPayload,
  ) {
    assert(() {
      final errors = (response.body['validationErrors'] as List? ?? [])
          .whereType<Map>()
          .map(
            (e) => '${e['validationErrorCode']}:${e['validationErrorColor']}',
          );
      debugPrint(
        '[FISCAL] device=${identity.deviceId} HTTP=${response.statusCode} validation=${errors.join(',')}',
      );
      return true;
    }());
    final sig = response.body['receiptServerSignature'];
    final validationErrors =
        (response.body['validationErrors'] as List<dynamic>? ?? [])
            .map(
              (e) => ValidationError(
                code: e['validationErrorCode'] as String? ?? '',
                color: e['validationErrorColor'] as String? ?? '',
                description: e['validationErrorDescription'] as String? ?? '',
              ),
            )
            .toList();

    return FiscalisedReceipt(
      receipt: receiptPayload,
      response: FiscalisedReceiptResponse(
        receiptId: (response.body['receiptID'] as num?)?.toInt(),
        serverDate: response.body['serverDate'] as String?,
        serverHash: sig is Map ? sig['hash'] as String? : null,
        signature: sig is Map ? sig['signature'] as String? : null,
        certificateThumbprint: sig is Map
            ? sig['certificateThumbprint'] as String?
            : null,
        operationId: response.body['operationID'] as String?,
        validationErrors: validationErrors,
        serverResponse: Map<String, dynamic>.from(response.body),
      ),
    );
  }

  /// Verification QR data for an already-signed receipt payload, or null
  /// when the FDMS config carries no `qrUrl`.
  String? qrDataForPayload(Map<String, dynamic> receiptPayload) {
    final qrUrl = _config?.qrUrl ?? '';
    if (qrUrl.isEmpty) return null;
    final r = receiptPayload['receipt'];
    if (r is! Map) return null;
    final sig = r['receiptDeviceSignature'];
    final sigB64 = sig is Map ? sig['signature'] as String? : null;
    final dateStr = r['receiptDate'] as String?;
    final globalNo = (r['receiptGlobalNo'] as num?)?.toInt();
    if (sigB64 == null || dateStr == null || globalNo == null) return null;
    return buildVerificationQrData(
      deviceId: identity.deviceId,
      receiptDate: DateTime.parse(dateStr),
      receiptGlobalNo: globalNo,
      deviceSignatureBase64: sigB64,
      qrBaseUrl: qrUrl,
    );
  }

  /// Resubmit an already-signed receipt payload (offline grace window or a
  /// retry after a network failure). FDMS de-duplicates identical
  /// submissions (same deviceID + receiptGlobalNo + receipt hash) and
  /// returns the original `receiptID`, so a retry never consumes a second
  /// receipt number. Local state is NOT advanced here — it was advanced
  /// when the receipt was first signed.
  Future<FiscalisedReceipt> resubmitReceipt(
    Map<String, dynamic> receiptPayload,
  ) async {
    validateReceiptPayload(receiptPayload);
    const op = 'SubmitReceipt';
    final path = '/Device/v1/${identity.deviceId}/SubmitReceipt';
    _logRequest(op, path, receiptPayload);
    final response = await _transport.post(path, body: receiptPayload);
    _logResponse(op, response);

    if (!response.isSuccess) {
      throw ZimraException(
        'RCP020',
        'Receipt rejected (${response.statusCode}): '
            '${describeProblem(response)}',
      );
    }
    final parsed = _parseSubmitResponse(response, receiptPayload);
    for (final error in parsed.response.validationErrors.where(
      (e) => e.isRed,
    )) {
      if (!_dayState.redErrors.contains(error.code)) {
        _dayState.redErrors.add(error.code);
      }
    }
    return FiscalisedReceipt(
      receipt: parsed.receipt,
      response: parsed.response,
      qrData: qrDataForPayload(receiptPayload),
    );
  }

  // ---------------------------------------------------------------------------
  // Offline queue
  // ---------------------------------------------------------------------------

  /// Add a receipt to the offline queue (called when network is unavailable).
  void queueOfflineReceipt({
    required Map<String, dynamic> receiptPayload,
    required int fiscalDayNo,
    required int receiptGlobalNo,
  }) {
    offlineQueue.add(
      PendingReceipt(
        id: const Uuid().v4(),
        receiptPayload: receiptPayload,
        createdAt: DateTime.now(),
        fiscalDayNo: fiscalDayNo,
        receiptGlobalNo: receiptGlobalNo,
      ),
    );
  }

  /// Flush the offline queue — submit pending receipts in FIFO order.
  ///
  /// FDMS has a 72-hour grace window for queued receipts; identical
  /// resubmissions are de-duplicated server-side.
  Future<List<FiscalisedReceipt>> flushOfflineQueue() async {
    final results = <FiscalisedReceipt>[];
    final failed = <PendingReceipt>[];

    for (var index = 0; index < offlineQueue.length; index++) {
      final pending = offlineQueue[index];
      try {
        results.add(await resubmitReceipt(pending.receiptPayload));
      } catch (_) {
        // Later receipts depend on this receipt's number and hash.
        failed.addAll(offlineQueue.skip(index));
        break;
      }
    }

    // Keep only failed receipts
    offlineQueue
      ..clear()
      ..addAll(failed);

    return results;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Check the complete wire representation, including signed offline retries.
  /// Never rewrite a queued payload when configuration changes.
  void validateReceiptPayload(Map<String, dynamic> payload) {
    if (!isOpen || _config == null) {
      throw const ZimraException(
        'RCP001',
        'An open fiscal day and FDMS configuration are required.',
      );
    }
    try {
      final receipt = payload['receipt'] as Map;
      validateReceiptBuyer(receipt);
      final date = DateTime.parse(receipt['receiptDate'] as String);
      final lineMaps = (receipt['receiptLines'] as List).cast<Map>();
      final lines = lineMaps
          .map(
            (line) => ReceiptLineInput(
              name: line['receiptLineName'] as String,
              price: (line['receiptLinePrice'] as num).toDouble(),
              quantity: (line['receiptLineQuantity'] as num).toDouble(),
              taxId: line['taxID'] as int,
              taxPercent: (line['taxPercent'] as num?)?.toDouble(),
              taxCode: line['taxCode'] as String?,
              lineType: line['receiptLineType'] as String,
            ),
          )
          .toList();
      validateReceiptInputs(
        config: _config!,
        deviceId: identity.deviceId,
        date: date,
        currency: receipt['receiptCurrency'] as String,
        lines: lines,
      );
      if (!ReceiptType.values.any(
            (t) => t.apiValue == receipt['receiptType'],
          ) ||
          (receipt['receiptCounter'] as int) <= 0 ||
          (receipt['receiptGlobalNo'] as int) <= 0 ||
          (receipt['receiptDeviceSignature'] as Map)['signature'] == null) {
        throw const FormatException(
          'Invalid receipt type, numbering or signature',
        );
      }
      final plan = _planTaxes(
        lines,
        receipt['receiptLinesTaxInclusive'] as bool,
      );
      int cents(dynamic value) {
        if (value is! num || !value.isFinite)
          throw const FormatException('Invalid amount');
        if ((value * 100 - (value * 100).round()).abs() > 0.000001) {
          throw const FormatException(
            'Money amounts must have at most two decimal places',
          );
        }
        return (value * 100).round();
      }

      final wireLines = lineMaps.toList();
      for (var i = 0; i < wireLines.length; i++) {
        if (wireLines[i]['receiptLineNo'] != i + 1 ||
            cents(wireLines[i]['receiptLineTotal']) !=
                cents(plan.lineDtos[i]['receiptLineTotal'])) {
          throw const FormatException('Line total does not reconcile');
        }
      }
      final taxes = (receipt['receiptTaxes'] as List).cast<Map>();
      if (taxes.length != plan.groups.length)
        throw const FormatException('Tax groups do not reconcile');
      for (final group in plan.groups) {
        final matches = taxes
            .where(
              (t) =>
                  t['taxID'] == group.taxId &&
                  t['taxPercent'] == group.taxPercent,
            )
            .toList();
        if (matches.length != 1 ||
            matches.single['taxCode'] != group.taxCode ||
            cents(matches.single['taxAmount']) != group.taxAmount ||
            cents(matches.single['salesAmountWithTax']) != group.totalAmount) {
          throw const FormatException('Receipt taxes do not reconcile');
        }
      }
      final payments = (receipt['receiptPayments'] as List).cast<Map>();
      const moneyTypes = {
        'Cash',
        'Card',
        'MobileWallet',
        'Coupon',
        'Credit',
        'BankTransfer',
        'Other',
      };
      if (payments.isEmpty ||
          payments.any((p) => !moneyTypes.contains(p['moneyTypeCode'])) ||
          payments.fold<int>(0, (sum, p) => sum + cents(p['paymentAmount'])) !=
              plan.totalCents ||
          cents(receipt['receiptTotal']) != plan.totalCents) {
        throw const FormatException(
          'Receipt total or payments do not reconcile',
        );
      }
    } on ZimraException {
      rethrow;
    } catch (e) {
      throw ZimraException('RCP008', 'Invalid FDMS receipt payload: $e');
    }
  }

  /// Validate before signing; no manual entry may reach an FDMS payload.
  static void validateReceiptInputs({
    required ZimraConfig config,
    required int deviceId,
    required DateTime date,
    required String currency,
    required List<ReceiptLineInput> lines,
  }) {
    if (deviceId <= 0 ||
        (config.deviceId != null && config.deviceId != deviceId)) {
      throw const ZimraException(
        'RCP003',
        'FDMS configuration belongs to a different device.',
      );
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency) || lines.isEmpty) {
      throw const ZimraException(
        'RCP004',
        'Invalid currency or empty receipt.',
      );
    }
    for (final line in lines) {
      if (!line.price.isFinite ||
          !line.quantity.isFinite ||
          line.quantity <= 0 ||
          (line.lineType != 'Sale' && line.lineType != 'Discount')) {
        throw const ZimraException(
          'RCP005',
          'Invalid receipt line amount, quantity or type.',
        );
      }
      final matches = config.applicableTaxes
          .where((t) => t.taxId == line.taxId && t.isValidOn(date))
          .toList();
      if (matches.length != 1) {
        throw const ZimraException(
          'RCP006',
          'Tax ID is not uniquely present in current FDMS configuration. Refresh GetConfig.',
        );
      }
      final tax = matches.single;
      final matchesRate = tax.isExempt
          ? line.taxPercent == null
          : line.taxPercent != null &&
                line.taxPercent!.isFinite &&
                (tax.taxPercent - line.taxPercent!).abs() < 0.000001;
      if (!matchesRate ||
          (line.taxCode != null && line.taxCode != tax.taxCode)) {
        throw const ZimraException(
          'RCP007',
          'Tax ID and rate/code disagree with current FDMS configuration.',
        );
      }
    }
  }

  /// FDMS receipt total in cents for a set of lines — the single source of
  /// truth used to build payments FDMS will accept.
  static int computeReceiptTotalCents(
    List<ReceiptLineInput> lines, {
    bool linesTaxInclusive = true,
  }) => _planTaxes(lines, linesTaxInclusive).totalCents;

  /// FDMS line/tax math: every line's tax is rounded on its own, then
  /// grouped by (taxID, taxPercent) exactly as the reference SDK does.
  /// Also builds the `ReceiptLineDto` wire entries from the same numbers.
  static _TaxPlan _planTaxes(List<ReceiptLineInput> lines, bool taxInclusive) {
    final groups = <String, _TaxGroup>{};
    final lineDtos = <Map<String, dynamic>>[];
    var linesTotalCents = 0;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final priceCents = _toCents(line.price);
      final totalCents = (priceCents * line.quantity).round();
      linesTotalCents += totalCents;

      final rate = (line.taxPercent ?? 0) / 100;
      final taxCents = taxInclusive
          ? (totalCents - totalCents / (1 + rate)).round()
          : (totalCents * rate).round();

      final key = '${line.taxId}|${line.taxPercent ?? ''}';
      final g = groups.putIfAbsent(
        key,
        () => _TaxGroup(
          taxId: line.taxId,
          taxPercent: line.taxPercent,
          taxCode: line.taxCode,
        ),
      );
      g.taxAmount += taxCents;
      g.totalAmount += taxInclusive ? totalCents : totalCents + taxCents;
      g.taxableAmount += taxInclusive ? totalCents - taxCents : totalCents;

      lineDtos.add({
        'receiptLineType': line.lineType,
        'receiptLineNo': i + 1,
        if (line.hsCode != null) 'receiptLineHSCode': line.hsCode,
        'receiptLineName': line.name,
        'receiptLinePrice': centsToAmount(priceCents),
        'receiptLineQuantity': line.quantity,
        'receiptLineTotal': centsToAmount(totalCents),
        if (line.taxCode != null) 'taxCode': line.taxCode,
        if (line.taxPercent != null) 'taxPercent': line.taxPercent,
        'taxID': line.taxId,
      });
    }

    final taxCentsTotal = groups.values.fold<int>(0, (s, g) => s + g.taxAmount);
    return _TaxPlan(
      groups: groups.values.toList(),
      lineDtos: lineDtos,
      totalCents: linesTotalCents + (taxInclusive ? 0 : taxCentsTotal),
    );
  }

  /// Build the canonical signing string for a receipt:
  /// `deviceId + RECEIPTTYPE + CURRENCY + receiptGlobalNo + receiptDate +
  /// receiptTotal(cents) + taxes(sorted by taxID) + previousReceiptHash`.
  String _buildReceiptSigningString({
    required int deviceId,
    required ReceiptType receiptType,
    required String currency,
    required int globalNo,
    required DateTime date,
    required int totalCents,
    required List<_TaxGroup> taxGroups,
    String? previousHash,
  }) {
    final sb = StringBuffer();
    sb.write(deviceId);
    sb.write(receiptType.xmlValue);
    sb.write(currency.toUpperCase());
    sb.write(globalNo);
    sb.write(_formatDateTime(date));
    sb.write(totalCents);

    for (final tg in taxGroups) {
      // Null tax percent = exempt line (empty in the string); a real 0%
      // zero-rated line formats as "0.00".
      if (tg.taxPercent != null) {
        sb.write(tg.taxPercent!.toStringAsFixed(2));
      }
      sb.write(tg.taxAmount);
      sb.write(tg.totalAmount);
    }

    if (previousHash != null) {
      sb.write(previousHash);
    }

    return sb.toString();
  }

  /// Build the `SubmitReceiptRequest` body — the contract wraps the
  /// `ReceiptDto` in a `receipt` property and all amounts are major units
  /// (dollars), not cents.
  Map<String, dynamic> _buildReceiptPayload({
    required String currency,
    required String invoiceNo,
    required List<Map<String, dynamic>> lineDtos,
    required List<ReceiptPayment> payments,
    required ReceiptType receiptType,
    required bool linesTaxInclusive,
    required DateTime date,
    required int globalNo,
    required int receiptNo,
    required int totalCents,
    required List<_TaxGroup> taxGroups,
    required String signature,
    required String hash,
    required String receiptPrintForm,
    String? notes,
    BuyerData? buyer,
    CreditDebitNoteRef? creditDebitNote,
  }) {
    final receiptTaxes = taxGroups
        .map(
          (tg) => {
            if (tg.taxCode != null) 'taxCode': tg.taxCode,
            if (tg.taxPercent != null) 'taxPercent': tg.taxPercent,
            'taxID': tg.taxId,
            'taxAmount': centsToAmount(tg.taxAmount),
            'salesAmountWithTax': centsToAmount(tg.totalAmount),
          },
        )
        .toList();

    Map<String, dynamic>? buyerDto;
    if (buyer != null) {
      // The buyer was validated before signing (validateFiscalBuyer);
      // forward the complete validated DTO verbatim. Re-filtering fields
      // here silently dropped vatNumber/tradeName/address/contacts and
      // made name+TIN-only receipts.
      buyerDto = buyer.toJson();
    }

    return {
      'receipt': {
        'receiptType': receiptType.apiValue,
        'receiptCurrency': currency.toUpperCase(),
        'receiptCounter': receiptNo,
        'receiptGlobalNo': globalNo,
        'invoiceNo': invoiceNo.length > 50
            ? invoiceNo.substring(0, 50)
            : invoiceNo,
        if (buyerDto != null) 'buyerData': buyerDto,
        if (notes != null && notes.isNotEmpty)
          'receiptNotes': notes.length > 500 ? notes.substring(0, 500) : notes,
        'receiptDate': _formatDateTime(date),
        if (creditDebitNote != null)
          'creditDebitNote': creditDebitNote.toJson(),
        'receiptLinesTaxInclusive': linesTaxInclusive,
        'receiptLines': lineDtos,
        'receiptTaxes': receiptTaxes,
        'receiptPayments': payments
            .map(
              (p) => {
                'moneyTypeCode': p.moneyType,
                'paymentAmount': centsToAmount(p.amount),
              },
            )
            .toList(),
        'receiptTotal': centsToAmount(totalCents),
        'receiptPrintForm': receiptPrintForm,
        'receiptDeviceSignature': {'hash': hash, 'signature': signature},
      },
    };
  }

  /// Data content of the verification QR code printed on every fiscal
  /// receipt, exactly as FDMS prescribes:
  ///
  /// `{qrUrl}/{deviceId padded to 10}{ddMMyyyy}{receiptGlobalNo padded to
  /// 10}{first 16 hex chars of MD5 over the raw device-signature bytes}`
  static String buildVerificationQrData({
    required int deviceId,
    required DateTime receiptDate,
    required int receiptGlobalNo,
    required String deviceSignatureBase64,
    required String qrBaseUrl,
  }) {
    final sigBytes = base64Decode(deviceSignatureBase64);
    final md5Hex = md5.convert(sigBytes).toString();
    final base = qrBaseUrl.endsWith('/') ? qrBaseUrl : '$qrBaseUrl/';
    String p2(int n) => n.toString().padLeft(2, '0');
    final ddMMyyyy =
        '${p2(receiptDate.day)}${p2(receiptDate.month)}${receiptDate.year}';
    return base +
        deviceId.toString().padLeft(10, '0') +
        ddMMyyyy +
        receiptGlobalNo.toString().padLeft(10, '0') +
        md5Hex.substring(0, 16);
  }

  /// Fold a fiscalised receipt into the running FDMS day counters
  /// (`SaleByTax`/`SaleTaxByTax`/credit/debit variants plus
  /// `BalanceByMoneyType` per payment) — port of the reference SDK's
  /// `accumulateCounters()`.
  void _accumulateCounters({
    required ReceiptType receiptType,
    required String currency,
    required List<_TaxGroup> taxGroups,
    required List<ReceiptPayment> payments,
  }) {
    final sign = receiptType == ReceiptType.creditNote ? -1 : 1;
    final byTaxType = switch (receiptType) {
      ReceiptType.fiscalInvoice => 'SaleByTax',
      ReceiptType.creditNote => 'CreditNoteByTax',
      ReceiptType.debitNote => 'DebitNoteByTax',
    };
    final taxByTaxType = switch (receiptType) {
      ReceiptType.fiscalInvoice => 'SaleTaxByTax',
      ReceiptType.creditNote => 'CreditNoteTaxByTax',
      ReceiptType.debitNote => 'DebitNoteTaxByTax',
    };

    for (final g in taxGroups) {
      _upsertCounter(
        type: byTaxType,
        currency: currency,
        taxId: g.taxId,
        taxPercent: g.taxPercent,
        delta: sign * centsToAmount(g.totalAmount),
      );
      _upsertCounter(
        type: taxByTaxType,
        currency: currency,
        taxId: g.taxId,
        taxPercent: g.taxPercent,
        delta: sign * centsToAmount(g.taxAmount),
      );
    }
    for (final p in payments) {
      _upsertCounter(
        type: 'BalanceByMoneyType',
        currency: currency,
        moneyType: p.moneyType,
        delta: sign * centsToAmount(p.amount),
      );
    }
  }

  /// Add [delta] to the counter identified by (type, currency, tax id /
  /// money type), creating it when needed. Arithmetic is cents-precise.
  void _upsertCounter({
    required String type,
    required String currency,
    int? taxId,
    double? taxPercent,
    String? moneyType,
    required double delta,
  }) {
    final idx = _dayState.counters.indexWhere(
      (c) =>
          c.type == type &&
          c.currency == currency &&
          c.taxId == taxId &&
          c.moneyType == moneyType,
    );
    if (idx >= 0) {
      final c = _dayState.counters[idx];
      _dayState.counters[idx] = c.copyWith(value: _addAmount(c.value, delta));
    } else {
      _dayState.counters.add(
        FiscalDayCounter(
          type: type,
          currency: currency,
          taxId: taxId,
          taxPercent: taxPercent,
          moneyType: moneyType,
          value: _addAmount(0, delta),
        ),
      );
    }
  }

  /// Cents-precise addition of money amounts.
  static double _addAmount(double a, double b) =>
      (_toCents(a) + _toCents(b)) / 100;

  /// Convert a dollar amount to integer cents.
  static int _toCents(double amount) {
    return (amount * 100).round();
  }

  /// Format cents as a dollar string.
  static String _fromCents(int cents) {
    return '\$${(cents / 100).toStringAsFixed(2)}';
  }

  /// Format date as YYYY-MM-DD.
  static String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  /// Format datetime as YYYY-MM-DDTHH:mm:ss (no timezone).
  static String _formatDateTime(DateTime dt) {
    return '${_formatDate(dt)}T'
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}

/// Internal tax group accumulator (amounts in cents).
class _TaxGroup {
  final int taxId;

  /// Null = exempt line; 0 = zero-rated (FDMS formats these differently).
  final double? taxPercent;
  final String? taxCode;
  int taxableAmount = 0; // cents, excl. tax
  int taxAmount = 0; // cents
  int totalAmount = 0; // cents, incl. tax

  _TaxGroup({required this.taxId, required this.taxPercent, this.taxCode});
}

/// Result of FDMS line/tax math for one receipt.
class _TaxPlan {
  final List<_TaxGroup> groups;
  final List<Map<String, dynamic>> lineDtos;
  final int totalCents;

  const _TaxPlan({
    required this.groups,
    required this.lineDtos,
    required this.totalCents,
  });
}

/// Convert cents to the major-unit amount FDMS expects on the wire.
double centsToAmount(int cents) => cents / 100;
