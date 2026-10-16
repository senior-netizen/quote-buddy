import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../providers/organization_provider.dart';
import '../services/calculations.dart';
import '../widgets/reference_design.dart';

class ProductsScreen extends StatefulWidget {
  final bool picking;
  final String? orgId;
  const ProductsScreen({super.key, this.picking = false, this.orgId});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _search = TextEditingController();
  String _query = '', _stock = 'All', _sort = 'name';
  static const _lowStock = 5.0;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orgs = context.watch<OrganizationProvider>();
    final orgId = widget.orgId ?? orgs.activeOrgId;
    final org = orgs.organizations.firstWhere((o) => o.id == orgId);
    final provider = context.watch<ProductProvider>();
    final all = provider.search(orgId, '');
    final products = provider
        .search(orgId, _query)
        .where(
          (p) => switch (_stock) {
            'In stock' => p.quantity > 0,
            'Low stock' => p.quantity > 0 && p.quantity < _lowStock,
            'Out of stock' => p.quantity == 0,
            _ => true,
          },
        )
        .toList();
    if (_sort == 'price') products.sort((a, b) => a.price.compareTo(b.price));
    if (_sort == 'stock') {
      products.sort((a, b) => a.quantity.compareTo(b.quantity));
    }
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: widget.picking
          ? referenceAppBar(context, 'Select a product')
          : null,
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.picking)
                    ReferenceHeading(
                      eyebrow: 'Inventory',
                      title: 'Products',
                      subtitle:
                          'Manage your products and stock levels\nto keep your business running smoothly.',
                      action: FilledButton.icon(
                        onPressed: () => showProductForm(context, orgId),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New product'),
                        style: FilledButton.styleFrom(
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  if (!widget.picking) const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search name, SKU or category…',
                          ),
                          onChanged: (value) => setState(() => _query = value),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        tooltip: 'Find product by SKU',
                        onPressed: () => _findSku(),
                        icon: const Icon(Icons.qr_code_scanner),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final status in [
                        'All',
                        'In stock',
                        'Low stock',
                        'Out of stock',
                      ])
                        ChoiceChip(
                          label: Text(status),
                          selected: _stock == status,
                          showCheckmark: false,
                          avatar: Icon(
                            status == 'All'
                                ? Icons.inventory_2_outlined
                                : Icons.circle,
                            size: status == 'All' ? 17 : 8,
                            color: _stock == status
                                ? Colors.white
                                : status == 'In stock'
                                ? const Color(0xFF22B975)
                                : status == 'Low stock'
                                ? Colors.orange
                                : Colors.red,
                          ),
                          selectedColor: colors.primary,
                          backgroundColor: colors.surface,
                          side: BorderSide.none,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            color: _stock == status
                                ? Colors.white
                                : colors.onSurfaceVariant,
                          ),
                          shape: const StadiumBorder(),
                          onSelected: (_) => setState(() => _stock = status),
                        ),
                    ],
                  ),
                  if (!widget.picking) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _metric(
                          'Total products',
                          all.length,
                          Icons.inventory_2_outlined,
                          colors.primary,
                        ),
                        const SizedBox(width: 10),
                        _metric(
                          'In stock',
                          all.where((p) => p.quantity > 0).length,
                          Icons.inventory_2_outlined,
                          const Color(0xFF20B779),
                        ),
                        const SizedBox(width: 10),
                        _metric(
                          'Low stock',
                          all
                              .where(
                                (p) => p.quantity > 0 && p.quantity < _lowStock,
                              )
                              .length,
                          Icons.inventory_2_outlined,
                          const Color(0xFFF35D77),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const ReferenceNotice(
                      'Stock quantities are updated manually.\nAdding products to documents does not change stock.',
                    ),
                    const SizedBox(height: 22),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${products.length} ${products.length == 1 ? 'product' : 'products'}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Sort products',
                        initialValue: _sort,
                        onSelected: (value) => setState(() => _sort = value),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'name',
                            child: Text('Name (A–Z)'),
                          ),
                          PopupMenuItem(
                            value: 'price',
                            child: Text('Price (low to high)'),
                          ),
                          PopupMenuItem(
                            value: 'stock',
                            child: Text('Stock (low to high)'),
                          ),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Text(
                                _sort == 'name'
                                    ? 'Name (A–Z)'
                                    : _sort == 'price'
                                    ? 'Price'
                                    : 'Stock',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.expand_more, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          if (products.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Text(
                    _query.isNotEmpty || _stock != 'All'
                        ? 'No matching products'
                        : 'No products yet. Add your first product.',
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
              sliver: SliverList.separated(
                itemCount: products.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final p = products[index];
                  final inStock = p.quantity > 0;
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => widget.picking
                          ? Navigator.pop(context, p)
                          : showProductForm(context, orgId, product: p),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 68,
                              height: 76,
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: p.imageDataUrl == null
                                  ? Icon(
                                      Icons.inventory_2_outlined,
                                      size: 34,
                                      color: colors.primary.withValues(
                                        alpha: .6,
                                      ),
                                    )
                                  : Image.memory(
                                      base64Decode(
                                        p.imageDataUrl!.split(',').last,
                                      ),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Icon(
                                        Icons.inventory_2_outlined,
                                        color: colors.primary,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          p.name,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (!widget.picking)
                                        SizedBox(
                                          width: 26,
                                          height: 28,
                                          child: PopupMenuButton<String>(
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(
                                              Icons.more_horiz,
                                              size: 20,
                                            ),
                                            tooltip: 'Product actions',
                                            onSelected: (action) =>
                                                _productAction(
                                                  action,
                                                  p,
                                                  orgId,
                                                  provider,
                                                ),
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Text('Edit product'),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (p.sku.isNotEmpty)
                                    Text(
                                      'SKU  ${p.sku}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  const SizedBox(height: 9),
                                  if (p.category.isNotEmpty)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.sell_outlined,
                                          size: 14,
                                          color: colors.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 7),
                                        Expanded(
                                          child: Text(
                                            p.category,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: colors.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    spacing: 10,
                                    runSpacing: 8,
                                    children: [
                                      Text(
                                        '${p.quantity.toStringAsFixed(p.quantity == p.quantity.roundToDouble() ? 0 : 2)} ${p.unit} in stock',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                      Text(
                                        formatMoney(p.price, org.currency),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (inStock ? Colors.green : Colors.red)
                                              .withValues(alpha: .08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      inStock ? 'In stock' : 'Out of stock',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: inStock
                                            ? const Color(0xFF169452)
                                            : Colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.picking)
                              const Icon(Icons.add_circle_outline),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _metric(String label, int value, IconData icon, Color color) =>
      Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ReferenceIcon(icon, color: color, size: 24),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$value',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(
                      label == 'Total products'
                          ? Icons.bar_chart_rounded
                          : Icons.circle_outlined,
                      color: color.withValues(alpha: .4),
                      size: 24,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _findSku() async {
    var query = '';
    final value = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Find product by SKU'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(labelText: 'SKU'),
          onChanged: (value) => query = value,
          onSubmitted: (value) => Navigator.pop(dialog, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, query),
            child: const Text('Search'),
          ),
        ],
      ),
    );
    if (mounted && value != null) {
      setState(() {
        _search.text = value;
        _query = value;
      });
    }
  }

  Future<void> _productAction(
    String action,
    Product product,
    String orgId,
    ProductProvider provider,
  ) async {
    if (action == 'edit') {
      await showProductForm(context, orgId, product: product);
      return;
    }
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          'Remove ${product.name} from inventory? Existing documents will keep their line items.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (remove == true) {
      try {
        await provider.delete(product);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not delete product. Try again.'),
            ),
          );
        }
      }
    }
  }
}

Future<void> showProductForm(
  BuildContext context,
  String orgId, {
  Product? product,
}) => showDialog<void>(
  context: context,
  builder: (_) => _ProductForm(orgId: orgId, product: product),
);

class _ProductForm extends StatefulWidget {
  final String orgId;
  final Product? product;
  const _ProductForm({required this.orgId, this.product});
  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final _form = GlobalKey<FormState>();
  late final List<TextEditingController> _fields;
  bool _saving = false;
  String? _error;
  String? _imageDataUrl;
  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _imageDataUrl = p?.imageDataUrl;
    _fields = [
      p?.name ?? '',
      p?.sku ?? '',
      p?.category ?? '',
      p?.unit ?? 'each',
      p?.price.toString() ?? '0',
      p?.quantity.toString() ?? '0',
    ].map((s) => TextEditingController(text: s)).toList();
  }

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<ProductProvider>().save(
        Product(
          id: widget.product?.id ?? const Uuid().v4(),
          orgId: widget.orgId,
          name: _fields[0].text.trim(),
          sku: _fields[1].text.trim(),
          category: _fields[2].text.trim(),
          unit: _fields[3].text.trim(),
          price: double.parse(_fields[4].text.trim()),
          quantity: double.parse(_fields[5].text.trim()),
          imageDataUrl: _imageDataUrl,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is ArgumentError
              ? error.message.toString()
              : 'Could not save product. Try again.';
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 600000) {
        throw const FormatException('Choose an image smaller than 600 KB.');
      }
      final type = bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50
          ? 'png'
          : bytes.length > 2 && bytes[0] == 0xff && bytes[1] == 0xd8
          ? 'jpeg'
          : bytes.length > 12 &&
                ascii.decode(bytes.sublist(0, 4), allowInvalid: true) ==
                    'RIFF' &&
                ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP'
          ? 'webp'
          : null;
      if (type == null) {
        throw const FormatException('Choose a JPEG, PNG or WebP image.');
      }
      if (mounted) {
        setState(() {
          _imageDataUrl = 'data:image/$type;base64,${base64Encode(bytes)}';
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : 'Could not open the photo. Try another image.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.product == null ? 'New product' : 'Edit product'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_imageDataUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        base64Decode(_imageDataUrl!.split(',').last),
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: _saving ? null : _pickImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      _imageDataUrl == null
                          ? 'Add product photo'
                          : 'Change photo',
                    ),
                  ),
                  if (_imageDataUrl != null)
                    IconButton(
                      tooltip: 'Remove photo',
                      onPressed: _saving
                          ? null
                          : () => setState(() => _imageDataUrl = null),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _fields.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _fields[i],
                    enabled: !_saving,
                    decoration: InputDecoration(
                      labelText: [
                        'Product name *',
                        'SKU',
                        'Category',
                        'Unit *',
                        'Selling price *',
                        'Stock quantity *',
                      ][i],
                    ),
                    keyboardType: i >= 4
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.text,
                    validator: (value) {
                      if ((i == 0 || i == 3) &&
                          (value?.trim().isEmpty ?? true)) {
                        return 'Required';
                      }
                      if (i >= 4) {
                        final number = double.tryParse(value?.trim() ?? '');
                        if (number == null || !number.isFinite || number < 0) {
                          return 'Enter a valid number of zero or more';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving…' : 'Save product'),
      ),
    ],
  );
}
