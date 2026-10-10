# RoomCraft

**Design your room. See it in 3D.**

RoomCraft is a mobile room planner. You build a room, furnish it in a 3D view and a 2D plan that stay in sync, get AI layout ideas that the app checks for safety before you can use them, and share a read-only live view with someone on another phone. There are no accounts and no sign-up.

Built with Flutter, three.js and Supabase. Android first.

---

## What it does

| Requirement | How RoomCraft does it |
| --- | --- |
| **Create the room** | Rectangle or L-shape. Quick-start templates are Bedroom, Living room, Studio and Custom. Walls are 2 to 12 m and the wall height is 2.2 to 4.0 m, set with sliders or typed values; the room redraws as you change them. Doors and windows are placed by tapping a wall and dragged along it; ones that no longer fit are removed with a message. |
| **Furniture catalogue** | 12 pieces: bed, sofa, chair, wardrobe, bookshelf, TV unit, desk, dining table, coffee table, rug, plant, floor lamp. They sit in a tray with category chips (Sleep, Sit, Store, Work, Decor). Each piece is drawn from simple shapes, with no model files. A new piece lands on the **nearest free spot**, so it never starts in a warning. Up to 40 pieces per room. |
| **Move, rotate, delete** | Drag in 3D or 2D. Rotation is in 90° steps. While dragging, positions snap to a 5 cm grid, pull to walls within 10 cm and line up with other pieces within 3 cm, with live guides and distance-to-wall labels. A floating action bar offers Rotate, Copy, Finish, Lock and Delete; Delete can be undone from a toast. |
| **Connected 2D and 3D** | One room, two views. A drag in either view moves the piece in the other in the same frame, and selection is shared. The editor can show **3D**, **2D** or **Both**, and remembers the choice. |
| **Interactive 3D** | Orbit, zoom, select and drag in 3D; dragging a piece never moves the camera. Camera presets are Corner, Top and Eye level. Eye level picks a standing spot away from doors and furniture. Walls facing the camera fade out (cutaway). Rendering happens only when something changes, and quality steps down on slow phones. |
| **Material finishes** | Items: oak, walnut, white lacquer, sage fabric, beige linen. Floor: oak, light oak, walnut. Walls: warm white, sand, sage. Changes show instantly in both views, and each one is its own undo step. |
| **Overlap and door warnings** | Detects furniture overlapping furniture (rugs excluded), furniture outside the room (including the L-shape notch), and furniture inside a door's **0.9 m keep-out zone**. The offending pieces turn terracotta with a hatch pattern in both views, a banner names the problem ("Sofa overlaps Bed"), **Show me** zooms to it, and the warning clears once it is fixed. |
| **AI Layout Assistant** | Shows what it understood about the room, asks Gemini for layouts, **checks every suggestion with the same rules**, rejects unsafe ones with a reason, and offers up to 3 safe options. Each option shows a picture, its movement score before and after, and how many items moved. You can preview a draft over a faint copy of the real room, edit it, hold to compare, and Apply it as one undo step. A draft with a problem cannot be applied. |
| **Live sharing** | The owner starts a session and gets a 6-character code. A viewer enters it in **Watch live** and sees changes in about 1 second, with no refresh. The viewer is strictly read-only, and the database itself refuses viewer writes. Dragged pieces glide on the viewer, the owner sees how many people are watching, and stopping the session ends it for everyone. |
| **Save and recover** | Every accepted change is saved on the phone at once and uploaded to the cloud. After closing the app, the room comes back exactly: items, positions, rotations, finishes and lighting. A room lost on the phone is restored from the cloud. |
| **Undo and redo** | 50 steps. A whole drag is one step, and so is an AI apply. |
| **Units** | Metres or feet, everywhere, with one tap. |

### Optional stretch goals built

- **Lighting presets:** Daylight, Golden hour, Evening (each floor lamp casts warm light) and Soft. The lighting is saved with the room, can be undone, and is shared live.
- **Offline conflict merging:** if the cloud copy changed while this phone was editing offline, the two versions are merged item by item and field by field before uploading. Nothing is silently overwritten.

### Also included

- A three-page welcome tour, bottom navigation (Rooms, Watch live, Settings), and a Settings page with appearance (follow phone, light, dark), units, vibration and help.
- Rooms list: 2 or 3 columns with plan thumbnails and sync status. Rooms can be renamed, duplicated, or deleted with Undo.
- Offline: editing keeps working, a banner explains what is happening, and uploads resume on reconnect.
- Accessibility:
  - Every plan item is described for screen readers ("Sofa, 2.0 by 0.9 metres, left side of the room") and has actions for Move left, right, up and down (0.25 m), Rotate, Lock and Delete.
  - Touch targets are at least 48 dp.
  - Every screen works at 130% text size.
  - Reduce-motion is respected.
  - Warnings never rely on colour alone.

---

## How it works

### Architecture

