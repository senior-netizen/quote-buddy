import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/business_account_provider.dart';
import '../providers/organization_provider.dart';
import '../widgets/reference_design.dart';
import 'credits_screen.dart';

class BusinessAccountScreen extends StatefulWidget {
  const BusinessAccountScreen({super.key});
  @override
  State<BusinessAccountScreen> createState() => _BusinessAccountScreenState();
}

class _BusinessAccountScreenState extends State<BusinessAccountScreen>
    with WidgetsBindingObserver {
  final _loginForm = GlobalKey<FormState>(),
      _businessForm = GlobalKey<FormState>();
  final _email = TextEditingController(),
      _password = TextEditingController(),
      _code = TextEditingController();
  final _name = TextEditingController(),
      _tin = TextEditingController(),
      _contact = TextEditingController(),
      _phone = TextEditingController(),
      _address = TextEditingController(),
      _devices = TextEditingController(),
      _evidence = TextEditingController();
  bool _register = true,
      _reset = false,
      _resetSent = false,
      _seeded = false,
      _foreground = true;
  Timer? _timer;
  String? _localError;
  String? _orgId;
  String? _hydratedApp;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshQuietly(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_seeded) {
      final org = context.read<OrganizationProvider>().organization;
      _orgId = org.id;
      _name.text = org.name.toLowerCase() == 'your company' ? '' : org.name;
      _tin.text = org.tin ?? '';
      _phone.text = org.phone ?? '';
      _address.text = [
        org.address,
        org.city,
      ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
      _email.text = org.emails.isEmpty ? '' : org.emails.first;
      _seeded = true;
    }
  }

  Future<void> _refreshQuietly() async {
    if (!mounted ||
        !_foreground ||
        !(ModalRoute.of(context)?.isCurrent ?? true))
      return;
    final account = context.read<BusinessAccountProvider>();
    if (account.signedIn && !account.busy) {
      try {
        await account.refreshStatus();
      } catch (_) {
        /* Manual refresh shows connection errors. */
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _refreshQuietly();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in [
      _email,
      _password,
      _code,
      _name,
      _tin,
      _contact,
      _phone,
      _address,
      _devices,
      _evidence,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboard,
    bool secret = false,
    int lines = 1,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: secret,
      autocorrect: !secret,
      enableSuggestions: !secret,
      maxLines: secret ? 1 : lines,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label),
      validator:
          validator ??
          (value) =>
              (value?.trim().isEmpty ?? true) ? 'This field is required' : null,
    ),
  );
  Widget _card(List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
  void _verifyEmail(BusinessAccountProvider account) {
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
      setState(() => _localError = 'Enter the six-digit code from your email.');
      return;
    }
    setState(() => _localError = null);
    account.verify(_code.text);
  }

  Future<void> _submit(BusinessAccountProvider account) async {
    if (!_businessForm.currentState!.validate()) return;
    final devices = _devices.text
        .split(RegExp(r'[\s,]+'))
        .where((s) => s.isNotEmpty)
        .map(int.tryParse)
        .toList();
    if (devices.isEmpty ||
        devices.any((d) => d == null || d <= 0) ||
        devices.toSet().length != devices.length ||
        devices.length > 20) {
      setState(
        () => _localError =
            'Enter up to 20 unique positive device IDs, separated by commas.',
      );
      return;
    }
    setState(() => _localError = null);
    final success = await account.submit({
      'businessName': _name.text.trim(),
      'tin': _tin.text.trim(),
      'contactName': _contact.text.trim(),
      'phone': _phone.text.trim(),
      'address': _address.text.trim(),
      'devices': devices,
      'evidence': _evidence.text.trim(),
    });
    if (success && mounted) {
      final org = context.read<OrganizationProvider>();
      if (org.activeOrgId == _orgId) {
        await org.updateOrganization(
          name: _name.text,
          tin: _tin.text,
          phone: _phone.text,
          address: _address.text,
          emails: [account.account!['email'] as String],
        );
      }
    }
  }

  Future<void> _openWallet(
    BusinessAccountProvider account,
    Map<String, dynamic> application,
  ) async {
    final org = context.read<OrganizationProvider>();
    final tin = application['tin'] as String;
    if (!await account.connectWallet(tin) || !mounted) return;
    final matches = org.organizations.where((o) => o.tin == tin);
    if (matches.isNotEmpty) {
      await org.activateOrganization(matches.first.id);
    } else {
      await org.createOrganization(application['business_name'] as String);
      final profile = application['profile'] as Map? ?? {};
      await org.updateOrganization(
        tin: tin,
        emails: [account.account!['email'] as String],
        phone: profile['phone'] as String?,
        address: profile['address'] as String?,
      );
    }
    if (mounted)
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const CreditsScreen()),
      );
  }

  Future<void> _upload(BusinessAccountProvider account, String id) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        withData: false,
        withReadStream: true,
      );
      if (result == null || !mounted) return;
      final file = result.files.single;
      if (file.size > 1048576) {
        setState(() => _localError = 'Choose a PDF, PNG or JPEG up to 1 MB.');
        return;
      }
      setState(() => _localError = null);
      final bytes = BytesBuilder(copy: false);
      if (file.readStream != null) {
        await for (final chunk in file.readStream!) {
          if (bytes.length + chunk.length > 1048576)
            throw StateError('File too large');
          bytes.add(chunk);
        }
      } else if (file.bytes != null) {
        bytes.add(file.bytes!);
      } else {
        throw StateError('File could not be read');
      }
      if (!mounted) return;
      await account.upload(id, file.name, base64Encode(bytes.takeBytes()));
    } catch (_) {
      if (mounted)
        setState(
          () => _localError = 'Could not read that document. Please try again.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<BusinessAccountProvider>();
    final colors = Theme.of(context).colorScheme;
    final apps = account.applications
        .where((a) => a['tin'] == _tin.text.trim())
        .toList();
    final application = apps.isEmpty ? null : apps.first;
    if (application != null && _hydratedApp != application['id']) {
      _hydratedApp = application['id'] as String;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final profile = application['profile'] as Map? ?? {};
        setState(() {
          if (_contact.text.isEmpty)
            _contact.text = profile['contactName'] as String? ?? '';
          if (_phone.text.isEmpty)
            _phone.text = profile['phone'] as String? ?? '';
          if (_address.text.isEmpty)
            _address.text = profile['address'] as String? ?? '';
          if (_devices.text.isEmpty)
            _devices.text = (application['device_ids'] as List? ?? []).join(
              ', ',
            );
          if (_evidence.text.isEmpty)
            _evidence.text = application['evidence'] as String? ?? '';
        });
      });
    }
    final state = application?['state'] as String?;
    final canEdit =
        application == null ||
        state == 'changes_requested' ||
        state == 'rejected';
    return Scaffold(
      appBar: referenceAppBar(
        context,
        'Business account',
        subtitle: 'REGISTRATION & VERIFICATION',
        actions: [
          if (account.signedIn)
            IconButton(
              tooltip: 'Refresh application status',
              onPressed: account.busy ? null : () => account.checkStatus(),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const ReferenceNotice(
                'Your quotations and ordinary invoices remain available while business verification is pending. Fiscal access requires administrator approval.',
              ),
              const SizedBox(height: 18),
              if (account.busy || account.restoring)
                const LinearProgressIndicator(),
              if (account.error != null || _localError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _localError ?? account.error!,
                    style: TextStyle(color: colors.error),
                  ),
                ),
              if (account.notice != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    account.notice!,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
              if (!account.signedIn)
                _card([
                  Text(
                    _reset
                        ? 'Reset your password'
                        : _register
                        ? 'Create your business account'
                        : 'Welcome back',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _reset
                        ? 'We will email a reset code if your account exists.'
                        : 'Use an email you can access. We verify your contact before reviewing business ownership.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  Form(
                    key: _loginForm,
                    child: Column(
                      children: [
                        _field(
                          'Email address',
                          _email,
                          keyboard: TextInputType.emailAddress,
                          validator: (v) =>
                              RegExp(
                                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                              ).hasMatch(v?.trim() ?? '')
                              ? null
                              : 'Enter a valid email',
                        ),
                        if (!_reset || _resetSent)
                          _field(
                            _reset ? 'New password' : 'Password',
                            _password,
                            secret: true,
                            validator: (v) =>
                                (v?.length ?? 0) >= 16 &&
                                    (v?.length ?? 0) <= 1024
                                ? null
                                : 'Use at least 16 characters',
                          ),
                        if (_resetSent)
                          _field(
                            'Reset code',
                            _code,
                            keyboard: TextInputType.number,
                            validator: (v) =>
                                RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '')
                                ? null
                                : 'Enter the six-digit code',
                          ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: account.busy
                        ? null
                        : () async {
                            if (!_loginForm.currentState!.validate()) return;
                            if (_reset) {
                              if (!_resetSent) {
                                if (await account.requestReset(_email.text) &&
                                    mounted)
                                  setState(() => _resetSent = true);
                              } else if (await account.resetPassword(
                                    _email.text,
                                    _code.text,
                                    _password.text,
                                  ) &&
                                  mounted) {
                                _password.clear();
                                _code.clear();
                                setState(() {
                                  _reset = false;
                                  _resetSent = false;
                                  _register = false;
                                });
                              }
                            } else if (await account.signIn(
                                  _email.text,
                                  _password.text,
                                  register: _register,
                                ) &&
                                mounted) {
                              _password.clear();
                            }
                          },
                    child: Text(
                      _reset
                          ? (_resetSent ? 'Reset password' : 'Send reset code')
                          : _register
                          ? 'Create account'
                          : 'Sign in',
                    ),
                  ),
                  TextButton(
                    onPressed: account.busy
                        ? null
                        : () => setState(() {
                            _register = !_register;
                            _reset = false;
                            _resetSent = false;
                            _password.clear();
                          }),
                    child: Text(
                      _register
                          ? 'Already registered? Sign in'
                          : 'New business? Create an account',
                    ),
                  ),
                  if (!_register && !_reset)
                    TextButton(
                      onPressed: () => setState(() {
                        _reset = true;
                        _resetSent = false;
                        _password.clear();
                      }),
                      child: const Text('Forgot password?'),
                    ),
                ]),
              if (account.signedIn) ...[
                _card([
                  Text(
                    account.account!['email'] as String,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    account.emailVerified
                        ? 'Email verified'
                        : 'Confirm your email to submit an application',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  if (!account.emailVerified) ...[
                    const SizedBox(height: 16),
                    _field(
                      'Six-digit email code',
                      _code,
                      keyboard: TextInputType.number,
                      validator: (_) => null,
                    ),
                    FilledButton(
                      onPressed: account.busy
                          ? null
                          : () => _verifyEmail(account),
                      child: const Text('Verify email'),
                    ),
                    TextButton(
                      onPressed: account.busy ? null : () => account.resend(),
                      child: const Text('Resend code'),
                    ),
                  ],
                ]),
                const SizedBox(height: 18),
                if (account.emailVerified) ...[
                  if (application == null)
                    ExpansionTile(
                      title: const Text('Link an existing verified business'),
                      subtitle: const Text(
                        'Use the registered email and your current business access code',
                      ),
                      children: [
                        _field(
                          'Existing business TIN',
                          _tin,
                          keyboard: TextInputType.number,
                          validator: (_) => null,
                        ),
                        _field(
                          'Existing business access code',
                          _code,
                          secret: true,
                          validator: (_) => null,
                        ),
                        OutlinedButton(
                          onPressed: account.busy
                              ? null
                              : () async {
                                  if (await account.linkExisting(
                                        _tin.text,
                                        _code.text,
                                      ) &&
                                      mounted)
                                    _code.clear();
                                },
                          child: const Text('Link existing business'),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  if (application != null)
                    _card([
                      Row(
                        children: [
                          Icon(
                            state == 'approved'
                                ? Icons.verified_outlined
                                : Icons.hourglass_top,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(switch (state) {
                              'approved' => 'Business approved',
                              'rejected' => 'Application not approved',
                              'changes_requested' => 'More information needed',
                              _ => 'Under review',
                            }, style: Theme.of(context).textTheme.titleLarge),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Business TIN: ${application['tin']}'),
                      if ((application['public_message'] as String? ?? '')
                          .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(application['public_message'] as String),
                        ),
                      if (state == 'pending')
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Attach ownership evidence below. The QuoteFlow team will review your business identity and fiscal-device assignment. Check back here for updates.',
                          ),
                        ),
                      if (state == 'pending' ||
                          state == 'changes_requested') ...[
                        const SizedBox(height: 14),
                        for (final file
                            in (application['files'] as List? ?? []))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.description_outlined),
                            title: Text((file as Map)['name'] as String),
                            subtitle: const Text('Uploaded securely'),
                          ),
                        OutlinedButton.icon(
                          onPressed:
                              account.busy ||
                                  (application['files'] as List? ?? [])
                                          .length >=
                                      5
                              ? null
                              : () => _upload(
                                  account,
                                  application['id'] as String,
                                ),
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Upload ownership document'),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'PDF, PNG or JPEG · up to 1 MB each · up to five files',
                        ),
                      ],
                      if (state == 'approved') ...[
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: account.busy
                              ? null
                              : () => _openWallet(account, application),
                          child: const Text('Connect wallet & view credits'),
                        ),
                      ],
                    ]),
                  if (canEdit) ...[
                    const SizedBox(height: 18),
                    _card([
                      Text(
                        state == 'changes_requested'
                            ? 'Update your application'
                            : 'Business verification',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Form(
                        key: _businessForm,
                        child: Column(
                          children: [
                            _field('Registered business name', _name),
                            _field(
                              'Business TIN',
                              _tin,
                              keyboard: TextInputType.number,
                              validator: (v) =>
                                  RegExp(
                                    r'^[1-9]\d{9}$',
                                  ).hasMatch(v?.trim() ?? '')
                                  ? null
                                  : 'Enter a valid ten-digit TIN',
                            ),
                            _field('Contact person', _contact),
                            _field(
                              'Mobile number',
                              _phone,
                              keyboard: TextInputType.phone,
                            ),
                            _field('Business address', _address, lines: 2),
                            _field(
                              'Fiscal device IDs',
                              _devices,
                              keyboard: TextInputType.text,
                            ),
                            _field(
                              'Ownership evidence / explanation',
                              _evidence,
                              lines: 3,
                              validator: (v) => (v?.trim().length ?? 0) >= 8
                                  ? null
                                  : 'Explain the ownership evidence you will attach',
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        'Submit the details above, then attach your registration or device-ownership documents. Email confirmation alone does not approve fiscal access.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: account.busy ? null : () => _submit(account),
                        child: Text(
                          state == 'changes_requested'
                              ? 'Resubmit for review'
                              : 'Submit for verification',
                        ),
                      ),
                    ]),
                  ],
                  if (apps.isEmpty && account.applications.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _card([
                      Text(
                        'Your submitted businesses',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final app in account.applications)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(app['business_name'] as String),
                          subtitle: Text('${app['tin']} · ${app['state']}'),
                          onTap: () => setState(() {
                            _tin.text = app['tin'] as String;
                            _name.text = app['business_name'] as String;
                            _devices.text = (app['device_ids'] as List).join(
                              ', ',
                            );
                            final profile = app['profile'] as Map? ?? {};
                            _contact.text =
                                profile['contactName'] as String? ?? '';
                            _phone.text = profile['phone'] as String? ?? '';
                            _address.text = profile['address'] as String? ?? '';
                          }),
                        ),
                    ]),
                  ],
                ],
                const SizedBox(height: 18),
                TextButton(
                  onPressed: account.busy ? null : () => account.signOut(),
                  child: const Text('Sign out of business account'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
