# Progress Photos – Implementation Plan

## Overview

A visual body transformation diary. Users take photos (front/side/back) at regular intervals and can compare them side-by-side to see progress beyond the scale. Photos are stored in the app's documents directory; only metadata (path, timestamp, weight, note, category) goes into SQLite.

---

## 1. Data Model

### `lib/models/progress_photo.dart`

```dart
enum PhotoCategory { front, side, back, other }

class ProgressPhoto {
  final String id;
  final String imagePath;       // Relative path in app docs dir
  final DateTime timestamp;
  final double? weightKg;       // Optional: auto-filled from latest weight
  final String? note;
  final PhotoCategory category;
  final DateTime createdAt;

  const ProgressPhoto({
    required this.id,
    required this.imagePath,
    required this.timestamp,
    this.weightKg,
    this.note,
    this.category = PhotoCategory.front,
    required this.createdAt,
  });

  // copyWith, toJson, fromJson (matching existing model conventions)
}
```

### Photo Storage Strategy
- Photos saved to `{appDocDir}/progress_photos/{id}.jpg`
- Thumbnails: `{appDocDir}/progress_photos/{id}_thumb.jpg` (300px max dimension)
- On delete: remove both files from disk
- On export: bundle photos as base64 in JSON or zip archive

---

## 2. Database

### New Table in `database_service.dart`

```dart
class ProgressPhotos extends Table {
  TextColumn get id => text()();
  TextColumn get imagePath => text()();
  DateTimeColumn get timestamp => dateTime()();
  RealColumn get weightKg => real().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get category => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

### Migration
- Bump `schemaVersion` from 5 → 6
- Add migration step in `onUpgrade`: `if (from <= 5 && to >= 6)` → createTable(progressPhotos)

### Database Methods
```dart
Future<List<ProgressPhoto>> getAllPhotos();
Future<int> insertPhoto(ProgressPhoto photo);
Future<int> deletePhoto(String id);
Future<ProgressPhoto?> getPhotoById(String id);
Future<List<ProgressPhoto>> getPhotosByCategory(PhotoCategory category);
```

---

## 3. Business Logic

### `lib/services/progress_photo_controller.dart`

```dart
class ProgressPhotoController {
  final DatabaseService _db;

  // Add photo: saves image to disk + creates DB entry
  Future<ProgressPhoto> addPhoto({
    required File imageFile,
    DateTime? timestamp,
    double? weightKg,
    String? note,
    PhotoCategory category = PhotoCategory.front,
  });

  // Delete photo: removes from DB + deletes files from disk
  Future<void> deletePhoto(String id);

