/// Maps QuoteFlow documents onto FDMS receipt input and back.
///
/// Everything here follows the FDMS `ReceiptDto` contract implemented by
/// this project (see /swagger/Device-v1/swagger.json and the zimra-fdms
/// reference SDK): nothing fiscal is invented — the verification QR payload
/// always comes from [ZimraFiscalDevice.buildVerificationQrData].
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/document.dart';
import '../models/organization.dart';
import 'calculations.dart' show round2;
import 'tax_engine.dart';
import 'tax_resolver.dart';
import 'zimra/zimra.dart';

/// `MoneyTypeEnum` values offered when fiscalising a document.
const List<String> fiscalMoneyTypes = [
  'Cash',
  'Card',
  'MobileWallet',
  'Coupon',
  'Credit',
  'BankTransfer',
  'Other',
];

/// The slice of the ZIMRA provider that fiscalisation logic needs. Keeps
/// this service testable without Flutter/provider plumbing and stops the
/// service from depending on a concrete provider class.
abstract interface class ZimraProviderLike {
  bool get isRegistered;
  bool get isOpen;
  ZimraConfig? get effectiveConfig;
  String get currencyCode;
}

/// Structured audit events for the fiscalisation pipeline. Identifier
/// metadata only — payloads, receipts, certificates and credentials are
/// never passed here.
void fiscalAuditLog(String event, Map<String, Object?> fields) {
  assert(() {
    final ts = DateTime.now().toUtc().toIso8601String();
    final kv = fields.entries.map((e) => '${e.key}=${e.value}').join(' ');
    debugPrint('[FISCAL-AUDIT] $event $ts $kv');
    return true;
  }());
}

/// Default payment money type per document: a receipt is settled, an
/// invoice/credit/debit note is granted on credit. The user can override it.
String defaultFiscalMoneyType(DocumentType type) =>
    type == DocumentType.receipt ? 'Cash' : 'Credit';

/// FDMS `ReceiptTypeEnum` value for each fiscal document type.
ReceiptType fiscalReceiptType(DocumentType type) => switch (type) {
  DocumentType.creditNote => ReceiptType.creditNote,
  DocumentType.debitNote => ReceiptType.debitNote,
  DocumentType.invoice ||
  DocumentType.receipt ||
  DocumentType.quote => ReceiptType.fiscalInvoice,
};

T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

/// Pre-flight checks before a document is sent to FDMS. Returns a
/// human-readable problem, or null when fiscalisation can proceed.
///
/// Pass the provider's current GetConfig table. Local taxes are ineligible.
String? fiscalConfigProblem(ZimraConfig? config) {
  if (config == null) {
    return 'FDMS configuration is not loaded. Sync the ZIMRA config first.';
  }
  if (!config.applicableTaxes.any((t) => t.isValidOn(DateTime.now()))) {
    return 'FDMS configuration carries no applicable taxes for the current date — refresh '
        'the device configuration in Settings → ZIMRA FDMS.';
  }
  if (config.qrUrl.isEmpty) {
    return 'FDMS configuration has no QR URL — cannot build the '
        'verification QR code.';
  }
  return null;
}

// -----------------------------------------------------------------------------
// Preflight validation — one authoritative gate before any FDMS request
// -----------------------------------------------------------------------------

/// Machine-readable reason a document cannot be fiscalised.
enum FiscalPreflightCode {
  /// No document to validate.
  missingInvoice,

  /// The document has no line items.
  noItems,

  /// No registered fiscal device.
  noDevice,

  /// The fiscal day is not open.
  dayNotOpen,

  /// The currency code is not a 3-letter code.
  invalidCurrency,

  /// A line's treatment/rate/quantity/price is invalid.
  invalidLine,

  /// Stored totals do not reconcile with the line items.
  totalsMismatch,

  /// The document was already fiscalised — nothing to do.
  alreadyFiscalised,

  /// A required ZIMRA tax mapping could not be resolved.
  taxMappingNotFound,

