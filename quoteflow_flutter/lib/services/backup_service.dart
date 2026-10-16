import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/document.dart';
import '../models/client.dart';
import '../models/product.dart';
import '../models/organization.dart';
import '../services/storage.dart';

class BackupService {
  final StorageService _storage;

  BackupService(this._storage);

  /// Export all data to a JSON map
  Map<String, dynamic> exportData() {
    final docs = _storage.getAllDocuments();
    final clients = _storage.getAllClients();
    final org = _storage.getActiveOrg();

    return {
      'version': '1.2.0',
      'organizations': _storage.listOrgs().map((o) => o.toJson()).toList(),
      'active_organization_id': org.id,
      'exportedAt': DateTime.now().toIso8601String(),
      'organization': org.toJson(),
      'documents': docs.map((d) => d.toJson()).toList(),
      'clients': clients.map((c) => c.toJson()).toList(),
      'products': _storage.getAllProducts().map((p) => p.toJson()).toList(),
    };
  }

  /// Export data as JSON string
  String exportJson() {
    return jsonEncode(exportData());
  }

  /// Serialize one organization's branding + PDF settings as a shareable
  /// JSON string (logo included).
  String exportOrgPreset(Organization org) {
    return jsonEncode({
      'type': 'quoteflow_org_preset',
      'version': '1.0.0',
      'organization': org.toJson(),
    });
  }

  /// Parse a branding-preset JSON string back into an Organization, or null
  /// when the file isn't a valid preset.
  Organization? parseOrgPreset(String jsonStr) {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (data['type'] != 'quoteflow_org_preset' ||
          data['organization'] == null) {
        return null;
      }
      return Organization.fromJson(
        data['organization'] as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Save a branding preset to a file and return its path.
  Future<String> saveOrgPresetToFile(Organization org) async {
    if (kIsWeb) {
      throw UnsupportedError('File export is not supported on web');
    }
    final dir = await getApplicationDocumentsDirectory();
    final safe = org.name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(' ', '_');
    final path =
        '${dir.path}/quoteflow_org_${safe}_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File(path);
    await file.writeAsString(exportOrgPreset(org));
    return path;
  }

  /// Get the default export file path
  Future<String> getExportPath() async {
    if (kIsWeb) return '';
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .substring(0, 19);
    return '${dir.path}/quoteflow_backup_$timestamp.json';
  }

  /// Save export to file
  Future<String> saveExportToFile() async {
    if (kIsWeb) {
      throw UnsupportedError('File export is not supported on web');
    }
    final path = await getExportPath();
    final file = File(path);
    await file.writeAsString(exportJson());
    return path;
  }

  /// Import data from JSON string
  Future<ImportResult> importFromJson(String jsonStr) async {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Validate containers before making any changes. Branding presets are
      // separate files and must not be mistaken for a complete data backup.
      if (data['type'] != null ||
          !['documents', 'clients', 'products'].any(data.containsKey)) {
        throw const FormatException(
          'This file is not a QuoteFlow data backup.',
        );
      }
      for (final key in ['documents', 'clients', 'products', 'organizations']) {
        if (data[key] != null && data[key] is! List) {
          throw FormatException('Invalid backup collection: $key.');
        }
      }
      final organizations = <Organization>[];
      final orgRows =
          data['organizations'] as List? ??
          (data['organization'] == null ? [] : [data['organization']]);
      for (final row in orgRows) {
        final org = Organization.fromJson(
          Map<String, dynamic>.from(row as Map),
        );
        if (org.id.isEmpty || org.name.trim().isEmpty) {
          throw const FormatException(
            'Backup business details are incomplete.',
          );
        }
        organizations.add(org);
      }
      final previousActive = _storage.getActiveOrg().id;
      final targetActive =
          data['active_organization_id'] ??
          (data['organization'] as Map?)?['id'] ??
          previousActive;
      final knownIds = {
        ..._storage.listOrgs().map((o) => o.id),
        ...organizations.map((o) => o.id),
      };
      if (targetActive is! String || !knownIds.contains(targetActive)) {
        throw const FormatException('Backup active business is missing.');
      }
      int docsImported = 0,
          clientsImported = 0,
          productsImported = 0,
          skipped = 0;
      // Save every business before its records, then restore the selected one.
      for (final org in organizations) {
        await _storage.saveActiveOrg(org);
      }
      await _storage.switchOrg(targetActive);
      for (final row in data['products'] as List? ?? const []) {
        try {
          final product = Product.fromJson(
            Map<String, dynamic>.from(row as Map),
          );
          final existing = _storage.getProduct(product.id);
          if (!knownIds.contains(product.orgId) ||
              (existing != null && existing.orgId != product.orgId)) {
            skipped++;
            continue;
          }
          await _storage.saveProduct(product);
          productsImported++;
        } catch (_) {
          skipped++;
        }
      }
      for (final row in data['documents'] as List? ?? const []) {
        try {
          final doc = QuoteflowDocument.fromJson(
            Map<String, dynamic>.from(row as Map),
          );
          doc.orgId ??= targetActive;
          final existing = _storage.getDocument(doc.id);
          // Fiscal acknowledgements and queued signed receipts must never be
          // replaced by stale backups, even within the same business.
          if (doc.id.isEmpty ||
              !knownIds.contains(doc.orgId) ||
              (existing != null &&
                  (existing.isFiscalised ||
                      existing.isFiscalPending ||
                      existing.orgId != doc.orgId))) {
            skipped++;
            continue;
          }
          await _storage.saveDocument(doc);
          docsImported++;
        } catch (_) {
          skipped++;
        }
      }
      for (final row in data['clients'] as List? ?? const []) {
        try {
          final client = Client.fromJson(Map<String, dynamic>.from(row as Map));
          client.orgId ??= targetActive;
          final existing = _storage.getClient(client.id);
          if (client.id.isEmpty ||
              !knownIds.contains(client.orgId) ||
              (existing != null && existing.orgId != client.orgId)) {
            skipped++;
            continue;
          }
          await _storage.saveClient(client);
          clientsImported++;
        } catch (_) {
          skipped++;
        }
      }

      return ImportResult(
        success: true,
        documentsImported: docsImported,
        clientsImported: clientsImported,
        message:
            'Imported $docsImported documents, $clientsImported clients and $productsImported products. '
            '$skipped records skipped (protected fiscal records, ownership conflicts or invalid data).',
        recordsSkipped: skipped,
        productsImported: productsImported,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        documentsImported: 0,
        clientsImported: 0,
        message: 'Import failed: $e',
      );
    }
  }
}

class ImportResult {
  final bool success;
  final int documentsImported;
  final int clientsImported;
  final int productsImported;
  final String message;
  final int recordsSkipped;

  ImportResult({
    required this.success,
    required this.documentsImported,
    required this.clientsImported,
    this.productsImported = 0,
    this.recordsSkipped = 0,
    required this.message,
  });
}
