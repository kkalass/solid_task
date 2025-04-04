import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/item.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:solid_auth/solid_auth.dart';
import 'package:fast_rsa/fast_rsa.dart';
import 'package:solid_task/services/logger_service.dart';

class CrdtService {
  final Box<Item> _box;
  final String _webId;
  final String? _podUrl;
  final String? _accessToken;
  final http.Client? _client;
  final KeyPair? rsaKeyPair;
  final Map<String, dynamic>? publicKeyJwk;
  final ContextLogger _logger;

  bool get _isSolidConnected => _podUrl != null && _accessToken != null;

  CrdtService.connected({
    required Box<Item> box,
    required String webId,
    required String podUrl,
    required String accessToken,
    required http.Client client,
    required this.rsaKeyPair,
    required this.publicKeyJwk,
  }) : _box = box,
       _webId = webId,
       _podUrl = podUrl,
       _accessToken = accessToken,
       _client = client,
       _logger = LoggerService().createLogger('CrdtService');

  CrdtService.unconnected({required Box<Item> box})
    : _box = box,
      _webId = 'local',
      _podUrl = null,
      _accessToken = null,
      _client = null,
      rsaKeyPair = null,
      publicKeyJwk = null,
      _logger = LoggerService().createLogger('CrdtService');

  // Add a new item
  Future<Item> addItem(String text) async {
    _logger.debug('Adding new item: $text');
    final item = Item(text: text, lastModifiedBy: _webId);
    item.incrementClock(_webId);
    await _box.put(item.id, item);
    if (_isSolidConnected) {
      await syncToPod();
    }
    return item;
  }

  // Update an existing item
  Future<void> updateItem(Item item) async {
    _logger.debug('Updating item: ${item.id}');
    item.incrementClock(_webId);
    await _box.put(item.id, item);
    if (_isSolidConnected) {
      await syncToPod();
    }
  }

  // Delete an item (soft delete)
  Future<void> deleteItem(String id) async {
    _logger.debug('Deleting item: $id');
    final item = _box.get(id);
    if (item != null) {
      item.isDeleted = true;
      item.incrementClock(_webId);
      await _box.put(id, item);
      if (_isSolidConnected) {
        await syncToPod();
      }
    }
  }

  // Sync with Solid pod
  Future<void> syncToPod() async {
    if (!_isSolidConnected) return;

    try {
      _logger.debug('Syncing to pod: $_podUrl');
      final items = _box.values.where((item) => !item.isDeleted).toList();
      final jsonData = items.map((item) => item.toJson()).toList();
      final dataUrl = '${_podUrl}todos.json';

      // Generate DPoP token for the request
      final dPopToken = genDpopToken(
        dataUrl,
        rsaKeyPair!,
        publicKeyJwk!,
        'PUT',
      );

      final response = await _client!.put(
        Uri.parse(dataUrl),
        headers: {
          'Accept': '*/*',
          'Authorization': 'DPoP $_accessToken',
          'Connection': 'keep-alive',
          'Content-Type': 'application/json',
          'DPoP': dPopToken,
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        _logger.error(
          'Failed to sync with pod: ${response.statusCode} file $dataUrl',
        );
        throw Exception(
          'Failed to sync with pod: ${response.statusCode} file $dataUrl',
        );
      }
      _logger.info('Successfully synced ${items.length} items to pod');
    } catch (e, stackTrace) {
      _logger.error('Error syncing with pod', e, stackTrace);
    }
  }

  // Sync from Solid pod
  Future<void> syncFromPod() async {
    if (!_isSolidConnected) return;

    try {
      _logger.debug('Syncing from pod: $_podUrl');
      final dataUrl = '${_podUrl}todos.json';

      // Generate DPoP token for the request
      final dPopToken = genDpopToken(
        dataUrl,
        rsaKeyPair!,
        publicKeyJwk!,
        'GET',
      );

      final response = await _client!.get(
        Uri.parse(dataUrl),
        headers: {
          'Accept': '*/*',
          'Authorization': 'DPoP $_accessToken',
          'Connection': 'keep-alive',
          'DPoP': dPopToken,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        final remoteItems =
            jsonData.map((json) => Item.fromJson(json)).toList();
        _logger.info('Retrieved ${remoteItems.length} items from pod');

        for (final remoteItem in remoteItems) {
          final localItem = _box.get(remoteItem.id);
          if (localItem == null) {
            _logger.debug('Adding new item from pod: ${remoteItem.id}');
            await _box.put(remoteItem.id, remoteItem);
          } else {
            _logger.debug('Merging item from pod: ${remoteItem.id}');
            localItem.merge(remoteItem);
            await _box.put(remoteItem.id, localItem);
          }
        }
      } else {
        _logger.error(
          'Failed to sync from pod: ${response.statusCode} file $dataUrl',
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Error syncing from pod', e, stackTrace);
    }
  }

  // Close the service
  void dispose() {
    _logger.debug('Disposing CrdtService');
    _client?.close();
  }

  Future<void> _checkStorageQuota() async {
    if (kIsWeb) {
      // Implement web storage quota check if needed
      // You can use window.navigator.storage.estimate()

      // FIXME: Implement web storage quota check (and call this method)
    }
  }
}
