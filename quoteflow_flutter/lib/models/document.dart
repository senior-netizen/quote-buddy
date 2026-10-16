import '../services/zimra/buyer_contract.dart';
import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class LineItem extends HiveObject {
  @HiveField(0)
  String description;

  @HiveField(1)
  double quantity;

  @HiveField(2)
  double unitPrice;

  /// Per-line tax treatment. Null = unassigned (legacy lines): the
  /// organisation's default treatment applies at calculation time.
  /// Stored as the TaxTreatment string ('no_tax', 'standard', …).
  @HiveField(3)
  String? taxTreatment;

  LineItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.taxTreatment,
  });

  double get total => quantity * unitPrice;

  Map<String, dynamic> toJson() => {
    'description': description,
    'quantity': quantity,
    'unit_price': unitPrice,
    if (taxTreatment != null) 'tax_treatment': taxTreatment,
  };

  factory LineItem.fromJson(Map<String, dynamic> json) => LineItem(
    description: json['description'] ?? '',
    quantity: (json['quantity'] ?? 0).toDouble(),
    unitPrice: (json['unit_price'] ?? 0).toDouble(),
    taxTreatment: json['tax_treatment'] as String?,
  );
}

enum DocumentType { quote, invoice, creditNote, debitNote, receipt }

extension DocumentTypeExtension on DocumentType {
  String get label {
    switch (this) {
      case DocumentType.quote:
        return 'Quotation';
      case DocumentType.invoice:
        return 'Invoice';
      case DocumentType.creditNote:
        return 'Credit Note';
      case DocumentType.debitNote:
        return 'Debit Note';
      case DocumentType.receipt:
        return 'Receipt';
    }
  }

  String get shortLabel {
    switch (this) {
      case DocumentType.quote:
        return 'Quote';
      case DocumentType.invoice:
        return 'Invoice';
      case DocumentType.creditNote:
        return 'Credit note';
      case DocumentType.debitNote:
        return 'Debit note';
      case DocumentType.receipt:
        return 'Receipt';
    }
  }

  String get prefix {
    switch (this) {
      case DocumentType.quote:
        return 'QT';
      case DocumentType.invoice:
        return 'INV';
      case DocumentType.creditNote:
        return 'CN';
      case DocumentType.debitNote:
        return 'DN';
      case DocumentType.receipt:
        return 'RC';
    }
  }

  bool get isFiscal => switch (this) {
    DocumentType.invoice ||
    DocumentType.creditNote ||
    DocumentType.debitNote ||
    DocumentType.receipt => true,
    DocumentType.quote => false,
  };
}

DocumentType documentTypeFromString(String s) {
  switch (s) {
    case 'invoice':
      return DocumentType.invoice;
    case 'credit_note':
      return DocumentType.creditNote;
    case 'debit_note':
      return DocumentType.debitNote;
    case 'receipt':
      return DocumentType.receipt;
    default:
      return DocumentType.quote;
  }
}

String documentTypeToString(DocumentType t) {
  switch (t) {
    case DocumentType.quote:
      return 'quote';
    case DocumentType.invoice:
      return 'invoice';
    case DocumentType.creditNote:
      return 'credit_note';
    case DocumentType.debitNote:
      return 'debit_note';
    case DocumentType.receipt:
      return 'receipt';
  }
}

// ── Document Status ──

enum DocumentStatus { draft, sent, accepted, declined, paid, overdue }

extension DocumentStatusExtension on DocumentStatus {
  String get label {
    switch (this) {
      case DocumentStatus.draft:
        return 'Draft';
      case DocumentStatus.sent:
        return 'Sent';
      case DocumentStatus.accepted:
        return 'Accepted';
      case DocumentStatus.declined:
        return 'Declined';
      case DocumentStatus.paid:
        return 'Paid';
      case DocumentStatus.overdue:
        return 'Overdue';
    }
  }

  String get shortLabel => label;
}

DocumentStatus documentStatusFromString(String s) {
  switch (s) {
    case 'sent':
      return DocumentStatus.sent;
    case 'accepted':
      return DocumentStatus.accepted;
    case 'declined':
      return DocumentStatus.declined;
    case 'paid':
      return DocumentStatus.paid;
    case 'overdue':
      return DocumentStatus.overdue;
    default:
      return DocumentStatus.draft;
  }
}

