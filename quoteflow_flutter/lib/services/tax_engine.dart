/// QuoteFlow tax engine — organisation tax profiles, tax definitions and
/// per-line tax treatment.
///
/// Business rules (deliberately enforced here, not assumed):
///  * An organisation may be VAT-registered (`taxEnabled: true`) or not
///    (`taxEnabled: false`). A non-VAT business's invoices carry NO tax —
///    a $2,000 invoice totals $2,000.
///  * Tax rates are organisation configuration, never a universal constant.
///    There is no `15.5` (or any other rate) baked into this engine.
///  * Zero-valued tax is NOT one thing: zero-rated, exempt and
///    not-tax-applicable are distinct treatments and stay distinct.
///  * ZIMRA FDMS tax IDs are NEVER invented — they resolve exclusively
///    from the device's GetConfig `applicableTaxes` (see tax_resolver.dart).
library;

import 'calculations.dart' show round2;
import '../models/document.dart';
import '../models/organization.dart';

/// Semantic tax treatment of a line/document. These are QuoteFlow concepts,
/// NOT ZIMRA tax IDs and NOT percentages.
enum TaxTreatment {
  /// No tax applies at all (business not registered / item out of scope).
  noTax,

  /// Standard VAT at the definition's rate (e.g. 15.5%, 15%, …).
  standard,

  /// Zero-rated: VAT applies at 0% but the transaction is VAT-able.
  zeroRated,

  /// Exempt: the transaction is outside VAT; no VAT is charged.
  exempt;

  String get label => switch (this) {
    TaxTreatment.noTax => 'No tax',
    TaxTreatment.standard => 'Standard VAT',
    TaxTreatment.zeroRated => 'Zero rated',
    TaxTreatment.exempt => 'Exempt',
  };
}

TaxTreatment taxTreatmentFromString(String? s) {
  switch (s) {
    case 'no_tax':
      return TaxTreatment.noTax;
    case 'standard':
      return TaxTreatment.standard;
    case 'zero_rated':
      return TaxTreatment.zeroRated;
    case 'exempt':
      return TaxTreatment.exempt;
    default:
      return TaxTreatment.noTax;
  }
}

String taxTreatmentToString(TaxTreatment t) => switch (t) {
  TaxTreatment.noTax => 'no_tax',
  TaxTreatment.standard => 'standard',
  TaxTreatment.zeroRated => 'zero_rated',
  TaxTreatment.exempt => 'exempt',
};

/// Where a tax definition came from.
enum TaxSource { manual, fdms }

/// A reusable tax definition owned by the organisation.
///
/// [fdmsTaxId] is only ever a cached observation of what ZIMRA's
/// GetConfig returned — it is never authored here and the live resolver
/// re-derives it from the current FDMS configuration.
class TaxDefinition {
  final String id;
  final String name;

  /// Rate in percent (15.5 → 15.5). Null for treatments that never carry a
  /// rate (noTax / exempt).
  final double? rate;
  final TaxTreatment type;
  final bool enabled;

  /// When true, new lines default to this treatment.
  final bool isDefault;

  final TaxSource source;

  /// Nullable — only meaningful for [TaxSource.fdms] observations.
  final int? fdmsTaxId;

  /// ISO dates delimiting when this definition is valid (nullable = open).
  final String? validFrom;
  final String? validTill;

  const TaxDefinition({
    required this.id,
    required this.name,
    this.rate,
    required this.type,
    this.enabled = true,
    this.isDefault = false,
    this.source = TaxSource.manual,
    this.fdmsTaxId,
    this.validFrom,
    this.validTill,
  });

  /// True when [date] (ISO) falls inside the definition's validity window.
  bool isValidOn(DateTime date) {
    final from = DateTime.tryParse(validFrom ?? '');
    final till = DateTime.tryParse(validTill ?? '');
    if (from != null && date.isBefore(DateTime(from.year, from.month, from.day))) {
      return false;
    }
    if (till != null && date.isAfter(DateTime(till.year, till.month, till.day, 23, 59, 59))) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (rate != null) 'rate': rate,
    'type': taxTreatmentToString(type),
    'enabled': enabled,
    'is_default': isDefault,
    'source': source == TaxSource.fdms ? 'fdms' : 'manual',
    if (fdmsTaxId != null) 'fdms_tax_id': fdmsTaxId,
    if (validFrom != null) 'valid_from': validFrom,
    if (validTill != null) 'valid_till': validTill,
  };

  factory TaxDefinition.fromJson(Map<String, dynamic> j) => TaxDefinition(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    rate: (j['rate'] as num?)?.toDouble(),
    type: taxTreatmentFromString(j['type'] as String?),
    enabled: j['enabled'] as bool? ?? true,
    isDefault: j['is_default'] as bool? ?? false,
    source: j['source'] == 'fdms' ? TaxSource.fdms : TaxSource.manual,
    fdmsTaxId: (j['fdms_tax_id'] as num?)?.toInt(),
    validFrom: j['valid_from'] as String?,
    validTill: j['valid_till'] as String?,
  );