  // Comparison helper: get two photos for side-by-side
  Future<({ProgressPhoto before, ProgressPhoto after})?> getComparison({
    DateTime? beforeDate,
    DateTime? afterDate,
  });
}
```

### Integration in `NutritionProvider`
- Add `List<ProgressPhoto> _photos` field
- Delegate to `ProgressPhotoController`
- Expose via getter: `List<ProgressPhoto> get photos`
- Expose methods: `addPhoto(...)`, `deletePhoto(...)`
- Auto-fill weight: when adding photo, use `latestWeight?.weightKg`
- Notify listeners on changes

---

## 4. UI Components

### `lib/ui/screens/progress_photos_screen.dart`

Main screen showing photo timeline/grid.

```
┌─────────────────────────────────┐
│  AppBar: "Progress Photos"      │
│  Actions: [Compare] [Camera]    │
├─────────────────────────────────┤
│  SegmentedControl: [All|Front|  │
│                    Side|Back]    │
├─────────────────────────────────┤
│  ┌─────────┐ ┌─────────┐       │
│  │ Photo   │ │ Photo   │       │
│  │ 12. Feb │ │ 26. Feb │  ...  │
│  │ 85.3 kg │ │ 84.1 kg │       │
│  └─────────┘ └─────────┘       │
│  ┌─────────┐ ┌─────────┐       │
│  │ Photo   │ │ Photo   │  ...  │
│  │ ...     │ │ ...     │       │
│  └─────────┘ └─────────┘       │
├─────────────────────────────────┤
│  FAB: Camera icon               │
└─────────────────────────────────┘
```

Features:
- 2-column grid (GridView), newest first
- Segmented filter by PhotoCategory
- Each tile: thumbnail, date, weight (if available)
- Long-press: delete confirmation
- Tap: full-screen viewer with swipe between photos
- FAB: opens AddPhotoSheet

### `lib/ui/screens/progress_photo_viewer.dart`

Full-screen photo viewer with:
- Hero animation from grid tile
- Pinch-to-zoom (InteractiveViewer)
- Swipe left/right to navigate photos (PageView)
- AppBar overlay that fades on tap
- Share button
- Delete button
- Bottom info bar: date, weight, note

### `lib/ui/screens/progress_photo_compare.dart`

Side-by-side comparison view.

```
┌─────────────────────────────────┐
│  AppBar: "Compare"              │
├─────────────────────────────────┤
│  ┌──────────┐ ┌──────────┐     │
│  │  BEFORE  │ │  AFTER   │     │
│  │          │ │          │     │
│  │  Photo   │ │  Photo   │     │
│  │          │ │          │     │
│  │ 12. Feb  │ │ 26. Apr  │     │
│  │ 85.3 kg  │ │ 81.2 kg  │     │
│  └──────────┘ └──────────┘     │
│  ────────────  ────────────    │
│  Weight: -4.1 kg               │
│  Duration: 73 days             │
├─────────────────────────────────┤
│  [Share Comparison]  [Export]  │
└─────────────────────────────────┘
```

Features:
- Two image pickers (before/after date selectors)
- Tap each image to change which photo
- Weight delta calculation
- "Share" generates a combined image (two photos side-by-side with stats overlay)
- Uses Screenshot widget or Canvas for export

### `lib/ui/components/add_photo_sheet.dart`

Bottom sheet for adding a new photo.

```
┌─────────────────────────────────┐
│  Add Progress Photo             │
│  ─────────────────────────────  │
│  Category: ○ Front ● Side       │
│            ○ Back  ○ Other      │
│                                 │
│  Date: [12. Feb 2025  ▼]       │
│  Weight: [85.3] kg (auto)      │
│  Note: [________________]      │
│                                 │
│  [Take Photo]  [Choose from     │
│                 Gallery]        │
└─────────────────────────────────┘
```

### Dashboard Card Integration

Add `'progress_photos'` to `DashboardCardIds`:
```dart
static const progressPhotos = 'progress_photos';
```

Dashboard card showing:
- Latest front photo thumbnail
- Days since first photo
- "Compare" / "Add Photo" quick actions
- Total photos count

### Reuse Existing Components
- `FadeInSlide` for staggered list animations
- `GlassCard` / `OrganicCard` for photo tiles
- `SectionHeader` for filtered sections
- `EmptyState` for "No photos yet"
- `AnimatedNumber` for weight display
- Existing `image_picker` dependency for camera/gallery

---

## 5. Data Export/Import

### Export
- ProgressPhotos included in `DataExportService.exportData()`
- JSON metadata array in export JSON under `"progressPhotos"` key
- Photos embedded as base64 strings in JSON (or separate zip)
- Option: export as zip with JSON + image files

### Import
- Parse `progressPhotos` from JSON
- Decode base64 → save to disk
- Insert into DB with original IDs (upsert mode)
- Handle missing image data gracefully

---

## 6. Permissions

iOS (`Info.plist`):
```xml
<!-- Already present for AI camera -->
<key>NSCameraUsageDescription</key>
<key>NSPhotoLibraryUsageDescription</key>
<!-- Add if not present -->
<key>NSPhotoLibraryAddUsageDescription</key>
```

Android: Already handled by `image_picker`.

---

## 7. Testing

### Unit Tests
- `ProgressPhoto.fromJson()` / `toJson()` roundtrip
- `ProgressPhotoController.addPhoto()` creates file + DB entry
- `ProgressPhotoController.deletePhoto()` removes file + DB entry
- `ProgressPhotoController.getComparison()` returns correct pair

### Widget Tests
- `ProgressPhotosScreen` renders empty state
- `ProgressPhotosScreen` renders photo grid
- `AddPhotoSheet` validates input
- `ProgressPhotoCompare` shows weight delta

---

## 8. Implementation Order

| Step | File | Effort |
|------|------|--------|
| 1. | `lib/models/progress_photo.dart` | S |
| 2. | `lib/services/database_service.dart` (table + migration) | M |
| 3. | `dart run build_runner build` (regenerate .g.dart) | S |
| 4. | `lib/services/progress_photo_controller.dart` | M |
| 5. | `lib/providers/nutrition_provider.dart` (integration) | M |
| 6. | `lib/ui/components/add_photo_sheet.dart` | M |
| 7. | `lib/ui/screens/progress_photos_screen.dart` | L |
| 8. | `lib/ui/screens/progress_photo_viewer.dart` | M |
| 9. | `lib/ui/screens/progress_photo_compare.dart` | L |
| 10. | Dashboard card integration | S |
| 11. | `lib/services/data_export_service.dart` (export/import) | M |
| 12. | Localization (en + de ARB files) | S |
| 13. | Tests | M |
| 14. | `flutter analyze` + fix issues | S |

Total estimated: ~6-8 days for a solo developer.

---

## 9. Edge Cases & Considerations

- **Large photos**: Resize to max 1920px on save to save disk space
- **Orphaned files**: On app start, clean up photos/ dir for DB entries that no longer exist
- **iCloud backup**: Photo files excluded from iCloud backup (set `NSURLIsExcludedFromBackupKey`), DB path syncs metadata
- **Migration from SharedPreferences**: N/A – this is a new feature, no legacy data
- **Storage quota**: Show warning if disk space is low before taking photo
- **Privacy**: All photos stay local – never uploaded anywhere
