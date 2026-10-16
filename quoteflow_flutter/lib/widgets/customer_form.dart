import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client.dart';
import 'reference_design.dart';
import '../providers/client_provider.dart';

Future<Client?> showCustomerForm(BuildContext context, {Client? customer}) =>
    showDialog<Client>(
      context: context,
      builder: (_) => CustomerForm(customer: customer),
    );

/// Shared by the customer list, customer detail and document editor.
class CustomerForm extends StatefulWidget {
  final Client? customer;
  const CustomerForm({super.key, this.customer});
  @override
  State<CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<CustomerForm> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  late String _type;
  late bool _vat;
  late bool _fiscal;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final data = widget.customer?.toJson() ?? <String, dynamic>{};
    _type = widget.customer?.customerType ?? 'individual';
    _vat = widget.customer?.vatRegistered ?? false;
    _fiscal = widget.customer?.useFiscalDetails ?? false;
    _fields = {
      for (final key in [
        'company_name',
        'registered_name',
        'trade_name',
        'phone',
        'email',
        'tin',
        'vat_number',
        'house_no',
        'street',
        'suburb',
        'city',
        'province',
        'country',
        'address',
      ])
        key: TextEditingController(
          text: data[key] as String? ?? (key == 'country' ? 'Zimbabwe' : ''),
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _field(String key, String label, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _fields[key],
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label),
      keyboardType: key == 'email'
          ? TextInputType.emailAddress
          : key == 'phone'
          ? TextInputType.phone
          : TextInputType.text,
      validator: (v) {
        final value = v?.trim() ?? '';
        if (required && value.isEmpty) return 'Customer name is required';
        if (value.isEmpty) return null;
        if (key == 'email' &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
          return 'Enter a valid email address';
        }
        if (key == 'phone' &&
            !RegExp(
              r'^\+?\d{7,15}$',
            ).hasMatch(value.replaceAll(RegExp(r'[\s()-]'), ''))) {
          return 'Enter a valid phone number';
        }
        return null;
      },
    ),
  );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Work on a copy: cancellation or a failed write never mutates a Hive row.
      final data = widget.customer?.toJson() ?? <String, dynamic>{'id': ''};
      for (final entry in _fields.entries) {
        final value = entry.value.text.trim();
        data[entry.key] = value.isEmpty ? null : value;
      }
      data['customer_type'] = _type;
      data['vat_registered'] = _vat;
      data['use_fiscal_details'] = _fiscal;
      final saved = await context.read<ClientProvider>().saveCustomer(
        Client.fromJson(data),
      );
      if (mounted) Navigator.pop(context, saved);
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = 'Could not save customer. Please try again.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    title: Row(
      children: [
        const ReferenceIcon(Icons.person_outline, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.customer == null ? 'New customer' : 'Edit customer',
          ),
        ),
      ],
    ),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Save contact details for faster quotations and invoices.',
              ),
              const SizedBox(height: 20),
              Text(
                'Customer details',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Customer type'),
                items: const [
                  DropdownMenuItem(
                    value: 'individual',
                    child: Text('Individual'),
                  ),
                  DropdownMenuItem(value: 'business', child: Text('Business')),
                ],
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 12),
              _field(
                'company_name',
                'Display / Customer Name *',
                required: true,
              ),
              _field('registered_name', 'Registered Name'),
              _field('trade_name', 'Trade Name'),
              _field('phone', 'Phone'),
              _field('email', 'Email'),
              ExpansionTile(
                title: const Text('Tax & Fiscal Details'),
                tilePadding: EdgeInsets.zero,
                children: [
                  _field('tin', 'TIN'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('VAT Registered'),
                    subtitle: Text(_vat ? 'Yes' : 'No'),
                    value: _vat,
                    onChanged: (v) => setState(() => _vat = v),
                  ),
                  if (_vat) _field('vat_number', 'VAT Registration Number'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use fiscal details on new documents'),
                    value: _fiscal,
                    onChanged: (v) => setState(() => _fiscal = v),
                  ),
                  const Text(
                    'Optional when saving a customer. Required fiscal fields are checked before submission to ZIMRA.',
                  ),
                ],
              ),
              ExpansionTile(
                title: const Text('Address'),
                tilePadding: EdgeInsets.zero,
                children: [
                  _field('house_no', 'House / Building Number'),
                  _field('street', 'Street'),
                  _field('suburb', 'Suburb'),
                  _field('city', 'City / Town'),
                  _field('province', 'Province'),
                  _field('country', 'Country'),
                  if (widget.customer?.address?.isNotEmpty ?? false)
                    _field('address', 'Existing address'),
                ],
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
        child: Text(_saving ? 'Saving…' : 'Save Customer'),
      ),
    ],
  );
}
