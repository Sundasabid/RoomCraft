import '../../core/strings.dart';

enum Category { sleep, sit, store, work, decor }

class CatalogueItem {
  const CatalogueItem({
    required this.id,
    required this.name,
    required this.category,
    required this.width,
    required this.depth,
    required this.height,
    required this.defaultFinish,
    this.floorOnly = false,
  });

  final String id;
  final String name;
  final Category category;
  final double width;
  final double depth;
  final double height;
  final String defaultFinish;

  /// Lies on the floor under other items (the rug): skipped by overlap and
  /// door checks but must still be inside the room.
  final bool floorOnly;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'width': width,
    'depth': depth,
    'height': height,
    'defaultFinish': defaultFinish,
    'floorOnly': floorOnly,
  };
}

abstract final class Catalogue {
  static const items = <CatalogueItem>[
    CatalogueItem(
      id: 'bed',
      name: S.itemBed,
      category: Category.sleep,
      width: 1.60,
      depth: 2.00,
      height: 1.00,
      defaultFinish: 'beige_linen',
    ),
    CatalogueItem(
      id: 'sofa',
      name: S.itemSofa,
      category: Category.sit,
      width: 2.00,
      depth: 0.90,
      height: 0.85,
      defaultFinish: 'sage_fabric',
    ),
    CatalogueItem(
      id: 'chair',
      name: S.itemChair,
      category: Category.sit,
      width: 0.50,
      depth: 0.50,
      height: 0.90,
      defaultFinish: 'oak',
    ),
    CatalogueItem(
      id: 'wardrobe',
      name: S.itemWardrobe,
      category: Category.store,
      width: 1.20,
      depth: 0.60,
      height: 2.00,
      defaultFinish: 'walnut',
    ),
    CatalogueItem(
      id: 'bookshelf',
      name: S.itemBookshelf,
      category: Category.store,
      width: 0.80,
      depth: 0.30,
      height: 1.80,
      defaultFinish: 'oak',
    ),
    CatalogueItem(
      id: 'tv_unit',
      name: S.itemTvUnit,
      category: Category.store,
      width: 1.50,
      depth: 0.40,
      height: 0.50,
      defaultFinish: 'white_lacquer',
    ),
    CatalogueItem(
      id: 'desk',
      name: S.itemDesk,
      category: Category.work,
      width: 1.40,
      depth: 0.70,
      height: 0.75,
      defaultFinish: 'oak',
    ),
    CatalogueItem(
      id: 'dining_table',
      name: S.itemDiningTable,
      category: Category.work,
      width: 1.60,
      depth: 0.90,
      height: 0.75,
      defaultFinish: 'walnut',
    ),
    CatalogueItem(
      id: 'coffee_table',
      name: S.itemCoffeeTable,
      category: Category.work,
      width: 1.00,
      depth: 0.50,
      height: 0.45,
      defaultFinish: 'oak',
    ),
    CatalogueItem(
      id: 'rug',
      name: S.itemRug,
      category: Category.decor,
      width: 2.00,
      depth: 1.40,
      height: 0.02,
      defaultFinish: 'beige_linen',
      floorOnly: true,
    ),
    CatalogueItem(
      id: 'plant',
      name: S.itemPlant,
      category: Category.decor,
      width: 0.40,
      depth: 0.40,
      height: 1.00,
      defaultFinish: 'white_lacquer',
    ),
    CatalogueItem(
      id: 'floor_lamp',
      name: S.itemFloorLamp,
      category: Category.decor,
      width: 0.35,
      depth: 0.35,
      height: 1.60,
      defaultFinish: 'white_lacquer',
    ),
  ];

  static final Map<String, CatalogueItem> _byId = {
    for (final i in items) i.id: i,
  };

  static CatalogueItem byId(String id) =>
      _byId[id] ?? (throw ArgumentError.value(id, 'catalogueId', 'unknown'));

  static bool has(String id) => _byId.containsKey(id);
}
