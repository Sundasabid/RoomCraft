/// Every user-facing sentence in the app. Widgets never hold their own text.
abstract final class S {
  // Brand
  static const appName = 'RoomCraft';

  // Onboarding
  static const skip = 'Skip';
  static const next = 'Next';
  static const getStarted = 'Get started';
  static const onboardDesignTitle = 'Design your room';
  static const onboardDesignBody =
      'Pick a shape, set the size and drop in furniture. '
      'Everything snaps neatly into place.';
  static const onboard3dTitle = 'See it in 3D';
  static const onboard3dBody =
      'Walk around your room in 3D. Ask AI for layouts '
      'that keep every path clear.';
  static const onboardLiveTitle = 'Share it live';
  static const onboardLiveBody =
      'Send a 6-letter code. Friends watch your room change '
      'as you design, on their own phone.';
  static String pageOf(int n, int of) => 'Page $n of $of';

  // Bottom navigation
  static const tabRooms = 'Rooms';
  static const tabLive = 'Watch live';
  static const tabSettings = 'Settings';

  // Watch live tab
  static const liveTitle = 'Watch live';
  static const liveHero =
      'See someone else design their room, live, on your phone.';
  static const liveCodeLabel = 'Enter their 6-letter code';
  static const howItWorks = 'How it works';
  static const liveStep1 = 'Your friend opens a room and taps Share live.';
  static const liveStep2 = 'They send you the 6-letter code.';
  static const liveStep3 =
      'Type it above. You see every change as they make it, '
      'but you cannot change anything.';
  static const liveOwnRoom =
      'Want to share your own room? Open it and tap Share live at the top.';

  // Share sheet steps
  static const shareStep1 = 'Tap Start sharing to get a 6-letter code.';
  static const shareStep2 = 'Send the code to a friend.';
  static const shareStep3 = 'They open Watch live in RoomCraft and type it.';

  // Settings
  static const settingsTitle = 'Settings';
  static const sectionLook = 'Look and feel';
  static const sectionMeasure = 'Measurements';
  static const sectionHelp = 'Help';
  static const sectionAbout = 'About';
  static const unitsTitle = 'Units';
  static const metres = 'Metres';
  static const feet = 'Feet';
  static const hapticsTitle = 'Vibration';
  static const hapticsBody = 'A small tap when items snap, add or delete';
  static const replayTour = 'Show the welcome tour';
  static const howLiveWorks = 'How live viewing works';
  static String versionLabel(String v) => 'Version $v';
  static const privacyNote =
      'No account needed. Your rooms are saved on this phone '
      'and backed up privately.';

  // Projects
  static const projectsTitle = 'Your rooms';
  static const newRoom = 'New room';
  static const rename = 'Rename';
  static const duplicate = 'Duplicate';
  static const delete = 'Delete';
  static const renameRoom = 'Rename room';
  static const save = 'Save';
  static const cancel = 'Cancel';
  static const roomDeleted = 'Room deleted';
  static const undo = 'Undo';
  static const redo = 'Redo';
  static const projectsEmptyTitle = 'No rooms yet';
  static const projectsEmptyBody =
      'Make your first room and see it come to life in 3D.';
  static const offlineList =
      "You're offline. Showing rooms saved on this device.";
  static const cloudListFailed = 'Showing rooms saved on this device';
  static const copySuffix = ' copy';
  static const more = 'More';
  static String projectSubtitle(String edited, int items) =>
      'Edited $edited, $items ${items == 1 ? 'item' : 'items'}';

  // Time wording
  static const justNow = 'just now';
  static const yesterday = 'yesterday';
  static String minAgo(int n) => '$n min ago';
  static String hoursAgo(int n) => '$n h ago';

  // Merging
  static const mergedChanges = 'Changes from another phone were added.';
  static const mergedKeptMine =
      'Changes from another phone were added. '
      "Where you both changed the same thing, this phone's version was kept.";

