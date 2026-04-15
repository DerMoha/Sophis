import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:sophis/models/water_entry.dart';
import 'package:sophis/services/database_service.dart';

class WaterStore extends ChangeNotifier {
  final DatabaseService _db;

  List<WaterEntry> _waterEntries = [];
  DateTime? _cacheDate;

  WaterStore(this._db);

  List<WaterEntry> get waterEntries => _waterEntries;

  void loadData(List<WaterEntry> entries) {
    _waterEntries = entries;
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

  Future<void> addWater(double ml) async {
    final entry = WaterEntry(
      id: const Uuid().v4(),
      amountMl: ml,
      timestamp: DateTime.now(),
    );
    await restoreWaterEntry(entry);
  }

  Future<void> restoreWaterEntry(WaterEntry entry) async {
    _waterEntries.add(entry);
    _invalidateCache();
    await _db.insertWater(entry);
    notifyListeners();
  }

  Future<void> removeWaterEntry(String id) async {
    _waterEntries.removeWhere((e) => e.id == id);
    _invalidateCache();
    await _db.deleteWater(id);
    notifyListeners();
  }

  double getTodayWaterTotal() {
    _prepareTodayCache();
    final now = DateTime.now();
    var total = 0.0;
    for (final entry in _waterEntries) {
      if (entry.timestamp.year == now.year &&
          entry.timestamp.month == now.month &&
          entry.timestamp.day == now.day) {
        total += entry.amountMl;
      }
    }
    return total;
  }

  List<WaterEntry> getTodayWaterEntries() {
    _prepareTodayCache();
    final now = DateTime.now();
    final entries = _waterEntries.where((e) {
      return e.timestamp.year == now.year &&
          e.timestamp.month == now.month &&
          e.timestamp.day == now.day;
    }).toList();
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  void clearAll() {
    _waterEntries = [];
    _invalidateCache();
  }
}
