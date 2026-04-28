import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:sophis/models/supplement.dart';
import 'package:sophis/models/supplement_log.dart';
import 'package:sophis/services/database_service.dart';
import 'package:sophis/services/notification_service.dart';
import 'package:sophis/services/service_result.dart';

/// Provider for managing supplement tracking, including completion logging
/// and daily reminder notifications.
///
/// Supplements use notification IDs in the range 100-199, allowing a maximum
/// of 100 supplements with reminders. This range prevents conflicts with other
/// notification types (e.g., meal reminders use IDs 0-99).
class SupplementsProvider extends ChangeNotifier {
  final DatabaseService _db;
  final NotificationService _notifications;
  final _uuid = const Uuid();

  // Notification ID range for supplements (100-199, max 100 supplements)
  static const _notificationIdStart = 100;
  static const _notificationIdEnd = 200;
  static const _maxSupplements = 100;

  List<Supplement> _supplements = [];
  List<SupplementLogEntry> _logs = [];
  bool _isLoading = true;
  String? _lastError;
  List<Supplement>? _enabledSupplementsCache;
  Set<String>? _todayCompletedIdsCache;
  DateTime? _todayCompletedCacheDate;

  SupplementsProvider(this._db, this._notifications) {
    _loadData();
  }

  // ---------------------------------------------------------------------------
  // GETTERS
  // ---------------------------------------------------------------------------

  List<Supplement> get supplements => _supplements;
  List<SupplementLogEntry> get logs => _logs;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  List<Supplement> get enabledSupplements {
    if (_enabledSupplementsCache != null) {
      return _enabledSupplementsCache!;
    }

    _enabledSupplementsCache = List<Supplement>.unmodifiable(
      _supplements.where((s) => s.enabled),
    );
    return _enabledSupplementsCache!;
  }

