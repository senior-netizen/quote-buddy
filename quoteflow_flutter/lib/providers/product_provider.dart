import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/storage.dart';

class ProductProvider extends ChangeNotifier {
  final StorageService storage;
  ProductProvider(this.storage);

  void refresh() => notifyListeners();

  List<Product> search(
    String orgId,
    String query, {
    bool inStockOnly = false,
  }) =>
      storage
          .getAllProducts()
          .where(
            (p) =>
                p.orgId == orgId &&
                p.matches(query) &&
                (!inStockOnly || p.quantity > 0),
          )
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  Future<void> save(Product product) async {
    product.validate();
    final existing = storage.getProduct(product.id);
    if (existing != null && existing.orgId != product.orgId) {
      throw ArgumentError('A product cannot be moved between organizations.');
    }
    if (product.sku.trim().isNotEmpty &&
        search(product.orgId, '').any(
          (p) =>
              p.id != product.id &&
              p.sku.trim().toLowerCase() == product.sku.trim().toLowerCase(),
        )) {
      throw ArgumentError('A product with this SKU already exists.');
    }
    await storage.saveProduct(product);
    notifyListeners();
  }

  Future<void> delete(Product product) async {
    await storage.deleteProduct(product.id);
    notifyListeners();
  }
}
