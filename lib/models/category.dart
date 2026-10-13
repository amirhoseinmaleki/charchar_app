import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/widgets.dart' show IconData;

enum CategoryId { name, family, city, country, animal, fruit, color, food }

extension CategoryIdX on CategoryId {
  String get wireId => name;

  static CategoryId fromWire(String id) {
    return CategoryId.values.firstWhere((c) => c.wireId == id, orElse: () => CategoryId.name);
  }

  String get labelFa {
    switch (this) {
      case CategoryId.name:
        return 'اسم';
      case CategoryId.family:
        return 'فامیل';
      case CategoryId.city:
        return 'شهر';
      case CategoryId.country:
        return 'کشور';
      case CategoryId.animal:
        return 'حیوان';
      case CategoryId.fruit:
        return 'میوه';
      case CategoryId.color:
        return 'رنگ';
      case CategoryId.food:
        return 'غذا';
    }
  }

  IconData get icon {
    switch (this) {
      case CategoryId.name:
        return LucideIcons.user;
      case CategoryId.family:
        return LucideIcons.users;
      case CategoryId.city:
        return LucideIcons.building2;
      case CategoryId.country:
        return LucideIcons.globe;
      case CategoryId.animal:
        return LucideIcons.cat;
      case CategoryId.fruit:
        return LucideIcons.apple;
      case CategoryId.color:
        return LucideIcons.palette;
      case CategoryId.food:
        return LucideIcons.utensils;
    }
  }
}
