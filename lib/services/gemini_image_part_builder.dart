import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';

/// Builds image parts that Gemini can decode reliably.
class GeminiImagePartBuilder {
  const GeminiImagePartBuilder();

  static const _supportedMimeTypes = <String>{
    'image/heic',
    'image/heif',
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  Future<DataPart> buildPart(File file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const GeminiImageException('The selected image is empty.');
    }

    final mimeType = _detectMimeType(file.path, bytes);
    final normalized = await compute(_normalizeForGemini, bytes);

    if (normalized != null) {
      return DataPart('image/jpeg', normalized);
    }

    if (mimeType != null && _supportedMimeTypes.contains(mimeType)) {
      // image.decodeImage does not support HEIC/HEIF. Keep those bytes intact
      // and tell Gemini their real type instead of incorrectly calling them
      // JPEGs.
      return DataPart(mimeType, bytes);
    }

    final description = mimeType ?? 'unknown';
    throw GeminiImageException(
      'The selected image format is unsupported or unreadable ($description).',
    );
  }

  Future<List<DataPart>> buildParts(Iterable<File> files) async {
    final parts = <DataPart>[];
    for (final file in files) {
      parts.add(await buildPart(file));
    }
    return parts;
  }

  String? _detectMimeType(String path, Uint8List bytes) {
    // An empty path prevents the resolver from falling back to an extension
    // when the file contents identify a different format, such as HEIC saved
    // with a temporary .jpg name.
    final contentMimeType = lookupMimeType('', headerBytes: bytes);
    return contentMimeType ?? lookupMimeType(path);
  }
}

Uint8List? _normalizeForGemini(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    var oriented = img.bakeOrientation(decoded);
    const maxDimension = 2048;
    if (oriented.width > maxDimension || oriented.height > maxDimension) {
      oriented = oriented.width >= oriented.height
          ? img.copyResize(oriented, width: maxDimension)
          : img.copyResize(oriented, height: maxDimension);
    }
    return Uint8List.fromList(img.encodeJpg(oriented, quality: 85));
  } on Object {
    return null;
  }
}

class GeminiImageException implements Exception {
  const GeminiImageException(this.message);

  final String message;

  @override
  String toString() => message;
}