  TaxDefinition copyWith({
    String? name,
    double? rate,
    bool? enabled,
    bool? isDefault,
    String? validFrom,
    String? validTill,
  }) => TaxDefinition(
    id: id,
    name: name ?? this.name,
    rate: rate ?? this.rate,
    type: type,
    enabled: enabled ?? this.enabled,
    isDefault: isDefault ?? this.isDefault,
    source: source,
    fdmsTaxId: fdmsTaxId,
    validFrom: validFrom ?? this.validFrom,
    validTill: validTill ?? this.validTill,
  );

  @override
  bool operator ==(Object other) =>
      other is TaxDefinition &&
      other.id == id &&
      other.name == name &&
      other.rate == rate &&
      other.type == type &&
      other.enabled == enabled &&
      other.isDefault == isDefault &&
      other.source == source &&
      other.fdmsTaxId == fdmsTaxId &&
      other.validFrom == validFrom &&
      other.validTill == validTill;

  @override
  int get hashCode => Object.hash(
    id, name, rate, type, enabled, isDefault, source, fdmsTaxId, validFrom, validTill,
  );

  @override
  String toString() => 'TaxDefinition($id, $name, ${type.name}, $rate%)';
}

/// Decimal-safe percent comparison. Money/percent values are stored as
/// binary doubles, so `15.5 == 15.5` can be `15.4999... != 15.5000...1`.
/// Comparing in integer percent-cents (1550 == 1550) removes the binary
/// fraction entirely — a value of 15.5% matches an FDMS entry carrying
/// 15.5 and never 15.49 or 15.51.
bool taxRateEquals(double? a, double? b) {
  if (a == null || b == null) return a == b;
  return percentToCents(a) == percentToCents(b);
}

/// Convert a percent value (15.5) into integer percent-cents (1550).
/// Half-up rounding at the 2nd decimal absorbs binary-representation noise
/// (15.499999… → 1550) so the comparison is exact at percent-cent
/// precision — the finest precision FDMS rates are expressed in.
int percentToCents(double percent) {
  final scaled = percent * 100;
  final down = scaled.floorToDouble();
  final frac = scaled - down;
  final extra = frac > 0.5 ? 1 : (frac < 0.5 ? 0 : (down.isNegative ? 0 : 1));
  return (down + extra).toInt();
}

/// Build the organisation's tax definitions from its configuration.
///
/// A tax-disabled organisation yields no definitions — lines resolve to
/// [TaxTreatment.noTax] and no tax is ever computed.
List<TaxDefinition> organisationTaxDefinitions(Organization org) =>
    org.taxEnabled ? org.taxDefinitions : const [];

/// The default [TaxTreatment] for NEW lines of this organisation.
///
/// Tax-disabled organisations are always noTax. Tax-enabled organisations
/// default to their configured default definition's type, falling back to
/// standard only when an explicit default definition exists and carries a
/// rate; there is no universal fallback rate.
TaxTreatment defaultTaxTreatment(Organization org) {
  if (!org.taxEnabled) return TaxTreatment.noTax;
  final d = org.taxDefinitions
      .where((t) => t.enabled && t.isDefault)
      .cast<TaxDefinition?>()
      .firstWhere((_) => true, orElse: () => null);
  if (d != null) return d.type;
  final anyEnabled = org.taxDefinitions
      .where((t) => t.enabled)
      .cast<TaxDefinition?>()
      .firstWhere((_) => true, orElse: () => null);
  return anyEnabled?.type ?? TaxTreatment.noTax;
}

TaxDefinition? defaultTaxDefinition(Organization org) {
  if (!org.taxEnabled) return null;
  final enabled = org.taxDefinitions.where((t) => t.enabled).toList();
  for (final t in enabled) {
    if (t.isDefault) return t;
  }
  return enabled.isEmpty ? null : enabled.first;
}

/// The treatment a line carries: its own, or the organisation default when
/// unassigned (legacy lines stored before per-line tax).
TaxTreatment lineTaxTreatment(LineItem line, Organization org) {
  if (!org.taxEnabled) return TaxTreatment.noTax;
  final own = line.taxTreatment;
  if (own != null) return taxTreatmentFromString(own);
  return defaultTaxTreatment(org);
}

/// The rate a line's treatment resolves to, or null when the treatment
/// never carries a rate (noTax / exempt).
double? lineTaxRate(LineItem line, Organization org) {
  final treatment = lineTaxTreatment(line, org);
  switch (treatment) {
    case TaxTreatment.noTax:
    case TaxTreatment.exempt:
      return null;
    case TaxTreatment.standard:
      final d = _definitionFor(org, TaxTreatment.standard);
      return d?.rate;
    case TaxTreatment.zeroRated:
      return 0.0;
  }
}

