import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:sophis/models/progress_photo.dart';
import 'package:sophis/services/database_service.dart';

class ProgressPhotoController {
  final DatabaseService _db;

  ProgressPhotoController(this._db);

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
    await File(imagePath).writeAsBytes(jpgBytes);

    // Generate thumbnail (300px max)
    const thumbMax = 300;
    final thumb = img.copyResize(
      image,
      width: image.width > image.height ? thumbMax : null,
      height: image.height >= image.width ? thumbMax : null,
    );
    final thumbBytes = img.encodeJpg(thumb, quality: 85);
    await File(thumbPath).writeAsBytes(thumbBytes);

    final photo = ProgressPhoto(
      id: id,
      imagePath: imagePath,
      timestamp: timestamp ?? DateTime.now(),
      weightKg: weightKg,
      note: note,
      category: category,
      createdAt: DateTime.now(),
    );

    await _db.insertPhoto(photo);
    return photo;
  }

  Future<void> deletePhoto(String id) async {
    final photo = await _db.getPhotoById(id);
    if (photo != null) {
      final imageFile = File(photo.imagePath);
      if (imageFile.existsSync()) {
        imageFile.deleteSync();
      }
      final thumbFile = File('${photo.imagePath.replaceAll('.jpg', '')}_thumb.jpg');
      if (thumbFile.existsSync()) {
        thumbFile.deleteSync();
      }
    }
    await _db.deletePhoto(id);
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
        (p) => p.timestamp.isBefore(beforeDate) || p.timestamp.isAtSameMomentAs(beforeDate),
        orElse: () => photos.last,
      );
      after = photos.firstWhere(
        (p) => p.timestamp.isBefore(afterDate) || p.timestamp.isAtSameMomentAs(afterDate),
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
    final validIds = photos.map((p) => p.id).toSet();

    for (final entity in photosDir.listSync()) {
      if (entity is! File) continue;
      final basename = p.basename(entity.path);
      final id = basename.replaceAll('_thumb.jpg', '').replaceAll('.jpg', '');
      if (!validIds.contains(id)) {
        entity.deleteSync();
      }
    }
  }

  Future<Uint8List?> getImageBytes(String path) async {
    final file = File(path);
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }
}
