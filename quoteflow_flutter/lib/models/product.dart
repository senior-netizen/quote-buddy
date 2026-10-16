import 'dart:convert';

class Product {
  final String id;
  final String orgId;
  final String name;
  final String sku;
  final String category;
  final String unit;
  final double price;
  final double quantity;
  final String? imageDataUrl;

  const Product({
    required this.id,
    required this.orgId,
    required this.name,
    this.sku = '',
    this.category = '',
    this.unit = 'each',
    required this.price,
    required this.quantity,
    this.imageDataUrl,
  });

  bool matches(String query) {
    final text = '$name $sku $category'.toLowerCase();
    return query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .every(text.contains);
  }

  void validate() {
    if (id.isEmpty || orgId.isEmpty || name.trim().isEmpty) {
      throw ArgumentError('Product name and organization are required.');
    }
    if (!price.isFinite || price < 0 || !quantity.isFinite || quantity < 0) {
      throw ArgumentError(
        'Price and stock must be valid non-negative numbers.',
      );
    }
    if (imageDataUrl != null) {
      if (!RegExp(
            r'^data:image/(png|jpeg|webp);base64,',
          ).hasMatch(imageDataUrl!) ||
          imageDataUrl!.length > 800100) {
        throw ArgumentError(
          'Product photo must be a small JPEG, PNG or WebP image.',
        );
      }
      try {
        base64Decode(imageDataUrl!.split(',').last);
      } on FormatException {
        throw ArgumentError('Product photo is invalid.');
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'org_id': orgId,
    'name': name,
    'sku': sku,
    'category': category,
    'unit': unit,
    'price': price,
    'quantity': quantity,
    if (imageDataUrl != null) 'image_data_url': imageDataUrl,
  };

  factory Product.fromJson(Map<String, dynamic> json) {
    final product = Product(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      name: json['name'] as String,
      sku: json['sku'] as String? ?? '',
      category: json['category'] as String? ?? '',
      unit: json['unit'] as String? ?? 'each',
      price: (json['price'] as num).toDouble(),
      quantity: (json['quantity'] as num).toDouble(),
      imageDataUrl: json['image_data_url'] as String?,
    );
    product.validate();
    return product;
  }
}
