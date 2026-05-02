import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/progress_photo.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/ui/theme/app_theme.dart';

class ProgressPhotoCompare extends StatefulWidget {
  const ProgressPhotoCompare({super.key});

  @override
  State<ProgressPhotoCompare> createState() => _ProgressPhotoCompareState();
}

class _ProgressPhotoCompareState extends State<ProgressPhotoCompare> {
  ProgressPhoto? _before;
  ProgressPhoto? _after;

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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.compare),
        actions: [
          if (_before != null && _after != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: _shareComparison,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Row(
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
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  Expanded(
                    child: _buildPhotoColumn(
                      l10n.after,
                      _after,
                      () => _selectPhoto(false),
                    ),
                  ),
                ],
              ),
            ),
            _buildStatsBar(l10n, theme),
          ],
        ),
      ),
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
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
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
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to select',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
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
                      style: theme.textTheme.bodySmall,
                    ),
                    if (photo.weightKg != null)
                      Text(
                        '${photo.weightKg!.toStringAsFixed(1)} kg',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            if (duration != null)
              _buildStat(l10n.duration, duration, theme),
            if (weightDelta != null)
              _buildStat(l10n.weightDelta, weightDelta, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
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
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: theme.textTheme.titleLarge,
              ),
            ),
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
      ),
    );
  }
}
