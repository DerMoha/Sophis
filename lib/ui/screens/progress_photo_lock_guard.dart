import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/services/progress_photo_lock_service.dart';

class ProgressPhotoLockGuard {
  static bool _isUnlocked = false;
  static Future<bool>? _unlockFuture;

  static bool get isUnlocked => _isUnlocked;

  static void lock() {
    _isUnlocked = false;
  }

  static void markUnlocked() {
    _isUnlocked = true;
  }

  static Future<bool> requireUnlock(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    if (!settings.progressPhotoLockEnabled) {
      _isUnlocked = true;
      return true;
    }

    if (_isUnlocked) return true;

    _unlockFuture ??= _authenticate(context);
    final unlocked = await _unlockFuture!;
    _unlockFuture = null;
    return unlocked;
  }

  static Future<bool> _authenticate(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final result = await ProgressPhotoLockService.authenticate(
      localizedReason: l10n.progressPhotoAuthReason,
    );

    if (!context.mounted) return false;

    switch (result) {
      case ProgressPhotoAuthResult.success:
        _isUnlocked = true;
        return true;
      case ProgressPhotoAuthResult.unavailable:
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.progressPhotoLockUnavailable)),
        );
        return false;
      case ProgressPhotoAuthResult.failed:
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.progressPhotoUnlockFailed)),
        );
        return false;
    }
  }
}

class ProgressPhotoLockScope extends StatefulWidget {
  final Widget child;

  const ProgressPhotoLockScope({super.key, required this.child});

  @override
  State<ProgressPhotoLockScope> createState() => _ProgressPhotoLockScopeState();
}

class _ProgressPhotoLockScopeState extends State<ProgressPhotoLockScope>
    with WidgetsBindingObserver {
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlockIfNeeded());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      ProgressPhotoLockGuard.lock();
      if (mounted) setState(() {});
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _unlockIfNeeded();
    }
  }

  Future<void> _unlockIfNeeded() async {
    if (_isAuthenticating) return;

    final settings = context.read<SettingsProvider>();
    if (!settings.progressPhotoLockEnabled ||
        ProgressPhotoLockGuard.isUnlocked) {
      if (mounted) setState(() {});
      return;
    }

    setState(() => _isAuthenticating = true);
    await ProgressPhotoLockGuard.requireUnlock(context);
    if (!mounted) return;
    setState(() => _isAuthenticating = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    if (!settings.progressPhotoLockEnabled ||
        ProgressPhotoLockGuard.isUnlocked) {
      return widget.child;
    }

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.progressPhotos)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.progressPhotosLocked,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _isAuthenticating ? null : _unlockIfNeeded,
                  icon: _isAuthenticating
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.lock_open_outlined),
                  label: Text(l10n.unlockProgressPhotos),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