TaxDefinition? _definitionFor(Organization org, TaxTreatment type) {
  for (final t in org.taxDefinitions) {
    if (t.enabled && t.type == type) return t;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Totals
// ---------------------------------------------------------------------------

/// Per-line tax breakdown — each line is computed independently.
class LineTax {
  final LineItem item;
  final TaxTreatment treatment;

  /// Rate applied (null when the treatment never carries one).
  final double? rate;

  /// This line's own share of the document discount (proportional).
  final double discountShare;
  final double lineSubtotal;
  final double taxAmount;
  final double lineTotal;

  const LineTax({
    required this.item,
    required this.treatment,
    required this.rate,
    required this.discountShare,
    required this.lineSubtotal,
    required this.taxAmount,
    required this.lineTotal,
  });
}

class DocumentTotals {
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double total;
  final List<LineTax> lines;

  /// True when at least one line carries a rate-carrying treatment.
  final bool hasTax;

  /// The single rate when every taxable line shares one rate, otherwise
  /// null. Convenience for legacy `taxRate` storage (see below).
  double? get uniformRate {
    final rates = lines.map((l) => l.rate).whereType<double>().toSet();
    return rates.length == 1 ? rates.first : null;
  }

  /// Legacy-compatible single rate: uniformRate when uniform, else the
  /// blended (tax / taxBase) percentage. 0 when no tax applies. Used only
  /// to populate the document's legacy `taxRate` field for display;
  /// per-line treatments remain the source of truth.
  double get effectiveRate {
    final uniform = uniformRate;
    if (uniform != null) return uniform;
    final taxBase = lines.fold<double>(
      0,
      (s, l) => s + l.lineSubtotal - l.discountShare,
    );
    if (taxBase <= 0) return 0;
    return round2(taxAmount / taxBase * 100);
  }

  const DocumentTotals({
    required this.subtotal,
    required this.discount,
    required this.taxAmount,
    required this.total,
    required this.lines,
    required this.hasTax,
  });
}

/// Compute totals for [items] with per-line tax treatments.
///
/// Each line's tax is its own (rate × line subtotal), discounts are shared
/// across lines proportionally to their line subtotal so the document total
/// stays exact. Tax-exempt/no-tax lines contribute zero tax regardless of
/// any configured rate elsewhere on the invoice.
DocumentTotals computeTotalsV2({
  required List<LineItem> items,
  required Organization org,
  double discount = 0,
}) {
  final rawSubtotal = items.fold<double>(
    0,
    (sum, i) => sum + i.quantity * i.unitPrice,
  );

  // Proportional discount shares (guard against zero-subtotal documents).
  double shareFor(double lineSub) =>
      rawSubtotal > 0 ? discount * (lineSub / rawSubtotal) : 0.0;

  var hasTax = false;
  final lines = <LineTax>[];
  for (final item in items) {
    final treatment = lineTaxTreatment(item, org);
    final rate = lineTaxRate(item, org);
    final lineSub = item.quantity * item.unitPrice;
    if (rate != null) hasTax = true;
    final effectiveRate = rate ?? 0.0;
    final share = shareFor(lineSub);
    final taxBase = lineSub - share;
    final tax = round2(taxBase * effectiveRate / 100);
    lines.add(
      LineTax(
        item: item,
        treatment: treatment,
        rate: rate,
        discountShare: round2(share),
        lineSubtotal: round2(lineSub),
        taxAmount: tax,
        lineTotal: round2(taxBase + tax),
      ),
    );
  }

  final subtotal = round2(rawSubtotal);
  final taxAmount = round2(lines.fold<double>(0, (s, l) => s + l.taxAmount));
  final total = round2(subtotal - discount + taxAmount);
  return DocumentTotals(
    subtotal: subtotal,
    discount: round2(discount),
    taxAmount: taxAmount,
    total: total,
    lines: lines,
    hasTax: hasTax,
  );
}

/// The single treatment a document resolves to for FDMS purposes, or null
/// when the lines genuinely mix treatments (then FDMS lines carry their own
/// treatments and there is no single document-level one).
TaxTreatment? documentTaxTreatment(DocumentTotals totals) {
  final distinct = totals.lines.map((l) => l.treatment).toSet();
  if (distinct.isEmpty) return null;
  if (distinct.length == 1) return distinct.first;
  // Mixed: collapse only the trivial case where all lines are non-taxable.
  if (distinct
      .every((t) => t == TaxTreatment.noTax || t == TaxTreatment.exempt)) {
    return TaxTreatment.noTax;
  }
  return null;
}
