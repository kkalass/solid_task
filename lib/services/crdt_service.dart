import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/item.dart';

class CrdtService {
  final Box<Item> _box;
  final String _webId;
  final String _podUrl;
  final http.Client _client;
  final String _accessToken;

  CrdtService({
    required Box<Item> box,
    required String webId,
    required String podUrl,
    required String accessToken,
    http.Client? client,
  }) : _box = box,
       _webId = webId,
       _podUrl = podUrl,
       _accessToken = accessToken,
       _client = client ?? http.Client();

  // Add a new item
  Future<Item> addItem(String text) async {
    final item = Item(text: text, lastModifiedBy: _webId);
    item.incrementClock(_webId);
    await _box.put(item.id, item);
    await _syncToPod();
    return item;
  }

  // Update an existing item
  Future<void> updateItem(Item item) async {
    item.incrementClock(_webId);
    await _box.put(item.id, item);
    await _syncToPod();
  }

  // Delete an item (soft delete)
  Future<void> deleteItem(String id) async {
    final item = _box.get(id);
    if (item != null) {
      item.isDeleted = true;
      item.incrementClock(_webId);
      await _box.put(id, item);
      await _syncToPod();
    }
  }

  // Sync with Solid pod
  Future<void> _syncToPod() async {
    try {
      final items = _box.values.where((item) => !item.isDeleted).toList();
      final jsonData = items.map((item) => item.toJson()).toList();

      final response = await _client.put(
        Uri.parse('$_podUrl/todos.json'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to sync with pod: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing with pod: $e');
      // In a real app, you might want to queue failed syncs for retry
    }
  }

  // Sync from Solid pod
  Future<void> syncFromPod() async {
    try {
      final response = await _client.get(
        Uri.parse('$_podUrl/todos.json'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        final remoteItems =
            jsonData.map((json) => Item.fromJson(json)).toList();

        // Merge remote items with local items
        for (final remoteItem in remoteItems) {
          final localItem = _box.get(remoteItem.id);
          if (localItem == null) {
            await _box.put(remoteItem.id, remoteItem);
          } else {
            localItem.merge(remoteItem);
            await _box.put(remoteItem.id, localItem);
          }
        }
      }
    } catch (e) {
      print('Error syncing from pod: $e');
    }
  }

  // Close the service
  void dispose() {
    _client.close();
  }
}
