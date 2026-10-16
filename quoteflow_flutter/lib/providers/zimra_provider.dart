/// State management for ZIMRA FDMS integration.
///
/// Persists device identity, credentials, fiscal day state, and offline queue
/// to Hive. Provides the UI with the current device status and day lifecycle.
library;

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../services/fiscalisation.dart' show ZimraProviderLike;
import '../services/zimra/zimra.dart';
import '../services/compliance/fdms_readiness.dart';

/// Manages ZIMRA FDMS device state, fiscal day lifecycle, and receipt history.
class ZimraProvider extends ChangeNotifier implements ZimraProviderLike {
  final Box _box;

  ZimraProvider(
    this._box, {
    this.transportFactory,
    this.productionTransportFactory,
    this.testTransportFactory,
  });

  final ZimraApi Function()? transportFactory;
  final ZimraApi Function(ZimraDeviceIdentity, ZimraCredentials)?
  productionTransportFactory;
  final ZimraApi? Function(ZimraDeviceIdentity, ZimraCredentials)?
  testTransportFactory;
  Future<ZimraConfig?>? _configRequest;
  Future<void> _fiscalOperations = Future<void>.value();
  Future<void> _evidenceWrites = Future.value();
  String? evidenceError;
  String _caseKey(ZimraDeviceIdentity identity) =>
      'fdms_readiness_v1:${identity.deviceId}:${identity.serialNumber}';
  FdmsReadiness? get approvalCase {
    final key = _environment == ZimraEnvironment.test && _identity != null
        ? _caseKey(_identity!)
        : _box.get('fdms_selected_approval_case') as String?;
    if (key == null) return null;
    final value = _box.get(key);
    if (value is Map) return FdmsReadiness.fromJson(value);
    return _identity != null && _environment == ZimraEnvironment.test
        ? FdmsReadiness(identity: _identity!.toJson())
        : null;
  }

  Future<void> saveApprovalMetadata(Map<String, dynamic> metadata) async {
    await _evidenceWrites;
    final current = approvalCase;
    if (current == null)
      throw const FormatException(
        'Register a Test device before preparing approval evidence.',
      );
    if (current.events.isNotEmpty &&
        ((current.metadata['orderNumber'] != null &&
                current.metadata['orderNumber'] != metadata['orderNumber']) ||
            (current.metadata['tin'] != null &&
                current.metadata['tin'] != metadata['tin'])))
      throw const FormatException(
        'This evidence belongs to its original order. Preserve the order number; use a new Test device for another case.',
      );
    current.metadata = metadata;
    if ('${metadata['approvalReference'] ?? ''}'.trim().isNotEmpty &&
        !current.ready) {
      throw const FormatException(
        'Complete the recorded Test checklist before recording the external approval reference.',
      );
    }
    final key =
        'fdms_readiness_v1:${current.identity['deviceId']}:${current.identity['serialNumber']}';
    await _box.put(key, current.toJson());
    await _box.put('fdms_selected_approval_case', key);
    notifyListeners();
  }

  Future<void> _captureEvidence(
    ZimraDeviceIdentity identity,
    int? dayNo,
    String method,
    String path,
    Map<String, dynamic>? body,
    ZimraHttpResponse response,
  ) {
    final task = _evidenceWrites.then((_) async {
      final key = _caseKey(identity), value = _box.get(_caseKey(identity));
      final current = value is Map
          ? FdmsReadiness.fromJson(value)
          : FdmsReadiness(identity: identity.toJson());
      current.record(method, path, body, response, dayNo);
      await _box.put(key, current.toJson());
      evidenceError = null;
    });
    _evidenceWrites = task.catchError((Object e) {
      evidenceError = 'Evidence capture failed: $e';
    });
    return task;
  }

