import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/supplement.dart';
import '../models/supplement_log.dart';
import 'database_service.dart';
import 'notification_service.dart';

class SupplementsProvider extends ChangeNotifier {
  final DatabaseService _db;
  final NotificationService _notifications;
  final _uuid = const Uuid();

  List<Supplement> _supplements = [];
  List<SupplementLogEntry> _logs = [];
  bool _isLoading = true;

  SupplementsProvider(this._db, this._notifications) {
    _loadData();
  }

  // ---------------------------------------------------------------------------
  // GETTERS
  // ---------------------------------------------------------------------------

  List<Supplement> get supplements => _supplements;
  List<SupplementLogEntry> get logs => _logs;
  bool get isLoading => _isLoading;

  List<Supplement> get enabledSupplements =>
      _supplements.where((s) => s.enabled).toList();

  /// Returns set of supplement IDs completed today
  Set<String> getTodayCompletedIds() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return _logs
        .where((log) =>
            log.timestamp.isAfter(today) &&
            log.timestamp.isBefore(tomorrow))
        .map((log) => log.supplementId)
        .toSet();
  }

  /// Check if a supplement is completed today
  bool isCompletedToday(String supplementId) {
    return getTodayCompletedIds().contains(supplementId);
  }

  /// Get today's completion count
  int get todayCompletedCount => getTodayCompletedIds().length;

  /// Get today's total supplements (enabled only)
  int get todayTotalCount => enabledSupplements.length;

  // ---------------------------------------------------------------------------
  // DATA LOADING
  // ---------------------------------------------------------------------------

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _supplements = await _db.getAllSupplements();
      _logs = await _db.getAllSupplementLogs();
    } catch (e) {
      debugPrint('Error loading supplements: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await _loadData();
  }

  // ---------------------------------------------------------------------------
  // COMPLETION TRACKING
  // ---------------------------------------------------------------------------

  /// Toggle supplement completion for today
  Future<void> toggleCompletion(String supplementId) async {
    if (isCompletedToday(supplementId)) {
      // Find and remove today's log
      final todayLog = _logs.firstWhere(
        (log) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final tomorrow = today.add(const Duration(days: 1));
          return log.supplementId == supplementId &&
              log.timestamp.isAfter(today) &&
              log.timestamp.isBefore(tomorrow);
        },
      );
      await _db.deleteSupplementLog(todayLog.id);
      _logs.removeWhere((log) => log.id == todayLog.id);
    } else {
      // Add new log for today
      final log = SupplementLogEntry(
        id: _uuid.v4(),
        supplementId: supplementId,
        timestamp: DateTime.now(),
      );
      await _db.insertSupplementLog(log);
      _logs.add(log);
    }

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // CRUD OPERATIONS
  // ---------------------------------------------------------------------------

  /// Add a new supplement
  Future<void> addSupplement(Supplement supplement) async {
    await _db.insertSupplement(supplement);
    _supplements.add(supplement);
    _supplements.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    if (supplement.enabled && supplement.reminderTime != null) {
      await _scheduleNotification(supplement);
    }

    notifyListeners();
  }

  /// Update an existing supplement
  Future<void> updateSupplement(Supplement supplement) async {
    await _db.updateSupplement(supplement);

    final index = _supplements.indexWhere((s) => s.id == supplement.id);
    if (index != -1) {
      _supplements[index] = supplement;
    }

    // Reschedule notification
    await _cancelNotification(supplement);
    if (supplement.enabled && supplement.reminderTime != null) {
      await _scheduleNotification(supplement);
    }

    notifyListeners();
  }

  /// Delete a supplement
  Future<void> deleteSupplement(String id) async {
    final supplement = _supplements.firstWhere((s) => s.id == id);

    await _db.deleteSupplement(id);
    _supplements.removeWhere((s) => s.id == id);

    // Delete associated logs
    _logs.removeWhere((log) => log.supplementId == id);

    // Cancel notification
    await _cancelNotification(supplement);

    notifyListeners();
  }

  /// Reorder supplements
  Future<void> reorderSupplements(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final supplement = _supplements.removeAt(oldIndex);
    _supplements.insert(newIndex, supplement);

    // Update sortOrder for all supplements
    for (var i = 0; i < _supplements.length; i++) {
      _supplements[i] = _supplements[i].copyWith(sortOrder: i);
      await _db.updateSupplement(_supplements[i]);
    }

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // NOTIFICATIONS
  // ---------------------------------------------------------------------------

  /// Get notification ID for a supplement (100-199 range)
  int _getNotificationId(String supplementId) {
    final index = _supplements.indexWhere((s) => s.id == supplementId);
    if (index == -1) return 100;
    return 100 + index; // Start at 100, max 199
  }

  /// Schedule notification for a supplement
  Future<void> _scheduleNotification(Supplement supplement) async {
    if (supplement.reminderTime == null) return;

    final parts = supplement.reminderTime!.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    await _notifications.scheduleMealReminder(
      id: _getNotificationId(supplement.id),
      title: 'Time for ${supplement.name}',
      body: 'Don\'t forget to take your ${supplement.name}',
      hour: hour,
      minute: minute,
    );
  }

  /// Cancel notification for a supplement
  Future<void> _cancelNotification(Supplement supplement) async {
    await _notifications.cancelReminder(_getNotificationId(supplement.id));
  }

  /// Update all notifications (reschedule all enabled supplements)
  Future<void> updateAllNotifications() async {
    // Cancel all supplement notifications (100-199)
    for (var i = 100; i < 200; i++) {
      await _notifications.cancelReminder(i);
    }

    // Schedule notifications for all enabled supplements
    for (final supplement in _supplements) {
      if (supplement.enabled && supplement.reminderTime != null) {
        await _scheduleNotification(supplement);
      }
    }
  }
}