  /// Get today's date range (midnight to midnight)
  ({DateTime start, DateTime end}) get _todayRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    return (start: today, end: tomorrow);
  }

  void _invalidateDerivedCaches() {
    _enabledSupplementsCache = null;
    _todayCompletedIdsCache = null;
    _todayCompletedCacheDate = null;
  }

  bool _isTodayCompletionCacheValid() {
    if (_todayCompletedIdsCache == null || _todayCompletedCacheDate == null) {
      return false;
    }

    final now = DateTime.now();
    return _todayCompletedCacheDate!.year == now.year &&
        _todayCompletedCacheDate!.month == now.month &&
        _todayCompletedCacheDate!.day == now.day;
  }

  /// Returns set of supplement IDs completed today
  Set<String> getTodayCompletedIds() {
    if (_isTodayCompletionCacheValid()) {
      return _todayCompletedIdsCache!;
    }

    final range = _todayRange;
    final completedIds = <String>{};

    for (final log in _logs) {
      if (!log.timestamp.isBefore(range.start) &&
          log.timestamp.isBefore(range.end)) {
        completedIds.add(log.supplementId);
      }
    }

    _todayCompletedIdsCache = completedIds;
    _todayCompletedCacheDate = range.start;
    return completedIds;
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
      _invalidateDerivedCaches();
    } catch (e) {
      // Failed to load supplements
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await _loadData();
  }

  /// Clear the last error state
  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // COMPLETION TRACKING
  // ---------------------------------------------------------------------------

  /// Toggle supplement completion for today
  Future<void> toggleCompletion(String supplementId) async {
    final supplementIndex =
        _supplements.indexWhere((s) => s.id == supplementId);
    if (supplementIndex == -1) {
      return;
    }
    final supplement = _supplements[supplementIndex];

    bool isNowCompleted;
    if (isCompletedToday(supplementId)) {
      // Find and remove today's log
      try {
        final range = _todayRange;

        final todayLog = _logs.firstWhere(
          (log) =>
              log.supplementId == supplementId &&
              log.timestamp.isAfter(range.start) &&
              log.timestamp.isBefore(range.end),
        );

        await _db.deleteSupplementLog(todayLog.id);
        _logs.removeWhere((log) => log.id == todayLog.id);
        _invalidateDerivedCaches();
        isNowCompleted = false;
      } catch (e) {
        return; // Skip notification if log not found
      }
    } else {
      // Add new log for today
      final log = SupplementLogEntry(
        id: _uuid.v4(),
        supplementId: supplementId,
        timestamp: DateTime.now(),
      );
      await _db.insertSupplementLog(log);
      _logs.add(log);
      _invalidateDerivedCaches();
      isNowCompleted = true;
    }

    await _rescheduleNotificationForCompletion(
      supplement,
      completed: isNowCompleted,
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // CRUD OPERATIONS
  // ---------------------------------------------------------------------------

  /// Add a new supplement
  ServiceResult<void> addSupplement(Supplement supplement) {
    // Validate max supplements limit (notification ID constraint)
    if (_supplements.length >= _maxSupplements) {
      const message =
          'Cannot add more than $_maxSupplements supplements. '
          'This limit exists to prevent notification ID conflicts.';
      _lastError = message;
      notifyListeners();
      return const Failure(ServiceErrorType.unknown, message);
    }

    _db.insertSupplement(supplement).then((_) async {
      _supplements.add(supplement);
      _supplements.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      _invalidateDerivedCaches();

      if (supplement.enabled && supplement.reminderTime != null) {
        await _scheduleNotification(
          supplement,
          skipToday: isCompletedToday(supplement.id),
        );
      }

      _lastError = null;
      notifyListeners();
    });

    return const Success(null);
  }

  /// Update an existing supplement
  Future<ServiceResult<void>> updateSupplement(Supplement supplement) async {
    try {
      await _db.updateSupplement(supplement);

      final index = _supplements.indexWhere((s) => s.id == supplement.id);
      if (index != -1) {
        _supplements[index] = supplement;
        _invalidateDerivedCaches();
      }

      // Reschedule notification
      await _cancelNotification(supplement);
      if (supplement.enabled && supplement.reminderTime != null) {
        await _scheduleNotification(
          supplement,
          skipToday: isCompletedToday(supplement.id),
        );
      }

      _lastError = null;
      notifyListeners();
      return const Success(null);
    } catch (e) {
      final message = 'Failed to update supplement: $e';
      _lastError = message;
      notifyListeners();
      return Failure(ServiceErrorType.unknown, message);
    }
  }

  /// Delete a supplement
  ServiceResult<void> deleteSupplement(String id) {
    final index = _supplements.indexWhere((s) => s.id == id);
    if (index == -1) {
      const message = 'Supplement not found';
      _lastError = message;
      notifyListeners();
      return const Failure(ServiceErrorType.notFound, message);
    }

    final supplement = _supplements[index];

    _db.deleteSupplement(id).then((_) async {
      _supplements.removeWhere((s) => s.id == id);

      // Delete associated logs
      _logs.removeWhere((log) => log.supplementId == id);
      _invalidateDerivedCaches();

      // Cancel notification
      await _cancelNotification(supplement);

      _lastError = null;
      notifyListeners();
    });

    return const Success(null);
  }

  /// Reorder supplements by moving from oldIndex to newIndex
  ///
  /// Updates sortOrder for all supplements and performs a batch database update
  /// for optimal performance (single transaction instead of N individual updates).
  Future<ServiceResult<void>> reorderSupplements(int oldIndex, int newIndex) async {
    try {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      final supplement = _supplements.removeAt(oldIndex);
      _supplements.insert(newIndex, supplement);

      // Update sortOrder for all supplements in batch
      for (var i = 0; i < _supplements.length; i++) {
        _supplements[i] = _supplements[i].copyWith(sortOrder: i);
      }
      _invalidateDerivedCaches();

      // Batch update to database for better performance
      await _db.batchUpdateSupplements(_supplements);

      // Update all notifications to reflect new indices after reordering
      await updateAllNotifications();

      _lastError = null;
      notifyListeners();
      return const Success(null);
    } catch (e) {
      final message = 'Failed to reorder supplements: $e';
      _lastError = message;
      notifyListeners();
      return Failure(ServiceErrorType.unknown, message);
    }
  }

  // ---------------------------------------------------------------------------
  // NOTIFICATIONS
  // ---------------------------------------------------------------------------

  /// Get notification ID for a supplement (100-199 range, max 100 supplements)
  int _getNotificationId(String supplementId) {
    final index = _supplements.indexWhere((s) => s.id == supplementId);
    if (index == -1 || index >= _maxSupplements) {
      return _notificationIdStart; // Fallback to first ID
    }
    return _notificationIdStart + index;
  }

  /// Schedule notification for a supplement
  Future<void> _scheduleNotification(
    Supplement supplement, {
    bool skipToday = false,
  }) async {
    if (!supplement.enabled || supplement.reminderTime == null) return;

    final parts = supplement.reminderTime!.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    await _notifications.scheduleMealReminder(
      id: _getNotificationId(supplement.id),
      title: 'Time for ${supplement.name}',
      body: 'Don\'t forget to take your ${supplement.name}',
      hour: hour,
      minute: minute,
      startTomorrow: skipToday,
    );
  }

  /// Cancel notification for a supplement
  Future<void> _cancelNotification(Supplement supplement) async {
    await _notifications.cancelReminder(_getNotificationId(supplement.id));
  }

  Future<void> _rescheduleNotificationForCompletion(
    Supplement supplement, {
    required bool completed,
  }) async {
    if (!supplement.enabled || supplement.reminderTime == null) return;

    try {
      await _cancelNotification(supplement);
      await _scheduleNotification(
        supplement,
        skipToday: completed,
      );
    } catch (e) {
      // Failed to reschedule notification silently
    }
  }

  /// Update all notifications (reschedule all enabled supplements)
  Future<void> updateAllNotifications({bool enable = true}) async {
    // Cancel all supplement notifications (100-199)
    for (var i = _notificationIdStart; i < _notificationIdEnd; i++) {
      await _notifications.cancelReminder(i);
    }

    if (!enable) return;

    // Schedule notifications for all enabled supplements (up to max)
    for (var i = 0; i < _supplements.length && i < _maxSupplements; i++) {
      final supplement = _supplements[i];
      if (supplement.enabled && supplement.reminderTime != null) {
        await _scheduleNotification(
          supplement,
          skipToday: isCompletedToday(supplement.id),
        );
      }
    }
  }
}
