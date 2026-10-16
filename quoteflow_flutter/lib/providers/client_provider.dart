import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/client.dart';
import '../services/storage.dart';

class ClientProvider extends ChangeNotifier {
  final StorageService _storage;
  final _uuid = const Uuid();

  List<Client> _clients = [];
  String _search = '';
  bool _showAll = false;

  ClientProvider(this._storage) {
    refresh();
  }

  /// Clients visible in the current view: everything when [showAll] is on,
  /// otherwise only the active organization's clients.
  List<Client> get _scoped => _showAll
      ? _clients
      : _clients.where((c) => c.orgId == _storage.getActiveOrg().id).toList();

  /// When true, lists include every organization's clients.
  bool get showAll => _showAll;

  void setShowAll(bool value) {
    _showAll = value;
    notifyListeners();
  }

  List<Client> get clients {
    if (_search.isEmpty) return _scoped;
    final q = _search.toLowerCase();
    return _scoped.where((c) {
      return c.matchesSearch(q);
    }).toList();
  }

  List<Client> clientsForOrganization(String orgId) =>
      _clients.where((c) => c.orgId == orgId).toList();

  Future<Client> saveCustomer(Client client) async {
    if (client.companyName.trim().isEmpty) {
      throw ArgumentError("Customer name is required");
    }
    if (client.id.isEmpty) client.id = _uuid.v4();
    client.orgId ??= _storage.getActiveOrg().id;
    await _storage.saveClient(client);
    refresh();
    return client;
  }

  List<Client> get allClients => _clients;
  String get search => _search;

  Client? getClient(String id) => _storage.getClient(id);

  void setSearch(String value) {
    _search = value;
    notifyListeners();
  }

  Future<Client> createClient({
    required String companyName,
    String? address,
    String? email,
    String? phone,
  }) async {
    final client = Client(
      id: _uuid.v4(),
      companyName: companyName,
      address: address,
      email: email,
      phone: phone,
      orgId: _storage.getActiveOrg().id,
    );

    await _storage.saveClient(client);
    refresh();
    return client;
  }

  Future<void> updateClient(Client client) async {
    await _storage.saveClient(client);
    refresh();
  }

  Future<void> deleteClient(String id) async {
    await _storage.deleteClient(id);
    refresh();
  }

  void refresh() {
    _clients = _storage.getAllClients();
    notifyListeners();
  }
}