  // Sync states
  static const synced = 'Saved';
  static const pendingSync = 'Waiting to sync';
  static const localOnly = 'Saved on this device only';

  // Setup
  static const setupTitle = 'New room';
  static const templateBedroom = 'Bedroom';
  static const templateLiving = 'Living room';
  static const templateStudio = 'Studio';
  static const templateCustom = 'Custom';
  static const shapeRectangle = 'Rectangle';
  static const shapeL = 'L-shape';
  static const width = 'Width';
  static const length = 'Length';
  static const notchWidth = 'Notch width';
  static const notchLength = 'Notch length';
  static const wallHeight = 'Wall height';
  static const openingsTitle = 'Doors and windows';
  static const addDoor = 'Add door';
  static const addWindow = 'Add window';
  static const roomName = 'Room name';
  static const startDesigning = 'Start designing';
  static const addDoorHint = 'Add a door so movement checks can work';
  static const windowRemoved = 'Window removed: the wall is too short';
  static const doorRemoved = 'Door removed: the wall is too short';
  static const door = 'Door';
  static const window = 'Window';
  static const decrease = 'Decrease';
  static const topWall = 'top wall';
  static const rightWall = 'right wall';
  static const bottomWall = 'bottom wall';
  static const leftWall = 'left wall';
  static const notchWall = 'notch wall';
  static String openingRow(String kind, String wall) => '$kind, $wall';
  static String atOffset(String v) => 'at $v';
  static const customName = 'My room';
  static const roomPreview =
      'Room preview. Tap a wall to choose where new doors and windows go.';
  static const increase = 'Increase';

  // Editor
  static const toolAdd = 'Add';
  static const toolFinish = 'Finish';
  static const toolAi = 'AI layout';
  static const share = 'Share';
  static const back = 'Back';
  static const emptyRoomHint = 'Tap Add to place your first piece';
  static const rotate = 'Rotate';
  static const copy = 'Copy';
  static const lock = 'Lock';
  static const unlock = 'Unlock';
  static const narrower = 'Narrower';
  static const wider = 'Wider';
  static const view3d = '3D';
  static const view2d = '2D';
  static const viewBoth = 'Both';
  static const camera = 'Camera';
  static const recentre = 'Show the whole room';
  static const hint3d =
      'Drag furniture to move it. Drag empty space to look around.';
  static const cameraCorner = 'Corner';
  static const cameraTop = 'Top';
  static const cameraEye = 'Eye level';
  static const showMe = 'Show me';
  static const itemDeleted = 'Item deleted';
  static String layoutApplied(int from, int to) =>
      'Layout applied. Movement $from to $to';
  static const offlineEditor =
      "You're offline. Changes are saved on this device.";
  static const roomFullToast = 'The room is full (40 items)';
  static const view3dLabel = '3D room view. Use the plan to move furniture.';
  static const dragToResize = 'Drag to resize';
  static String selectionLabel(String name, String size) => '$name, $size';
  static const switchUnit = 'Switch between metres and feet';
  static const closePanel = 'Close';

  // Plan items for screen readers
  static String itemSpoken(
    String name,
    String w,
    String d,
    String unit,
    String place,
  ) => '$name, $w by $d $unit, $place';
  static const metresWord = 'metres';
  static const feetWord = 'feet';
  static const isLocked = 'locked';
  static const hasProblem = 'has a problem';
  static const placeMiddle = 'middle of the room';
  static const placeLeft = 'left side of the room';
  static const placeRight = 'right side of the room';
  static const placeTop = 'top side of the room';
  static const placeBottom = 'bottom side of the room';
  static String placeCorner(String v, String h) => '$v $h corner of the room';
  static const top = 'top';
  static const bottom = 'bottom';
  static const left = 'left';
  static const right = 'right';
  static const moveLeft = 'Move left';
  static const moveRight = 'Move right';
  static const moveUp = 'Move up';
  static const moveDown = 'Move down';

