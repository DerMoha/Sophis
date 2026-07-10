import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/progress_photo.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/screens/progress_photo_lock_guard.dart';
import 'package:sophis/ui/components/progress_photo_slider.dart';
import 'package:sophis/ui/components/modal_sheet.dart';

enum CompareMode { sideBySide, slider }

class ProgressPhotoCompare extends StatefulWidget {
  const ProgressPhotoCompare({super.key});

  @override
  State<ProgressPhotoCompare> createState() => _ProgressPhotoCompareState();
}

class _ProgressPhotoCompareState extends State<ProgressPhotoCompare> {
  ProgressPhoto? _before;
  ProgressPhoto? _after;
  CompareMode _compareMode = CompareMode.sideBySide;

  @override
  void initState() {
    super.initState();
    final photos = context.read<NutritionProvider>().photos;
    if (photos.length >= 2) {
      _before = photos.last;
      _after = photos.first;
    }
  }

  Future<void> _shareComparison() async {
    if (_before == null || _after == null) return;
    final files = [
      XFile(_before!.imagePath),
      XFile(_after!.imagePath),
    ];
    await Share.shareXFiles(files, text: 'Progress Comparison');
  }

  Future<void> _selectPhoto(bool isBefore) async {
    final photos = context.read<NutritionProvider>().photos;
    final l10n = AppLocalizations.of(context)!;

    final selected = await showModalBottomSheet<ProgressPhoto>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PhotoSelectorSheet(
        photos: photos,
        title: isBefore ? l10n.selectBeforePhoto : l10n.selectAfterPhoto,
      ),
    );

    if (selected != null) {
      setState(() {
        if (isBefore) {
          _before = selected;
        } else {
          _after = selected;
        }
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String? _getDuration() {
    if (_before == null || _after == null) return null;
    final diff = _after!.timestamp.difference(_before!.timestamp);
    final days = diff.inDays;
    if (days < 1) return '<1 day';
    if (days == 1) return '1 day';
    return '$days days';
  }

  String? _getWeightDelta() {
    if (_before?.weightKg == null || _after?.weightKg == null) return null;
    final delta = _after!.weightKg! - _before!.weightKg!;
    final sign = delta >= 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(1)} kg';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final showContent = _before != null && _after != null;

    return ProgressPhotoLockScope(
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.compare),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          actions: [
            if (showContent)
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: _shareComparison,
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (showContent) _buildModeSelector(theme, l10n),
              Expanded(
                child: showContent
                    ? _buildComparisonView(theme, l10n)
                    : _buildPhotoSelectionGrid(theme, l10n),
              ),
              if (showContent) _buildStatsBar(l10n, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector(ThemeData theme, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeTab(
              label: l10n.sideBySide,
              isSelected: _compareMode == CompareMode.sideBySide,
              onTap: () =>
                  setState(() => _compareMode = CompareMode.sideBySide),
              theme: theme,
            ),
          ),
          Expanded(
            child: _buildModeTab(
              label: l10n.interactiveSlider,
              isSelected: _compareMode == CompareMode.slider,
              onTap: () => setState(() => _compareMode = CompareMode.slider),
              theme: theme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.animFast,
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonView(ThemeData theme, AppLocalizations l10n) {
    if (_compareMode == CompareMode.slider) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: AspectRatio(
          aspectRatio: 0.72,
          child: ProgressPhotoSlider(
            beforeImage: File(_before!.imagePath),
            afterImage: File(_after!.imagePath),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildPhotoColumn(
            l10n.before,
            _before,
            () => _selectPhoto(true),
          ),
        ),
        Container(
          width: 1,
          color: theme.colorScheme.outline.withValues(alpha: 0.12),
        ),
        Expanded(
          child: _buildPhotoColumn(
            l10n.after,
            _after,
            () => _selectPhoto(false),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSelectionGrid(ThemeData theme, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: _buildPhotoColumn(
            l10n.before,
            _before,
            () => _selectPhoto(true),
          ),
        ),
        Container(
          width: 1,
          color: theme.colorScheme.outline.withValues(alpha: 0.12),
        ),
        Expanded(
          child: _buildPhotoColumn(
            l10n.after,
            _after,
            () => _selectPhoto(false),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoColumn(
    String label,
    ProgressPhoto? photo,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: photo != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      child: Image.file(
                        File(photo.imagePath),
                        fit: BoxFit.cover,
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 40,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.35),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to select',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            if (photo != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(
                      _formatDate(photo.timestamp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (photo.weightKg != null)
                      Text(
                        '${photo.weightKg!.toStringAsFixed(1)} kg',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBar(AppLocalizations l10n, ThemeData theme) {
    final duration = _getDuration();
    final weightDelta = _getWeightDelta();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (duration != null)
                  _buildStat(l10n.duration, duration, theme),
                if (weightDelta != null)
                  _buildStat(l10n.weightDelta, weightDelta, theme),
              ],
            ),
            if (_compareMode == CompareMode.slider) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => _selectPhoto(true),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text(
                      l10n.changeBefore,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: () => _selectPhoto(false),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text(
                      l10n.changeAfter,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, ThemeData theme) {
    final isLoss = value.contains('-');

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: label.contains('Weight') || value.contains('kg')
                ? (isLoss ? AppTheme.success : AppTheme.warning)
                : theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _PhotoSelectorSheet extends StatelessWidget {
  final List<ProgressPhoto> photos;
  final String title;

  const _PhotoSelectorSheet({
    required this.photos,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return ModalSheetSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ModalSheetHandle(),
          ModalSheetHeader(
            icon: Icons.photo_library_outlined,
            iconColor: AppTheme.emerald,
            title: title,
          ),
          const SizedBox(height: 8),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.8,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];
                return GestureDetector(
                  onTap: () => Navigator.pop(context, photo),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    child: Image.file(
                      File(photo.imagePath),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
