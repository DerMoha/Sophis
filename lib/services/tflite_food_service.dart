import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

/// TFLite-based food classification service
/// Uses Food101 model for offline food recognition
class TFLiteFoodService {
  static const _modelPath = 'assets/ml/food101_model.tflite';
  static const _labelsPath = 'assets/ml/food101_labels.txt';
  static const _inputSize = 224;
  
  Interpreter? _interpreter;
  List<String>? _labels;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initialize the TFLite interpreter and load labels
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load model
      _interpreter = await Interpreter.fromAsset(_modelPath);
      
      // Load labels
      final labelsData = await rootBundle.loadString(_labelsPath);
      _labels = labelsData.split('\n').where((l) => l.isNotEmpty).toList();
      
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }

  /// Classify a food image and return top predictions
  Future<List<FoodPrediction>> classify(File imageFile, {int topK = 5}) async {
    if (!_isInitialized || _interpreter == null || _labels == null) {
      throw Exception('TFLite service not initialized');
    }

    // Load and preprocess image
    final imageBytes = await imageFile.readAsBytes();
    final image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('Failed to decode image');

    // Resize to model input size
    final resized = img.copyResize(image, width: _inputSize, height: _inputSize);
    
    // Convert to float32 input tensor [1, 224, 224, 3]
    final input = _imageToInput(resized);
    
    // Prepare output tensor
    final output = List.filled(_labels!.length, 0.0).reshape([1, _labels!.length]);
    
    // Run inference
    _interpreter!.run(input, output);
    
    // Get predictions
    final predictions = <FoodPrediction>[];
    final scores = output[0] as List<double>;
    
    // Create indexed scores and sort
    final indexed = scores.asMap().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Take top K
    for (var i = 0; i < topK && i < indexed.length; i++) {
      final entry = indexed[i];
      predictions.add(FoodPrediction(
        label: _labels![entry.key],
        confidence: entry.value,
      ));
    }

    return predictions;
  }

  /// Convert image to normalized float32 input
  List<List<List<List<double>>>> _imageToInput(img.Image image) {
    final input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(
          _inputSize,
          (x) {
            final pixel = image.getPixel(x, y);
            return [
              pixel.r / 255.0, // Normalize to [0, 1]
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          },
        ),
      ),
    );
    return input;
  }

  /// Clean up resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}

/// A food classification prediction
class FoodPrediction {
  final String label;
  final double confidence;

  FoodPrediction({required this.label, required this.confidence});

  String get displayLabel => label.replaceAll('_', ' ').trim();
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';
}
