/// Maps QuoteFlow tax treatments onto ZIMRA FDMS tax entries.
///
/// The FDMS configuration returned by GetConfig (`applicableTaxes`) is the
/// SOLE authority for taxID values — nothing here authors, caches as truth,
/// or guesses a taxID. A mapping failure is a hard stop for fiscalisation,
/// never a silent substitution.
library;

import 'tax_engine.dart';
import 'zimra/zimra_models.dart';

/// The outcome of resolving one treatment against the FDMS tax table.
class FdmsTaxResolution {
  /// The resolved FDMS tax entry. Null when [problem] != null.
  final ZimraTax? tax;

  /// The treatment that was resolved.
  final TaxTreatment treatment;

  /// Human-readable reason when no valid mapping exists.
  final String? problem;

  const FdmsTaxResolution._(this.tax, this.treatment, this.problem);

  bool get ok => tax != null && problem == null;
}

/// Resolve a single tax treatment to a currently-valid FDMS tax entry.
///
/// Non-VAT prefers an explicitly named Non-VAT 0% entry, then an exempt
/// entry for backwards compatibility. Generic zero-rated VAT is not Non-VAT.
/// Only current, non-manual entries participate. Ambiguity blocks submission.
FdmsTaxResolution resolveFdmsTax({
  required TaxTreatment treatment,
  required DateTime documentDate,
  required List<ZimraTax> applicableTaxes,
  double? rate,
  String? definitionName,
}) {
  if (applicableTaxes.isEmpty) {
    return FdmsTaxResolution._(
      null,
      treatment,
      'The ZIMRA FDMS configuration carries no applicable taxes. '
      'Refresh the configuration in Settings → ZIMRA FDMS.',
    );
  }

  // Only entries valid on the document date participate.
  final valid = _validOn(applicableTaxes, documentDate);
  if (valid.isEmpty) {
    return FdmsTaxResolution._(
      null,
      treatment,
      'No ZIMRA tax entries were valid on ${_fmtDate(documentDate)}. '
      'Check the tax validity dates in Settings → ZIMRA FDMS.',
    );
  }

  switch (treatment) {
    case TaxTreatment.noTax:
      final nonVat = valid
          .where(
            (t) =>
                isNonVatTax(t) && !t.isExempt && taxRateEquals(t.taxPercent, 0),
          )
          .toList();
      final candidates = nonVat.isNotEmpty
          ? nonVat
          : valid.where((t) => t.isExempt).toList();
      if (candidates.length != 1) {
        return FdmsTaxResolution._(
          null,
          treatment,
          'No compatible ZIMRA tax configuration is available for this transaction. '
          'Refresh the FDMS configuration or review the organisation\'s tax settings.'
          '${candidates.length > 1 ? ' Multiple compatible entries require review.' : ''}',
        );
      }
      return FdmsTaxResolution._(candidates.single, treatment, null);

    case TaxTreatment.exempt:
      final exempt = valid
          .where((t) => t.isExempt)
          .cast<ZimraTax?>()
          .firstWhere((_) => true, orElse: () => null);
      if (exempt == null) {
        return FdmsTaxResolution._(
          null,
          treatment,
          'No exempt tax entry exists in the ZIMRA FDMS configuration — '
          'cannot fiscalise an exempt line.',
        );
      }
      return FdmsTaxResolution._(exempt, treatment, null);

    case TaxTreatment.zeroRated:
      final zero = valid
          .where(
            (t) =>
                !t.isExempt &&
                !isNonVatTax(t) &&
                taxRateEquals(t.taxPercent, 0),
          )
          .cast<ZimraTax?>()
          .firstWhere((_) => true, orElse: () => null);
      if (zero == null) {
        return FdmsTaxResolution._(
          null,
          treatment,
          'No 0% (zero-rated) entry exists in the ZIMRA FDMS configuration '
          '— cannot fiscalise a zero-rated line.',
        );
      }
      return FdmsTaxResolution._(zero, treatment, null);

    case TaxTreatment.standard:
      if (rate == null) {
        return FdmsTaxResolution._(
          null,
          treatment,
          'No rate is configured for the standard VAT treatment — set it '
          'in Settings → Tax before fiscalising.',
        );
      }
      final match = valid
          .where(
            (t) =>
                !t.isExempt &&
                !isNonVatTax(t) &&
                taxRateEquals(t.taxPercent, rate),
          )
          .cast<ZimraTax?>()
          .firstWhere((_) => true, orElse: () => null);
      if (match == null) {
        return FdmsTaxResolution._(
          null,
          treatment,
          'No ZIMRA tax entry matches ${_fmtRate(rate)}%'
          '${definitionName == null ? '' : ' ($definitionName)'} — refresh '
          'the ZIMRA configuration in Settings → ZIMRA FDMS.',
        );
      }
      return FdmsTaxResolution._(match, treatment, null);
  }
}

