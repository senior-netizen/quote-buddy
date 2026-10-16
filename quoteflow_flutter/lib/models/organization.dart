import 'package:hive/hive.dart';

import '../services/tax_engine.dart';

@HiveType(typeId: 3)
class Organization extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? shortName;

  @HiveField(3)
  String? logoUrl; // stored as base64 data URL locally

  @HiveField(4)
  List<String> emails;

  @HiveField(5)
  String? website;

  @HiveField(6)
  String? registration;

  @HiveField(7)
  String? tin;

  @HiveField(8)
  String? duns;

  @HiveField(9)
  String? praz;

  @HiveField(10)
  String currency;

  @HiveField(11)
  double defaultTaxRate;

  @HiveField(12)
  String? address;

  @HiveField(13)
  String? phone;

  @HiveField(14)
  String? paymentInstructions;

  @HiveField(15)
  String pdfTheme; // 'classic', 'modern', 'minimal', 'bold', 'elegant', 'fresh'

  // ── Address (structured, in addition to the free-form address line) ──
  @HiveField(16)
  String? city;

  @HiveField(17)
  String? state;

  @HiveField(18)
  String? postalCode;

  @HiveField(19)
  String? country;

  // ── Tax / legal identifiers ──
  @HiveField(20)
  String? vatNumber;

  // ── Banking details (used on invoices / payment footer) ──
  @HiveField(21)
  String? bankAccountName;

  @HiveField(22)
  String? bankName;

  @HiveField(23)
  String? bankBranch;

  @HiveField(24)
  String? bankAccountNumber;

  @HiveField(25)
  String? bankIban;

  @HiveField(26)
  String? bankSwift;

  /// Default payment terms in days used when creating new invoices
  /// (e.g. 14 = net 14). Null falls back to 14 days.
  @HiveField(27)
  int? defaultPaymentTerms;

  /// Where the logo sits on generated PDFs: 'left' or 'right'.
  /// Null means the theme's default (left).
  @HiveField(28)
  String? logoPosition;

  /// Line-items table style used on generated PDFs:
  /// 'striped', 'bordered', 'outlined' or 'minimal'.
  /// Null means the theme's own default style.
  @HiveField(29)
  String? tableStyle;

  /// Header logo height in points on generated PDFs. Null means 36.
  @HiveField(30)
  double? logoSize;

  // ── Tax profile ─────────────────────────────────────────────────
  // The organisation's BUSINESS tax configuration. Deliberately separate
  // from the raw ZIMRA FDMS device configuration (ZimraProvider).

  /// Whether this organisation charges tax at all. False = not VAT
  /// registered (or otherwise out of scope): invoices carry no tax, totals
  /// never include tax, and the UI/PDF never claim VAT was charged.
  @HiveField(31)
  bool taxEnabled;

  /// The organisation's own tax definitions (rates and treatments). These
  /// are configuration — NOT ZIMRA tax IDs. FDMS taxIDs resolve live from
  /// GetConfig's applicableTaxes at fiscalisation time.
  @HiveField(32, defaultValue: [])
  List<Map<String, dynamic>> taxDefinitionsRaw = const [];

  /// Which treatment new lines default to ('no_tax' | 'standard' |
  /// 'zero_rated' | 'exempt'). Null = derive from the definitions.
  @HiveField(33)
  String? defaultTaxTreatment;

  List<TaxDefinition> get taxDefinitions => taxDefinitionsRaw
      .map(TaxDefinition.fromJson)
      .toList();

  set taxDefinitions(List<TaxDefinition> defs) {
    taxDefinitionsRaw = defs.map((d) => d.toJson()).toList();
  }

  TaxTreatment get defaultTreatment =>
      taxTreatmentFromString(defaultTaxTreatment);

  Organization({
    required this.id,
    required this.name,
    this.shortName,
    this.logoUrl,
    this.emails = const [],
    this.website,
    this.registration,
    this.tin,
    this.duns,
    this.praz,
    this.currency = 'USD',
    this.defaultTaxRate = 15,
    this.address,
    this.phone,
    this.paymentInstructions,
    this.pdfTheme = 'classic',
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.vatNumber,
    this.bankAccountName,
    this.bankName,
    this.bankBranch,
    this.bankAccountNumber,
    this.bankIban,
    this.bankSwift,
    this.defaultPaymentTerms,
    this.logoPosition,
    this.tableStyle,
    this.logoSize,
    this.taxEnabled = false,
    List<TaxDefinition>? taxDefinitions,
    this.defaultTaxTreatment,
  }) {
    if (taxDefinitions != null) {
      this.taxDefinitions = taxDefinitions;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'short_name': shortName,
    'logo_url': logoUrl,
    'emails': emails,
    'website': website,
    'registration': registration,
    'tin': tin,
    'duns': duns,
    'praz': praz,
    'currency': currency,
    'default_tax_rate': defaultTaxRate,
    'address': address,
    'phone': phone,
    'payment_instructions': paymentInstructions,
    'pdf_theme': pdfTheme,
    'city': city,
    'state': state,
    'postal_code': postalCode,
    'country': country,
    'vat_number': vatNumber,
    'bank_account_name': bankAccountName,
    'bank_name': bankName,
    'bank_branch': bankBranch,
    'bank_account_number': bankAccountNumber,
    'bank_iban': bankIban,
    'bank_swift': bankSwift,
    'default_payment_terms': defaultPaymentTerms,
    'logo_position': logoPosition,
    'table_style': tableStyle,
    'logo_size': logoSize,
    'tax_enabled': taxEnabled,
    'tax_definitions': taxDefinitionsRaw,
    'default_tax_treatment': defaultTaxTreatment,
  };

  factory Organization.fromJson(Map<String, dynamic> json) => Organization(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    shortName: json['short_name'],
    logoUrl: json['logo_url'],
    emails: (json['emails'] as List?)?.cast<String>() ?? [],
    website: json['website'],
    registration: json['registration'],
    tin: json['tin'],
    duns: json['duns'],
    praz: json['praz'],
    currency: json['currency'] ?? 'USD',
    defaultTaxRate: (json['default_tax_rate'] ?? 15).toDouble(),
    address: json['address'],
    phone: json['phone'],
    paymentInstructions: json['payment_instructions'],
    pdfTheme: json['pdf_theme'] ?? 'classic',
    city: json['city'],
    state: json['state'],
    postalCode: json['postal_code'],
    country: json['country'],
    vatNumber: json['vat_number'],
    bankAccountName: json['bank_account_name'],
    bankName: json['bank_name'],
    bankBranch: json['bank_branch'],
    bankAccountNumber: json['bank_account_number'],
    bankIban: json['bank_iban'],
    bankSwift: json['bank_swift'],
    defaultPaymentTerms: (json['default_payment_terms'] as num?)?.toInt(),
    logoPosition: json['logo_position'],
    tableStyle: json['table_style'],
    logoSize: (json['logo_size'] as num?)?.toDouble(),
    taxEnabled: json['tax_enabled'] as bool? ?? false,
    taxDefinitions: ((json['tax_definitions'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => TaxDefinition.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    defaultTaxTreatment: json['default_tax_treatment'] as String?,
  );

  /// Copy this organization, optionally overriding PDF styling fields.
  /// All other fields are preserved.
  Organization copyWith({
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
  }) => Organization(
    id: id,
    name: name ?? this.name,
    shortName: shortName ?? this.shortName,
    logoUrl: logoUrl ?? this.logoUrl,
    emails: emails ?? this.emails,
    website: website ?? this.website,
    registration: registration ?? this.registration,
    tin: tin ?? this.tin,
    duns: duns ?? this.duns,
    praz: praz ?? this.praz,
    currency: currency ?? this.currency,
    defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
    address: address ?? this.address,
    phone: phone ?? this.phone,
    paymentInstructions: paymentInstructions ?? this.paymentInstructions,
    pdfTheme: pdfTheme ?? this.pdfTheme,
    city: city ?? this.city,
    state: state ?? this.state,
    postalCode: postalCode ?? this.postalCode,
    country: country ?? this.country,
    vatNumber: vatNumber ?? this.vatNumber,
    bankAccountName: bankAccountName ?? this.bankAccountName,
    bankName: bankName ?? this.bankName,
    bankBranch: bankBranch ?? this.bankBranch,
    bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
    bankIban: bankIban ?? this.bankIban,
    bankSwift: bankSwift ?? this.bankSwift,
    defaultPaymentTerms: defaultPaymentTerms ?? this.defaultPaymentTerms,
    logoPosition: logoPosition ?? this.logoPosition,
    tableStyle: tableStyle ?? this.tableStyle,
    logoSize: logoSize ?? this.logoSize,
    taxEnabled: taxEnabled ?? this.taxEnabled,
    taxDefinitions: taxDefinitions ?? this.taxDefinitions,
    defaultTaxTreatment: defaultTaxTreatment ?? this.defaultTaxTreatment,
  );

  static Organization defaultOrg() =>
      Organization(id: 'default', name: 'Your Company');
}