  /// Each operation must read the state persisted by its predecessor.
  Future<T> _withFiscalLock<T>(Future<T> Function() action) {
    final result = _fiscalOperations.then((_) => action());
    _fiscalOperations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  // ---------------------------------------------------------------------------
  // Stored state
  // ---------------------------------------------------------------------------

  ZimraDeviceIdentity? _identity;
  ZimraCredentials? _credentials;
  ZimraEnvironment _environment = ZimraEnvironment.test;
  FiscalDayState _dayState = FiscalDayState();
  ZimraConfig? _config;
  DateTime? _configFetchedAt;
  List<ZimraTax> _manualTaxes = [];
  final List<PendingReceipt> _offlineQueue = [];
  final List<FiscalisedReceipt> _receiptHistory = [];

  // Current status
  bool _loading = false;
  String? _error;
  bool _stateLoadFailed = false;
  ZimraException? _lastSubmitError;
  FiscalDayStatus _status = FiscalDayStatus.fiscalDayClosed;
  int _receiptCount = 0;
  int _globalReceiptCount = 0;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  ZimraDeviceIdentity? get identity => _identity;
  ZimraCredentials? get credentials => _credentials;
  ZimraEnvironment get environment => _environment;
  FiscalDayState get dayState => _dayState;
  ZimraConfig? get config => _config;

  /// When the FDMS configuration was last fetched from ZIMRA.
  DateTime? get configFetchedAt => _configFetchedAt;

  /// Legacy local entries retained for inspection/removal only.
  List<ZimraTax> get manualTaxes => List.unmodifiable(_manualTaxes);

  /// Only the device's GetConfig table is eligible for fiscalisation.
  ZimraConfig? get effectiveConfig => _config;

  List<PendingReceipt> get offlineQueue => List.unmodifiable(_offlineQueue);

  /// Fallback fiscalisation currency when no organisation supplies one.
  /// The document's organisation currency is authoritative (see
  /// validateFiscalisation); this only serves ZimraProviderLike's contract
  /// for org-less preflight calls.
  @override
  String get currencyCode => 'USD';
  List<FiscalisedReceipt> get receiptHistory =>
      List.unmodifiable(_receiptHistory);

  bool get isRegistered => _identity != null && _credentials != null;
  bool get isLoading => _loading || isFetchingConfig;
  bool get isFetchingConfig => _configRequest != null;
  String? get error => _error;

  /// Structured cause of the most recent receipt submission failure — lets
  /// callers distinguish offline queueing (RCP030) from FDMS rejection.
  ZimraException? get lastSubmitError => _lastSubmitError;
  FiscalDayStatus get status => _status;
  int get receiptCount => _receiptCount;
  int get globalReceiptCount => _globalReceiptCount;
  bool get hasOfflineReceipts => _offlineQueue.isNotEmpty;
  int get offlineQueueLength => _offlineQueue.length;

  // ---------------------------------------------------------------------------
  // Persistence keys
  // ---------------------------------------------------------------------------

  static const _keyIdentity = 'zimra_identity';
  static const _keyCredentials = 'zimra_credentials';
  static const _keyEnvironment = 'zimra_environment';
  static const _keyDayState = 'zimra_day_state';
  static const _keyOfflineQueue = 'zimra_offline_queue';
  static const _keyConfig = 'zimra_config';
  static const _keyConfigFetchedAt = 'zimra_config_fetched_at';
  static const _keyManualTaxes = 'zimra_manual_taxes';
  static const _keyReceiptHistory = 'zimra_receipt_history';

  // ---------------------------------------------------------------------------
  // Init — load persisted state
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    _stateLoadFailed = false;
    try {
      // Load identity
      final identityJson = _box.get(_keyIdentity);
      if (identityJson != null) {
        _identity = ZimraDeviceIdentity.fromJson(
          Map<String, dynamic>.from(identityJson),
        );
      }

      // Load credentials
      final credJson = _box.get(_keyCredentials);
      if (credJson != null) {
        _credentials = ZimraCredentials.fromJson(
          Map<String, dynamic>.from(credJson),
        );
      }

      // Load environment
      final envStr = _box.get(_keyEnvironment) as String?;
      if (envStr != null) {
        _environment = envStr == 'production'
            ? ZimraEnvironment.production
            : ZimraEnvironment.test;
      }

      // Load fiscal day state
      final dayJson = _box.get(_keyDayState);
      if (dayJson != null) {
        _dayState = FiscalDayState.fromJson(Map<String, dynamic>.from(dayJson));
      }
      _status = _dayState.status;

      // Load offline queue
      final queueJson = _box.get(_keyOfflineQueue);
      if (queueJson is List) {
        _offlineQueue.clear();
        for (final item in queueJson) {
          _offlineQueue.add(
            PendingReceipt.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }

      // Load config
      final configJson = _box.get(_keyConfig);
      if (configJson != null) {
        _config = ZimraConfig.fromJson(Map<String, dynamic>.from(configJson));
      }
      final fetchedAt = _box.get(_keyConfigFetchedAt) as String?;
      if (fetchedAt != null) {
        _configFetchedAt = DateTime.tryParse(fetchedAt);
      }

      // Load user-recorded applicable taxes (Settings → ZIMRA FDMS).
      final manualTaxesJson = _box.get(_keyManualTaxes);
      if (manualTaxesJson is List) {
        _manualTaxes = manualTaxesJson
            .whereType<Map>()
            .map(
              (t) => ZimraTax.fromJson({
                ...Map<String, dynamic>.from(t),
                'isManual': true,
              }),
            )
            .toList();
      }

      // Load receipt history
      final histJson = _box.get(_keyReceiptHistory);
      if (histJson is List) {
        _receiptHistory.clear();
        for (final item in histJson) {
          final map = Map<String, dynamic>.from(item);
          _receiptHistory.add(
            FiscalisedReceipt(
              receipt: Map<String, dynamic>.from(map['receipt'] ?? {}),
              response: FiscalisedReceiptResponse.fromJson(
                Map<String, dynamic>.from(map['response'] ?? {}),
              ),
              qrData: map['qrData'] as String?,
            ),
          );
        }
      }

      _updateCounts();
      notifyListeners();
    } catch (e) {
      _stateLoadFailed = true;
      _error = 'Failed to load ZIMRA state: $e';
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Device registration
  // ---------------------------------------------------------------------------

  /// Register a new device with FDMS.
  Future<void> registerDevice({
    required ZimraDeviceIdentity device,
    required String activationKey,
    ZimraEnvironment environment = ZimraEnvironment.test,
    DateTime? credentialsIssuedAt,
    String? businessTin,
  }) async {
    final age = credentialsIssuedAt == null
        ? null
        : DateTime.now().difference(credentialsIssuedAt);
    if (age == null || age.isNegative || age >= const Duration(hours: 24)) {
      throw const ZimraException(
        'ACTIVATION_EXPIRED',
        'Record when FDMS issued these credentials. Activate within 24 hours; request fresh credentials if they have expired.',
      );
    }
    if (environment == ZimraEnvironment.production) {
      final approval = approvalCase;
      if (evidenceError != null ||
          approval?.approvalRecorded != true ||
          (_environment == ZimraEnvironment.test &&
              (hasOfflineReceipts ||
                  _status != FiscalDayStatus.fiscalDayClosed)) ||
          businessTin != approval?.metadata['tin']) {
        throw const ZimraException(
          'APPROVAL_REQUIRED',
          'Complete the Test evidence checklist and record the external ZIMRA approval reference for this taxpayer before Production registration.',
        );
      }
    }
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await ZimraFiscalDevice.registerDevice(
        device: device,
        activationKey: activationKey,
        environment: environment,
      );

      _identity = device;
      _credentials = result.credentials;
      _environment = environment;
      _dayState = FiscalDayState();

      await _saveAll();
      _loading = false;
      notifyListeners();
    } catch (e) {
      _loading = false;
      _error = 'Registration failed: $e';
      notifyListeners();
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Fetch and cache the FDMS configuration (tax tables, QR URL).
  Future<ZimraConfig?> fetchConfig() {
    if (!isRegistered) return Future.value(null);
    if (_configRequest != null) return _configRequest!;
    _error = null;
    _configRequest = Future(_fetchConfig).whenComplete(() {
      _configRequest = null;
      notifyListeners();
    });
    notifyListeners();
    return _configRequest!;
  }

  Future<ZimraConfig?> _fetchConfig() async {
    ZimraFiscalDevice? device;
    try {
      device = _buildDevice();
      final config = await device.getConfig().timeout(
        const Duration(seconds: 30),
      );
      // Device isolation: the fetched table belongs to the device that
      // answered. A mismatch (device re-registered under another ID, stale
      // box) must never let one device's taxes serve another's receipts.
      if (config.deviceId != null && config.deviceId != identity!.deviceId) {
        debugPrint(
          '[FISCAL] GetConfig device mismatch: '
          '${config.deviceId} != ${identity!.deviceId}',
        );
        _error =
            'The fiscal configuration returned by ZIMRA belongs to device '
            '${config.deviceId}, but this device is ${identity!.deviceId}.';
        notifyListeners();
        return null;
      }
      final fetchedAt = DateTime.now();
      await _box.putAll({
        _keyConfig: config.toJson(),
        _keyConfigFetchedAt: fetchedAt.toIso8601String(),
      });
      _config = config;
      _configFetchedAt = fetchedAt;
      _reconcileManualTaxes(config);
      _logAudit('ZIMRA_CONFIG_REFRESH', {
        'deviceId': identity!.deviceId,
        'taxCount': config.applicableTaxes.length,
        'fetchedAt': fetchedAt.toIso8601String(),
      });
      return _config;
    } on ZimraException catch (e) {
      // Missing/invalid config fields surface here with the exact field
      // named — show that, not a bare cast failure.
      debugPrint('[FISCAL] fetchConfig failed: $e');
      _error = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('[FISCAL] fetchConfig failed: $e');
      _error = 'Failed to fetch config: $e';
      notifyListeners();
      return null;
    } finally {
      device?.close();
    }
  }

  /// Replace the user-recorded applicable taxes (Settings → ZIMRA FDMS).
  /// Persists local entries only; they are never eligible for fiscalisation.
  Future<void> setManualTaxes(List<ZimraTax> taxes) async {
    _manualTaxes = taxes
        .map((t) => ZimraTax.fromJson({...t.toJson(), 'isManual': true}))
        .toList();
    await _box.put(
      _keyManualTaxes,
      _manualTaxes.map((t) => t.toJson()).toList(),
    );
    notifyListeners();
  }

  /// Reconcile the user's manually recorded taxes against a fresh GetConfig
  /// response: manual entries whose taxID ZIMRA also returned are dropped
  /// (ZIMRA's own values are authoritative), while manual entries for IDs
  /// ZIMRA did not return survive — they exist precisely because the device
  /// config lacks them.
  void _reconcileManualTaxes(ZimraConfig config) {
    if (_manualTaxes.isEmpty) return;
    final fdmsIds = config.applicableTaxes.map((t) => t.taxId).toSet();
    final remaining = _manualTaxes
        .where((t) => !fdmsIds.contains(t.taxId))
        .toList();
    if (remaining.length != _manualTaxes.length) {
      _manualTaxes = remaining;
      _box.put(_keyManualTaxes, _manualTaxes.map((t) => t.toJson()).toList());
    }
  }

  /// Structured audit log for fiscalisation events. Identifier metadata
  /// only — receipts, payloads and credentials are never logged here.
  void _logAudit(String event, Map<String, Object?> fields) {
    assert(() {
      final ts = DateTime.now().toUtc().toIso8601String();
      final kv = fields.entries.map((e) => '${e.key}=${e.value}').join(' ');
      debugPrint('[FISCAL-AUDIT] $event $ts $kv');
      return true;
    }());
  }

  // ---------------------------------------------------------------------------
  // Fiscal day lifecycle
  // ---------------------------------------------------------------------------

  /// Check the current day status from FDMS.
  Future<void> refreshStatus() async {
    return _withFiscalLock(() async {
      if (!isRegistered) return;

      ZimraFiscalDevice? device;
      try {
        device = _buildDevice();
        _status = await device.getStatus().timeout(const Duration(seconds: 30));
        _dayState = device.getState();
        _error = null;
        await _saveDayState();
        _updateCounts();
        notifyListeners();
      } catch (e) {
        _error = 'Failed to check status: $e';
        notifyListeners();
      } finally {
        device?.close();
      }
    });
  }

  /// Open a new fiscal day.
  Future<void> openDay() async {
    return _withFiscalLock(() async {
      if (!isRegistered) return;

      _loading = true;
      _error = null;
      notifyListeners();

      ZimraFiscalDevice? device;
      try {
        device = _buildDevice();
        await device.openDay();
        _dayState = device.getState();
        _status = FiscalDayStatus.fiscalDayOpened;
        await _saveDayState();
        _loading = false;
        _updateCounts();
        notifyListeners();
      } catch (e) {
        _loading = false;
        _error = 'Failed to open day: $e';
        notifyListeners();
        rethrow;
      } finally {
        device?.close();
      }
    });
  }

  /// Close the current fiscal day.
  Future<void> closeDay({bool force = false}) async {
    return _withFiscalLock(() async {
      if (!isRegistered) return;

      _loading = true;
      _error = null;
      notifyListeners();

      ZimraFiscalDevice? device;
      try {
        device = _buildDevice();
        await device.closeDay(force: force);
        _dayState = device.getState();
        _status = _dayState.status;
        await _saveDayState();
        _loading = false;
        _updateCounts();
        notifyListeners();
      } catch (e) {
        _loading = false;
        _error = 'Failed to close day: $e';
        notifyListeners();
        rethrow;
      } finally {
        device?.close();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Receipt submission
  // ---------------------------------------------------------------------------

  /// Submit a receipt to FDMS. Returns the fiscalised receipt with QR data.
  Future<FiscalisedReceipt?> submitReceipt({
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
    return _withFiscalLock(() async {
      if (!isRegistered || !isOpen) return null;

      final device = _buildDevice();
      _lastSubmitError = null;
      try {
        final result = await device.submitReceipt(
          currency: currency,
          invoiceNo: invoiceNo,
          lines: lines,
          payments: payments,
          receiptType: receiptType,
          linesTaxInclusive: linesTaxInclusive,
          receiptDate: receiptDate,
          notes: notes,
          buyer: buyer,
          creditDebitNote: creditDebitNote,
          receiptPrintForm: receiptPrintForm,
        );

        _dayState = device.getState();
        _status = device.dayState.status;
        _receiptHistory.insert(0, result);

        await _saveDayState();
        await _saveOfflineQueue();
        await _saveReceiptHistory();
        _updateCounts();
        notifyListeners();

        return result;
      } on ZimraException catch (e) {
        // Rejection (state unchanged) or offline queueing (state advanced —
        // the signed receipt was journaled). Persist whichever it is so a
        // restart cannot lose receipt numbers or the hash chain.
        _lastSubmitError = e;
        _dayState = device.getState();
        _offlineQueue
          ..clear()
          ..addAll(device.offlineQueue);
        _error = 'Receipt submission failed: $e';
        await _saveDayState();
        await _saveOfflineQueue();
        _updateCounts();
        notifyListeners();
        return null;
      } catch (e) {
        _dayState = device.getState();
        _error = 'Receipt submission failed: $e';
        await _saveDayState();
        _updateCounts();
        notifyListeners();
        return null;
      } finally {
        device.close();
      }
    });
  }

  /// Clear the last submission error (before a new attempt).
  void clearSubmitError() {
    _lastSubmitError = null;
    _error = null;
  }

  /// Resubmit an already-signed receipt payload (retry after a network
  /// failure or an offline-queue flush). Never consumes a new receipt
  /// number — FDMS de-duplicates identical submissions.
  Future<FiscalisedReceipt?> resubmitReceipt(
    Map<String, dynamic> receiptPayload,
  ) async {
    return _withFiscalLock(() async {
      if (!isRegistered) return null;

      final requested = receiptPayload['receipt'] as Map?;
      for (final accepted in _receiptHistory) {
        final receipt = accepted.receipt['receipt'] as Map?;
        if (accepted.response.receiptId != null &&
            requested != null &&
            receipt?['receiptGlobalNo'] == requested['receiptGlobalNo'] &&
            (receipt?['receiptDeviceSignature'] as Map?)?['hash'] ==
                (requested['receiptDeviceSignature'] as Map?)?['hash']) {
          return accepted;
        }
      }

      final device = _buildDevice();
      _lastSubmitError = null;
      try {
        final result = await device.resubmitReceipt(receiptPayload);
        _dayState = device.getState();
        _offlineQueue.removeWhere(
          (pending) =>
              pending.receiptGlobalNo ==
              (receiptPayload['receipt'] as Map)['receiptGlobalNo'],
        );
        _receiptHistory.insert(0, result);
        await _saveDayState();
        await _saveOfflineQueue();
        await _saveReceiptHistory();
        notifyListeners();
        return result;
      } on ZimraException catch (e) {
        _lastSubmitError = e;
        _error = 'Receipt resubmission failed: $e';
        notifyListeners();
        return null;
      } catch (e) {
        // Network-level failure — the caller keeps its pending record.
        _error = 'Receipt resubmission failed: $e';
        notifyListeners();
        return null;
      } finally {
        device.close();
      }
    });
  }

  /// Flush any pending offline receipts.
  Future<int> flushOfflineQueue() async {
    return _withFiscalLock(() async {
      if (!isRegistered || _offlineQueue.isEmpty) return 0;

      final device = _buildDevice();
      try {
        final results = await device.flushOfflineQueue();

        _dayState = device.getState();

        _offlineQueue.clear();
        _offlineQueue.addAll(device.offlineQueue);
        _receiptHistory.insertAll(0, results);

        await _saveDayState();
        await _saveOfflineQueue();
        await _saveReceiptHistory();
        _updateCounts();
        notifyListeners();

        return results.length;
      } catch (e) {
        _error = 'Failed to flush offline queue: $e';
        notifyListeners();
        return 0;
      } finally {
        device.close();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Device management
  // ---------------------------------------------------------------------------

  /// Clear all ZIMRA data (de-register device).
  Future<void> clearDevice() async {
    return _withFiscalLock(() async {
      if (isLoading) return;
      _identity = null;
      _credentials = null;
      _dayState = FiscalDayState();
      _config = null;
      _configFetchedAt = null;
      _manualTaxes = [];
      _lastSubmitError = null;
      _offlineQueue.clear();
      _receiptHistory.clear();
      _status = FiscalDayStatus.fiscalDayClosed;
      _error = null;

      await _box.delete(_keyIdentity);
      await _box.delete(_keyCredentials);
      await _box.delete(_keyEnvironment);
      await _box.delete(_keyDayState);
      await _box.delete(_keyOfflineQueue);
      await _box.delete(_keyConfig);
      await _box.delete(_keyConfigFetchedAt);
      await _box.delete(_keyManualTaxes);
      await _box.delete(_keyReceiptHistory);
      _updateCounts();
      notifyListeners();
    });
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  ZimraFiscalDevice _buildDevice() {
    if (_stateLoadFailed) {
      throw const ZimraException(
        'STATE001',
        'Stored fiscal state could not be loaded. Recover the fiscal journal before continuing.',
      );
    }
    ZimraApi? transport = transportFactory?.call();
    if (_environment == ZimraEnvironment.production && transport == null) {
      if (productionTransportFactory == null) {
        throw const ZimraException(
          'BILLING_CONFIG',
          'Production fiscalisation requires the credit gateway.',
        );
      }
      transport = productionTransportFactory!(_identity!, _credentials!);
    }
    if (_environment == ZimraEnvironment.test) {
      final identity = _identity!;
      final dayNo = _dayState.fiscalDayNo;
      transport ??= ZimraTransport(
        baseUrl: _environment.baseUrl,
        certificatePem: _credentials!.certificatePem,
        privateKeyPem: _credentials!.privateKeyPem,
        defaultHeaders: identity.requestHeaders,
      );
      transport = EvidenceTransport(
        transport,
        (method, path, body, response) =>
            _captureEvidence(identity, dayNo, method, path, body, response),
        (error) {
          evidenceError = 'Evidence capture failed: $error';
        },
      );
    }
    return ZimraFiscalDevice(
      identity: _identity!,
      credentials: _credentials!,
      environment: _environment,
      dayState: _dayState.clone(),
      offlineQueue: List.from(_offlineQueue),
      transport: transport,
      // Seed the persisted FDMS configuration so operations that need it
      // (submitReceipt's signing/QR step — RCP002) work from cache without
      // a fresh GetConfig round-trip on every call.
      config: _config,
    );
  }

  bool get isOpen => _dayState.isOpen;

  void _updateCounts() {
    _receiptCount = _dayState.receiptCounter;
    _globalReceiptCount = _dayState.receiptGlobalNo;
  }

  Future<void> _saveAll() async {
    await _saveIdentity();
    await _saveCredentials();
    await _saveEnvironment();
    await _saveDayState();
  }

  Future<void> _saveIdentity() async {
    if (_identity != null) {
      await _box.put(_keyIdentity, _identity!.toJson());
    } else {
      await _box.delete(_keyIdentity);
    }
  }

  Future<void> _saveCredentials() async {
    if (_credentials != null) {
      await _box.put(_keyCredentials, _credentials!.toJson());
    } else {
      await _box.delete(_keyCredentials);
    }
  }

  Future<void> _saveEnvironment() async {
    await _box.put(_keyEnvironment, _environment.name);
  }

  Future<void> _saveDayState() async {
    await _box.put(_keyDayState, _dayState.toJson());
  }

  Future<void> _saveOfflineQueue() async {
    await _box.put(
      _keyOfflineQueue,
      _offlineQueue.map((r) => r.toJson()).toList(),
    );
  }

  Future<void> _saveReceiptHistory() async {
    // Fiscal records must survive restarts regardless of UI history size.
    // Retention/archival must be explicit, never a silent rolling limit.
    await _box.put(
      _keyReceiptHistory,
      _receiptHistory
          .map(
            (r) => {
              'receipt': r.receipt,
              'response': r.response.toJson(),
              'qrData': r.qrData,
            },
          )
          .toList(),
    );
  }
}
