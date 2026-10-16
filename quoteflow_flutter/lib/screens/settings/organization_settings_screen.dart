import '../../utils/share_origin.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:local_auth/local_auth.dart';
import '../../models/organization.dart';
import '../../providers/organization_provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/storage.dart';
import '../../theme/app_theme.dart';
import '../../services/calculations.dart';
import '../../services/pdf_service.dart';
import '../../services/tax_engine.dart';
import '../../services/backup_service.dart';
import '../../services/web_download.dart';
import 'about_screen.dart';
import 'zimra_settings_screen.dart';
import '../../widgets/reference_design.dart';

class OrganizationSettingsScreen extends StatefulWidget {
  const OrganizationSettingsScreen({super.key});

  @override
  State<OrganizationSettingsScreen> createState() =>
      _OrganizationSettingsScreenState();
}

class _OrganizationSettingsScreenState
    extends State<OrganizationSettingsScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _shortNameCtrl;
  late TextEditingController _emailsCtrl;
  late TextEditingController _websiteCtrl;
  late TextEditingController _regCtrl;
  late TextEditingController _tinCtrl;
  late TextEditingController _dunsCtrl;
  late TextEditingController _prazCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _stateCtrl;
  late TextEditingController _postalCtrl;
  late TextEditingController _countryCtrl;
  late TextEditingController _vatCtrl;
  late TextEditingController _bankAcctNameCtrl;
  late TextEditingController _bankNameCtrl;
  late TextEditingController _bankBranchCtrl;
  late TextEditingController _bankAcctNumCtrl;
  late TextEditingController _ibanCtrl;
  late TextEditingController _swiftCtrl;
  late TextEditingController _currencyCtrl;
  late TextEditingController _taxRateCtrl;
  late TextEditingController _termsCtrl;
  late TextEditingController _paymentCtrl;
  bool _taxEnabled = false;
  String? _defaultTreatment;
  bool _loaded = false;
  String? _loadedOrgId;
  String _selectedTheme = 'classic';
  String _logoPosition = 'left';
  String _tableStyle = 'auto';
  double _logoSize = 36;
  bool _biometricsAvailable = false;
  bool _checkedBiometrics = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _createFormControllers();
      _applyOrgToForm(context.read<OrganizationProvider>().organization);
      _loaded = true;
    }
    if (!_checkedBiometrics) {
      _checkedBiometrics = true;
      _checkBiometricsAvailability();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _shortNameCtrl.dispose();
    _emailsCtrl.dispose();
    _websiteCtrl.dispose();
    _regCtrl.dispose();
    _tinCtrl.dispose();
    _dunsCtrl.dispose();
    _prazCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _postalCtrl.dispose();
    _countryCtrl.dispose();
    _vatCtrl.dispose();
    _bankAcctNameCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankBranchCtrl.dispose();
    _bankAcctNumCtrl.dispose();
    _ibanCtrl.dispose();
    _swiftCtrl.dispose();
    _currencyCtrl.dispose();
    _taxRateCtrl.dispose();
    _termsCtrl.dispose();
    _paymentCtrl.dispose();
    super.dispose();
  }

  void _createFormControllers() {
    _nameCtrl = TextEditingController();
    _shortNameCtrl = TextEditingController();
    _emailsCtrl = TextEditingController();
    _websiteCtrl = TextEditingController();
    _regCtrl = TextEditingController();
    _tinCtrl = TextEditingController();
    _dunsCtrl = TextEditingController();
    _prazCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _cityCtrl = TextEditingController();
    _stateCtrl = TextEditingController();
    _postalCtrl = TextEditingController();
    _countryCtrl = TextEditingController();
    _vatCtrl = TextEditingController();
    _bankAcctNameCtrl = TextEditingController();
    _bankNameCtrl = TextEditingController();
    _bankBranchCtrl = TextEditingController();
    _bankAcctNumCtrl = TextEditingController();
    _ibanCtrl = TextEditingController();
    _swiftCtrl = TextEditingController();
    _currencyCtrl = TextEditingController();
    _taxRateCtrl = TextEditingController();
    _termsCtrl = TextEditingController();
    _paymentCtrl = TextEditingController();
  }

  /// Fill the form fields with an organization's values. Used on first
  /// load and whenever the active organization changes.
  void _applyOrgToForm(Organization org) {
    _nameCtrl.text = org.name;
    _shortNameCtrl.text = org.shortName ?? '';
    _emailsCtrl.text = org.emails.join(', ');
    _websiteCtrl.text = org.website ?? '';
    _regCtrl.text = org.registration ?? '';
    _tinCtrl.text = org.tin ?? '';
    _dunsCtrl.text = org.duns ?? '';
    _prazCtrl.text = org.praz ?? '';
    _phoneCtrl.text = org.phone ?? '';
    _addressCtrl.text = org.address ?? '';
    _cityCtrl.text = org.city ?? '';
    _stateCtrl.text = org.state ?? '';
    _postalCtrl.text = org.postalCode ?? '';
    _countryCtrl.text = org.country ?? '';
    _vatCtrl.text = org.vatNumber ?? '';
    _bankAcctNameCtrl.text = org.bankAccountName ?? '';
    _bankNameCtrl.text = org.bankName ?? '';
    _bankBranchCtrl.text = org.bankBranch ?? '';
    _bankAcctNumCtrl.text = org.bankAccountNumber ?? '';
    _ibanCtrl.text = org.bankIban ?? '';
    _swiftCtrl.text = org.bankSwift ?? '';
    _currencyCtrl.text = org.currency;
    _taxRateCtrl.text = org.defaultTaxRate.toString();
    _termsCtrl.text = (org.defaultPaymentTerms ?? 14).toString();
    _paymentCtrl.text = org.paymentInstructions ?? '';
    _taxEnabled = org.taxEnabled;
    _defaultTreatment = org.defaultTaxTreatment;
    _selectedTheme = org.pdfTheme;
    _logoPosition = org.logoPosition ?? 'left';
    _tableStyle = org.tableStyle ?? 'auto';
    _logoSize = org.logoSize ?? 36;
    _loadedOrgId = org.id;
  }

  // ── Tax definitions editor ──

  Widget _buildTaxDefinitionsEditor() {
    final org = context.read<OrganizationProvider>().organization;
    final defs = org.taxDefinitions;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          for (final d in defs)
            ListTile(
              dense: true,
              leading: Icon(
                d.type == TaxTreatment.standard
                    ? Icons.percent
                    : d.type == TaxTreatment.zeroRated
                    ? Icons.exposure_zero
                    : d.type == TaxTreatment.exempt
                    ? Icons.block
                    : Icons.money_off,
                size: 18,
                color: scheme.primary,
              ),
              title: Text(
                d.rate == null
                    ? '${d.name} — ${d.type.label}'
                    : (d.rate == d.rate!.roundToDouble()
                          ? '${d.name} — ${d.type.label} (${d.rate!.toStringAsFixed(0)}%)'
                          : '${d.name} — ${d.type.label} (${d.rate!.toStringAsFixed(1)}%)'),
                style: const TextStyle(fontSize: 13.5),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (d.isDefault)
                    Tooltip(
                      message: 'Default for new lines',
                      child: Icon(Icons.star, size: 16, color: scheme.primary),
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    onPressed: () => _removeTaxDefinition(d.id),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addTaxDefinition,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add tax treatment'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addTaxDefinition() async {
    final result = await showDialog<TaxDefinition>(
      context: context,
      builder: (ctx) => const _TaxDefinitionDialog(),
    );
    if (result == null) return;
    final provider = context.read<OrganizationProvider>();
    final org = provider.organization;
    final defs = [...org.taxDefinitions, result];
    // Only one default.
    final defs2 = result.isDefault
        ? defs
              .map((d) => d.id == result.id ? d : d.copyWith(isDefault: false))
              .toList()
        : defs;
    await provider.updateOrganization(taxDefinitions: defs2);
    setState(() {});
  }

  Future<void> _removeTaxDefinition(String id) async {
    final provider = context.read<OrganizationProvider>();
    final org = provider.organization;
    await provider.updateOrganization(
      taxDefinitions: org.taxDefinitions.where((d) => d.id != id).toList(),
    );
    setState(() {});
  }

  // ── Organizations ──

  Widget _buildOrganizationsSection() {
    final orgProvider = context.watch<OrganizationProvider>();
    final orgs = orgProvider.organizations;
    final activeId = orgProvider.activeOrgId;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (final org in orgs) ...[
            ListTile(
              dense: true,
              leading: Icon(
                org.id == activeId
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 20,
                color: org.id == activeId
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
              ),
              title: Text(
                org.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: org.id == activeId
                  ? Text(
                      'Active',
                      style: TextStyle(fontSize: 11, color: scheme.primary),
                    )
                  : null,
              trailing: orgs.length > 1 && org.id != activeId
                  ? IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.red.shade400,
                      ),
                      tooltip: 'Delete organization',
                      onPressed: () => _deleteOrganization(org),
                    )
                  : null,
              onTap: org.id == activeId ? null : () => _switchOrganization(org),
            ),
            if (org != orgs.last)
              Divider(height: 1, thickness: 0.5, color: scheme.outlineVariant),
          ],
          const Divider(height: 1, thickness: 0.5),
          ListTile(
            dense: true,
            leading: Icon(Icons.add, size: 20, color: scheme.primary),
            title: const Text(
              'Add organization',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            onTap: _addOrganization,
          ),
          const Divider(height: 1, thickness: 0.5),
          ListTile(
            dense: true,
            leading: Icon(Icons.ios_share, size: 20, color: scheme.primary),
            title: const Text(
              'Export company preset',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Share branding & PDF style as a file',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            onTap: _exportOrgPreset,
          ),
          ListTile(
            dense: true,
            leading: Icon(
              Icons.download_outlined,
              size: 20,
              color: scheme.primary,
            ),
            title: const Text(
              'Import company preset',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              "Apply someone else's branding to this org or a new one",
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            onTap: _importOrgPreset,
          ),
        ],
      ),
    );
  }

  Future<void> _switchOrganization(Organization org) async {
    final provider = context.read<OrganizationProvider>();
    final switched = provider.switchOrganization(org.id);
    if (switched != null && mounted) {
      _applyOrgToForm(switched);
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Switched to ${org.name}')));
    }
  }

  Future<void> _addOrganization() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New organization'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Company name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;
    final created = await context
        .read<OrganizationProvider>()
        .createOrganization(name);
    if (mounted) {
      _applyOrgToForm(created);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Created "${created.name}" — add its details below and save',
          ),
        ),
      );
    }
  }

  Future<void> _deleteOrganization(Organization org) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${org.name}?'),
        content: const Text(
          'This removes the organization and its PDF branding. '
          'Documents and clients are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<OrganizationProvider>();
    await provider.deleteOrganization(org.id);
    if (mounted) {
      _applyOrgToForm(provider.organization);
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Organization deleted')));
    }
  }

  // ── Branding presets ──

  Future<void> _exportOrgPreset() async {
    final org = context.read<OrganizationProvider>().organization;
    try {
      final backupService = BackupService(context.read<StorageService>());
      if (kIsWeb) {
        final safeName = org.name
            .replaceAll(RegExp(r'[^\w\s-]'), '')
            .trim()
            .replaceAll(' ', '_');
        downloadTextFile(
          backupService.exportOrgPreset(org),
          'quoteflow_org_${safeName.isEmpty ? 'preset' : safeName}.json',
        );
        return;
      }
      final path = await backupService.saveOrgPresetToFile(org);
      if (mounted) {
        await Share.shareXFiles([
          XFile(path),
        ], text: 'QuoteFlow branding preset — ${org.name}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Preset export failed: $e')));
      }
    }
  }

  Future<void> _importOrgPreset() async {
    final backupService = BackupService(context.read<StorageService>());
    String? json;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: kIsWeb,
    );
    if (result == null) return;
    final picked = result.files.single;
    if (picked.bytes != null) {
      json = utf8.decode(picked.bytes!);
    } else if (picked.path != null) {
      json = await File(result.files.single.path!).readAsString();
    }

    if (json == null || json.trim().isEmpty || !mounted) return;
    final preset = backupService.parseOrgPreset(json);
    if (preset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not a valid branding preset')),
      );
      return;
    }

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Apply "${preset.name}" preset?'),
        content: const Text(
          'Apply its branding and PDF style to the current organization, '
          'or create a brand-new organization from it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'apply'),
            child: const Text('Apply to current'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'create'),
            child: const Text('Create new org'),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;

    final provider = context.read<OrganizationProvider>();
    if (action == 'apply') {
      await provider.updateOrganization(
        name: preset.name,
        shortName: preset.shortName,
        logoUrl: preset.logoUrl,
        emails: preset.emails,
        website: preset.website,
        registration: preset.registration,
        tin: preset.tin,
        vatNumber: preset.vatNumber,
        duns: preset.duns,
        praz: preset.praz,
        phone: preset.phone,
        address: preset.address,
        city: preset.city,
        state: preset.state,
        postalCode: preset.postalCode,
        country: preset.country,
        currency: preset.currency,
        defaultTaxRate: preset.defaultTaxRate,
        defaultPaymentTerms: preset.defaultPaymentTerms,
        paymentInstructions: preset.paymentInstructions,
        bankAccountName: preset.bankAccountName,
        bankName: preset.bankName,
        bankBranch: preset.bankBranch,
        bankAccountNumber: preset.bankAccountNumber,
        bankIban: preset.bankIban,
        bankSwift: preset.bankSwift,
        pdfTheme: preset.pdfTheme,
        logoPosition: preset.logoPosition,
        tableStyle: preset.tableStyle,
        logoSize: preset.logoSize,
      );
    } else {
      await provider.createOrganizationFromPreset(preset);
    }
    if (mounted) {
      _applyOrgToForm(provider.organization);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'apply'
                ? 'Preset applied to ${provider.organization.name}'
                : 'Created ${provider.organization.name} from preset',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 500;
    final pad = isNarrow ? 16.0 : 24.0;
    final org = context.watch<OrganizationProvider>().organization;
    final hasLogo = org.logoUrl != null && org.logoUrl!.isNotEmpty;

    // When the active organization changes elsewhere (e.g. the app-bar
    // switcher) while this screen is alive, reload the form fields for it.
    if (_loaded && org.id != _loadedOrgId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _applyOrgToForm(context.read<OrganizationProvider>().organization);
          });
        }
      });
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ReferenceHeading(
              eyebrow: 'Settings',
              title: 'Workspace',
              subtitle:
                  'Manage your organisation, branding and document style.\nChanges apply across documents, clients and reports.',
            ),
            const SizedBox(height: 18),
            // ── Organizations ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('Organisations'),
                    const SizedBox(height: 4),
                    Text(
                      'Switch between companies. Each has its own branding, bank '
                      'details and PDF style. Documents and clients stay linked to their organisation; the overview can show all companies.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildOrganizationsSection(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Branding ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('Branding'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Logo preview / tap to upload
                        GestureDetector(
                          onTap: _pickLogo,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                            ),
                            child: hasLogo
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _buildLogoImage(org.logoUrl!),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_a_photo_outlined,
                                        size: 20,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Add logo',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tap the image to upload your company logo.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Works with camera, gallery, or files on all platforms.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  height: 1.5,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _pickLogo,
                                icon: const Icon(
                                  Icons.image_outlined,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Change logo',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                              if (hasLogo) ...[
                                const SizedBox(height: 6),
                                TextButton.icon(
                                  onPressed: _removeLogo,
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 14,
                                  ),
                                  label: const Text(
                                    'Remove logo',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red.shade400,
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ── PDF Theme ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('PDF Style'),
                    const SizedBox(height: 6),
                    Text(
                      'Choose the default style for your quotations, invoices and credit notes.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPdfThemeSelector(),
                    const SizedBox(height: 16),
                    _buildPdfStyleControls(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Identity ──
            _sectionHeader('Identity'),
            const SizedBox(height: 16),
            _fieldRow('Company name *', _nameCtrl),
            _fieldRow('Short name', _shortNameCtrl),
            _fieldRow('Emails (comma-separated)', _emailsCtrl),
            _fieldRow('Website', _websiteCtrl),
            _fieldRow('Registration №', _regCtrl),
            _fieldRow('TIN', _tinCtrl),
            _fieldRow('VAT №', _vatCtrl),
            _fieldRow('DUNS', _dunsCtrl),
            _fieldRow('PRAZ', _prazCtrl),
            _fieldRow('Phone', _phoneCtrl),
            _fieldRow('Street address', _addressCtrl, maxLines: 2),
            _fieldRow('City', _cityCtrl),
            _fieldRow('State / Province', _stateCtrl),
            _fieldRow('Postal / ZIP code', _postalCtrl),
            _fieldRow('Country', _countryCtrl),

            const SizedBox(height: 24),

            // ── Tax (organisation business configuration) ──
            _sectionHeader('Tax'),
            const SizedBox(height: 4),
            Text(
              'Your business tax profile. ZIMRA FDMS device taxes are '
              'configured separately under ZIMRA FDMS.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tax enabled'),
              subtitle: Text(
                _taxEnabled
                    ? 'Invoices charge tax using the treatments below.'
                    : 'Not registered for tax — invoices carry no tax.',
                style: const TextStyle(fontSize: 12.5),
              ),
              value: _taxEnabled,
              onChanged: (v) => setState(() => _taxEnabled = v),
            ),
            if (_taxEnabled) ...[
              const SizedBox(height: 8),
              _buildTaxDefinitionsEditor(),
            ],
            const SizedBox(height: 24),

            // ── Document defaults ──
            _sectionHeader('Document defaults'),
            const SizedBox(height: 16),
            _currencyDropdown(),
            _fieldRow(
              'Legacy default tax rate (%) — unused when per-line tax is set',
              _taxRateCtrl,
            ),
            _fieldRow(
              'Default payment terms (days, e.g. 14 = net 14)',
              _termsCtrl,
            ),
            _fieldRow(
              'Payment instructions (footer)',
              _paymentCtrl,
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            // ── Bank details ──
            _sectionHeader('Bank details'),
            const SizedBox(height: 4),
            Text(
              'Shown on invoices so your clients know where to pay.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _fieldRow('Account holder name', _bankAcctNameCtrl),
            _fieldRow('Bank name', _bankNameCtrl),
            _fieldRow('Branch', _bankBranchCtrl),
            _fieldRow('Account number', _bankAcctNumCtrl),
            _fieldRow('IBAN', _ibanCtrl),
            _fieldRow('SWIFT / BIC code', _swiftCtrl),

            const SizedBox(height: 24),

            // ── Save ──
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                ),
                child: const Text('Save changes'),
              ),
            ),
            const SizedBox(height: 16),

            // ── Appearance ──
            _sectionHeader('Appearance'),
            const SizedBox(height: 12),
            _buildDarkModeToggle(),
            const SizedBox(height: 24),

            // ── Security ──
            _sectionHeader('Security'),
            const SizedBox(height: 12),
            _buildAppLockSection(),
            const SizedBox(height: 24),

            // ── Backup & Restore ──
            _sectionHeader('Backup & Restore'),
            const SizedBox(height: 12),
            _buildBackupRestoreSection(),
            const SizedBox(height: 16),

            // ── Tax Compliance ──
            _sectionHeader('Tax Compliance'),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ZimraSettingsScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ZIMRA FDMS',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Fiscal device registration, day management, receipt history',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── About ──
            _sectionHeader('About'),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AboutScreen()));
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          'Q',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'About QuoteFlow',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'v1.0.1 · Company info, team & details',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Logo helpers ──

  Widget _buildLogoImage(String logoUrl) {
    // Try to decode as base64 data URL
    if (logoUrl.startsWith('data:image')) {
      final base64Data = logoUrl.split(',').last;
      try {
        final bytes = base64Decode(base64Data);
        return Image.memory(bytes, fit: BoxFit.cover, width: 80, height: 80);
      } catch (_) {
        // fall through
      }
    }
    // Try file path
    if (!kIsWeb && (logoUrl.startsWith('/') || logoUrl.contains(':\\'))) {
      return Image.file(
        File(logoUrl),
        fit: BoxFit.cover,
        width: 80,
        height: 80,
      );
    }
    // Network image
    return Image.network(
      logoUrl,
      fit: BoxFit.cover,
      width: 80,
      height: 80,
      errorBuilder: (_, __, ___) => Icon(
        Icons.broken_image,
        size: 24,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();

    // Show a bottom sheet letting user choose source
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Upload Logo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: const Text('Pick a file'),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (picked == null) return;

      String logoData;

      if (kIsWeb) {
        // On web, read as bytes and encode to base64
        final bytes = await picked.readAsBytes();
        logoData = 'data:image/png;base64,${base64Encode(bytes)}';
      } else {
        // On mobile/desktop, store file path (or encode to base64 for portability)
        final file = File(picked.path);
        final bytes = await file.readAsBytes();
        logoData = 'data:image/png;base64,${base64Encode(bytes)}';
      }

      if (mounted) {
        context.read<OrganizationProvider>().updateOrganization(
          logoUrl: logoData,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Logo updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  void _removeLogo() {
    context.read<OrganizationProvider>().updateOrganization(logoUrl: '');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Logo removed')));
  }

  // ── PDF Theme Selector ──

  Widget _buildPdfThemeSelector() => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 650 ? 3 : 2;
      final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: pdfThemeIds.map((id) {
          final selected = _selectedTheme == id;
          return Semantics(
            selected: selected,
            button: true,
            label: '${pdfThemeLabel(id)} PDF style',
            child: InkWell(
              onTap: () => setState(() => _selectedTheme = id),
              borderRadius: BorderRadius.circular(13),
              child: Container(
                width: width,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withValues(alpha: .5),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ReferenceDocumentPreview(
                          style: id,
                          accent: _themePreviewColor(id),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pdfThemeLabel(id),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                pdfThemeDescription(id),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9,
                                  height: 1.3,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (selected)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Icon(
                          Icons.check_circle,
                          size: 15,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    },
  );

  // ── PDF Style Controls (logo position, table style, live preview) ──

  Widget _buildPdfStyleControls() {
    final scheme = Theme.of(context).colorScheme;
    final org = context.watch<OrganizationProvider>().organization;
    final accent = _themePreviewColor(_selectedTheme);
    final right = _logoPosition == 'right';
    final effStyle = effectiveTableStyle(
      _selectedTheme,
      _tableStyle == 'auto' ? null : _tableStyle,
    );

    Widget logoBox() {
      final size = _logoSize.clamp(20.0, 80.0);
      final url = org.logoUrl;
      if (url != null && url.startsWith('data:image')) {
        try {
          final bytes = base64Decode(url.split(',').last);
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(bytes, height: size, fit: BoxFit.contain),
          );
        } catch (_) {}
      }
      final initial = (org.shortName ?? org.name).trim();
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            initial.isEmpty ? 'Q' : initial[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      );
    }

    Widget titleCol() => Column(
      crossAxisAlignment: right
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          'QUOTATION',
          style: TextStyle(
            fontSize: 8,
            letterSpacing: 2,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Q-2026-0001',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ],
    );

    final headerBg = (effStyle == 'striped' || effStyle == 'bordered')
        ? accent
        : null;
    final zebraBg = effStyle == 'striped'
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.6)
        : null;
    final borderColor = scheme.outlineVariant;
    final headerLine = headerBg == null && effStyle != 'minimal';

    Widget miniRow(
      List<String> cells, {
      Color? bg,
      Color? text,
      bool bold = false,
      bool header = false,
      bool underline = true,
    }) {
      return Container(
        decoration: BoxDecoration(
          color: bg,
          border: effStyle == 'bordered'
              ? Border.all(color: borderColor, width: 0.5)
              : Border(
                  bottom: underline
                      ? BorderSide(color: borderColor, width: 0.5)
                      : BorderSide.none,
                ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: header ? 5 : 4),
        child: Row(
          children: [
            for (final (i, c) in cells.indexed)
              Expanded(
                flex: i == 1 ? 3 : 1,
                child: Text(
                  c,
                  textAlign: (i == 0 || i == 1)
                      ? TextAlign.left
                      : TextAlign.right,
                  style: TextStyle(
                    fontSize: header ? 7 : 9,
                    color: text ?? scheme.onSurface,
                    fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: header ? 1 : 0,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live header + table preview on a paper-like card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2C2C2E)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.3
                      : 0.06,
                ),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (right) ...[
                    Expanded(child: titleCol()),
                    const SizedBox(width: 12),
                    logoBox(),
                  ] else ...[
                    logoBox(),
                    const SizedBox(width: 12),
                    Expanded(child: titleCol()),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              miniRow(
                ['#', 'DESCRIPTION', 'QTY', 'PRICE', 'AMOUNT'],
                bg: headerBg,
                text: headerBg != null ? Colors.white : scheme.onSurfaceVariant,
                bold: true,
                header: true,
                underline: headerLine,
              ),
              miniRow([
                '1',
                'Consulting services',
                '1',
                '\$1,200.00',
                '\$1,200.00',
              ], bg: zebraBg),
              miniRow(['2', 'Travel expenses', '2', '\$25.00', '\$50.00']),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 9,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '\$1,250.00',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Logo position
        Text(
          'Logo position',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'left',
              label: Text('Left'),
              icon: Icon(Icons.format_align_left, size: 16),
            ),
            ButtonSegment(
              value: 'right',
              label: Text('Right'),
              icon: Icon(Icons.format_align_right, size: 16),
            ),
          ],
          selected: {_logoPosition},
          onSelectionChanged: (s) => setState(() => _logoPosition = s.first),
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(height: 16),

        // Table style
        Text(
          'Table style',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tableStyleIds.map((id) {
            return ChoiceChip(
              label: Text(tableStyleLabel(id)),
              selected: _tableStyle == id,
              onSelected: (_) => setState(() => _tableStyle = id),
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Text(
          tableStyleDescription(_tableStyle),
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),

        // Logo size
        Text(
          'Logo size',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _logoSize,
                min: 20,
                max: 80,
                divisions: 12,
                label: '${_logoSize.round()}pt',
                onChanged: (v) => setState(() => _logoSize = v),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 38,
              child: Text(
                '${_logoSize.round()}pt',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _themePreviewColor(String id) {
    switch (id) {
      case 'modern':
        return const Color(0xFF1e293b);
      case 'minimal':
        return const Color(0xFF64748b);
      case 'bold':
        return const Color(0xFFdc2626);
      case 'elegant':
        return const Color(0xFF1f3a57);
      case 'boutique':
      case 'editorial':
      case 'ledger':
        return const Color(0xFF292929);
      case 'contractor':
        return const Color(0xFFFF8900);
      case 'studio':
        return const Color(0xFFEC6033);
      case 'fresh':
        return const Color(0xFF0d9488);
      default:
        return const Color(0xFFf97316); // classic / orange
    }
  }

  // ── Currency dropdown ──

  Widget _currencyDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Currency',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _currencyCtrl.text.isEmpty
                ? 'USD'
                : _currencyCtrl.text.toUpperCase(),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            items: kCurrencies.map((c) {
              return DropdownMenuItem(
                value: c['code'],
                child: Text('${c['symbol']}  ${c['code']}  —  ${c['name']}'),
              );
            }).toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _currencyCtrl.text = v;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  // ── Existing helpers ──

  Widget _sectionHeader(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );
  }

  Widget _fieldRow(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dark Mode Toggle ──

  Widget _buildDarkModeToggle() {
    final settings = context.watch<AppSettingsProvider>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            settings.darkMode ? Icons.dark_mode : Icons.light_mode,
            color: settings.darkMode ? AppColors.yellow : AppColors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dark Mode',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  settings.darkMode
                      ? 'Dark theme enabled'
                      : 'Light theme enabled',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: settings.darkMode,
            onChanged: (_) => settings.toggleDarkMode(),
          ),
        ],
      ),
    );
  }

  // ── App Lock ──

  Widget _buildAppLockSection() {
    final settings = context.watch<AppSettingsProvider>();
    final enabled = settings.appLockEnabled;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            secondary: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.lock_outline,
                size: 20,
                color: Colors.deepPurple.shade600,
              ),
            ),
            title: const Text(
              'App Lock',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              enabled
                  ? 'A PIN is required to open QuoteFlow'
                  : 'Lock QuoteFlow behind a PIN',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            value: enabled,
            onChanged: _onAppLockToggle,
          ),
          if (enabled) ...[
            const Divider(height: 1, thickness: 0.5),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.password, size: 20, color: AppColors.orange),
              ),
              title: const Text(
                'Change PIN',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onTap: _onChangePin,
            ),
            if (_biometricsAvailable) ...[
              const Divider(height: 1, thickness: 0.5),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                secondary: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.fingerprint,
                    size: 20,
                    color: Colors.teal.shade600,
                  ),
                ),
                title: const Text(
                  'Fingerprint / Face unlock',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  settings.appLockBiometrics
                      ? 'Unlock with your device biometrics'
                      : 'Unlock with your fingerprint or face',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                value: settings.appLockBiometrics,
                onChanged: _onBiometricToggle,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _onAppLockToggle(bool value) async {
    final settings = context.read<AppSettingsProvider>();
    if (value) {
      final pin = await _pinDialog(
        title: 'Create a PIN',
        actionLabel: 'Enable lock',
        subtitle:
            'Choose a 4–6 digit PIN. QuoteFlow will ask for it each time it opens.',
        captureNew: true,
      );
      if (pin == null || !mounted) return;
      await settings.setAppLockPin(pin);
      await settings.setAppLockEnabled(true);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('App lock enabled')));
      }
    } else {
      final result = await _pinDialog(
        title: 'Disable App Lock',
        actionLabel: 'Disable',
        subtitle: 'Enter your current PIN to disable the lock.',
        requireCurrent: true,
      );
      if (result == null || !mounted) return;
      await settings.setAppLockEnabled(false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('App lock disabled')));
      }
    }
  }

  Future<void> _onChangePin() async {
    final pin = await _pinDialog(
      title: 'Change PIN',
      actionLabel: 'Save',
      subtitle: 'First confirm your current PIN, then choose a new one.',
      requireCurrent: true,
      captureNew: true,
    );
    if (pin == null || !mounted) return;
    final settings = context.read<AppSettingsProvider>();
    await settings.setAppLockPin(pin);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PIN updated')));
    }
  }

  Future<void> _onBiometricToggle(bool value) async {
    final settings = context.read<AppSettingsProvider>();
    if (!value) {
      await settings.setAppLockBiometrics(false);
      return;
    }
    // Confirm the user can actually authenticate before enabling.
    try {
      final auth = LocalAuthentication();
      final ok = await auth.authenticate(
        localizedReason: 'Verify your fingerprint to enable biometric unlock',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Authentication failed — biometric unlock not enabled',
              ),
            ),
          );
        }
        return;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometrics are not available on this device'),
          ),
        );
      }
      return;
    }
    await settings.setAppLockBiometrics(true);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Biometric unlock enabled')));
    }
  }

  Future<bool> _biometricsSupported() async {
    if (kIsWeb) return false;
    try {
      final auth = LocalAuthentication();
      return await auth.isDeviceSupported() && await auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkBiometricsAvailability() async {
    final ok = await _biometricsSupported();
    if (mounted && ok != _biometricsAvailable) {
      setState(() => _biometricsAvailable = ok);
    }
  }

  /// Shows a dialog that creates, verifies or changes the app-lock PIN.
  /// Returns the new PIN to store on success, or null if cancelled/failed.
  Future<String?> _pinDialog({
    required String title,
    required String actionLabel,
    String? subtitle,
    bool requireCurrent = false,
    bool captureNew = false,
  }) async {
    final currentCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? errorText;
    final settings = context.read<AppSettingsProvider>();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void submit() {
            setDialogState(() => errorText = null);
            if (requireCurrent && currentCtrl.text != settings.appLockPin) {
              setDialogState(() => errorText = 'Incorrect current PIN');
              return;
            }
            if (!captureNew) {
              Navigator.of(ctx).pop('verified');
              return;
            }
            final newPin = pinCtrl.text;
            if (newPin.length < 4 || newPin.length > 6) {
              setDialogState(() => errorText = 'PIN must be 4–6 digits');
              return;
            }
            if (newPin != confirmCtrl.text) {
              setDialogState(() => errorText = "PINs don't match");
              return;
            }
            Navigator.of(ctx).pop(newPin);
          }

          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subtitle != null) ...[
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (requireCurrent) ...[
                    _pinField(currentCtrl, 'Current PIN', autofocus: true),
                    const SizedBox(height: 10),
                  ],
                  if (captureNew) ...[
                    _pinField(pinCtrl, 'New PIN (4–6 digits)'),
                    const SizedBox(height: 10),
                    _pinField(confirmCtrl, 'Confirm new PIN'),
                  ],
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        errorText!,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(onPressed: submit, child: Text(actionLabel)),
            ],
          );
        },
      ),
    );

    currentCtrl.dispose();
    pinCtrl.dispose();
    confirmCtrl.dispose();
    return result;
  }

  Widget _pinField(
    TextEditingController ctrl,
    String label, {
    bool autofocus = false,
  }) {
    return TextField(
      controller: ctrl,
      autofocus: autofocus,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }

  // ── Backup & Restore ──

  Widget _buildBackupRestoreSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Export button
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.upload_file,
                color: Colors.green.shade600,
                size: 20,
              ),
            ),
            title: const Text('Export Data'),
            subtitle: Text(
              'Save documents, clients, products & organization details to a JSON file',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: FilledButton.tonal(
              onPressed: _exportData,
              child: const Text('Export'),
            ),
          ),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          // Import button
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.download,
                color: Colors.blue.shade600,
                size: 20,
              ),
            ),
            title: const Text('Import Data'),
            subtitle: Text(
              'Restore from a previously exported backup file',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: FilledButton.tonal(
              onPressed: _importData,
              child: const Text('Import'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    try {
      final storage = context.read<StorageService>();
      final backupService = BackupService(storage);
      final json = backupService.exportJson();

      if (kIsWeb) {
        final timestamp = DateTime.now()
            .toIso8601String()
            .replaceAll(':', '-')
            .substring(0, 19);
        downloadTextFile(json, 'quoteflow_backup_$timestamp.json');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup downloaded successfully')),
          );
        }
      } else {
        final path = await backupService.saveExportToFile();
        if (mounted) {
          await Share.shareXFiles(
            [XFile(path)],
            text: 'QuoteFlow backup data',
            sharePositionOrigin: shareOrigin(context),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data exported successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _importData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: kIsWeb,
      );
      if (result == null) return;

      final picked = result.files.single;
      final json = picked.bytes != null
          ? utf8.decode(picked.bytes!)
          : await File(picked.path!).readAsString();
      final backupService = BackupService(context.read<StorageService>());
      final importResult = await backupService.importFromJson(json);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(importResult.message)));
        if (importResult.success) {
          await context.read<OrganizationProvider>().activateOrganization(
            context.read<StorageService>().getActiveOrg().id,
          );
          if (!mounted) return;
          setState(
            () => _applyOrgToForm(
              context.read<OrganizationProvider>().organization,
            ),
          );
          context.read<DocumentProvider>().refresh();
          context.read<ClientProvider>().refresh();
          context.read<ProductProvider?>()?.refresh();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Company name is required')));
      return;
    }

    final emails = _emailsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    context.read<OrganizationProvider>().updateOrganization(
      name: _nameCtrl.text,
      shortName: _shortNameCtrl.text,
      emails: emails,
      website: _websiteCtrl.text,
      registration: _regCtrl.text,
      tin: _tinCtrl.text,
      vatNumber: _vatCtrl.text,
      duns: _dunsCtrl.text,
      praz: _prazCtrl.text,
      phone: _phoneCtrl.text,
      address: _addressCtrl.text,
      city: _cityCtrl.text,
      state: _stateCtrl.text,
      postalCode: _postalCtrl.text,
      country: _countryCtrl.text,
      currency: _currencyCtrl.text,
      defaultTaxRate: double.tryParse(_taxRateCtrl.text) ?? 0,
      defaultPaymentTerms: int.tryParse(_termsCtrl.text),
      taxEnabled: _taxEnabled,
      defaultTaxTreatment: _defaultTreatment,
      bankAccountName: _bankAcctNameCtrl.text,
      bankName: _bankNameCtrl.text,
      bankBranch: _bankBranchCtrl.text,
      bankAccountNumber: _bankAcctNumCtrl.text,
      bankIban: _ibanCtrl.text,
      bankSwift: _swiftCtrl.text,
      paymentInstructions: _paymentCtrl.text,
      pdfTheme: _selectedTheme,
      logoPosition: _logoPosition,
      tableStyle: _tableStyle == 'auto' ? null : _tableStyle,
      logoSize: _logoSize,
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Settings saved')));
  }
}

/// Dialog to add a tax treatment definition to the organisation.
class _TaxDefinitionDialog extends StatefulWidget {
  const _TaxDefinitionDialog();

  @override
  State<_TaxDefinitionDialog> createState() => _TaxDefinitionDialogState();
}

class _TaxDefinitionDialogState extends State<_TaxDefinitionDialog> {
  final _nameCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  TaxTreatment _type = TaxTreatment.standard;
  bool _isDefault = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsRate = _type == TaxTreatment.standard;
    return AlertDialog(
      title: const Text('Add tax treatment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name *'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<TaxTreatment>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Treatment'),
            items: TaxTreatment.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          if (needsRate) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _rateCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Rate (%) *',
                hintText: 'e.g. 15.5',
              ),
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Default for new lines'),
            value: _isDefault,
            onChanged: (v) => setState(() => _isDefault = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            final rate = double.tryParse(_rateCtrl.text);
            if (needsRate && rate == null) return;
            Navigator.pop(
              context,
              TaxDefinition(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                name: name,
                rate: needsRate ? rate : null,
                type: _type,
                isDefault: _isDefault,
                source: TaxSource.manual,
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
