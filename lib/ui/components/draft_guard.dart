import 'dart:async';

import 'package:flutter/material.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';

/// Tracks the draft at entry, so reverting edits also removes the warning.
class DraftGuard extends StatefulWidget {
  final List<TextEditingController> controllers;
  final bool hasOtherChanges;
  final bool isSaving;
  final VoidCallback? onDiscard;
  final bool restoreOnDiscard;
  final Widget child;

  const DraftGuard({
    super.key,
    required this.controllers,
    required this.child,
    this.hasOtherChanges = false,
    this.isSaving = false,
    this.onDiscard,
    this.restoreOnDiscard = false,
  });

  @override
  State<DraftGuard> createState() => DraftGuardState();
}

class DraftGuardState extends State<DraftGuard> implements PopEntry<Object?> {
  ModalRoute<Object?>? _route;
  late List<String> _initialValues;
  bool _confirmed = false;
  bool _promptOpen = false;

  @override
  final ValueNotifier<bool> canPopNotifier = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _initialValues = widget.controllers.map((c) => c.text).toList();
    for (final controller in widget.controllers) {
      controller.addListener(_updateCanPop);
    }
    _updateCanPop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route == route) return;
    _route?.unregisterPopEntry(this);
    _route = route;
    _route?.registerPopEntry(this);
  }

  @override
  void didUpdateWidget(DraftGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateCanPop();
  }

  void _updateCanPop() {
    final dirty = widget.hasOtherChanges ||
        widget.controllers.asMap().entries.any(
              (entry) => entry.value.text != _initialValues[entry.key],
            );
    canPopNotifier.value = _confirmed || (!widget.isSaving && !dirty);
  }

  /// Call only after a successful commit, immediately before closing the route.
  void markSaved() {
    _confirmed = true;
    canPopNotifier.value = true;
  }

  /// Re-enable protection when a successful action leaves the form open.
  void resumeEditing() {
    _confirmed = false;
    _updateCanPop();
  }

  @override
  void onPopInvoked(bool didPop) => onPopInvokedWithResult(didPop, null);

  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {
    if (didPop ||
        canPopNotifier.value ||
        widget.isSaving ||
        _promptOpen ||
        !mounted) {
      return;
    }
    _promptOpen = true;
    // A drag may invoke this while the Navigator is locked in didPop.
    scheduleMicrotask(() => _confirmDiscard(result));
  }

  Future<void> _confirmDiscard(Object? result) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.discardDraftTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.keepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.discardDraft),
          ),
        ],
      ),
    );
    _promptOpen = false;
    if (!mounted || discard != true) return;
    if (widget.restoreOnDiscard) {
      for (var i = 0; i < widget.controllers.length; i++) {
        widget.controllers[i].text = _initialValues[i];
      }
    }
    widget.onDiscard?.call();
    markSaved();
    Navigator.of(context).pop(result);
  }

  @override
  void dispose() {
    _route?.unregisterPopEntry(this);
    for (final controller in widget.controllers) {
      controller.removeListener(_updateCanPop);
    }
    canPopNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Flutter's stock sheet drag uses pop directly. Honor draft guards for that
/// path too and restore the sheet after a rejected dismissal.
class _DraftSheetRoute<T> extends ModalBottomSheetRoute<T> {
  _DraftSheetRoute({
    required super.builder,
    required super.isScrollControlled,
    super.backgroundColor,
    super.shape,
    super.useSafeArea,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.modalBarrierColor,
    super.showDragHandle,
    super.sheetAnimationStyle,
  });

  @override
  bool didPop(T? result) {
    if (popDisposition == RoutePopDisposition.doNotPop) {
      onPopInvokedWithResult(false, result);
      controller?.forward();
      return false;
    }
    return super.didPop(result);
  }
}

Future<T?> showDraftBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  Color? backgroundColor,
  ShapeBorder? shape,
  bool useSafeArea = true,
  bool? showDragHandle,
}) {
  final navigator = Navigator.of(context);
  final localizations = MaterialLocalizations.of(context);
  return navigator.push<T>(
    _DraftSheetRoute<T>(
      builder: builder,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor,
      shape: shape,
      useSafeArea: useSafeArea,
      showDragHandle: showDragHandle,
      capturedThemes:
          InheritedTheme.capture(from: context, to: navigator.context),
      barrierLabel: localizations.scrimLabel,
      barrierOnTapHint:
          localizations.scrimOnTapHint(localizations.bottomSheetLabel),
      modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
    ),
  );
}