  /// A required field is blank (e.g. client name for a named buyer).
  missingField,
}

/// Structured preflight failure. [code] is stable for branching; [message]
/// is human-readable. For [FiscalPreflightCode.taxMappingNotFound] the
/// extra fields name the treatment/rate that failed and when the device
/// configuration was last refreshed.
class FiscalPreflightError implements Exception {
  final FiscalPreflightCode code;
  final String message;
  final TaxTreatment? invoiceTaxTreatment;
  final double? invoiceTaxRate;
  final DateTime? configurationLastUpdated;

  const FiscalPreflightError(
    this.code,
    this.message, {
    this.invoiceTaxTreatment,
    this.invoiceTaxRate,
    this.configurationLastUpdated,
  });

  /// The stable machine code (e.g. ZIMRA_TAX_MAPPING_NOT_FOUND) requested
  /// by the spec for structured error reporting.
  String get machineCode => switch (code) {
    FiscalPreflightCode.missingInvoice => 'INVOICE_MISSING',
    FiscalPreflightCode.noItems => 'INVOICE_NO_ITEMS',
    FiscalPreflightCode.noDevice => 'ZIMRA_DEVICE_NOT_CONFIGURED',
    FiscalPreflightCode.dayNotOpen => 'ZIMRA_DAY_NOT_OPEN',
    FiscalPreflightCode.invalidCurrency => 'CURRENCY_INVALID',
    FiscalPreflightCode.invalidLine => 'INVOICE_LINE_INVALID',
    FiscalPreflightCode.totalsMismatch => 'INVOICE_TOTALS_MISMATCH',
    FiscalPreflightCode.alreadyFiscalised => 'INVOICE_ALREADY_FISCALISED',
    FiscalPreflightCode.taxMappingNotFound => 'ZIMRA_TAX_MAPPING_NOT_FOUND',
    FiscalPreflightCode.missingField => 'INVOICE_FIELD_MISSING',
  };

  @override
  String toString() => message;
}

/// Everything a caller needs to know before submitting to FDMS.
class FiscalPreflightResult {
  /// Non-null when fiscalisation must not proceed.
  final FiscalPreflightError? error;

  /// The treatments resolved per line (document order) — only populated
  /// when every mapping exists.
  final List<TaxTreatment> treatments;

  /// The org-configured rate per line (document order, null where n/a).
  final List<double?> rates;

  const FiscalPreflightResult({
    this.error,
    this.treatments = const [],
    this.rates = const [],
  });

  bool get ok => error == null;
}

/// Amounts are internally consistent within one cent.
bool _amountsClose(double a, double b) => (a - b).abs() < 0.01;

