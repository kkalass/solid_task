import 'package:flutter/material.dart';
import 'package:solid_task/l10n/app_localizations.dart';
import 'package:solid_task/ext/solid/auth/models/auth_result.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_auth_operations.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_auth_state.dart';

import '../bootstrap/service_locator.dart';
import '../core/utils/date_formatter.dart';
import '../models/item.dart';
import '../screens/login_page.dart';

import '../services/repository/item_repository.dart';
import '../ext/solid/sync/sync_manager.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final _textController = TextEditingController();
  final _authState = sl<SolidAuthState>();
  final _authOperations = sl<SolidAuthOperations>();
  final _repository = sl<ItemRepository>();
  final _syncManager = sl<SyncManager>();

  bool get _isConnectedToSolid => _authState.isAuthenticated;

  @override
  void initState() {
    super.initState();

    // Listen to sync status updates for UI refresh only
    _syncManager.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {}); // Refresh UI when sync status changes
      }
    });
  }

  void _navigateToLogin() async {
    final result = await Navigator.push<AuthResult>(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );

    if (result != null && result.isSuccess && mounted) {
      setState(() {}); // Refresh UI
    }
  }

  Future<void> _disconnectFromPod() async {
    try {
      await _authOperations.logout();

      if (mounted) {
        setState(() {}); // Refresh UI to show disconnected state
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorDisconnecting),
          ),
        );
      }
    }
  }

  Future<void> _addItem(String text) async {
    if (text.isEmpty) return;
    // FIXME KK - the local fallback seems wrong to me. Actually, this is probably connected to correct implementation of CRDT. I believe, that we should have a device specific identifier here - neither local nor webId seem to be correct.
    await _repository.createItem(
      text,
      _authState.currentUser?.webId ?? 'local',
    );
    _textController.clear();
  }

  Future<void> _deleteItem(String id) async {
    await _repository.deleteItem(id, _authState.currentUser?.webId ?? 'local');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // Get sync status information from SyncManager
    final isSyncing = _syncManager.isSyncing;
    final hasError = _syncManager.hasError;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          l10n.appTitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (hasError)
            IconButton(
              icon: Icon(Icons.error_outline, color: colorScheme.error),
              onPressed: () => _syncManager.startSynchronization(),
              tooltip: l10n.syncError,
            ),
          IconButton(
            icon: _isConnectedToSolid
                ? (isSyncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_done))
                : const Icon(Icons.cloud_upload),
            onPressed: isSyncing
                ? null
                : (_isConnectedToSolid ? _disconnectFromPod : _navigateToLogin),
            tooltip: _isConnectedToSolid
                ? l10n.disconnectFromPod
                : l10n.connectToPod,
          ),
        ],
      ),
      body: Column(
        children: [
          // Add task input field
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: l10n.addTaskHint,
                filled: true,
                fillColor: colorScheme.surface,
                prefixIcon: const Icon(Icons.add_task),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
              ),
              onSubmitted: _addItem,
            ),
          ),

          // Tasks list
          Expanded(
            child: StreamBuilder<List<Item>>(
              stream: _repository.watchActiveItems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: colorScheme.error),
                    ),
                  );
                }

                final items = snapshot.data ?? [];

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.task_outlined,
                          size: 64,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noTasks,
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Dismissible(
                        key: Key(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: Icon(
                            Icons.delete_outline,
                            color: colorScheme.error,
                          ),
                        ),
                        onDismissed: (_) => _deleteItem(item.id),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          child: ListTile(
                            title: Text(
                              item.text,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'Created ${DateFormatter.formatRelativeTime(item.createdAt, context)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.outline,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