  // Catalogue
  static const addFurniture = 'Add furniture';
  static const catAll = 'All';
  static const catSleep = 'Sleep';
  static const catSit = 'Sit';
  static const catStore = 'Store';
  static const catWork = 'Work';
  static const catDecor = 'Decor';
  static const roomFull = 'The room is full (40 items)';

  // Furniture names
  static const itemBed = 'Bed';
  static const itemSofa = 'Sofa';
  static const itemChair = 'Chair';
  static const itemWardrobe = 'Wardrobe';
  static const itemBookshelf = 'Bookshelf';
  static const itemTvUnit = 'TV unit';
  static const itemDesk = 'Desk';
  static const itemDiningTable = 'Dining table';
  static const itemCoffeeTable = 'Coffee table';
  static const itemRug = 'Rug';
  static const itemPlant = 'Plant';
  static const itemFloorLamp = 'Floor lamp';

  // Finish names
  static const finishOak = 'Oak';
  static const finishWalnut = 'Walnut';
  static const finishWhiteLacquer = 'White lacquer';
  static const finishSageFabric = 'Sage fabric';
  static const finishBeigeLinen = 'Beige linen';
  static const finishLightOak = 'Light oak';
  static const finishWarmWhite = 'Warm white';
  static const finishSand = 'Sand';
  static const finishSage = 'Sage';

  // Lighting
  static const targetLight = 'Light';
  static const lightingTitle = 'Lighting';
  static const lightDay = 'Daylight';
  static const lightGolden = 'Golden hour';
  static const lightEvening = 'Evening';
  static const lightSoft = 'Soft';

  // Finishes
  static const targetItem = 'Item';
  static const targetFloor = 'Floor';
  static const targetWalls = 'Walls';
  static String finishFor(String name) => 'Finish for $name';
  static const floorFinish = 'Floor finish';
  static const finishPickItem =
      'To change a piece of furniture, tap it on the plan first.';
  static const wallFinish = 'Wall finish';

  // Warnings
  static String overlaps(String a, String b) => '$a overlaps $b';
  static String outside(String a) => '$a is outside the room';
  static String blocksDoor(String a) => '$a blocks the door';
  static String andMore(String first, int n) => '$first and $n more';

  // Share
  static const shareLive = 'Share live';
  static const shareBody =
      'Anyone with the code can watch this room update live. '
      'They can look, but not change anything.';
  static const startSharing = 'Start sharing';
  static const copyCode = 'Copy code';
  static const codeCopied = 'Code copied';
  static String shareText(String code) =>
      'Watch my room live in RoomCraft: code $code';
  static String watching(int n) => n == 0
      ? 'Nobody watching yet'
      : n == 1
      ? '1 person watching'
      : '$n people watching';
  static const stopSharing = 'Stop sharing';
  static const stopSharingTitle = 'Stop sharing?';
  static const stopSharingBody = 'Viewers will lose the room.';
  static const keepSharing = 'Keep sharing';
  static const offlineShare = 'Connect to the internet to share';
  static const offlineJoin = 'Connect to the internet to join';
  static const offlineAi = 'Connect to the internet to use AI layout';
  static const live = 'LIVE';

  // Join
  static const joinRoom = 'Join room';
  static const noRoom = 'No live room with that code';
  static const badLetters = "That code has letters we don't use";

  // Viewer
  static String updatedAt(String time) => 'Updated $time';
  static const reconnecting = 'Reconnecting';
  static const ownerStopped = 'The owner stopped sharing';
  static const backToStart = 'Back to start';

  // AI ask
  static const aiTitle = 'AI layout';
  static const whatIUnderstood = 'What I understood';
  static const movementNow = 'Movement now';
  static const goalMovement = 'Improve movement';
  static const goalDoors = 'Clear the door paths';
  static const goalHint = 'Or describe what you want';
  static const suggestLayouts = 'Suggest layouts';
  static const addFurnitureFirst = 'Add some furniture first';
  static String doors(int n) => n == 1 ? '1 door' : '$n doors';
  static String windows(int n) => n == 1 ? '1 window' : '$n windows';
  static String items(int n) => n == 1 ? '1 item' : '$n items';
  static String locked(int n) => '$n locked';