/// Resolve every line of a document. Returns the FDMS receipt lines, or a
/// [FdmsLinesResult] whose [FdmsLinesResult.problem] names the FIRST
/// treatment that could not be mapped.
class FdmsLinesResult {
  final List<ReceiptLineInput> lines;
  final String? problem;
  final List<ZimraTax> usedTaxes;

  const FdmsLinesResult({
    required this.lines,
    this.problem,
    this.usedTaxes = const [],
  });

  bool get ok => problem == null;
}

/// Resolve FDMS receipt lines for [treatments] (one per document line, same
/// order as the document's line items) against [applicableTaxes].
FdmsLinesResult resolveFdmsLines({
  required List<TaxTreatment> treatments,
  required List<double?> rates,
  required DateTime documentDate,
  required List<ZimraTax> applicableTaxes,
}) {
  if (treatments.isEmpty) {
    return const FdmsLinesResult(
      lines: [],
      problem: 'Document has no line items to fiscalise.',
    );
  }

  final lines = <ReceiptLineInput>[];
  final used = <ZimraTax>{};
  for (var i = 0; i < treatments.length; i++) {
    final res = resolveFdmsTax(
      treatment: treatments[i],
      rate: rates.length > i ? rates[i] : null,
      documentDate: documentDate,
      applicableTaxes: applicableTaxes,
    );
    if (!res.ok) {
      return FdmsLinesResult(lines: const [], problem: res.problem);
    }
    used.add(res.tax!);
    lines.add(
      ReceiptLineInput(
        name: '',
        price: 0,
        quantity: 1,
        taxId: res.tax!.taxId,
        taxPercent: res.tax!.isExempt ? null : res.tax!.taxPercent,
        taxCode: res.tax!.taxCode.isEmpty ? null : res.tax!.taxCode,
      ),
    );
  }
  return FdmsLinesResult(lines: lines, usedTaxes: used.toList());
}

/// The published GetConfig Tax schema has no classification enum. Preserve
/// optional type/category fields, but only recognize explicit semantic values;
/// never interpret numeric codes or infer an ID from a name.
bool isNonVatTax(ZimraTax tax) {
  String normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final structured = [
    tax.taxType,
    tax.taxCategory,
  ].whereType<String>().toList();
  if (structured.isNotEmpty) {
    return structured.any(
      (v) => {'nonvat', 'nonvat0', 'nonvatregistered'}.contains(normalize(v)),
    );
  }
  return RegExp(
    r'^non[\s_\-–—]*vat(?:\s+registered)?(?:\s+0(?:\.0+)?\s*%)?$',
    caseSensitive: false,
  ).hasMatch(tax.taxName.trim());
}

List<ZimraTax> _validOn(List<ZimraTax> taxes, DateTime date) =>
    taxes.where((tax) => tax.isValidOn(date)).toList();

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _fmtRate(double r) =>
    r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1);
