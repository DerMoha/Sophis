import 'package:uuid/uuid.dart';
import 'package:sophis/models/water_entry.dart';
import 'package:sophis/services/database_service.dart';
import 'package:sophis/services/nutrition/nutrition_store.dart';

/// Manages water entries and today's water cache.
class HydrationController {
  final DatabaseService _db;
  final Future<void> Function() _onChanged;
  final bool Function() _isCacheValid;
  final DateTime Function() _currentCacheDate;
  final NutritionStore? _store;

  List<WaterEntry> _waterEntries = [];

  double? _cachedTodayWaterTotal;
  List<WaterEntry>? _cachedTodayWaterEntries;

  HydrationController(
    this._db,
    this._onChanged,
    this._isCacheValid,
    this._currentCacheDate, {
    NutritionStore? store,
  }) : _store = store;

  List<WaterEntry> get waterEntries => _waterEntries;

  void loadData(List<WaterEntry> entries) {
    _waterEntries = entries;
    invalidateCache();
  }

  void invalidateCache() {
    _cachedTodayWaterTotal = null;
    _cachedTodayWaterEntries = null;
  }

  void _prepareTodayCache() {
    if (_isCacheValid()) return;
    invalidateCache();
  }

  Future<void> addWater(double ml) async {
    final entry = WaterEntry(
      id: const Uuid().v4(),
      amountMl: ml,
      timestamp: DateTime.now(),
    );
    await restoreWaterEntry(entry);
  }

  Future<void> restoreWaterEntry(WaterEntry entry) async {
    if (_store == null) {
      await _db.insertWater(entry);
    } else {
      await _store!.commitOrThrow(SaveWaterEntry(entry));
    }
    _waterEntries.add(entry);
    invalidateCache();
    await _onChanged();
  }

  Future<void> removeWaterEntry(String id) async {
    final index = _waterEntries.indexWhere((entry) => entry.id == id);
    if (index == -1) return;

    if (_store == null) {
      await _db.deleteWater(id);
    } else {
      await _store!.commitOrThrow(DeleteWaterEntry(id));
    }
    _waterEntries.removeAt(index);
    invalidateCache();
    await _onChanged();
  }

  double getTodayWaterTotal() {
    _prepareTodayCache();
    if (_cachedTodayWaterTotal != null) {
      return _cachedTodayWaterTotal!;
    }

    final now = _currentCacheDate();
    var total = 0.0;
    final todayEntries = <WaterEntry>[];

    for (final entry in _waterEntries) {
      if (entry.timestamp.year == now.year &&
          entry.timestamp.month == now.month &&
          entry.timestamp.day == now.day) {
        total += entry.amountMl;
        todayEntries.add(entry);
      }
    }

    todayEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _cachedTodayWaterTotal = total;
    _cachedTodayWaterEntries = todayEntries;
    return total;
  }

  List<WaterEntry> getTodayWaterEntries() {
    _prepareTodayCache();
    if (_cachedTodayWaterEntries != null) {
      return _cachedTodayWaterEntries!;
    }
    getTodayWaterTotal();
    return _cachedTodayWaterEntries ?? const <WaterEntry>[];
  }

  void clearAll() {
    _waterEntries = [];
    invalidateCache();
  }
}
