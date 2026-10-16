/// Data models for the ZIMRA Fiscalisation Data Management System (FDMS).
library;

import 'buyer_contract.dart';

///
/// Ported from zimra-fdms TypeScript SDK v0.4.0.
/// See https://zimrasdk.com/docs for the full protocol specification.

/// Defensively parse an integer field from FDMS / persisted JSON.
///
/// Accepts JSON numbers (int or double) and numeric strings; returns null
/// for anything else (including null itself). Callers must treat null as
/// "field missing" and validate — never substitute 0 for a required
/// fiscalisation value.
int? parseNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) {
    return value.isFinite && value == value.truncateToDouble()
        ? value.toInt()
        : null;
  }
  return int.tryParse(value.toString());
}

/// Defensively parse a double field (JSON number or numeric string).
double? parseNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

// ---------------------------------------------------------------------------
// Device identity & credentials
// ---------------------------------------------------------------------------

/// The physical device's identity — issued by the FDMS portal.
class ZimraDeviceIdentity {
  final int deviceId;
  final String serialNumber;
  final String modelName;
  final String modelVersion;

  const ZimraDeviceIdentity({
    required this.deviceId,
    required this.serialNumber,
    this.modelName = 'QuoteFlow',
    this.modelVersion = 'v1',
  });

  /// ZIMRA's required CSR subject common name format:
  /// `ZIMRA-{serialNumber}-{deviceId padded to 10 digits}`
  String get commonName =>
      'ZIMRA-$serialNumber-${deviceId.toString().padLeft(10, '0')}';

  /// Mandatory headers from the FDMS Public-v1 and Device-v1 OpenAPI schemas.
  Map<String, String> get requestHeaders => {
    'DeviceModelName': modelName,
    'DeviceModelVersion': modelVersion,
  };

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'serialNumber': serialNumber,
    'modelName': modelName,
    'modelVersion': modelVersion,
  };

  factory ZimraDeviceIdentity.fromJson(Map<String, dynamic> j) {
    // `deviceId` is the app's persisted spelling; accept `device_id` too.
    final deviceId = parseNullableInt(j['deviceId'] ?? j['device_id']);
    if (deviceId == null) {
      throw const FormatException(
        'required integer field "deviceId" is missing or invalid in the '
        'stored device identity',
      );
    }
    final serialNumber = j['serialNumber'] as String?;
    if (serialNumber == null || serialNumber.isEmpty) {
      throw const FormatException(
        'required field "serialNumber" is missing in the stored device '
        'identity',
      );
    }
    return ZimraDeviceIdentity(
      deviceId: deviceId,
      serialNumber: serialNumber,
      modelName: j['modelName'] as String? ?? 'QuoteFlow',
      modelVersion: j['modelVersion'] as String? ?? 'v1',
    );
  }
}

/// PEM-encoded key pair + certificate issued after device registration.
class ZimraCredentials {
  final String privateKeyPem;
  final String certificatePem;
  final String publicKeyPem;
  final String csrPem;

  const ZimraCredentials({
    required this.privateKeyPem,
    required this.certificatePem,
    this.publicKeyPem = '',
    this.csrPem = '',
  });

  Map<String, dynamic> toJson() => {
    'privateKeyPem': privateKeyPem,
    'certificatePem': certificatePem,
    'publicKeyPem': publicKeyPem,
    'csrPem': csrPem,
  };

  factory ZimraCredentials.fromJson(Map<String, dynamic> j) => ZimraCredentials(
    privateKeyPem: j['privateKeyPem'] as String,
    certificatePem: j['certificatePem'] as String,
    publicKeyPem: j['publicKeyPem'] as String? ?? '',
    csrPem: j['csrPem'] as String? ?? '',
  );
}

/// FDMS environment: test (self-service) or production.
enum ZimraEnvironment {
  test,
  production;