```
┌──────────────────────────── Flutter app ────────────────────────────┐
│  features/  screens and widgets (Rooms, Setup, Editor, Viewer, ...)  │
│  state/     Riverpod controllers (editor, AI, sharing, cloud sync)   │
│  data/      local JSON files, Supabase clients                       │
│  domain/    pure Dart: scene model, checks, snapping, scoring,       │
│             history, merge (no Flutter imports)                      │
└──────────────┬──────────────────────────────────┬───────────────────┘
               │ JavaScript bridge                │ HTTPS / WebSocket
┌──────────────▼─────────────┐      ┌─────────────▼─────────────────────┐
│ 3D layer (WebView)         │      │ Supabase                          │
│ three.js + TypeScript,     │      │ • anonymous auth                  │
│ built by Vite into one     │      │ • Postgres + row-level security   │
│ HTML file. Draws the room, │      │ • Realtime (live sharing)         │
│ reports taps and drags.    │      │ • Edge Function ai-layout → Gemini│
└────────────────────────────┘      └───────────────────────────────────┘
```

**Flutter is the single source of truth.** The scene changes only through `EditorController` methods. Each method returns a new immutable `Scene`, which is committed to the undo history, checked, saved and synced. The 3D layer never decides anything: it renders, reports touches and plays animations.

### Scene model

- The room is a flat map from id to node (room, opening, item). Ids are a type prefix plus 8 random characters.
- Coordinates are in metres. Rotations are 0, 90, 180 or 270°, so every footprint is an axis-aligned rectangle.
- JSON is written by hand (no code generation).
- Nodes marked transient (drag previews, AI drafts) are never saved, synced or put in history.
- The same JSON is used for local files, the cloud copy and live sharing.

### Flutter ↔ 3D bridge

Messages are JSON with a type and a sequence number. Flutter sends only what changed.

| Flutter → 3D | 3D → Flutter |
| --- | --- |
| `init`, `scene.replace`, `scene.patch` (changed ids only) | `ready` |
| `item.preview` (drag position), `selection.set`, `warnings.set` | `tap`, `drag.start`, `drag.move`, `drag.end`, `drag.cancel` |
| `draft.show` / `draft.hide`, `camera.preset`, `camera.focus`, `theme.set` | `selection.screen` (where to place the action bar), `error` |

The 3D side keeps an **id → mesh index** for picking and rebuilds only the items that changed. If the WebGL context is lost, it reloads once. If WebGL is unavailable, the plan keeps working on its own.

### Placement checks (`domain/checks`)

- `PlacementChecker` tests every footprint for overlap with other pieces, for staying inside the room polygon (L-shape included) and for door keep-out zones. Its messages count repeats: "Chair 2".
- `Snapper` applies grid, wall-pull and alignment snaps in a fixed priority order.
- `findFreeSpot` searches outward from the centre, or from the copied piece, in 10 cm steps.
- **Movement score**, from 0 to 100, measures how well a person can move around the room:
  `round(100 × (0.40·coverage + 0.20·comfort + 0.20·itemAccess + 0.20·doorLinks))`
  1. A 10 cm grid of the floor is flood-filled from the doors, once for a 0.30 m wide person and once for a 0.45 m wide person.
  2. **Coverage** is how much of the free floor can be walked on.
  3. **Comfort** is how much of it is also roomy enough for the wider person.
  4. **Item access** counts the pieces that can be reached (within 0.6 m).
  5. **Door links** checks that the doors connect to each other.

### AI pipeline: the AI proposes, the code decides

1. **Read.** `AiInputBuilder` turns the room into compact JSON: bounds, walls, doors with their keep-out zones, windows, every item with its size and current rectangle, and which items are locked.
2. **Ask.** The Supabase Edge Function `ai-layout` (Deno, JWT required) calls **Gemini Flash** with a strict JSON schema and asks for 3 different layouts.
   - The API key lives only in Edge Function secrets.
   - The model is set by the `GEMINI_MODEL` secret, with fallback models for when one is busy.
   - The whole call stays inside 22 s.
3. **Check.** `LayoutValidator` rejects each bad candidate with a plain reason: missing or repeated items, unknown ids, bad numbers or angles, overlaps, pieces outside the room, blocked doors, or no change at all. Locked items must stay where they are.
4. **Fix once.** If fewer than two layouts pass, the rejected ones are sent back to the AI with every problem listed, and both rounds are merged.
5. **Show.** The remaining layouts are scored, duplicates are removed, and up to 3 are shown, best first. "We skipped n ideas that were not safe" reports the rejected ones honestly.
6. **Apply.** A draft can be edited, and Apply stays disabled while it has a violation. Apply commits as one undo step.

Errors map to clear messages: rate limited, AI unavailable, unusable answer, timeout. Each says nothing was changed and offers Try again.

### Live sharing protocol

