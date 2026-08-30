import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:sophis/models/progress_photo.dart';
import 'package:sophis/services/database_service.dart';
import 'package:sophis/services/nutrition/nutrition_store.dart';

class ProgressPhotoController {
  final DatabaseService _db;
  final NutritionStore? _store;

  ProgressPhotoController(
    this._db, {
    NutritionStore? store,
  }) : _store = store;

  Future<Directory> _getPhotosDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'progress_photos'));
    if (!photosDir.existsSync()) {
      photosDir.createSync(recursive: true);
    }
    return photosDir;
  }

  Future<ProgressPhoto> addPhoto({
    required File imageFile,
    DateTime? timestamp,
    double? weightKg,
    String? note,
    PhotoCategory category = PhotoCategory.front,
  }) async {
    final id = const Uuid().v4();
    final photosDir = await _getPhotosDir();
    final imagePath = p.join(photosDir.path, '$id.jpg');
    final thumbPath = p.join(photosDir.path, '${id}_thumb.jpg');

    final bytes = await imageFile.readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Resize main image to max 1920px
    const maxDimension = 1920;
    if (image.width > maxDimension || image.height > maxDimension) {
      image = img.copyResize(
        image,
        width: image.width > image.height ? maxDimension : null,
        height: image.height >= image.width ? maxDimension : null,
      );
    }

    final jpgBytes = img.encodeJpg(image, quality: 90);

    // Generate thumbnail (300px max)
    const thumbMax = 300;
    final thumb = img.copyResize(
      image,
      width: image.width > image.height ? thumbMax : null,
      height: image.height >= image.width ? thumbMax : null,
    );
    final thumbBytes = img.encodeJpg(thumb, quality: 85);
    try {
      await _writeAtomically(File(imagePath), jpgBytes);
      await _writeAtomically(File(thumbPath), thumbBytes);

      final now = DateTime.now().toUtc();
      final photo = ProgressPhoto(
        id: id,
        imagePath: imagePath,
        timestamp: (timestamp ?? now).toUtc(),
        weightKg: weightKg,
        note: note,
        category: category,
        createdAt: now,
      );

      if (_store == null) {
        await _db.insertPhoto(photo);
      } else {
        await _store!.commitOrThrow(SaveProgressPhoto(photo));
      }
      return photo;
    } catch (_) {
      await _deleteIfExists(File(imagePath));
      await _deleteIfExists(File(thumbPath));
      rethrow;
    }
  }

  Future<void> deletePhoto(String id) async {
    final photo = await _db.getPhotoById(id);
    if (_store == null) {
      await _db.deletePhoto(id);
    } else {
      await _store!.commitOrThrow(DeleteProgressPhoto(id));
    }
    if (photo != null) {
      await _deleteIfExists(File(photo.imagePath));
      await _deleteIfExists(_thumbnailFile(photo.imagePath));
    }
  }

  Future<List<ProgressPhoto>> getAllPhotos() => _db.getAllPhotos();

  Future<List<ProgressPhoto>> getPhotosByCategory(PhotoCategory category) =>
      _db.getPhotosByCategory(category);

  Future<({ProgressPhoto before, ProgressPhoto after})?> getComparison({
    DateTime? beforeDate,
    DateTime? afterDate,
  }) async {
    final photos = await _db.getAllPhotos();
    if (photos.length < 2) return null;

    ProgressPhoto? before;
    ProgressPhoto? after;

    if (beforeDate != null && afterDate != null) {
      before = photos.lastWhere(
        (p) =>
            p.timestamp.isBefore(beforeDate) ||
            p.timestamp.isAtSameMomentAs(beforeDate),
        orElse: () => photos.last,
      );
      after = photos.firstWhere(
        (p) =>
            p.timestamp.isBefore(afterDate) ||
            p.timestamp.isAtSameMomentAs(afterDate),
        orElse: () => photos.first,
      );
    } else {
      before = photos.last;
      after = photos.first;
    }

    return (before: before, after: after);
  }

  /// Clean up orphaned photo files that have no DB entry
  Future<void> cleanupOrphanedFiles() async {
    final photosDir = await _getPhotosDir();
    final photos = await _db.getAllPhotos();
    final validPaths = <String>{};
    for (final photo in photos) {
      validPaths.add(photo.imagePath);
      validPaths.add(_thumbnailFile(photo.imagePath).path);
    }

    await for (final entity in photosDir.list()) {
      if (entity is! File) continue;
      if (!validPaths.contains(entity.path)) {
        await _deleteIfExists(entity);
      }
    }
  }

  Future<void> deleteAllPhotoFiles() async {
    final photosDir = await _getPhotosDir();
    if (!photosDir.existsSync()) return;
    await for (final entity in photosDir.list()) {
      if (entity is File) await _deleteIfExists(entity);
    }
  }

  Future<ProgressPhoto> stageBackupPhoto(
    ProgressPhoto metadata,
    List<int> imageBytes, {
    List<int>? thumbnailBytes,
  }) async {
    final photosDir = await _getPhotosDir();
    final suffix = const Uuid().v4();
    final imagePath = p.join(photosDir.path, '${metadata.id}_$suffix.jpg');
    final thumbnailPath =
        p.join(photosDir.path, '${metadata.id}_${suffix}_thumb.jpg');
    try {
      await _writeAtomically(File(imagePath), imageBytes);

      if (thumbnailBytes != null) {
        await _writeAtomically(File(thumbnailPath), thumbnailBytes);
      } else {
        final decoded = img.decodeImage(Uint8List.fromList(imageBytes));
        if (decoded == null) throw const FormatException('Invalid photo data');
        const thumbMax = 300;
        final thumbnail = img.copyResize(
          decoded,
          width: decoded.width > decoded.height ? thumbMax : null,
          height: decoded.height >= decoded.width ? thumbMax : null,
        );
        await _writeAtomically(
          File(thumbnailPath),
          img.encodeJpg(thumbnail, quality: 85),
        );
      }
    } catch (_) {
      await _deleteIfExists(File(imagePath));
      await _deleteIfExists(File(thumbnailPath));
      rethrow;
    }

    return metadata.copyWith(imagePath: imagePath);
  }

  Future<Uint8List?> getImageBytes(String path) async {
    final file = File(path);
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  File _thumbnailFile(String imagePath) =>
      File('${imagePath.replaceFirst(RegExp(r'\.jpg$'), '')}_thumb.jpg');

  Future<void> _writeAtomically(File target, List<int> bytes) async {
    final temporary = File('${target.path}.${const Uuid().v4()}.tmp');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(target.path);
    } finally {
      await _deleteIfExists(temporary);
    }
  }

  Future<void> _deleteIfExists(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException catch (_) {
      // File cleanup is best effort. The next orphan sweep can retry it.
    }
  }
}