  String get baseUrl => this == ZimraEnvironment.test
      ? 'https://fdmsapitest.zimra.co.zw'
      : 'https://fdmsapi.zimra.co.zw';
}

// ---------------------------------------------------------------------------
// Tax configuration (from getConfig + user-supplied entries)
// ---------------------------------------------------------------------------

class ZimraTax {
  final int taxId;
  final String taxCode;
  final String taxName;
  final double taxPercent;
  final bool isExempt;

  /// FDMS `validFrom` / `validTill` (ISO strings) when the device config
  /// carries them — null means open-ended. Used by the tax resolver to
  /// pick entries valid on the document date.
  final String? validFrom;
  final String? validTill;

  /// Legacy local entry. Never eligible for an FDMS receipt payload.
  final bool isManual;
  final String? taxType;
  final String? taxCategory;
  final bool active;
  String get source => isManual ? 'local' : 'FDMS';

  bool isValidOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    DateTime? parse(String? value) =>
        value == null ? null : DateTime.tryParse(value);
    final start = parse(validFrom);
    final end = parse(validTill);
    if ((validFrom != null && start == null) ||
        (validTill != null && end == null)) {
      return false;
    }
    return active &&
        !isManual &&
        (start == null ||
            !day.isBefore(DateTime(start.year, start.month, start.day))) &&
        (end == null || !day.isAfter(DateTime(end.year, end.month, end.day)));
  }

  const ZimraTax({
    required this.taxId,
    required this.taxCode,
    required this.taxName,
    required this.taxPercent,
    this.isExempt = false,
    this.validFrom,
    this.validTill,
    this.isManual = false,
    this.taxType,
    this.taxCategory,
    this.active = true,
  });

  factory ZimraTax.fromJson(Map<String, dynamic> j) {
    // FDMS wire field is `taxID` (capital ID — GetConfigResponse
    // TaxDefinition in the Device-v1 swagger). `taxId` is the spelling
    // this app persists locally; accept both, require one to be present.
    final taxId = parseNullableInt(j['taxID'] ?? j['taxId']);
    if (taxId == null) {
      final name = j['taxName'] as String? ?? '<unnamed tax>';
      throw FormatException(
        'required integer field "taxID" is missing or invalid for tax '
        '"$name"',
      );
    }
    final percent = parseNullableDouble(j['taxPercent']);
    if (j['taxPercent'] != null &&
        (percent == null || !percent.isFinite || percent < 0)) {
      throw const FormatException('Invalid FDMS taxPercent');
    }
    return ZimraTax(
      taxId: taxId,
      taxCode: j['taxCode'] as String? ?? '',
      taxName: (j['taxName'] ?? j['description']) as String? ?? '',
      // taxPercent is null/absent for exempt taxes (per the wire contract).
      taxPercent: percent ?? 0,
      isExempt: j['isExempt'] as bool? ?? j['taxPercent'] == null,
      validFrom:
          (j['validFrom'] ?? j['valid_from'] ?? j['taxValidFrom']) as String?,
      validTill:
          (j['validTill'] ?? j['valid_till'] ?? j['taxValidTill']) as String?,
      isManual: j['isManual'] == true || j['source'] == 'local',
      taxType: j['taxType']?.toString(),
      taxCategory: j['taxCategory']?.toString(),
      active: j['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    // Persist under this app's `taxId` spelling; fromJson accepts the FDMS
    // wire spelling `taxID` too.
    'taxId': taxId,
    'taxCode': taxCode,
    'taxName': taxName,
    'taxPercent': taxPercent,
    'isExempt': isExempt,
    if (validFrom != null) 'validFrom': validFrom,
    if (validTill != null) 'validTill': validTill,
    if (isManual) 'isManual': true,
    'source': source,
    if (taxType != null) 'taxType': taxType,
    if (taxCategory != null) 'taxCategory': taxCategory,
    'active': active,
  };
}

class ZimraConfig {
  final List<ZimraTax> applicableTaxes;
  final String qrUrl;

  /// The fiscal device this configuration belongs to. Stamp prevents one
  /// tenant/business/device's tax table from leaking into another when a
  /// box is restored or a device is re-registered under a different ID.
  /// Null only for configurations persisted by older builds.
  final int? deviceId;

  /// When GetConfig last answered. Null for older persisted configs.
  final DateTime? fetchedAt;

  /// The applicableTaxes elements exactly as ZIMRA returned them (wire
  /// field names preserved) — for debugging and support, never for
  /// fiscalisation logic.
  final List<Map<String, dynamic>> rawTaxes;

  const ZimraConfig({
    required this.applicableTaxes,
    required this.qrUrl,
    this.deviceId,
    this.fetchedAt,
    this.rawTaxes = const [],
  });

  factory ZimraConfig.fromJson(Map<String, dynamic> j) {
    final rawTaxes = (j['applicableTaxes'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((t) => Map<String, dynamic>.from(t))
        .toList();
    return ZimraConfig(
      applicableTaxes: rawTaxes.map((t) => ZimraTax.fromJson(t)).toList(),
      // Validated by fiscalConfigProblem / getConfig — never defaulted to a
      // fabricated URL.
      qrUrl: j['qrUrl'] as String? ?? '',
      deviceId: parseNullableInt(j['deviceId'] ?? j['deviceID']),
      fetchedAt: j['fetchedAt'] is String
          ? DateTime.tryParse(j['fetchedAt'] as String)
          : null,
      rawTaxes:
          (j['rawTaxes'] as List?)
              ?.whereType<Map>()
              .map((t) => Map<String, dynamic>.from(t))
              .toList() ??
          rawTaxes,
    );
  }

  Map<String, dynamic> toJson() => {
    'applicableTaxes': applicableTaxes.map((t) => t.toJson()).toList(),
    'qrUrl': qrUrl,
    if (deviceId != null) 'deviceId': deviceId,
    if (fetchedAt != null) 'fetchedAt': fetchedAt!.toIso8601String(),
    // Raw wire payloads are preserved verbatim for debugging; note they use
    // ZIMRA's field spellings (taxID etc.) and are never re-parsed as truth.
    if (rawTaxes.isNotEmpty) 'rawTaxes': rawTaxes,
  };

  /// Return a copy stamped with device/fetch metadata (used by getConfig).
  ZimraConfig stamp({
    int? deviceId,
    DateTime? fetchedAt,
    List<Map<String, dynamic>>? rawTaxes,
  }) => ZimraConfig(
    applicableTaxes: applicableTaxes,
    qrUrl: qrUrl,
    deviceId: deviceId ?? this.deviceId,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    rawTaxes: rawTaxes ?? this.rawTaxes,
  );
}

/// Compatibility helper: local entries can never override or supplement FDMS.
List<ZimraTax> mergeTaxTables(
  List<ZimraTax> fdmsTaxes,
  List<ZimraTax> manualTaxes,
) => fdmsTaxes.where((tax) => !tax.isManual).toList();

// ---------------------------------------------------------------------------
// Fiscal day state
// ---------------------------------------------------------------------------

enum FiscalDayStatus {
  fiscalDayClosed,
  fiscalDayOpened,
  fiscalDayCloseInitiated,
  fiscalDayCloseFailed;

  /// Map the FDMS `FiscalDayStatusEnum` wire value (e.g. `FiscalDayOpened`)
  /// to a status. Unknown values must not authorize opening a new day.
  static FiscalDayStatus fromString(String s) => switch (s) {
    'FiscalDayOpened' => fiscalDayOpened,
    'FiscalDayCloseInitiated' => fiscalDayCloseInitiated,
    'FiscalDayCloseFailed' => fiscalDayCloseFailed,
    'FiscalDayClosed' => fiscalDayClosed,
    // Legacy lowercase names written by earlier builds of this app.
    'fiscalDayOpened' => fiscalDayOpened,
    'fiscalDayCloseInitiated' => fiscalDayCloseInitiated,
    'fiscalDayCloseFailed' => fiscalDayCloseFailed,
    'fiscalDayClosed' => fiscalDayClosed,
    _ => throw FormatException('Unknown FDMS fiscal day status', s),
  };
}

/// Money type must match the FDMS `MoneyTypeEnum` wire values.
enum MoneyType {
  cash,
  card,
  mobileWallet,
  coupon,
  credit,
  bankTransfer,
  other;

  /// Wire value sent to FDMS (`PaymentDto.moneyTypeCode`).
  String get label => switch (this) {
    cash => 'Cash',
    card => 'Card',
    mobileWallet => 'MobileWallet',
    coupon => 'Coupon',
    credit => 'Credit',
    bankTransfer => 'BankTransfer',
    other => 'Other',
  };
}

/// One fiscal counter exactly as FDMS defines it (`FiscalDayCounterDto`).
///
/// `type` follows `FiscalCounterTypeEnum` (SaleByTax, SaleTaxByTax,
/// BalanceByMoneyType, CreditNoteByTax, …), `currency` is the 3-letter ISO
/// code and [value] is an amount in major units (NOT cents).
class FiscalDayCounter {
  final String type;
  final String currency;
  final int? taxId;
  final double? taxPercent;
  final String? moneyType;
  final double value;

  const FiscalDayCounter({
    required this.type,
    required this.currency,
    this.taxId,
    this.taxPercent,
    this.moneyType,
    this.value = 0,
  });

  FiscalDayCounter copyWith({double? value}) => FiscalDayCounter(
    type: type,
    currency: currency,
    taxId: taxId,
    taxPercent: taxPercent,
    moneyType: moneyType,
    value: value ?? this.value,
  );

  Map<String, dynamic> toJson() => {
    'fiscalCounterType': type,
    'fiscalCounterCurrency': currency,
    if (taxId != null) 'fiscalCounterTaxID': taxId,
    if (taxPercent != null) 'fiscalCounterTaxPercent': taxPercent,
    if (moneyType != null) 'fiscalCounterMoneyType': moneyType,
    'fiscalCounterValue': value,
  };

  factory FiscalDayCounter.fromJson(Map<String, dynamic> j) => FiscalDayCounter(
    type: j['fiscalCounterType'] as String,
    currency: (j['fiscalCounterCurrency'] as String?) ?? 'USD',
    taxId: (j['fiscalCounterTaxID'] as num?)?.toInt(),
    taxPercent: (j['fiscalCounterTaxPercent'] as num?)?.toDouble(),
    moneyType: j['fiscalCounterMoneyType'] as String?,
    value: (j['fiscalCounterValue'] as num?)?.toDouble() ?? 0,
  );

  /// Merge counters that share the same FDMS identity (type + currency +
  /// tax id / money type), summing their values.
  static List<FiscalDayCounter> mergeAll(List<FiscalDayCounter> source) =>
      _mergeCounters(source);

  /// Expand one persisted counter entry into FDMS counters, merging equals.
  ///
  /// Older builds stored a per-(tax, money) row in cents
  /// (`{taxId, taxPercent, currency, moneyType, salesAmountWithTax, …}`);
  /// that row maps onto the Sale*/Balance counters it was derived from.
  static List<FiscalDayCounter> parsePersisted(Object? entry) {
    if (entry is! Map) return const [];
    final j = Map<String, dynamic>.from(entry);
    if (j.containsKey('fiscalCounterType')) {
      return [FiscalDayCounter.fromJson(j)];
    }

    final currency = (j['currency'] as String?) ?? 'USD';
    final taxId = (j['taxId'] as num?)?.toInt();
    final taxPercent = (j['taxPercent'] as num?)?.toDouble();
    final gross = ((j['salesAmountWithTax'] as num?)?.toInt() ?? 0) / 100;
    final tax = ((j['taxAmount'] as num?)?.toInt() ?? 0) / 100;
    var moneyType = j['moneyType'] as String?;
    if (moneyType == 'Mobile') moneyType = 'MobileWallet';

    return [
      FiscalDayCounter(
        type: 'SaleByTax',
        currency: currency,
        taxId: taxId,
        taxPercent: taxPercent,
        value: gross,
      ),
      FiscalDayCounter(
        type: 'SaleTaxByTax',
        currency: currency,
        taxId: taxId,
        taxPercent: taxPercent,
        value: tax,
      ),
      if (moneyType != null)
        FiscalDayCounter(
          type: 'BalanceByMoneyType',
          currency: currency,
          moneyType: moneyType,
          value: gross,
        ),
    ];
  }
}

/// Persistent fiscal day state — survives app restarts.
class FiscalDayState {
  int? fiscalDayNo;
  String? fiscalDayDate;
  int receiptCounter;
  int receiptGlobalNo;
  String? previousReceiptHash;
  List<FiscalDayCounter> counters;
  FiscalDayStatus status;
  List<String> redErrors;

  FiscalDayState({
    this.fiscalDayNo,
    this.fiscalDayDate,
    this.receiptCounter = 0,
    this.receiptGlobalNo = 0,
    this.previousReceiptHash,
    List<FiscalDayCounter>? counters,
    this.status = FiscalDayStatus.fiscalDayClosed,
    List<String>? redErrors,
  }) : counters = counters ?? [],
       redErrors = redErrors ?? [];

  bool get isClosed => status == FiscalDayStatus.fiscalDayClosed;
  bool get isOpen => status == FiscalDayStatus.fiscalDayOpened;
  bool get hasRedErrors => redErrors.isNotEmpty;

  /// Deep clone for persistence.
  FiscalDayState clone() => FiscalDayState(
    fiscalDayNo: fiscalDayNo,
    fiscalDayDate: fiscalDayDate,
    receiptCounter: receiptCounter,
    receiptGlobalNo: receiptGlobalNo,
    previousReceiptHash: previousReceiptHash,
    counters: counters.map((c) => c.copyWith(value: c.value)).toList(),
    status: status,
    redErrors: List.from(redErrors),
  );

  Map<String, dynamic> toJson() => {
    if (fiscalDayNo != null) 'fiscalDayNo': fiscalDayNo,
    if (fiscalDayDate != null) 'fiscalDayDate': fiscalDayDate,
    'receiptCounter': receiptCounter,
    'receiptGlobalNo': receiptGlobalNo,
    if (previousReceiptHash != null) 'previousReceiptHash': previousReceiptHash,
    'counters': counters.map((c) => c.toJson()).toList(),
    'status': status.name,
    'redErrors': redErrors,
  };

  factory FiscalDayState.fromJson(Map<String, dynamic> j) => FiscalDayState(
    fiscalDayNo: parseNullableInt(j['fiscalDayNo']),
    fiscalDayDate: j['fiscalDayDate'] as String?,
    receiptCounter: parseNullableInt(j['receiptCounter']) ?? 0,
    receiptGlobalNo: parseNullableInt(j['receiptGlobalNo']) ?? 0,
    previousReceiptHash: j['previousReceiptHash'] as String?,
    counters: _mergeCounters(
      (j['counters'] as List<dynamic>? ?? [])
          .expand((c) => FiscalDayCounter.parsePersisted(c))
          .toList(),
    ),
    status: FiscalDayStatus.fromString(j['status'] as String? ?? ''),
    redErrors: (j['redErrors'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList(),
  );
}

/// Merge counters that share the same FDMS identity (type + currency +
/// tax id / money type), summing their values.
List<FiscalDayCounter> _mergeCounters(List<FiscalDayCounter> source) {
  final merged = <String, FiscalDayCounter>{};
  for (final c in source) {
    final key = '${c.type}|${c.currency}|${c.taxId}|${c.moneyType}';
    final existing = merged[key];
    if (existing == null) {
      merged[key] = c;
    } else {
      merged[key] = existing.copyWith(value: existing.value + c.value);
    }
  }
  return merged.values.toList();
}

// ---------------------------------------------------------------------------
// Receipt input & output
// ---------------------------------------------------------------------------

enum ReceiptType {
  fiscalInvoice('FISCALINVOICE', 'FiscalInvoice'),
  creditNote('CREDITNOTE', 'CreditNote'),
  debitNote('DEBITNOTE', 'DebitNote');

  const ReceiptType(this.xmlValue, this.apiValue);

  /// Uppercase form used inside FDMS canonical signing strings.
  final String xmlValue;

  /// JSON enum value sent to FDMS (`ReceiptTypeEnum`).
  final String apiValue;
}

class ReceiptLineInput {
  final String name;
  final double price;
  final double quantity;
  final int taxId;
  final double? taxPercent;
  final String? taxCode;
  final String? hsCode;

  /// FDMS `ReceiptLineTypeEnum`: 'Sale' or 'Discount'.
  final String lineType;

  const ReceiptLineInput({
    required this.name,
    required this.price,
    required this.quantity,
    required this.taxId,
    this.taxPercent,
    this.taxCode,
    this.hsCode,
    this.lineType = 'Sale',
  });
}

class ReceiptPayment {
  final String moneyType;
  final int amount; // cents

  const ReceiptPayment({required this.moneyType, required this.amount});
}

class BuyerData {
  final String? tin;
  final String? name;
  final String? tradeName;
  final String? vatNumber;
  final Map<String, String> buyerAddress;
  final Map<String, String> buyerContacts;

  const BuyerData({
    this.tin,
    this.name,
    this.tradeName,
    this.vatNumber,
    this.buyerAddress = const {},
    this.buyerContacts = const {},
  });

  Map<String, dynamic> toJson() => {
    'buyerRegisterName': name?.trim(),
    'buyerTIN': tin?.trim(),
    if (tradeName != null) 'buyerTradeName': tradeName!.trim(),
    if (vatNumber != null) 'vatNumber': vatNumber!.trim(),
    if (buyerAddress.isNotEmpty) 'buyerAddress': buyerAddress,
    if (buyerContacts.isNotEmpty) 'buyerContacts': buyerContacts,
  };
}

/// Reference from a credit/debit note to the original fiscal document
/// (`ReceiptDto.creditDebitNote`, all fields nullable in the contract).
class CreditDebitNoteRef {
  final int? receiptId;
  final int? deviceId;
  final int? receiptGlobalNo;
  final int? fiscalDayNo;

  const CreditDebitNoteRef({
    this.receiptId,
    this.deviceId,
    this.receiptGlobalNo,
    this.fiscalDayNo,
  });

  Map<String, dynamic> toJson() => {
    if (receiptId != null) 'receiptID': receiptId,
    if (deviceId != null) 'deviceID': deviceId,
    if (receiptGlobalNo != null) 'receiptGlobalNo': receiptGlobalNo,
    if (fiscalDayNo != null) 'fiscalDayNo': fiscalDayNo,
  };
}

/// A fully fiscalised receipt returned by submitReceipt.
class FiscalisedReceipt {
  final Map<String, dynamic> receipt;
  final FiscalisedReceiptResponse response;
  final String? qrData;

  const FiscalisedReceipt({
    required this.receipt,
    required this.response,
    this.qrData,
  });
}

class FiscalisedReceiptResponse {
  /// FDMS `receiptID` (int64) — stable id of the stored receipt.
  final int? receiptId;

  /// FDMS `serverDate` — server-side receipt timestamp.
  final String? serverDate;

  /// `receiptServerSignature.hash` (base64 SHA-256 of the canonical string).
  final String? serverHash;

  /// `receiptServerSignature.signature` (base64) — ZIMRA's acknowledgement
  /// signature over the receipt, NOT a QR input.
  final String? signature;

  /// SHA-1 thumbprint of the certificate ZIMRA signed with.
  final String? certificateThumbprint;

  /// FDMS `operationID` assigned to this submission.
  final String? operationId;

  final List<ValidationError> validationErrors;
  final Map<String, dynamic> serverResponse;

  const FiscalisedReceiptResponse({
    this.receiptId,
    this.serverDate,
    this.serverHash,
    this.signature,
    this.certificateThumbprint,
    this.operationId,
    this.validationErrors = const [],
    this.serverResponse = const {},
  });

  Map<String, dynamic> toJson() => {
    'serverResponse': serverResponse,
    'receiptId': receiptId,
    'serverDate': serverDate,
    'serverHash': serverHash,
    'signature': signature,
    'certificateThumbprint': certificateThumbprint,
    'operationId': operationId,
    'validationErrors': validationErrors
        .map(
          (e) => {
            'code': e.code,
            'color': e.color,
            'description': e.description,
          },
        )
        .toList(),
  };

  factory FiscalisedReceiptResponse.fromJson(Map<String, dynamic> j) =>
      FiscalisedReceiptResponse(
        serverResponse: Map<String, dynamic>.from(
          j['serverResponse'] as Map? ?? {},
        ),
        receiptId: (j['receiptId'] as num?)?.toInt(),
        serverDate: j['serverDate'] as String?,
        serverHash: j['serverHash'] as String?,
        signature: j['signature'] as String?,
        certificateThumbprint: j['certificateThumbprint'] as String?,
        operationId: j['operationId'] as String?,
        validationErrors: (j['validationErrors'] as List<dynamic>? ?? [])
            .map(
              (e) => ValidationError(
                code: e['code'] as String? ?? '',
                color: e['color'] as String? ?? '',
                description: e['description'] as String? ?? '',
              ),
            )
            .toList(),
      );
}

class ValidationError {
  final String code;
  final String color;
  final String description;

  const ValidationError({
    required this.code,
    required this.color,
    required this.description,
  });

  String get userMessage => fiscalValidationMessage(code, description);

  bool get isRed => color.toLowerCase() == 'red';
  bool get isYellow => color.toLowerCase() == 'yellow';
}

// ---------------------------------------------------------------------------
// Offline queue
// ---------------------------------------------------------------------------

class PendingReceipt {
  final String id;
  final Map<String, dynamic> receiptPayload;
  final DateTime createdAt;
  final int fiscalDayNo;
  final int receiptGlobalNo;

  const PendingReceipt({
    required this.id,
    required this.receiptPayload,
    required this.createdAt,
    required this.fiscalDayNo,
    required this.receiptGlobalNo,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'receiptPayload': receiptPayload,
    'createdAt': createdAt.toIso8601String(),
    'fiscalDayNo': fiscalDayNo,
    'receiptGlobalNo': receiptGlobalNo,
  };

  factory PendingReceipt.fromJson(Map<String, dynamic> j) => PendingReceipt(
    id: j['id'] as String,
    receiptPayload: Map<String, dynamic>.from(j['receiptPayload'] as Map),
    createdAt: DateTime.parse(j['createdAt'] as String),
    fiscalDayNo:
        parseNullableInt(j['fiscalDayNo']) ??
        (throw const FormatException(
          'required integer field "fiscalDayNo" is missing in a persisted '
          'offline receipt',
        )),
    receiptGlobalNo:
        parseNullableInt(j['receiptGlobalNo']) ??
        (throw const FormatException(
          'required integer field "receiptGlobalNo" is missing in a '
          'persisted offline receipt',
        )),
  );
}
