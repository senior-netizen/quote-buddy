import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/organization_provider.dart';
import '../providers/document_provider.dart';
import '../widgets/app_logo.dart';
import 'dashboard_screen.dart';
import 'documents/document_list_screen.dart';
import 'clients/client_list_screen.dart';
import 'products_screen.dart';
import 'credits_screen.dart';
import 'business_account_screen.dart';
import '../providers/business_account_provider.dart';
import 'documents/document_detail_screen.dart';
import 'settings/organization_settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final _screens = const [
    DashboardScreen(),
    DocumentListScreen(),
    ClientListScreen(),
    ProductsScreen(),
    OrganizationSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final orgProvider = context.watch<OrganizationProvider>();
    final org = orgProvider.organization;
    final useNavigationRail = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        actions: [
          if (context.watch<BusinessAccountProvider?>() != null)
            IconButton(
              tooltip: 'Business account & verification',
              icon: const Icon(Icons.verified_user_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const BusinessAccountScreen(),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Business activity and credits',
            icon: Badge(
              isLabelVisible: context
                  .watch<DocumentProvider>()
                  .overdueDocuments
                  .isNotEmpty,
              smallSize: 7,
              child: const Icon(
                Icons.notifications_outlined,
                color: Color(0xFF606779),
              ),
            ),
            onPressed: () => _showActivity(context),
          ),
          PopupMenuButton<String>(
            tooltip: 'Organizations',
            onSelected: (id) => orgProvider.switchOrganization(id),
            itemBuilder: (_) => [
              for (final company in orgProvider.organizations)
                PopupMenuItem(value: company.id, child: Text(company.name)),
            ],
            child: Padding(
              padding: const EdgeInsets.only(right: 18, left: 8),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF293244),
                child: Text(
                  org.name.trim().isEmpty
                      ? 'Q'
                      : org.name.trim()[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
        title: PopupMenuButton<String>(
          onSelected: (id) {
            if (id != orgProvider.activeOrgId) {
              orgProvider.switchOrganization(id);
            }
          },
          tooltip: 'Switch organization',
          position: PopupMenuPosition.under,
          itemBuilder: (ctx) => [
            for (final o in orgProvider.organizations)
              PopupMenuItem(
                value: o.id,
                child: Row(
                  children: [
                    Icon(
                      o.id == orgProvider.activeOrgId
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 16,
                      color: o.id == orgProvider.activeOrgId
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        o.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            const PopupMenuDivider(),
            PopupMenuItem(
              enabled: false,
              child: Text(
                'Manage organizations in Settings',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 30),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QuoteFlow',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                        letterSpacing: -.3,
                      ),
                    ),
                    Text(
                      org.shortName ?? org.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: useNavigationRail
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (i) =>
                      setState(() => _currentIndex = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.square_outlined),
                      selectedIcon: Icon(Icons.square_rounded),
                      label: Text('Overview'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.description_outlined),
                      selectedIcon: Icon(Icons.description_rounded),
                      label: Text('Documents'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline_rounded),
                      selectedIcon: Icon(Icons.person_rounded),
                      label: Text('Clients'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2),
                      label: Text('Inventory'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings_rounded),
                      label: Text('Settings'),
                    ),
                  ],
                ),
                VerticalDivider(width: 1, color: scheme.outlineVariant),
                Expanded(
                  child: IndexedStack(index: _currentIndex, children: _screens),
                ),
              ],
            )
          : IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: useNavigationRail
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: .06),
                      blurRadius: 24,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: NavigationBar(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (i) =>
                        setState(() => _currentIndex = i),
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: 'Overview',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.description_outlined),
                        selectedIcon: Icon(Icons.description_rounded),
                        label: 'Documents',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.people_outline_rounded),
                        selectedIcon: Icon(Icons.people_rounded),
                        label: 'Clients',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.inventory_2_outlined),
                        selectedIcon: Icon(Icons.inventory_2),
                        label: 'Inventory',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings_rounded),
                        label: 'Settings',
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  void _showActivity(BuildContext context) {
    final documents = context.read<DocumentProvider>().overdueDocuments;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Fiscalisation credits'),
                subtitle: const Text('View your wallet or top up with Paynow'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheet);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreditsScreen()),
                  );
                },
              ),
              const Divider(),
              Text(
                'Business activity',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (documents.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No overdue documents.'),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final document in documents)
                      ListTile(
                        leading: const Icon(Icons.schedule, color: Colors.red),
                        title: Text(document.docNumber),
                        subtitle: const Text('Payment overdue'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(sheet);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DocumentDetailScreen(documentId: document.id),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
