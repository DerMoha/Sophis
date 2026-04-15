import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:sophis/models/workout_entry.dart';
import 'package:sophis/services/database_service.dart';

class WorkoutStore extends ChangeNotifier {
  final DatabaseService _db;

  List<WorkoutEntry> _workoutEntries = [];
  DateTime? _cacheDate;

  WorkoutStore(this._db);

  List<WorkoutEntry> get workoutEntries => _workoutEntries;

  void loadData(List<WorkoutEntry> entries) {
    _workoutEntries = entries;
    _invalidateCache();
    notifyListeners();
  }

  bool _isCacheValid() {
    if (_cacheDate == null) return false;
    final now = DateTime.now();
    return _cacheDate!.year == now.year &&
        _cacheDate!.month == now.month &&
        _cacheDate!.day == now.day;
  }

  void _prepareTodayCache() {
    if (_isCacheValid()) return;
    _cacheDate = DateTime.now();
  }

  void _invalidateCache() {
    _cacheDate = null;
  }

  Future<void> addWorkoutEntry(double calories, {String? note}) async {
    final entry = WorkoutEntry(
      id: const Uuid().v4(),
      caloriesBurned: calories,
      timestamp: DateTime.now(),
      note: note,
    );
    await restoreWorkoutEntry(entry);
  }

  Future<void> restoreWorkoutEntry(WorkoutEntry entry) async {
    _workoutEntries.add(entry);
    _invalidateCache();
    await _db.insertWorkout(entry);
    notifyListeners();
  }

  Future<void> updateWorkoutEntry(WorkoutEntry entry) async {
    final index = _workoutEntries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _workoutEntries[index] = entry;
      _invalidateCache();
      await _db.updateWorkout(entry);
      notifyListeners();
    }
  }

  Future<void> removeWorkoutEntry(String id) async {
    _workoutEntries.removeWhere((e) => e.id == id);
    _invalidateCache();
    await _db.deleteWorkout(id);
    notifyListeners();
  }

  double getTodayWorkoutCalories() {
    _prepareTodayCache();
    final now = DateTime.now();
    var total = 0.0;
    for (final entry in _workoutEntries) {
      if (entry.timestamp.year == now.year &&
          entry.timestamp.month == now.month &&
          entry.timestamp.day == now.day) {
        total += entry.caloriesBurned;
      }
    }
    return total;
  }

  List<WorkoutEntry> getTodayWorkoutEntries() {
    _prepareTodayCache();
    final now = DateTime.now();
    final entries = _workoutEntries.where((e) {
      return e.timestamp.year == now.year &&
          e.timestamp.month == now.month &&
          e.timestamp.day == now.day;
    }).toList();
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  void clearAll() {
    _workoutEntries = [];
    _invalidateCache();
  }
}
