import * as THREE from 'three';
import type { MaterialBank } from '../materials';
import type { CatalogueEntry } from '../types';
import { bed } from './bed';
import { bookshelf } from './bookshelf';
import { Builder, type FurnitureFn } from './builder';
import { chair } from './chair';
import { coffeeTable } from './coffee_table';
import { desk } from './desk';
import { diningTable } from './dining_table';
import { floorLamp } from './floor_lamp';
import { plant } from './plant';
import { rug } from './rug';
import { sofa } from './sofa';
import { tvUnit } from './tv_unit';
import { wardrobe } from './wardrobe';

const builders: Record<string, FurnitureFn> = {
  bed,
  sofa,
  chair,
  wardrobe,
  bookshelf,
  tv_unit: tvUnit,
  desk,
  dining_table: diningTable,
  coffee_table: coffeeTable,
  rug,
  plant,
  floor_lamp: floorLamp,
};

/** A model for one catalogue entry, sized exactly to its footprint and height. */
export function buildFurniture(entry: CatalogueEntry, finish: string, bank: MaterialBank): THREE.Group {
  const b = new Builder(bank, finish, entry.width, entry.depth, entry.height);
  (builders[entry.id] ?? ((x: Builder) => x.box(x.w, x.h, x.d, 0, 0, 0, 'M')))(b);
  return b.group;
}
