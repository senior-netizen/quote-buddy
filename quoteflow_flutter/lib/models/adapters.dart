import 'package:hive/hive.dart';
import '../services/tax_engine.dart';
import 'document.dart';
import 'client.dart';
import 'organization.dart';

// ── LineItem Adapter ──

class LineItemAdapter extends TypeAdapter<LineItem> {
  @override
  final int typeId = 0;

  @override
  LineItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return LineItem(
      description: fields[0] as String,
      quantity: fields[1] as double,
      unitPrice: fields[2] as double,
      // Field 3 added with per-line tax treatments; older rows are
      // unassigned (org default applies) — never force a treatment.
      taxTreatment: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LineItem obj) {
    writer.writeByte(4); // number of fields
    writer.writeByte(0);
    writer.write(obj.description);
    writer.writeByte(1);
    writer.write(obj.quantity);
    writer.writeByte(2);
    writer.write(obj.unitPrice);
    writer.writeByte(3);
    writer.write(obj.taxTreatment);
  }
}

// ── QuoteflowDocument Adapter ──

class DocumentAdapter extends TypeAdapter<QuoteflowDocument> {
  @override
  final int typeId = 1;

  @override
  QuoteflowDocument read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return QuoteflowDocument(
      id: fields[0] as String,
      docType: fields[1] as String,
      docNumber: fields[2] as String,
      issueDate: fields[3] as String,
      dueDate: fields[4] as String?,
      lineItems: (fields[5] as List).cast<LineItem>(),
      taxRate: fields[6] as double,
      discount: fields[7] as double,
      subtotal: fields[8] as double,
      taxAmount: fields[9] as double,
      total: fields[10] as double,
      notes: fields[11] as String?,
      clientId: fields[12] as String,
      createdAt: fields[13] as String,
      convertedFrom: fields[14] as String?,
      docStatus: fields[15] as String? ?? 'draft',
      signatureData: fields[16] as String?,
      signedAt: fields[17] as String?,
      pdfTheme: fields[18] as String?,
      logoPosition: fields[19] as String?,
      tableStyle: fields[20] as String?,
      orgId: fields[21] as String?,
      fiscalStatus: fields[22] as String?,
      includeBuyerDetails: fields[36] as bool? ?? false,
      // Fields 23–26 & 29: fiscal ints written by this app, but older
      // builds may have stored doubles (e.g. 501.0) — parse tolerantly.
      fiscalDeviceId: fields[23] is int
          ? fields[23] as int
          : int.tryParse('${fields[23]}'),
      fiscalDayNo: fields[24] is int
          ? fields[24] as int
          : int.tryParse('${fields[24]}'),
      fiscalReceiptNo: fields[25] is int
          ? fields[25] as int
          : int.tryParse('${fields[25]}'),
      fiscalReceiptGlobalNo: fields[26] is int
          ? fields[26] as int
          : int.tryParse('${fields[26]}'),
      fiscalQrPayload: fields[27] as String?,
      fiscalSignature: fields[28] as String?,
      fiscalReceiptId: fields[29] is int
          ? fields[29] as int
          : int.tryParse('${fields[29]}'),
      fiscalOperationId: fields[30] as String?,
      fiscalisedAt: fields[31] as String?,
      fiscalError: fields[32] as String?,
      fiscalPendingPayload: fields[33] as String?,
      fiscalRecord: fields[35] == null
          ? null
          : Map<String, dynamic>.from(fields[35] as Map),
      fiscalTaxSnapshot: (fields[34] as List?)
          ?.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }

