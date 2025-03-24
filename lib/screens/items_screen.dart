import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/item.dart';
import '../services/crdt_service.dart';

class ItemsScreen extends StatefulWidget {
  final String webId;
  final String accessToken;
  final Map<String, dynamic> decodedToken;

  const ItemsScreen({
    super.key,
    required this.webId,
    required this.accessToken,
    required this.decodedToken,
  });

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final _textController = TextEditingController();
  bool _isAdding = false;
  late CrdtService _crdtService;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _initializeCrdtService();
    _syncFromPod();
  }

  void _initializeCrdtService() {
    final box = Hive.box<Item>('items');
    _crdtService = CrdtService(
      box: box,
      webId: widget.webId,
      podUrl: widget.decodedToken['iss'], // Use the issuer URL as the pod URL
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Items'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon:
                _isSyncing
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.sync),
            onPressed: _isSyncing ? null : _syncFromPod,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isAdding)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'Enter item text',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (value) async {
                        if (value.isNotEmpty) {
                          await _crdtService.addItem(value);
                          _textController.clear();
                          setState(() => _isAdding = false);
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _textController.clear();
                      setState(() => _isAdding = false);
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Hive.box<Item>('items').listenable(),
              builder: (context, box, _) {
                final items =
                    box.values.where((item) => !item.isDeleted).toList();
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(item.text),
                      subtitle: Text(
                        'Created: ${item.createdAt.toString()}\n'
                        'Last modified by: ${item.lastModifiedBy}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _crdtService.deleteItem(item.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton:
          !_isAdding
              ? FloatingActionButton(
                onPressed: () => setState(() => _isAdding = true),
                child: const Icon(Icons.add),
              )
              : null,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _crdtService.dispose();
    super.dispose();
  }
}
