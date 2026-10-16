import 'package:hive/hive.dart';

@HiveType(typeId: 2)
class Client extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String companyName;

  @HiveField(2)
  String? address;

  @HiveField(3)
  String? email;

  @HiveField(4)
  String? phone;

  /// The organization this client belongs to. Null means "legacy" — the
  /// storage layer backfills it to the then-active organization once.
  @HiveField(5)
  String? orgId;

  /// Fiscal identifiers are stored as trimmed strings: whitespace-only or
  /// empty entries collapse to null. This keeps the UI display ("TIN:
  /// …") and the FDMS buyer mapping ([buyerText] applies the same
  /// normalization) from ever disagreeing about what is "present".
  static String? _cleanText(dynamic value) {
    if (value == null) return null;
    if (value is! String) return null; // corrupted type — treat as absent
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  @HiveField(6)
  String customerType;

  @HiveField(7)
  String? registeredName;

  @HiveField(8)
  String? tradeName;

  /// Normalized on assignment: trimmed; empty/whitespace-only -> null.
  /// Property syntax (not a plain field) so assignment-time writes through
  /// cascades (..tin = …) are normalized too. Hive annotations are inert
  /// here (no hive_generator; adapters are hand-written in adapters.dart).
  String? _tin;
  String? get tin => _tin;
  set tin(String? value) => _tin = _cleanText(value);

  @HiveField(10)
  bool vatRegistered;

  String? _vatNumber;
  String? get vatNumber => _vatNumber;
  set vatNumber(String? value) => _vatNumber = _cleanText(value);

  @HiveField(12)
  bool useFiscalDetails;

  @HiveField(13)
  String? houseNo;

  @HiveField(14)
  String? street;

  @HiveField(15)
  String? suburb;

  @HiveField(16)
  String? city;

  @HiveField(17)
  String? province;

  @HiveField(18)
  String? country;

  String get formattedAddress => [
    address,
    houseNo,
    street,
    suburb,
    city,
    province,
    country,
  ].whereType<String>().where((v) => v.trim().isNotEmpty).join(', ');

  bool matchesSearch(String query) =>
      [companyName, registeredName, tradeName, tin, phone, email]
          .whereType<String>()
          .any((v) => v.toLowerCase().contains(query.toLowerCase()));

  Client({
    required this.id,
    required this.companyName,
    this.address,
    this.email,
    this.phone,
    this.orgId,
    this.customerType = 'individual',
    this.registeredName,
    this.tradeName,
    String? tin,
    this.vatRegistered = false,
    String? vatNumber,
    this.useFiscalDetails = false,
    this.houseNo,
    this.street,
    this.suburb,
    this.city,
    this.province,
    this.country,
  }) {
    // Normalize once at the model boundary: every construction path (Hive
    // adapter, JSON restore, forms) lands here, so UI display and the FDMS
    // buyer mapping always see the same "present or absent" reality.
    this.tin = _cleanText(tin);
    this.vatNumber = _cleanText(vatNumber);
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'company_name': companyName,
    'address': address,
    'email': email,
    'phone': phone,
    'org_id': orgId,
    'customer_type': customerType,
    'registered_name': registeredName,
    'trade_name': tradeName,
    'tin': tin,
    'vat_registered': vatRegistered,
    'vat_number': vatNumber,
    'use_fiscal_details': useFiscalDetails,
    'house_no': houseNo,
    'street': street,
    'suburb': suburb,
    'city': city,
    'province': province,
    'country': country,
  };

  factory Client.fromJson(Map<String, dynamic> json) => Client(
    id: json['id'] ?? '',
    companyName: json['company_name'] ?? '',
    address: json['address'],
    email: json['email'],
    phone: json['phone'],
    orgId: json['org_id'],
    customerType: json['customer_type'] ?? 'individual',
    registeredName: json['registered_name'],
    tradeName: json['trade_name'],
    tin: _cleanText(json['tin']),
    vatRegistered: json['vat_registered'] ?? false,
    vatNumber: _cleanText(json['vat_number']),
    useFiscalDetails: json['use_fiscal_details'] ?? false,
    houseNo: json['house_no'],
    street: json['street'],
    suburb: json['suburb'],
    city: json['city'],
    province: json['province'],
    country: json['country'],
  );
}
