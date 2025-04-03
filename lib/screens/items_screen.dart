import 'package:flutter/material.dart';
import 'package:solid_auth/solid_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/item.dart';
import '../services/crdt_service.dart';
import '../screens/login_page.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:solid_auth/solid_auth.dart';
import '../services/logger_service.dart';

class ItemsScreen extends StatefulWidget {
  final String? webId;
  final String? accessToken;
  final Map<String, dynamic>? decodedToken;
  final Map<String, dynamic>? authData;

  const ItemsScreen({
    super.key,
    this.webId,
    this.accessToken,
    this.decodedToken,
    this.authData,
  });

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final _textController = TextEditingController();
  late CrdtService _crdtService;
  bool _isSyncing = false;
  bool get _isConnectedToSolid => widget.webId != null;
  final _logger = LoggerService();

  @override
  void initState() {
    super.initState();
    _initializeCrdtService();
    if (_isConnectedToSolid) {
      _syncFromPod();
    }
  }

  void _initializeCrdtService() {
    final box = Hive.box<Item>('items');
    _crdtService = CrdtService(
      box: box,
      webId: widget.webId ?? 'local',
      podUrl: widget.decodedToken?['iss'],
      accessToken: widget.accessToken,
    );
  }

  Future<void> _syncFromPod() async {
    setState(() => _isSyncing = true);
    try {
      await _crdtService.syncFromPod();
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  void _navigateToLogin() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );

    if (result != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => ItemsScreen(
                webId: result['webId'],
                accessToken: result['accessToken'],
                decodedToken: result['decodedToken'],
              ),
        ),
      );
    }
  }

  Future<void> _disconnectFromPod() async {
    try {
      await logout(widget.authData!['logoutUrl']);
      // Reset the screen without Solid credentials
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ItemsScreen()),
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Error disconnecting from pod', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorDisconnecting),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          l10n.appTitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon:
                _isConnectedToSolid
                    ? (_isSyncing
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.cloud_off))
                    : const Icon(Icons.cloud_upload),
            onPressed:
                _isSyncing
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
              onSubmitted: (value) async {
                if (value.isNotEmpty) {
                  await _crdtService.addItem(value);
                  _textController.clear();
                }
              },
            ),
          ),

          // Tasks list
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Hive.box<Item>('items').listenable(),
              builder: (context, box, _) {
                final items =
                    box.values.where((item) => !item.isDeleted).toList()
                      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
                        onDismissed: (_) => _crdtService.deleteItem(item.id),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: colorScheme.outline.withOpacity(0.2),
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
    _crdtService.dispose();
    super.dispose();
  }
}
