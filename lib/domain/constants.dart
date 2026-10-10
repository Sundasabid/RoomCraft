// Tunable rules in one place. All lengths are metres.

/// Touching edges are not an overlap.
const double eps = 0.001;

/// Position snapping step.
const double grid = 0.05;

/// Pull an item flush to a wall within this gap.
const double wallSnap = 0.10;

/// Align to another item's edge or centre line within this distance.
const double alignSnap = 0.03;

/// Depth of the clear zone in front of a door.
const double doorKeepOutDepth = 0.90;

/// Movement score grid cell.
const double scoreCell = 0.10;

/// 60 cm minimum passage.
const double walkerRadiusMin = 0.30;

/// 90 cm comfortable passage.
const double walkerRadiusComfort = 0.45;

/// How close a walkable cell must be to count an item as reachable.
const double accessDistance = 0.60;

/// Search grid for a new item's starting spot.
const double freeSpotStep = 0.10;

/// How far inside the room a door's entry point lies.
const double doorEntryDepth = 0.40;

/// How far from the entry point a passable cell may be.
const double doorEntrySearch = 0.30;

const int maxItems = 40;
const int maxNameLength = 40;
const int historyLimit = 50;

const double minRoomSide = 2.0;
const double maxRoomSide = 12.0;
const double minWallHeight = 2.2;
const double maxWallHeight = 4.0;
const double defaultWallHeight = 2.6;

/// Openings keep this distance from wall ends and from each other.
const double openingMargin = 0.10;

const double doorWidth = 0.9;
const double doorHeight = 2.1;
const double windowWidth = 1.2;
const double windowHeight = 1.2;
const double windowSill = 0.9;
const double minDoorWidth = 0.7;
const double maxDoorWidth = 1.2;
const double minWindowWidth = 0.6;
const double maxWindowWidth = 2.0;
