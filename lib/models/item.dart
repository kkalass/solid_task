import 'package:hive/hive.dart';

part 'item.g.dart';

@HiveType(typeId: 0)
class Item extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String text;

  @HiveField(2)
  late DateTime createdAt;

  Item({
    required this.text,
  }) {
    id = DateTime.now().millisecondsSinceEpoch.toString();
    createdAt = DateTime.now();
  }
}
