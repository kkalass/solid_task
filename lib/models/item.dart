import 'package:hive/hive.dart';
import 'dart:math' as math;
import 'package:uuid/uuid.dart';

part 'item.g.dart';

@HiveType(typeId: 0)
class Item extends HiveObject {
  // Static UUID generator instance to be reused
  static final Uuid _uuid = Uuid();

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
    // Generate a UUID v4 for guaranteed uniqueness
    id = _uuid.v4();
    createdAt = DateTime.now();
    vectorClock = {lastModifiedBy: 1};
    isDeleted = false;
  }

  // CRDT-specific methods
  void incrementClock(String clientId) {
    vectorClock[clientId] = (vectorClock[clientId] ?? 0) + 1;
  }

  bool isNewerThan(Item other) {
    bool hasGreaterTimestamp = false;

    // Check all our entries
    for (var entry in vectorClock.entries) {
      final otherClock = other.vectorClock[entry.key] ?? 0;
      if (entry.value > otherClock) {
        hasGreaterTimestamp = true;
      } else if (entry.value < otherClock) {
        // If any entry in the other clock is greater, we are not strictly newer
        return false;
      }
    }

    // Check for entries in other clock that we don't have
    for (var entry in other.vectorClock.entries) {
      if (!vectorClock.containsKey(entry.key) && entry.value > 0) {
        // The other item has an entry we don't have
        return false;
      }
    }

    // We are only newer if at least one timestamp is greater and none are less
    return hasGreaterTimestamp;
  }

  bool hasNewerInformation(Item other) {
    for (var entry in other.vectorClock.entries) {
      final ourValue = vectorClock[entry.key] ?? 0;
      if (entry.value > ourValue) {
        return true;
      }
    }
    return false;
  }

  void merge(Item other) {
    if (hasNewerInformation(other)) {
      text = other.text;
      isDeleted = other.isDeleted;
      lastModifiedBy = other.lastModifiedBy;
    }

    // Merge vector clocks
    for (var entry in other.vectorClock.entries) {
      vectorClock[entry.key] = math.max(
        vectorClock[entry.key] ?? 0,
        entry.value,
      );
    }
  }

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
