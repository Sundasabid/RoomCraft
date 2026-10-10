// Shapes of the data Flutter sends. Flutter owns the truth; this layer only draws it.

export type Vec = [number, number];

export interface RoomNode {
  id: string;
  type: 'room';
  corners: Vec[];
  wallHeight: number;
  floorFinish: string;
  wallFinish: string;
  lighting?: string;
}

export interface OpeningNode {
  id: string;
  type: 'opening';
  kind: 'door' | 'window';
  wallIndex: number;
  offset: number;
  width: number;
  height: number;
  sillHeight: number;
}

export interface ItemNode {
  id: string;
  type: 'item';
  catalogueId: string;
  x: number;
  z: number;
  rotation: number;
  finish: string;
  locked: boolean;
  visible?: boolean;
}

export type SceneNode = RoomNode | OpeningNode | ItemNode;

export interface SceneData {
  rootId: string;
  nodes: Record<string, SceneNode>;
}

export interface CatalogueEntry {
  id: string;
  width: number;
  depth: number;
  height: number;
  floorOnly: boolean;
}

export interface FinishDef {
  id: string;
  hex: string;
  roughness: number;
}

export interface Palette {
  background: string;
  primary: string;
  warning: string;
}
