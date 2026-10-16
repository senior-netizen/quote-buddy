import 'package:flutter/material.dart';
import '../models/client.dart';
import '../services/fiscal_buyer_mapper.dart';
import 'customer_form.dart';

class CustomerFiscalDetails extends StatelessWidget {
  final Client? customer;
  final bool include;
  final ValueChanged<bool> onChanged;
  final VoidCallback onEdited;
  const CustomerFiscalDetails({
    super.key,
    required this.customer,
    required this.include,
    required this.onChanged,
    required this.onEdited,
  });

  @override
  Widget build(BuildContext context) {
    final problems = FiscalBuyerMapper.problems(customer);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Include customer fiscal details'),
            value: include,
            onChanged: onChanged,
          ),
        ),
        if (include) ...[
          Text(
            'TIN: ${customer?.tin?.isNotEmpty == true ? customer!.tin : 'Missing'}',
          ),
          Text(
            'VAT: ${customer?.vatRegistered == true ? (customer?.vatNumber ?? 'Number missing') : 'Not registered'}',
          ),
          if (problems.isNotEmpty)
            Text('Fiscal details incomplete: ${problems.join('; ')}'),
          if (customer != null)
            TextButton.icon(
              onPressed: () async {
                final saved = await showCustomerForm(
                  context,
                  customer: customer,
                );
                if (saved != null) onEdited();
              },
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(
                problems.isEmpty ? 'Edit Customer' : 'Complete fiscal details',
              ),
            ),
        ],
      ],
    );
  }
}