/// Validate [doc] end-to-end BEFORE any FDMS request: document exists and
/// carries items, device/day state, currency, per-line treatments and
/// rates, quantities/prices, stored totals, and every line's ZIMRA tax
/// mapping against the device configuration (see [resolveFdmsLines]).
///
/// Financial values are never modified here — a mismatch is a hard stop,
/// not something to silently fix to please ZIMRA.
FiscalPreflightResult validateFiscalisation({
  required QuoteflowDocument? doc,
  required Organization? org,
  required ZimraProviderLike zimra,
}) {
  if (doc == null) {
    return FiscalPreflightResult(
      error: const FiscalPreflightError(
        FiscalPreflightCode.missingInvoice,
        'The document no longer exists.',
      ),
    );
  }
  if (!doc.isFiscalType) {
    return FiscalPreflightResult(
      error: const FiscalPreflightError(
        FiscalPreflightCode.invalidLine,
        'This document type cannot be fiscalised.',
      ),
    );
  }
  if (doc.lineItems.isEmpty) {
    return FiscalPreflightResult(
      error: const FiscalPreflightError(
        FiscalPreflightCode.noItems,
        'This document has no line items to fiscalise.',
      ),
    );
  }
  if (!zimra.isRegistered) {
    return FiscalPreflightResult(
      error: const FiscalPreflightError(
        FiscalPreflightCode.noDevice,
        'No ZIMRA fiscal device is configured. Register the device in '
        'Settings → ZIMRA FDMS first.',
      ),
    );
  }
  if (!zimra.isOpen) {
    return FiscalPreflightResult(
      error: const FiscalPreflightError(
        FiscalPreflightCode.dayNotOpen,
        'The fiscal day is not open. Open a fiscal day in Settings → '
        'ZIMRA FDMS before fiscalising.',
      ),
    );
  }
  // The organisation's currency is the fiscalisation currency (it prices
  // every document line); the provider value is only a fallback.
  final currency = (org?.currency ?? zimra.currencyCode).trim().toUpperCase();
  // Accepts any ISO-3166 alpha-3 shape; ZIMRA validates the actual value.
  final currencyOk =
      currency.length == 3 && RegExp(r'^[A-Z]{3}$').hasMatch(currency);
  if (!currencyOk) {
    return FiscalPreflightResult(
      error: FiscalPreflightError(
        FiscalPreflightCode.invalidCurrency,
        'The document currency "$currency" is not a valid ISO code.',
      ),
    );
  }

  // Per-line sanity: quantities and prices, then treatment/rate shape.
  final treatments = <TaxTreatment>[];
  final rates = <double?>[];
  for (final item in doc.lineItems) {
    if (item.quantity <= 0 || !item.quantity.isFinite) {
      final name = item.description.isEmpty ? 'unnamed item' : item.description;
      return FiscalPreflightResult(
        error: FiscalPreflightError(
          FiscalPreflightCode.invalidLine,
          'Line "$name" has an invalid quantity (${item.quantity}).',
        ),
      );
    }
    if (!item.unitPrice.isFinite) {
      final name = item.description.isEmpty ? 'unnamed item' : item.description;
      return FiscalPreflightResult(
        error: FiscalPreflightError(
          FiscalPreflightCode.invalidLine,
          'Line "$name" has an invalid price.',
        ),
      );
    }
    final t = org == null
        ? (item.taxTreatment != null
              ? taxTreatmentFromString(item.taxTreatment)
              : TaxTreatment.noTax)
        : lineTaxTreatment(item, org);
    final r = (t == TaxTreatment.standard && org != null)
        ? lineTaxRate(item, org)
        : null;
    if (t == TaxTreatment.standard && r == null) {
      final name = item.description.isEmpty ? 'unnamed item' : item.description;
      return FiscalPreflightResult(
        error: FiscalPreflightError(
          FiscalPreflightCode.invalidLine,
          'Line "$name" is standard-rated but the organisation has no '
          'standard VAT rate configured (Settings → Tax).',
        ),
      );
    }
    treatments.add(t);
    rates.add(r);
  }

  // Totals reconciliation: the stored numbers must match what the lines
  // produce. Derived from the document's own lines so both legacy and
  // treatment-era documents are checked against their own stored math.
  final derivedSubtotal = round2(
    doc.lineItems.fold<double>(0, (s, i) => s + i.quantity * i.unitPrice),
  );
  if (!_amountsClose(derivedSubtotal, doc.subtotal)) {
    return FiscalPreflightResult(
      error: FiscalPreflightError(
        FiscalPreflightCode.totalsMismatch,
        'The stored subtotal (${doc.subtotal.toStringAsFixed(2)}) does not '
        'match the line items (${derivedSubtotal.toStringAsFixed(2)}). '
        'Re-save the document before fiscalising.',
      ),
    );
  }
  final derivedTotal = round2(doc.subtotal - doc.discount + doc.taxAmount);
  if (!_amountsClose(derivedTotal, doc.total)) {
    return FiscalPreflightResult(
      error: FiscalPreflightError(
        FiscalPreflightCode.totalsMismatch,
        'The stored total (${doc.total.toStringAsFixed(2)}) does not equal '
        'subtotal − discount + tax '
        '(${derivedTotal.toStringAsFixed(2)}). Re-save the document '
        'before fiscalising.',
      ),
    );
  }

  // Required ZIMRA tax mappings — the LAST gate, against the current
  // device configuration.
  final config = zimra.effectiveConfig;
  final resolved = resolveFdmsLines(
    treatments: treatments,
    rates: rates,
    documentDate: DateTime.now(),
    applicableTaxes: config?.applicableTaxes ?? const [],
  );
  if (!resolved.ok) {
    final stdIndex = treatments.indexOf(TaxTreatment.standard);
    return FiscalPreflightResult(
      error: FiscalPreflightError(
        FiscalPreflightCode.taxMappingNotFound,
        resolved.problem!,
        invoiceTaxTreatment: stdIndex >= 0
            ? TaxTreatment.standard
            : (treatments.isNotEmpty ? treatments.first : null),
        invoiceTaxRate: rates.whereType<double>().isNotEmpty
            ? rates.whereType<double>().first
            : null,
        configurationLastUpdated: config?.fetchedAt?.toLocal(),
      ),
    );
  }

  return FiscalPreflightResult(treatments: treatments, rates: rates);
}

