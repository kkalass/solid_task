import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../core/service_locator.dart';
import '../models/item.dart';
import '../screens/login_page.dart';
import '../services/auth/auth_service.dart';
import '../services/repository/item_repository.dart';
import '../services/sync/sync_manager.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final _textController = TextEditingController();
  final _authService = sl<AuthService>();
  final _repository = sl<ItemRepository>();
  final _syncManager = sl<SyncManager>();

  bool get _isConnectedToSolid => _authService.isAuthenticated;

  @override
  void initState() {
    super.initState();
    // No need to manually start sync anymore, the SyncManager handles this

    // Listen to sync status updates
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
      // Auth service already has the credentials after successful login
      // SyncManager will automatically start syncing after auth changes
      _syncManager.handleAuthStateChange(_authService.isAuthenticated);
      setState(() {}); // Refresh UI
    }
  }

  Future<void> _disconnectFromPod() async {
    try {
      await _authService.logout();
      _syncManager.handleAuthStateChange(false);

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

    await _repository.createItem(text, _authService.currentWebId ?? 'local');
    _textController.clear();

    // If connected to a pod, sync the changes
    if (_isConnectedToSolid) {
      _syncManager.syncToRemote();
    }
  }

  Future<void> _deleteItem(String id) async {
    await _repository.deleteItem(id, _authService.currentWebId ?? 'local');

    // If connected to a pod, sync the changes
    if (_isConnectedToSolid) {
      _syncManager.syncToRemote();
    }
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
            icon:
                _isConnectedToSolid
                    ? (isSyncing
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.cloud_done))
                    : const Icon(Icons.cloud_upload),
            onPressed:
                isSyncing
                    ? null
                    : (_isConnectedToSolid
                        ? _disconnectFromPod
                        : _navigateToLogin),
            tooltip:
                _isConnectedToSolid
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
                              'Created ${_formatDate(item.createdAt)}',
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

  // FIXME KK - Shouldn't this method be somewhere else for proper reuse?
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    final l10n = AppLocalizations.of(context)!;

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        final minutes = difference.inMinutes;
        return l10n.createdAgo(l10n.minutes(minutes));
      }
      final hours = difference.inHours;
      return l10n.createdAgo(l10n.hours(hours));
    } else if (difference.inDays == 1) {
      return l10n.yesterday;
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return l10n.createdAgo(l10n.days(days));
    } else {
      return DateFormat.yMd(
        Localizations.localeOf(context).languageCode,
      ).format(date);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    // SyncManager is managed by ServiceLocator, no need to dispose it here
    super.dispose();
  }
}