  @override
  void write(BinaryWriter writer, QuoteflowDocument obj) {
    writer.writeByte(37);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.docType);
    writer.writeByte(2);
    writer.write(obj.docNumber);
    writer.writeByte(3);
    writer.write(obj.issueDate);
    writer.writeByte(4);
    writer.write(obj.dueDate);
    writer.writeByte(5);
    writer.write(obj.lineItems);
    writer.writeByte(6);
    writer.write(obj.taxRate);
    writer.writeByte(7);
    writer.write(obj.discount);
    writer.writeByte(8);
    writer.write(obj.subtotal);
    writer.writeByte(9);
    writer.write(obj.taxAmount);
    writer.writeByte(10);
    writer.write(obj.total);
    writer.writeByte(11);
    writer.write(obj.notes);
    writer.writeByte(12);
    writer.write(obj.clientId);
    writer.writeByte(13);
    writer.write(obj.createdAt);
    writer.writeByte(14);
    writer.write(obj.convertedFrom);
    writer.writeByte(15);
    writer.write(obj.docStatus);
    writer.writeByte(16);
    writer.write(obj.signatureData);
    writer.writeByte(17);
    writer.write(obj.signedAt);
    writer.writeByte(18);
    writer.write(obj.pdfTheme);
    writer.writeByte(19);
    writer.write(obj.logoPosition);
    writer.writeByte(20);
    writer.write(obj.tableStyle);
    writer.writeByte(21);
    writer.write(obj.orgId);
    writer.writeByte(22);
    writer.write(obj.fiscalStatus);
    writer.writeByte(23);
    writer.write(obj.fiscalDeviceId);
    writer.writeByte(24);
    writer.write(obj.fiscalDayNo);
    writer.writeByte(25);
    writer.write(obj.fiscalReceiptNo);
    writer.writeByte(26);
    writer.write(obj.fiscalReceiptGlobalNo);
    writer.writeByte(27);
    writer.write(obj.fiscalQrPayload);
    writer.writeByte(28);
    writer.write(obj.fiscalSignature);
    writer.writeByte(29);
    writer.write(obj.fiscalReceiptId);
    writer.writeByte(30);
    writer.write(obj.fiscalOperationId);
    writer.writeByte(31);
    writer.write(obj.fiscalisedAt);
    writer.writeByte(32);
    writer.write(obj.fiscalError);
    writer.writeByte(33);
    writer.write(obj.fiscalPendingPayload);
    writer.writeByte(34);
    writer.write(obj.fiscalTaxSnapshot);
    writer.writeByte(35);
    writer.write(obj.fiscalRecord);
    writer.writeByte(36);
    writer.write(obj.includeBuyerDetails);
  }
}

// ── Client Adapter ──

class ClientAdapter extends TypeAdapter<Client> {
  @override
  final int typeId = 2;

  @override
  Client read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Client(
      id: fields[0] as String,
      companyName: fields[1] as String,
      address: fields[2] as String?,
      email: fields[3] as String?,
      phone: fields[4] as String?,
      orgId: fields[5] as String?,
      customerType: fields[6] as String? ?? 'individual',
      registeredName: fields[7] as String?,
      tradeName: fields[8] as String?,
      tin: fields[9] as String?,
      vatRegistered: fields[10] as bool? ?? false,
      vatNumber: fields[11] as String?,
      useFiscalDetails: fields[12] as bool? ?? false,
      houseNo: fields[13] as String?,
      street: fields[14] as String?,
      suburb: fields[15] as String?,
      city: fields[16] as String?,
      province: fields[17] as String?,
      country: fields[18] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Client obj) {
    writer.writeByte(19);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.companyName);
    writer.writeByte(2);
    writer.write(obj.address);
    writer.writeByte(3);
    writer.write(obj.email);
    writer.writeByte(4);
    writer.write(obj.phone);
    writer.writeByte(5);
    writer.write(obj.orgId);
    writer.writeByte(6);
    writer.write(obj.customerType);
    writer.writeByte(7);
    writer.write(obj.registeredName);
    writer.writeByte(8);
    writer.write(obj.tradeName);
    writer.writeByte(9);
    writer.write(obj.tin);
    writer.writeByte(10);
    writer.write(obj.vatRegistered);
    writer.writeByte(11);
    writer.write(obj.vatNumber);
    writer.writeByte(12);
    writer.write(obj.useFiscalDetails);
    writer.writeByte(13);
    writer.write(obj.houseNo);
    writer.writeByte(14);
    writer.write(obj.street);
    writer.writeByte(15);
    writer.write(obj.suburb);
    writer.writeByte(16);
    writer.write(obj.city);
    writer.writeByte(17);
    writer.write(obj.province);
    writer.writeByte(18);
    writer.write(obj.country);
  }
}

// ── Organization Adapter ──

class OrganizationAdapter extends TypeAdapter<Organization> {
  @override
  final int typeId = 3;