/// Receipt lines for a document, resolved against the FDMS tax table.
class FiscalLinesResult {
  /// FDMS receipt lines (tax-exclusive: document prices exclude tax).
  final List<ReceiptLineInput> lines;

  /// Non-null when the document cannot be fiscalised as-is.
  final String? problem;

  const FiscalLinesResult({required this.lines, this.problem});

  bool get ok => problem == null;
}

/// Build the receipt lines for [doc] using the FDMS-applicable taxes.
///
/// Each line's tax treatment is resolved INDEPENDENTLY against ZIMRA's
/// GetConfig `applicableTaxes` — the sole authority for taxID values. A
/// document with mixed treatments (standard + zero-rated + exempt) yields
/// lines carrying their respective FDMS tax entries. Nothing is ever
/// collapsed into standard VAT and no taxID is ever invented: an
/// unresolvable treatment is a hard stop with a named problem.
///
/// [org] supplies the tax profile that fills unassigned line treatments.
/// Document math is tax-exclusive, so lines are sent with
/// `linesTaxInclusive = false`. A document discount becomes its own
/// 'Discount' line booked against an exempt/0% tax.
FiscalLinesResult buildFiscalLines({
  required QuoteflowDocument doc,
  required ZimraConfig config,
  Organization? org,
}) {
  final taxes = config.applicableTaxes
      .where((t) => t.isValidOn(DateTime.now()))
      .toList();
  if (taxes.isEmpty) {
    return const FiscalLinesResult(
      lines: [],
      problem: 'FDMS configuration carries no applicable taxes.',
    );
  }
  if (doc.lineItems.isEmpty) {
    return const FiscalLinesResult(
      lines: [],
      problem: 'Document has no line items to fiscalise.',
    );
  }

  final docDate = DateTime.now();

  // Effective treatment per line. Unassigned (legacy) lines fall back to
  // the organisation default; a tax-disabled organisation's lines are
  // noTax. Legacy documents stored before treatments (org == null) keep
  // their behaviour only through the org default — no rate matching.
  final treatments = <TaxTreatment>[];
  final rates = <double?>[];
  for (final item in doc.lineItems) {
    final treatment = org == null
        ? (item.taxTreatment != null
              ? taxTreatmentFromString(item.taxTreatment)
              : TaxTreatment.noTax)
        : lineTaxTreatment(item, org);
    treatments.add(treatment);
    rates.add(
      treatment == TaxTreatment.standard && org != null
          ? lineTaxRate(item, org)
          : null,
    );
  }

  final resolved = resolveFdmsLines(
    treatments: treatments,
    rates: rates,
    documentDate: docDate,
    applicableTaxes: taxes,
  );
  if (!resolved.ok) {
    return FiscalLinesResult(lines: const [], problem: resolved.problem);
  }

  final lines = <ReceiptLineInput>[];
  for (var i = 0; i < doc.lineItems.length; i++) {
    final item = doc.lineItems[i];
    final tax = resolved.lines[i];
    final name = item.description.isEmpty
        ? 'Item'
        : (item.description.length > 200
              ? item.description.substring(0, 200)
              : item.description);
    lines.add(
      ReceiptLineInput(
        name: name,
        price: item.unitPrice,
        quantity: item.quantity,
        taxId: tax.taxId,
        taxPercent: tax.taxPercent,
        taxCode: tax.taxCode,
      ),
    );
  }

  if (doc.discount > 0) {
    final nonVat = treatments.every((t) => t == TaxTreatment.noTax)
        ? resolved.usedTaxes.first
        : null;
    final exempt =
        nonVat ??
        _firstWhereOrNull(taxes, (t) => t.isExempt) ??
        _firstWhereOrNull(taxes, (t) => (t.taxPercent).abs() < 0.005);
    if (exempt == null) {
      return const FiscalLinesResult(
        lines: [],
        problem:
            'This document has a discount but the FDMS tax table has '
            'no exempt/0% entry to book it against.',
      );
    }
    lines.add(
      ReceiptLineInput(
        name: 'Discount',
        price: -doc.discount,
        quantity: 1,
        taxId: exempt.taxId,
        taxPercent: exempt.isExempt ? null : 0.0,
        taxCode: exempt.taxCode.isEmpty ? null : exempt.taxCode,
        lineType: 'Discount',
      ),
    );
  }

  return FiscalLinesResult(lines: lines);
}

