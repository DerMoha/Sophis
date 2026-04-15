import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:sophis/models/weight_entry.dart';
import 'package:sophis/services/database_service.dart';
import 'package:sophis/services/health_service.dart';

class WeightStore extends ChangeNotifier {
  final DatabaseService _db;
  final HealthService _healthService;

  List<WeightEntry> _weightEntries = [];

  WeightStore(this._db, this._healthService);

  List<WeightEntry> get weightEntries => _weightEntries;

  WeightEntry? get latestWeight =>
      _weightEntries.isEmpty ? null : _weightEntries.first;

  void loadData(List<WeightEntry> entries) {
    _weightEntries = entries;
    _weightEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifyListeners();
  }

  Future<void> addWeight(double kg, {String? note}) async {
    final entry = WeightEntry(
      id: const Uuid().v4(),
      weightKg: kg,
      timestamp: DateTime.now(),
      note: note,
      source: 'manual',
    );
    await restoreWeightEntry(entry);
  }

  Future<void> restoreWeightEntry(WeightEntry entry) async {
    _weightEntries.add(entry);
    _weightEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    await _db.insertWeight(entry);
    notifyListeners();
  }

  Future<void> removeWeightEntry(String id) async {
    _weightEntries.removeWhere((e) => e.id == id);
    await _db.deleteWeight(id);
    notifyListeners();
  }

  Future<void> syncWeightFromHealth() async {
    try {
      final end = DateTime.now();
      final start = end.subtract(const Duration(days: 30));
      final healthEntries = await _healthService.getWeightEntries(start, end);

      for (final he in healthEntries) {
        final alreadyExists = _weightEntries.any(
          (e) => (e.timestamp.difference(he.timestamp).inSeconds).abs() <= 60,
        );
        if (!alreadyExists) {
          final entry = WeightEntry(
            id: const Uuid().v4(),
            weightKg: he.kg,
            timestamp: he.timestamp,
            source: 'health',
          );
          _weightEntries.add(entry);
          await _db.insertWeight(entry);
        }
      }

      _weightEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      notifyListeners();
    } catch (e) {
      debugPrint('Weight sync from Health failed: $e');
    }
  }

  void clearAll() {
    _weightEntries = [];
  }
}