  static const aiIntro =
      'Get up to 3 new layouts of this room. Nothing changes until you Apply.';
  static const aiStep1 = 'Pick a goal, or say it in your own words.';
  static const aiStep2 = 'Compare up to 3 new layouts of this room.';
  static const aiStep3 =
      'Preview one, then Apply or Discard. Nothing changes before.';
  static const aiWhatWant = 'What would you like?';
  static const goalOpen = 'More open space';
  static const goalBedAway = 'Bed away from the door';
  static const goalCosy = 'Cosy seating corner';
  static const goalWork = 'Space to work';
  static const goalTypeHint = 'Or type your own idea';
  static String aiRoomLine(String size, String doors, String items) =>
      '$size · $doors · $items';
  static String movementOf(int score) => 'Movement $score/100';

  // AI working
  static const stageReading = 'Reading your room';
  static const stageAsking = 'Asking for layouts';
  static const stageChecking = 'Checking each layout';

  // AI results
  static String option(String letter) => 'Option $letter';
  static String itemsMoved(int n) => n == 1 ? '1 item moved' : '$n items moved';
  static String rejected(int n, int of) =>
      '$n of $of suggestions were rejected';
  static String aiFound(int n) => n == 1
      ? 'Here is 1 new way to arrange your room'
      : 'Here are $n ways to arrange your room';
  static String aiSkipped(int n) => n == 1
      ? 'We skipped 1 idea that was not safe'
      : 'We skipped $n ideas that were not safe';
  static const previewLayout = 'Preview this layout';
  static const changeRequest = 'Change my request';
  static String draftTitle(String label, String name) =>
      name.isEmpty ? label : '$label · $name';
  static String movement(int from, int to) => 'Movement $from to $to';
  static const tryAgain = 'Try again';
  static const noneValid =
      'None of the suggestions were safe to use. Nothing was changed.';
  static const aiReady = 'Two layout suggestions are ready';
  static String aiMissing(String name) => 'Leaves out $name';
  static String aiRepeated(String name) => 'Places $name twice';
  static const aiUnknownItem = 'Mentions furniture that is not in the room';
  static const aiBadNumber = 'Gives a position that is not a number';
  static const aiBadRotation = 'Turns furniture at an angle we do not support';
  static const aiBadShape = 'Was not a complete layout';
  static const aiNoMove = 'Moves nothing';

  // AI draft
  static String previewing(String name) =>
      'Previewing $name. Nothing has changed yet.';
  static const holdToCompare = 'Hold to compare';
  static const apply = 'Apply';
  static const discard = 'Discard';
  static const fixToApply = 'Fix the highlighted items to apply';

  // AI errors
  static const aiBadRequest =
      'Something went wrong preparing your room. Nothing was changed.';
  static const aiRateLimited =
      'Too many requests right now. Try again in a minute.';
  static const aiUnavailable =
      'The AI is not available right now. Nothing was changed.';
  static const aiBadOutput =
      'The AI gave an answer we could not use. Nothing was changed.';
  static const aiTimeout = 'The AI took too long. Nothing was changed.';

  // General
  static const genericError = 'Something went wrong. Please try again.';
  static const view3dReloading = 'The 3D view had a problem. Reloading it now.';
  static const view3dUnavailable =
      "This phone can't show the 3D view. The plan still works.";
  static const setupNeededTitle = 'Setup needed';
  static const setupNeededBody =
      'This build is missing its Supabase settings. Add env.json and rebuild.';

  // Settings
  static const themeSystem = 'Match phone';
  static const themeLight = 'Light';
  static const themeDark = 'Dark';
  static const appearance = 'Appearance';
  static const shareLiveShort = 'Live';
}