/// FDMS receipt total (in cents) for a fiscalised document — payments are
/// built from this so FDMS accepts the receipt.
int fiscalTotalCents(List<ReceiptLineInput> lines) =>
    ZimraFiscalDevice.computeReceiptTotalCents(lines, linesTaxInclusive: false);

/// FDMS `creditDebitNoteDto` reference from a credit/debit note to the
/// original fiscal document, when the note was converted from one that was
/// fiscalised. All fields are nullable in the contract; returns null when
/// there is nothing to reference.
CreditDebitNoteRef? fiscalOriginalReference({
  required QuoteflowDocument doc,
  required int deviceId,
  QuoteflowDocument? original,
}) {
  if (doc.type != DocumentType.creditNote &&
      doc.type != DocumentType.debitNote) {
    return null;
  }
  final src = original;
  if (src == null || !src.isFiscalised) return null;
  if (!((src.fiscalReceiptId ?? 0) > 0 ||
      ((src.fiscalDeviceId ?? 0) > 0 &&
          (src.fiscalReceiptGlobalNo ?? 0) > 0 &&
          (src.fiscalDayNo ?? 0) > 0))) {
    return null;
  }
  return CreditDebitNoteRef(
    receiptId: src.fiscalReceiptId,
    deviceId: src.fiscalDeviceId ?? deviceId,
    receiptGlobalNo: src.fiscalReceiptGlobalNo,
    fiscalDayNo: src.fiscalDayNo,
  );
}

// -----------------------------------------------------------------------------
// Pending fiscalisation (FDMS offline grace window)
// -----------------------------------------------------------------------------

/// Everything needed to finish a fiscalisation later WITHOUT re-signing or
/// consuming another receipt number: the exact signed request plus the few
/// values needed to rebuild the verification QR payload afterwards.
class PendingFiscalRecord {
  final Map<String, dynamic> payload;
  final int deviceId;
  final int? fiscalDayNo;
  final int receiptCounter;
  final int receiptGlobalNo;
  final String receiptDate;

  const PendingFiscalRecord({
    required this.payload,
    required this.deviceId,
    required this.fiscalDayNo,
    required this.receiptCounter,
    required this.receiptGlobalNo,
    required this.receiptDate,
  });

