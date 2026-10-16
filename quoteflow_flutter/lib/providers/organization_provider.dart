import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/organization.dart';
import '../services/storage.dart';
import '../services/tax_engine.dart';

class OrganizationProvider extends ChangeNotifier {
  final StorageService _storage;
  final _uuid = const Uuid();

  OrganizationProvider(this._storage);

  Organization get organization => _storage.getActiveOrg();

  List<Organization> get organizations => _storage.listOrgs();

  String get activeOrgId => organization.id;

  /// Make another organization active. Returns it (null if the id is
  /// unknown).
  Organization? switchOrganization(String id) {
    for (final org in organizations) {
      if (org.id == id) {
        _storage.switchOrg(id);
        notifyListeners();
        return org;
      }
    }
    return null;
  }

  Future<Organization?> activateOrganization(String id) async {
    final matches = organizations.where((org) => org.id == id);
    if (matches.isEmpty) return null;
    await _storage.switchOrg(id);
    notifyListeners();
    return matches.single;
  }

  /// Create a brand-new organization (with just a name) and activate it.
  Future<Organization> createOrganization(String name) async {
    final org = Organization(
      id: _uuid.v4(),
      name: name.trim().isEmpty ? 'Untitled Company' : name.trim(),
    );
    await _storage.saveActiveOrg(org);
    notifyListeners();
    return org;
  }

  /// Create a new organization from an imported branding preset (fresh id,
  /// everything else copied) and activate it.
  Future<Organization> createOrganizationFromPreset(Organization preset) async {
    final org = Organization(
      id: _uuid.v4(),
      name: preset.name.trim().isEmpty
          ? 'Untitled Company'
          : preset.name.trim(),
      shortName: preset.shortName,
      logoUrl: preset.logoUrl,
      emails: preset.emails,
      website: preset.website,
      registration: preset.registration,
      tin: preset.tin,
      vatNumber: preset.vatNumber,
      duns: preset.duns,
      praz: preset.praz,
      phone: preset.phone,
      address: preset.address,
      city: preset.city,
      state: preset.state,
      postalCode: preset.postalCode,
      country: preset.country,
      currency: preset.currency,
      defaultTaxRate: preset.defaultTaxRate,
      defaultPaymentTerms: preset.defaultPaymentTerms,
      paymentInstructions: preset.paymentInstructions,
      bankAccountName: preset.bankAccountName,
      bankName: preset.bankName,
      bankBranch: preset.bankBranch,
      bankAccountNumber: preset.bankAccountNumber,
      bankIban: preset.bankIban,
      bankSwift: preset.bankSwift,
      pdfTheme: preset.pdfTheme,
      logoPosition: preset.logoPosition,
      tableStyle: preset.tableStyle,
      logoSize: preset.logoSize,
      taxEnabled: preset.taxEnabled,
      taxDefinitions: preset.taxDefinitions,
      defaultTaxTreatment: preset.defaultTaxTreatment,
    );
    await _storage.saveActiveOrg(org);
    notifyListeners();
    return org;
  }

  /// Delete an organization. Returns the id of the new active org, or null
  /// when none remains.
  Future<String?> deleteOrganization(String id) async {
    final next = await _storage.deleteOrg(id);
    notifyListeners();
    return next;
  }

  /// String field semantics:
  ///  - `null` keeps the stored value untouched,
  ///  - an empty (or blank) string clears the stored value to `null`,
  ///  - any other value is stored trimmed.
  static String? _field(String? next, String? current) {
    if (next == null) return current;
    final v = next.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> updateOrganization({
    String? name,
    String? shortName,
    String? logoUrl,
    List<String>? emails,
    String? website,
    String? registration,
    String? tin,
    String? duns,
    String? praz,
    String? currency,
    double? defaultTaxRate,
    String? address,
    String? phone,
    String? paymentInstructions,
    String? pdfTheme,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    String? vatNumber,
    String? bankAccountName,
    String? bankName,
    String? bankBranch,
    String? bankAccountNumber,
    String? bankIban,
    String? bankSwift,
    int? defaultPaymentTerms,
    String? logoPosition,
    String? tableStyle,
    double? logoSize,
    bool? taxEnabled,
    List<TaxDefinition>? taxDefinitions,
    String? defaultTaxTreatment,
  }) async {
    final org = _storage.getActiveOrg();

    final updated = Organization(
      id: org.id,
      name: (name == null || name.trim().isEmpty) ? org.name : name.trim(),
      shortName: _field(shortName, org.shortName),
      logoUrl: _field(logoUrl, org.logoUrl),
      emails: emails ?? org.emails,
      website: _field(website, org.website),
      registration: _field(registration, org.registration),
      tin: _field(tin, org.tin),
      duns: _field(duns, org.duns),
      praz: _field(praz, org.praz),
      currency: (currency == null || currency.trim().isEmpty)
          ? org.currency
          : currency.trim().toUpperCase(),
      defaultTaxRate: defaultTaxRate ?? org.defaultTaxRate,
      address: _field(address, org.address),
      phone: _field(phone, org.phone),
      paymentInstructions: _field(paymentInstructions, org.paymentInstructions),
      pdfTheme: pdfTheme ?? org.pdfTheme,
      city: _field(city, org.city),
      state: _field(state, org.state),
      postalCode: _field(postalCode, org.postalCode),
      country: _field(country, org.country),
      vatNumber: _field(vatNumber, org.vatNumber),
      bankAccountName: _field(bankAccountName, org.bankAccountName),
      bankName: _field(bankName, org.bankName),
      bankBranch: _field(bankBranch, org.bankBranch),
      bankAccountNumber: _field(bankAccountNumber, org.bankAccountNumber),
      bankIban: _field(bankIban, org.bankIban),
      bankSwift: _field(bankSwift, org.bankSwift),
      defaultPaymentTerms: defaultPaymentTerms ?? org.defaultPaymentTerms,
      logoPosition: logoPosition ?? org.logoPosition,
      tableStyle: tableStyle ?? org.tableStyle,
      logoSize: logoSize ?? org.logoSize,
      taxEnabled: taxEnabled ?? org.taxEnabled,
      taxDefinitions: taxDefinitions ?? org.taxDefinitions,
      defaultTaxTreatment: _field(defaultTaxTreatment, org.defaultTaxTreatment),
    );

    await _storage.saveActiveOrg(updated);
    notifyListeners();
  }
}