- **Session.** `share_sessions` holds `code`, `owner_id`, `scene`, `revision`, `active` and `expires_at` (24 h). The code uses 6 characters from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`, generated with secure randomness and retried up to 5 times if a code is already taken.
- **Owner writes.** The owner writes the full scene with `revision + 1`, at most every 150 ms. Viewers receive it through **Postgres changes** over Supabase Realtime. Measured owner-to-viewer time: 0.7 to 1.0 s.
- **Drags.** While dragging, positions are broadcast on a Realtime channel at most every 100 ms, so the piece glides on the viewer.
- **Presence.** Presence on the same channel counts viewers. Stopping broadcasts `ended`.
- **Viewer safety.** A viewer ignores any revision that is not newer than what it shows. It re-syncs on reconnect and when the app resumes, and also checks quietly every 5 s in case an update was missed.
- **Security.** Row-level security lets viewers read only active, unexpired sessions; only the owner can write.

### Saving, sync and merge

- **Local.** Rooms are saved as JSON files in the app's documents folder. Each write goes to a temporary file that then replaces the old one, so a crash never leaves a half-written room. Saves are debounced by 300 ms.
- **Cloud.** The cloud copy goes to the `projects` table (only its owner can see it), 2 s after the last change. Uploads also run when the app goes to the background. Waiting uploads and deletes are remembered across restarts and retried on reconnect.
- **Rooms list.** The list merges local and cloud copies; the newer copy wins, and newer cloud copies are downloaded.
- **Merge.** The copy last agreed with the cloud is kept on the phone. Before an upload, if the cloud moved on, `SceneMerge` does a **three-way merge**:
  - A change made on only one side wins.
  - Different fields of the same item both apply.
  - x and z merge together, so a piece never lands at a mix of two positions.
  - When both sides changed the same field, this phone wins.
  - If one side deleted a piece and the other edited it, the edit is kept.

  An open editor folds the merge into its live state as one undo step and shows a toast.

---

## Tech stack

| Area | Choice |
| --- | --- |
| App | Flutter (Dart), Android minSdk 26 |
| State and routing | flutter_riverpod, go_router |
| 2D plan | `CustomPaint` (furniture drawn from above with soft shadows) |
| 3D | three.js + TypeScript, bundled by Vite into a single HTML file, shown in `webview_flutter` |
| Backend | Supabase: anonymous auth, Postgres, Realtime, Edge Functions (Deno) |
| AI | Google Gemini Flash, called only from the Edge Function |
| Storage on device | JSON files and `shared_preferences` |
| Fonts | Poppins (headings) and Inter (text), bundled under the SIL Open Font License |

---

## Project structure

```
lib/
  app.dart                 routes: welcome tour, tabs, setup, editor, viewer
  bridge/                  messages, SceneBridge, SceneSync (Flutter ↔ 3D)
  core/                    theme tokens, strings, units, haptics
  data/                    local files, Supabase cloud, share and AI services
  domain/                  scene, geometry, checks, history, AI input, share, sync
  features/                onboarding, home tabs, projects, setup, editor, join, viewer, settings
  state/                   Riverpod controllers
web3d/src/                 three.js layer: scene, room, furniture, lighting, interaction
assets/web3d/index.html    built 3D bundle used by the app
supabase/migrations/       database schema and row-level security
supabase/functions/ai-layout/   Edge Function that calls Gemini
test/                      unit, widget and live integration tests
tool/                      3D build script, headless 3D renderer, design screenshots
```

---

## Getting started

**You need:** Flutter (stable), Node.js 18+ for the 3D bundle, and a Supabase project.

1. **Database.** Apply `supabase/migrations/0001_init.sql` (for example with `supabase db push`). In Authentication, turn on **anonymous sign-ins**.
2. **AI function.**
   ```bash
   supabase secrets set GEMINI_API_KEY=<key> GEMINI_MODEL=<model name>
   supabase functions deploy ai-layout
   ```
3. **App settings.** Copy `env.example.json` to `env.json` and fill in your project URL and anon key. `env.json` is git-ignored.
4. **Run.**
   ```bash
   flutter pub get
   bash tool/build_3d.sh                  # only after changing web3d/
   flutter run --dart-define-from-file=env.json
   flutter build apk --release --dart-define-from-file=env.json
   ```

Without `env.json`, the app opens a "Setup needed" screen instead of failing.

---

## Tests

```bash
flutter analyze
flutter test
flutter test test/integration --dart-define-from-file=env.json   # live tests against Supabase and Gemini
```

254 automated tests cover:
- **Rules:** placement checks, snapping, free-spot search, movement score, history, scene JSON, three-way merge and the AI validator.
- **Controllers:** editor, AI, cloud sync, sharing and viewer.
- **Every editor tool, end to end:** Add, Finish, AI layout and Live, including switching straight between them.
- **Layout:** every screen at 320 dp, phone, tablet and landscape sizes, at 130% text, in light and dark.

The live integration tests sign in real anonymous users and check:
- a full save, list, recover and delete cycle;
- owner-to-viewer updates, previews, refused viewer writes and stopping a session;
- Gemini suggestions passing through the validator.