String documentStatusToString(DocumentStatus s) {
  switch (s) {
    case DocumentStatus.draft:
      return 'draft';
    case DocumentStatus.sent:
      return 'sent';
    case DocumentStatus.accepted:
      return 'accepted';
    case DocumentStatus.declined:
      return 'declined';
    case DocumentStatus.paid:
      return 'paid';
    case DocumentStatus.overdue:
      return 'overdue';
  }
}

@HiveType(typeId: 1)
class QuoteflowDocument extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String docType; // stored as string for Hive compatibility

  @HiveField(2)
  String docNumber;

  @HiveField(3)
  String issueDate;

  @HiveField(4)
  String? dueDate;

  @HiveField(5)
  List<LineItem> lineItems;

  @HiveField(6)
  double taxRate;

  @HiveField(7)
  double discount;

  @HiveField(8)
  double subtotal;

  @HiveField(9)
  double taxAmount;

  @HiveField(10)
  double total;

  @HiveField(11)
  String? notes;

  @HiveField(12)
  String clientId;

  @HiveField(13)
  String createdAt;

  @HiveField(14)
  String? convertedFrom;

  @HiveField(15)
  String docStatus; // stored as string for Hive compatibility

  /// Hand-drawn signature stored as a `data:image/png;base64,` URL.
  @HiveField(16)
  String? signatureData;

  /// ISO-8601 timestamp of when the signature was applied.
  @HiveField(17)
  String? signedAt;

  /// Per-document PDF overrides. When set, they win over the
  /// organization's global PDF settings for this document only.
  @HiveField(18)
  String? pdfTheme;

  @HiveField(19)
  String? logoPosition;

  @HiveField(20)
  String? tableStyle;

  /// The organization this document belongs to. Null means "legacy" — the
  /// storage layer backfills it to the then-active organization once.
  @HiveField(21)
  String? orgId;

  // ── ZIMRA fiscalisation ────────────────────────────────────────────
  // Set only after FDMS accepted the receipt. Null/absent = never
  // fiscalised. Values: 'pending' (signed, waiting for FDMS),
  // 'fiscalised' (accepted — only then may the document print as fiscal),
  // 'rejected' (FDMS refused it).
  @HiveField(22)
  String? fiscalStatus;

  /// FDMS device ID that fiscalised this document.
  @HiveField(23)
  int? fiscalDeviceId;

  /// Fiscal day number the receipt was issued under.
  @HiveField(24)
  int? fiscalDayNo;

  /// Receipt number within the fiscal day (`receiptCounter`).
  @HiveField(25)
  int? fiscalReceiptNo;

  /// Global receipt number (`receiptGlobalNo`) — unique across days.
  @HiveField(26)
  int? fiscalReceiptGlobalNo;

  /// Exact ZIMRA verification QR payload for this receipt. Regenerating a
  /// reprint uses this stored value — never a new one.
  @HiveField(27)
  String? fiscalQrPayload;

  /// Device signature (base64) over the receipt canonical string — an input
  /// to the verification QR payload.
  @HiveField(28)
  String? fiscalSignature;

  /// ZIMRA `receiptID` assigned by FDMS.
  @HiveField(29)
  int? fiscalReceiptId;

  /// FDMS `operationID` of the fiscalisation call.
  @HiveField(30)
  String? fiscalOperationId;

  /// ISO timestamp of successful fiscalisation.
  @HiveField(31)
  String? fiscalisedAt;

  /// Last fiscalisation failure diagnostic (status 'rejected').
  @HiveField(32)
  String? fiscalError;

  /// Signed `SubmitReceiptRequest` JSON held while status is 'pending',
  /// so a retry resubmits the SAME receipt instead of consuming a new one.
  @HiveField(33)
  String? fiscalPendingPayload;

  /// Tax mappings actually used at fiscalisation time — one entry per
  /// receipt line (document order): the line's treatment, the org rate
  /// that priced it, and the FDMS taxID/percent it was booked under.
  /// Persisting the snapshot keeps reprints and audits faithful even after
  /// the device configuration or business profile changes. Null on older
  /// documents (pre-snapshot builds).
  @HiveField(34)
  List<Map<String, dynamic>>? fiscalTaxSnapshot;

  /// Exact submitted request and response, independent of current config.
  @HiveField(35)
  Map<String, dynamic>? fiscalRecord;

  @HiveField(36)
  bool includeBuyerDetails;

  String get fiscalValidationLabel {
    final response = fiscalRecord?['response'] as Map?;
    final errors = response?['validationErrors'] as List? ?? [];
    final colors = errors.whereType<Map>().map(
      (e) => '${e['color']}'.toLowerCase(),
    );
    if (colors.contains('red')) return 'Fiscalised — validation error';
    if (colors.contains('yellow')) return 'Fiscalised — validation warning';
    return 'Fiscalised with ZIMRA';
  }

  List<String> get fiscalValidationDetails {
    final response = fiscalRecord?['response'] as Map?;
    final errors = response?['validationErrors'] as List? ?? [];
    return errors
        .whereType<Map>()
        .map(
          (e) =>
              '${e['code']} (${e['color']}): ${fiscalValidationMessage('${e['code']}', '${e['description']}')}',
        )
        .toList();
  }

  QuoteflowDocument({
    required this.id,
    required this.docType,
    required this.docNumber,
    required this.issueDate,
    this.dueDate,
    required this.lineItems,
    required this.taxRate,
    required this.discount,
    required this.subtotal,
    required this.taxAmount,
    required this.total,
    this.notes,
    required this.clientId,
    required this.createdAt,
    this.convertedFrom,
    this.docStatus = 'draft',
    this.signatureData,
    this.signedAt,
    this.pdfTheme,
    this.logoPosition,
    this.tableStyle,
    this.orgId,
    this.fiscalStatus,
    this.fiscalDeviceId,
    this.fiscalDayNo,
    this.fiscalReceiptNo,
    this.fiscalReceiptGlobalNo,
    this.fiscalQrPayload,
    this.fiscalSignature,
    this.fiscalReceiptId,
    this.fiscalOperationId,
    this.fiscalisedAt,
    this.fiscalError,
    this.fiscalPendingPayload,
    this.fiscalTaxSnapshot,
    this.fiscalRecord,
    this.includeBuyerDetails = false,
  });

  DocumentType get type => documentTypeFromString(docType);
  DocumentStatus get status => documentStatusFromString(docStatus);

  /// True when an invoice's due date has passed while its payment is still
  /// awaited (sent or accepted). This is derived from the calendar, never
  /// stored — a paid or declined invoice is never overdue, and drafts are
  /// not either (they were never sent). Only invoices carry a real due date.
  bool get isPastDue {
    if (docType != 'invoice') return false;
    final s = status;
    if (s != DocumentStatus.sent && s != DocumentStatus.accepted) {
      return false;
    }
    final due = DateTime.tryParse(dueDate ?? '');
    if (due == null) return false;
    final now = DateTime.now();
    // Compare calendar days only, so an invoice due today is not yet overdue.
    final dueDay = DateTime(due.year, due.month, due.day);
    final today = DateTime(now.year, now.month, now.day);
    return dueDay.isBefore(today);
  }

  /// The status shown to the user: the stored status, except invoices whose
  /// due date has passed while awaiting payment read as overdue.
  DocumentStatus get effectiveStatus =>
      isPastDue ? DocumentStatus.overdue : status;

  // ── Fiscalisation state ──────────────────────────────────────────

  /// True ONLY once FDMS accepted the receipt — the only state that may be
  /// presented as fiscalised on a printed document.
  bool get isFiscalised => fiscalStatus == 'fiscalised';

  /// True while a signed receipt waits for FDMS (offline grace window).
  bool get isFiscalPending => fiscalStatus == 'pending';

  /// True when FDMS refused the last fiscalisation attempt.
  bool get isFiscalRejected => fiscalStatus == 'rejected';

  /// The ZIMRA verification data for this document: the exact payload that
  /// is encoded into the verification QR code, built by FDMS rules
  /// (`qrUrl + deviceId + ddMMyyyy + receiptGlobalNo + MD5-16(signature)`).
  /// Never invented locally — it is stored from the fiscalised receipt.
  String? get fiscalVerificationCode => isFiscalised ? fiscalQrPayload : null;

  /// True when this document type must be fiscalised with ZIMRA.
  bool get isFiscalType => type.isFiscal;

  Map<String, dynamic> toJson() => {
    'id': id,
    'doc_type': docType,
    'doc_number': docNumber,
    'issue_date': issueDate,
    'due_date': dueDate,
    'line_items': lineItems.map((e) => e.toJson()).toList(),
    'tax_rate': taxRate,
    'discount': discount,
    'subtotal': subtotal,
    'tax_amount': taxAmount,
    'total': total,
    'notes': notes,
    'client_id': clientId,
    'created_at': createdAt,
    'converted_from': convertedFrom,
    'status': docStatus,
    'signature_data': signatureData,
    'signed_at': signedAt,
    'pdf_theme': pdfTheme,
    'logo_position': logoPosition,
    'table_style': tableStyle,
    'org_id': orgId,
    'fiscal_status': fiscalStatus,
    'fiscal_device_id': fiscalDeviceId,
    'fiscal_day_no': fiscalDayNo,
    'fiscal_receipt_no': fiscalReceiptNo,
    'fiscal_receipt_global_no': fiscalReceiptGlobalNo,
    'fiscal_qr_payload': fiscalQrPayload,
    'fiscal_signature': fiscalSignature,
    'fiscal_receipt_id': fiscalReceiptId,
    'fiscal_operation_id': fiscalOperationId,
    'fiscalised_at': fiscalisedAt,
    'fiscal_error': fiscalError,
    'fiscal_pending_payload': fiscalPendingPayload,
    'fiscal_tax_snapshot': fiscalTaxSnapshot,
    'fiscal_record': fiscalRecord,
    'include_buyer_details': includeBuyerDetails,
  };

  factory QuoteflowDocument.fromJson(Map<String, dynamic> json) =>
      QuoteflowDocument(
        includeBuyerDetails: json['include_buyer_details'] ?? false,
        id: json['id'] ?? '',
        docType: json['doc_type'] ?? 'quote',
        docNumber: json['doc_number'] ?? '',
        issueDate: json['issue_date'] ?? '',
        dueDate: json['due_date'],
        lineItems:
            (json['line_items'] as List?)
                ?.map((e) => LineItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        taxRate: (json['tax_rate'] ?? 0).toDouble(),
        discount: (json['discount'] ?? 0).toDouble(),
        subtotal: (json['subtotal'] ?? 0).toDouble(),
        taxAmount: (json['tax_amount'] ?? 0).toDouble(),
        total: (json['total'] ?? 0).toDouble(),
        notes: json['notes'],
        clientId: json['client_id'] ?? '',
        createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
        convertedFrom: json['converted_from'],
        docStatus: json['status'] ?? 'draft',
        signatureData: json['signature_data'],
        signedAt: json['signed_at'],
        pdfTheme: json['pdf_theme'],
        logoPosition: json['logo_position'],
        tableStyle: json['table_style'],
        orgId: json['org_id'],
        fiscalStatus: json['fiscal_status'],
        fiscalDeviceId: (json['fiscal_device_id'] as num?)?.toInt(),
        fiscalDayNo: (json['fiscal_day_no'] as num?)?.toInt(),
        fiscalReceiptNo: (json['fiscal_receipt_no'] as num?)?.toInt(),
        fiscalReceiptGlobalNo: (json['fiscal_receipt_global_no'] as num?)
            ?.toInt(),
        fiscalQrPayload: json['fiscal_qr_payload'],
        fiscalSignature: json['fiscal_signature'],
        fiscalReceiptId: (json['fiscal_receipt_id'] as num?)?.toInt(),
        fiscalOperationId: json['fiscal_operation_id'],
        fiscalisedAt: json['fiscalised_at'],
        fiscalError: json['fiscal_error'],
        fiscalPendingPayload: json['fiscal_pending_payload'],
        fiscalRecord: json['fiscal_record'] == null
            ? null
            : Map<String, dynamic>.from(json['fiscal_record'] as Map),
        fiscalTaxSnapshot: (json['fiscal_tax_snapshot'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
}
