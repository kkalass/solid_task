import 'package:hive/hive.dart';
import 'dart:math' as math;

part 'item.g.dart';

@HiveType(typeId: 0)
class Item extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String text;

  @HiveField(2)
  late DateTime createdAt;

  @HiveField(3)
  late Map<String, int> vectorClock;

  @HiveField(4)
  late bool isDeleted;

  @HiveField(5)
  late String lastModifiedBy;

  Item({required this.text, required this.lastModifiedBy}) {
    id = DateTime.now().millisecondsSinceEpoch.toString();
    createdAt = DateTime.now();
    vectorClock = {lastModifiedBy: 1};
    isDeleted = false;
  }

  // CRDT-specific methods
  void incrementClock(String clientId) {
    vectorClock[clientId] = (vectorClock[clientId] ?? 0) + 1;
  }

  bool isNewerThan(Item other) {
    bool isNewer = false;
    for (var entry in vectorClock.entries) {
      final otherClock = other.vectorClock[entry.key] ?? 0;
      if (entry.value > otherClock) {
        isNewer = true;
      } else if (entry.value < otherClock) {
        return false;
      }
    }
    return isNewer;
  }

  void merge(Item other) {
    // Merge vector clocks
    for (var entry in other.vectorClock.entries) {
      vectorClock[entry.key] = math.max(
        vectorClock[entry.key] ?? 0,
        entry.value,
      );
    }

    // If the other item is newer, update our fields
    if (other.isNewerThan(this)) {
      text = other.text;
      isDeleted = other.isDeleted;
      lastModifiedBy = other.lastModifiedBy;
    }
  }

  // FIXME KK - is this really correct CRDT implementation? I would
  // have expected to store the list of commands, and replay them if needed
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'vectorClock': vectorClock,
      'isDeleted': isDeleted,
      'lastModifiedBy': lastModifiedBy,
    };
  }

  factory Item.fromJson(Map<String, dynamic> json) {
    final item = Item(
      text: json['text'],
      lastModifiedBy: json['lastModifiedBy'],
    );
    item.id = json['id'];
    item.createdAt = DateTime.parse(json['createdAt']);
    item.vectorClock = Map<String, int>.from(json['vectorClock']);
    item.isDeleted = json['isDeleted'];
    return item;
  }
}
