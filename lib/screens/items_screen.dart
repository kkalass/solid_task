import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/item.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Items'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          final item = Item(text: value);
                          Hive.box<Item>('items').add(item);
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
                return ListView.builder(
                  itemCount: box.length,
                  itemBuilder: (context, index) {
                    final item = box.getAt(index) as Item;
                    return ListTile(
                      title: Text(item.text),
                      subtitle: Text(item.createdAt.toString()),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => box.deleteAt(index),
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
    super.dispose();
  }
}
