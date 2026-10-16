import 'package:hive_flutter/hive_flutter.dart';
import '../models/document.dart';
import '../models/client.dart';
import '../models/organization.dart';
import '../models/adapters.dart';
import '../models/product.dart';

class StorageService {
  static const _docsBoxName = 'documents';
  static const _clientsBoxName = 'clients';
  static const _orgBoxName = 'organization';
  static const _settingsBoxName = 'settings';

  late Box<QuoteflowDocument> _docsBox;
  late Box<Client> _clientsBox;
  late Box<Organization> _orgBox;
  late Box _settingsBox;
  late Box _productsBox;

  // ── Initialization ──

  Future<void> init() async {
    await Hive.initFlutter();
    registerAdapters();

    _docsBox = await Hive.openBox<QuoteflowDocument>(_docsBoxName);
    _clientsBox = await Hive.openBox<Client>(_clientsBoxName);
    _orgBox = await Hive.openBox<Organization>(_orgBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
    _productsBox = await Hive.openBox('products');

    // Seed default organization if empty
    if (_orgBox.isEmpty) {
      await _orgBox.put('default', Organization.defaultOrg());
    }

    // Migrate the legacy single-org entry (stored under the 'active' key)
    // to be keyed by the org's own id so multi-org switching can address it.
    if (_orgBox.containsKey('active')) {
      final legacy = _orgBox.get('active');
      if (legacy != null) {
        await _orgBox.put(legacy.id, legacy);
        await _orgBox.delete('active');
      }
    }

    // One-time migration: documents/clients created before multi-org
    // support have no orgId. Assign them to the active organization so
    // scoping works, then never run again.
    if (!_settingsBox.get(_orgBackfilledKey, defaultValue: false)) {
      final activeId = getActiveOrg().id;
      for (final doc in _docsBox.values) {
        if (doc.orgId == null) {
          doc.orgId = activeId;
          await _docsBox.put(doc.id, doc);
        }
      }
      for (final client in _clientsBox.values) {
        if (client.orgId == null) {
          client.orgId = activeId;
          await _clientsBox.put(client.id, client);
        }
      }
      await _settingsBox.put(_orgBackfilledKey, true);
    }
  }

  // ── Documents ──

  List<QuoteflowDocument> getAllDocuments() {
    final docs = _docsBox.values.toList();
    docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return docs;
  }

  List<QuoteflowDocument> getDocumentsByType(DocumentType type) {
    final typeStr = documentTypeToString(type);
    return getAllDocuments().where((d) => d.docType == typeStr).toList();
  }

  QuoteflowDocument? getDocument(String id) {
    return _docsBox.get(id);
  }

  Future<void> saveDocument(QuoteflowDocument doc) async {
    await _docsBox.put(doc.id, doc);
  }

  Future<void> deleteDocument(String id) async {
    await _docsBox.delete(id);
  }

  // ── Clients ──

  List<Client> getAllClients() {
    final clients = _clientsBox.values.toList();
    clients.sort((a, b) => a.companyName.compareTo(b.companyName));
    return clients;
  }

  Client? getClient(String id) {
    return _clientsBox.get(id);
  }

  Future<void> saveClient(Client client) async {
    await _clientsBox.put(client.id, client);
  }

  Future<void> deleteClient(String id) async {
    await _clientsBox.delete(id);
  }

  // ── Organization ──

  List<Product> getAllProducts() => _productsBox.values
      .map((row) => Product.fromJson(Map<String, dynamic>.from(row as Map)))
      .toList();

  Product? getProduct(String id) {
    final row = _productsBox.get(id);
    return row == null
        ? null
        : Product.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<void> saveProduct(Product product) async {
    product.validate();
    await _productsBox.put(product.id, product.toJson());
  }

  Future<void> deleteProduct(String id) => _productsBox.delete(id);

  static const _activeOrgKey = 'active_org_id';
  static const _orgBackfilledKey = 'org_ids_backfilled';

  /// Every saved organization.
  List<Organization> listOrgs() {
    final orgs = _orgBox.values.toList();
    orgs.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return orgs;
  }

  /// The currently active organization. Falls back to the first saved one
  /// (legacy installs stored a single org under the 'active' key), then to
  /// a fresh default.
  Organization getActiveOrg() {
    final activeId = _settingsBox.get(_activeOrgKey);
    if (activeId != null) {
      final org = _orgBox.get(activeId);
      if (org != null) return org;
    }
    final orgs = listOrgs();
    if (orgs.isNotEmpty) return orgs.first;
    return Organization.defaultOrg();
  }

  Future<void> saveActiveOrg(Organization org) async {
    await _orgBox.put(org.id, org);
    await _settingsBox.put(_activeOrgKey, org.id);
  }

  Future<void> switchOrg(String id) async {
    await _settingsBox.put(_activeOrgKey, id);
  }

  /// Delete an organization. When the active one is removed, the first
  /// remaining organization becomes active (returns its id, or null when
  /// the last one was deleted).
  Future<String?> deleteOrg(String id) async {
    await _orgBox.delete(id);
    final activeId = _settingsBox.get(_activeOrgKey);
    if (activeId == id) {
      final remaining = listOrgs();
      if (remaining.isNotEmpty) {
        await switchOrg(remaining.first.id);
        return remaining.first.id;
      }
      await _settingsBox.delete(_activeOrgKey);
    }
    return null;
  }

  // ── Settings ──

  String? getString(String key) => _settingsBox.get(key);

  Future<void> setString(String key, String value) async {
    await _settingsBox.put(key, value);
  }

  bool getBool(String key, {bool defaultValue = false}) =>
      _settingsBox.get(key, defaultValue: defaultValue);

  Future<void> setBool(String key, bool value) async {
    await _settingsBox.put(key, value);
  }

  // ── Cleanup ──

  Future<void> close() async {
    await Hive.close();
  }
}