  @override
  Organization read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final fieldId = reader.readByte();
      if (numOfFields == 28 && i == 27 && fieldId == 31) {
        // An earlier writer declared 28 fields and inserted a stray 31
        // before fields 27-30. Recover that exact format so existing company
        // settings can still load on startup without clearing saved data.
        for (var trailingField = 27; trailingField <= 30; trailingField++) {
          if (reader.readByte() != trailingField) {
            throw HiveError('Invalid legacy organization field sequence.');
          }
          fields[trailingField] = reader.read();
        }
      } else {
        fields[fieldId] = reader.read();
      }
    }
    return Organization(
      id: fields[0] as String,
      name: fields[1] as String,
      shortName: fields[2] as String?,
      logoUrl: fields[3] as String?,
      emails: (fields[4] as List?)?.cast<String>() ?? [],
      website: fields[5] as String?,
      registration: fields[6] as String?,
      tin: fields[7] as String?,
      duns: fields[8] as String?,
      praz: fields[9] as String?,
      currency: fields[10] as String,
      defaultTaxRate: fields[11] as double,
      address: fields[12] as String?,
      phone: fields[13] as String?,
      paymentInstructions: fields[14] as String?,
      pdfTheme: fields[15] as String? ?? 'classic',
      city: fields[16] as String?,
      state: fields[17] as String?,
      postalCode: fields[18] as String?,
      country: fields[19] as String?,
      vatNumber: fields[20] as String?,
      bankAccountName: fields[21] as String?,
      bankName: fields[22] as String?,
      bankBranch: fields[23] as String?,
      bankAccountNumber: fields[24] as String?,
      bankIban: fields[25] as String?,
      bankSwift: fields[26] as String?,
      defaultPaymentTerms: fields[27] as int?,
      logoPosition: fields[28] as String?,
      tableStyle: fields[29] as String?,
      logoSize: fields[30] as double?,
      // Tax profile fields (31–33) were added later: older boxes may not
      // contain them. taxEnabled defaults to FALSE — never force VAT on an
      // organisation that has not asked for it.
      taxEnabled: fields[31] as bool? ?? false,
      taxDefinitions: ((fields[32] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => TaxDefinition.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      defaultTaxTreatment: fields[33] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Organization obj) {
    writer.writeByte(34);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.name);
    writer.writeByte(2);
    writer.write(obj.shortName);
    writer.writeByte(3);
    writer.write(obj.logoUrl);
    writer.writeByte(4);
    writer.write(obj.emails);
    writer.writeByte(5);
    writer.write(obj.website);
    writer.writeByte(6);
    writer.write(obj.registration);
    writer.writeByte(7);
    writer.write(obj.tin);
    writer.writeByte(8);
    writer.write(obj.duns);
    writer.writeByte(9);
    writer.write(obj.praz);
    writer.writeByte(10);
    writer.write(obj.currency);
    writer.writeByte(11);
    writer.write(obj.defaultTaxRate);
    writer.writeByte(12);
    writer.write(obj.address);
    writer.writeByte(13);
    writer.write(obj.phone);
    writer.writeByte(14);
    writer.write(obj.paymentInstructions);
    writer.writeByte(15);
    writer.write(obj.pdfTheme);
    writer.writeByte(16);
    writer.write(obj.city);
    writer.writeByte(17);
    writer.write(obj.state);
    writer.writeByte(18);
    writer.write(obj.postalCode);
    writer.writeByte(19);
    writer.write(obj.country);
    writer.writeByte(20);
    writer.write(obj.vatNumber);
    writer.writeByte(21);
    writer.write(obj.bankAccountName);
    writer.writeByte(22);
    writer.write(obj.bankName);
    writer.writeByte(23);
    writer.write(obj.bankBranch);
    writer.writeByte(24);
    writer.write(obj.bankAccountNumber);
    writer.writeByte(25);
    writer.write(obj.bankIban);
    writer.writeByte(26);
    writer.write(obj.bankSwift);
    writer.writeByte(27);
    writer.write(obj.defaultPaymentTerms);
    writer.writeByte(28);
    writer.write(obj.logoPosition);
    writer.writeByte(29);
    writer.write(obj.tableStyle);
    writer.writeByte(30);
    writer.write(obj.logoSize);
    writer.writeByte(31);
    writer.write(obj.taxEnabled);
    writer.writeByte(32);
    writer.write(obj.taxDefinitionsRaw);
    writer.writeByte(33);
    writer.write(obj.defaultTaxTreatment);
  }
}

/// Register all Hive adapters.
///
/// Safe to call more than once: Hive throws when an adapter for a typeId is
/// already registered, which would otherwise crash a second
/// [StorageService.init] (hot restart, repeated test setup, …).
void registerAdapters() {
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(LineItemAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(DocumentAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(ClientAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(OrganizationAdapter());
}