  /// Build from a device's signed receipt payload.
  factory PendingFiscalRecord.fromPayload({
    required int deviceId,
    required int? fiscalDayNo,
    required Map<String, dynamic> receiptPayload,
  }) {
    final r = Map<String, dynamic>.from(receiptPayload['receipt'] as Map);
    return PendingFiscalRecord(
      payload: receiptPayload,
      deviceId: deviceId,
      fiscalDayNo: fiscalDayNo,
      receiptCounter: (r['receiptCounter'] as num).toInt(),
      receiptGlobalNo: (r['receiptGlobalNo'] as num).toInt(),
      receiptDate: r['receiptDate'] as String,
    );
  }

  /// Verification QR payload for the pending receipt (usable for a retry
  /// after FDMS accepts it).
  String qrPayload(String qrBaseUrl) {
    final r = Map<String, dynamic>.from(payload['receipt'] as Map);
    final sig = r['receiptDeviceSignature'] as Map;
    return ZimraFiscalDevice.buildVerificationQrData(
      deviceId: deviceId,
      receiptDate: DateTime.parse(receiptDate),
      receiptGlobalNo: receiptGlobalNo,
      deviceSignatureBase64: sig['signature'] as String,
      qrBaseUrl: qrBaseUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'payload': payload,
    'deviceId': deviceId,
    'fiscalDayNo': fiscalDayNo,
    'receiptCounter': receiptCounter,
    'receiptGlobalNo': receiptGlobalNo,
    'receiptDate': receiptDate,
  };

  factory PendingFiscalRecord.fromJson(Map<String, dynamic> j) =>
      PendingFiscalRecord(
        payload: Map<String, dynamic>.from(j['payload'] as Map),
        deviceId: (j['deviceId'] as num).toInt(),
        fiscalDayNo: (j['fiscalDayNo'] as num?)?.toInt(),
        receiptCounter: (j['receiptCounter'] as num).toInt(),
        receiptGlobalNo: (j['receiptGlobalNo'] as num).toInt(),
        receiptDate: j['receiptDate'] as String,
      );

  String encode() => jsonEncode(toJson());

  static PendingFiscalRecord? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return PendingFiscalRecord.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }
}

// -----------------------------------------------------------------------------
// Applying FDMS outcomes to documents
// -----------------------------------------------------------------------------

/// Persist a SUCCESSFUL fiscalisation onto the document. Call this only
/// after FDMS answered 2xx — a document may never claim fiscal status
/// otherwise. [taxSnapshot] records the mappings actually used (see
/// [buildFiscalTaxSnapshot]).
void applyFiscalisation(
  QuoteflowDocument doc, {
  required int deviceId,
  required int? fiscalDayNo,
  required FiscalisedReceipt result,
  required String? qrPayload,
  List<Map<String, dynamic>>? taxSnapshot,
}) {
  final receipt = Map<String, dynamic>.from(result.receipt['receipt'] as Map);
  final sig = receipt['receiptDeviceSignature'] as Map?;

  if (guardDoubleFiscalisation(doc) != null) return;
  doc.fiscalRecord =
      jsonDecode(
            jsonEncode({
              'request': result.receipt,
              'response': result.response.toJson(),
            }),
          )
          as Map<String, dynamic>;
  doc.fiscalStatus = 'fiscalised';
  doc.fiscalDeviceId = deviceId;
  doc.fiscalDayNo = fiscalDayNo;
  doc.fiscalReceiptNo = (receipt['receiptCounter'] as num?)?.toInt();
  doc.fiscalReceiptGlobalNo = (receipt['receiptGlobalNo'] as num?)?.toInt();
  doc.fiscalQrPayload = qrPayload;
  doc.fiscalSignature = sig?['signature'] as String?;
  doc.fiscalReceiptId = result.response.receiptId;
  doc.fiscalOperationId = result.response.operationId;
  doc.fiscalisedAt = DateTime.now().toIso8601String();
  doc.fiscalError = null;
  doc.fiscalPendingPayload = null;
  if (taxSnapshot != null) doc.fiscalTaxSnapshot = taxSnapshot;
}

