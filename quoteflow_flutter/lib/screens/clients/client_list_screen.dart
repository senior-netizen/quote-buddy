import '../../widgets/customer_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../../models/client.dart';
import '../../providers/client_provider.dart';
import '../../providers/organization_provider.dart';
import '../../theme/app_theme.dart';
import 'client_detail_screen.dart';

class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key});

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 500;
    final pad = isNarrow ? 16.0 : 24.0;

    // Rebuild when the active organization changes so the scoped client
    // list updates right away.
    context.watch<OrganizationProvider>();

    return Scaffold(
      body: Consumer<ClientProvider>(
        builder: (context, clientProvider, _) {
          final clients = clientProvider.clients;

          return Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(pad, isNarrow ? 28 : 32, pad, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MANAGE',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  letterSpacing: 2,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Clients',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _addClient(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New'),
                    ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: EdgeInsets.fromLTRB(pad, 16, pad, 0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => clientProvider.setSearch(v),
                  decoration: InputDecoration(
                    hintText: 'Search clients…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),

              // Client list
              Expanded(
                child: clients.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 48,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              clientProvider.search.isNotEmpty
                                  ? 'No matching clients.'
                                  : 'No clients yet.',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (clientProvider.search.isEmpty) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => _addClient(context),
                                child: const Text('Add your first client'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.all(pad),
                        itemCount: clients.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        itemBuilder: (context, i) {
                          final client = clients[i];
                          return Slidable(
                            key: ValueKey(client.id),
                            endActionPane: ActionPane(
                              motion: const ScrollMotion(),
                              children: [
                                SlidableAction(
                                  onPressed: (_) => _deleteClient(
                                    context,
                                    client,
                                    clientProvider,
                                  ),
                                  backgroundColor: AppColors.red,
                                  foregroundColor: Colors.white,
                                  icon: Icons.delete,
                                  label: 'Delete',
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                child: Text(
                                  client.companyName.isNotEmpty
                                      ? client.companyName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              title: Text(client.companyName),
                              subtitle: Text(
                                [
                                      client.email,
                                      client.phone,
                                    ].whereType<String>().isEmpty
                                    ? 'No contact info'
                                    : [
                                        client.email,
                                        client.phone,
                                      ].whereType<String>().join(' · '),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _editClient(context, client);
                                  } else if (value == 'view') {
                                    _viewClient(context, client);
                                  } else if (value == 'delete') {
                                    _deleteClient(
                                      context,
                                      client,
                                      clientProvider,
                                    );
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'view',
                                    child: Text('View details'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      'Delete',
                                      style: TextStyle(color: AppColors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _viewClient(BuildContext context, Client client) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientDetailScreen(clientId: client.id),
      ),
    );
  }

  void _addClient(BuildContext context) {
    showCustomerForm(context);
  }

  void _editClient(BuildContext context, Client client) {
    showCustomerForm(context, customer: client);
  }

  void _deleteClient(
    BuildContext context,
    Client client,
    ClientProvider cp,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete client?'),
        content: Text('Delete "${client.companyName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await cp.deleteClient(client.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${client.companyName}"'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await cp.saveCustomer(Client.fromJson(client.toJson()));
              },
            ),
          ),
        );
      }
    }
  }
}
