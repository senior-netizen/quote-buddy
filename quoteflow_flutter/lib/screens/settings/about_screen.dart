import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/reference_design.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: referenceAppBar(context, 'About'),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .09),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const AppLogo(size: 92),
              ),
              const SizedBox(height: 18),
              const Text(
                'QuoteFlow',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.6,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'v1.1.0',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Offline-first quotations & invoicing',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        _section(context, 'Company', [
          _row(
            context,
            Icons.business_outlined,
            'Company',
            'Squirrellabs Technologies Pvt Ltd',
          ),
          _row(context, Icons.inventory_2_outlined, 'Product', 'QuoteFlow'),
          _row(
            context,
            Icons.language,
            'Website',
            'www.quoteflow.co.zw',
            url: 'https://www.quoteflow.co.zw',
          ),
          _row(
            context,
            Icons.mail_outline,
            'Contact',
            'hello@quoteflow.co.zw',
            url: 'mailto:hello@quoteflow.co.zw',
          ),
          _row(
            context,
            Icons.location_on_outlined,
            'Address',
            'Squirrel House, between 2nd and 3rd Josiah Tongogara Avenue, Bulawayo',
          ),
          _row(context, Icons.verified_user_outlined, 'License', 'Proprietary'),
        ]),
        const SizedBox(height: 16),
        _section(context, 'Created by', [
          _creator(
            context,
            'Squirrellabs Technologies',
            'Product & Development',
            Icons.science_outlined,
            'https://www.squirrellabs.work',
          ),
          const Divider(height: 20),
          _creator(
            context,
            'Rodent, Inc.',
            'Innovation & Engineering',
            Icons.code_rounded,
            'https://rodent.co.zw',
          ),
        ]),
        const SizedBox(height: 16),
        _section(context, 'Technical details', [
          _row(context, Icons.layers_outlined, 'Version', '1.1.0 (Build 1)'),
          _row(
            context,
            Icons.devices_outlined,
            'Platform',
            'Mobile / Desktop / Web',
          ),
          _row(context, Icons.settings_outlined, 'Framework', 'Flutter 3.x'),
          _row(context, Icons.storage_outlined, 'Storage', 'Hive (local)'),
          _row(
            context,
            Icons.picture_as_pdf_outlined,
            'PDF Engine',
            'pdf package',
          ),
          _row(context, Icons.view_agenda_outlined, 'State Mgmt', 'Provider'),
        ]),
        const SizedBox(height: 24),
        Text(
          '© ${DateTime.now().year < 2026 ? 2026 : DateTime.now().year} Squirrellabs Technologies Pvt Ltd. All rights reserved.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
  Widget _section(BuildContext context, String title, List<Widget> children) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      );
  Widget _row(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    String? url,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReferenceIcon(icon, size: 26),
        const SizedBox(width: 10),
        SizedBox(
          width: 73,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: InkWell(
            onTap: url == null ? null : () => _open(context, url),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: url == null
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.primary,
                  decoration: url == null ? null : TextDecoration.underline,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
  Widget _creator(
    BuildContext context,
    String name,
    String role,
    IconData icon,
    String url,
  ) => InkWell(
    onTap: () => _open(context, url),
    child: Row(
      children: [
        ReferenceIcon(icon, size: 46),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                role,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, size: 20),
      ],
    ),
  );
  Future<void> _open(BuildContext context, String value) async {
    try {
      if (await launchUrl(
        Uri.parse(value),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open this link on your device.'),
        ),
      );
    }
  }
}