/// Record a signed-but-unsubmitted receipt (network failure). The document
/// is NOT fiscalised; a retry must resubmit [record]'s payload verbatim.
void markFiscalPending(
  QuoteflowDocument doc, {
  required PendingFiscalRecord record,
}) {
  if (guardDoubleFiscalisation(doc) != null) return;
  doc.fiscalStatus = 'pending';
  doc.fiscalPendingPayload = record.encode();
  doc.fiscalError = null;
  // Never carry stale verification data over from a previous attempt.
  doc.fiscalQrPayload = null;
  doc.fiscalTaxSnapshot = null;
}

/// Record an FDMS rejection. No fiscal claim may be printed.
void markFiscalRejected(QuoteflowDocument doc, String error) {
  if (guardDoubleFiscalisation(doc) != null) return;
  doc.fiscalStatus = 'rejected';
  doc.fiscalError = error;
  doc.fiscalPendingPayload = null;
  doc.fiscalQrPayload = null;
  doc.fiscalTaxSnapshot = null;
}

// -----------------------------------------------------------------------------
// Idempotency — a fiscalised document is never submitted twice
// -----------------------------------------------------------------------------

/// Guard against double fiscalisation (rapid double-taps, retries after a
/// crash, duplicate queue flushes). Returns the document's existing fiscal
/// record when it is already fiscalised — the caller must then NOT submit
/// again — or null when the document may proceed to fiscalisation.
///
/// The document's persisted [QuoteflowDocument.fiscalStatus] is the
/// server-side-fact-of-record locally: it is only ever 'fiscalised' after
/// FDMS answered 2xx (see [applyFiscalisation]).
Map<String, dynamic>? guardDoubleFiscalisation(QuoteflowDocument doc) {
  if (!doc.isFiscalised && doc.fiscalReceiptId == null) return null;
  fiscalAuditLog('ZIMRA_FISCALISATION_SKIPPED_ALREADY_FISCALISED', {
    'invoiceId': doc.id,
    'receiptId': doc.fiscalReceiptId,
    'receiptGlobalNo': doc.fiscalReceiptGlobalNo,
  });
  return {
    'fiscalReceiptId': doc.fiscalReceiptId,
    'fiscalReceiptNo': doc.fiscalReceiptNo,
    'fiscalReceiptGlobalNo': doc.fiscalReceiptGlobalNo,
    'fiscalDayNo': doc.fiscalDayNo,
    'fiscalDeviceId': doc.fiscalDeviceId,
    'fiscalQrPayload': doc.fiscalQrPayload,
    'fiscalisedAt': doc.fiscalisedAt,
  };
}

// -----------------------------------------------------------------------------
// Fiscal tax snapshot — what was actually booked with ZIMRA
// -----------------------------------------------------------------------------

/// Persist the tax mappings actually used at fiscalisation time: one entry
/// per receipt line (document order). Stored on the document so reprints
/// and audits stay faithful even after device configuration or business
/// tax settings change.
List<Map<String, dynamic>> buildFiscalTaxSnapshot({
  required List<TaxTreatment> treatments,
  required List<double?> rates,
  required List<ReceiptLineInput> lines,
}) {
  final snapshot = <Map<String, dynamic>>[];
  for (var i = 0; i < lines.length; i++) {
    final t = i < treatments.length ? treatments[i] : null;
    final r = i < rates.length ? rates[i] : null;
    snapshot.add({
      'tax_treatment': t == null ? null : taxTreatmentToString(t),
      'tax_rate': r,
      'zimra_tax_id': lines[i].taxId,
      if (lines[i].taxPercent != null) 'zimra_tax_percent': lines[i].taxPercent,
      if (lines[i].taxCode != null && lines[i].taxCode!.isNotEmpty)
        'zimra_tax_code': lines[i].taxCode,
    });
  }
  return snapshot;
}
