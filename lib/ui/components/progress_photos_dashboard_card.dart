import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/progress_photo.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/screens/progress_photos_screen.dart';
import 'package:sophis/ui/components/add_photo_sheet.dart';
import 'package:sophis/ui/screens/progress_photo_lock_guard.dart';

class ProgressPhotosDashboardCard extends StatefulWidget {
  const ProgressPhotosDashboardCard({super.key});

  @override
  State<ProgressPhotosDashboardCard> createState() => _ProgressPhotosDashboardCardState();
}

class _ProgressPhotosDashboardCardState extends State<ProgressPhotosDashboardCard> {
  bool _revealPhotos = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final photos = context.watch<NutritionProvider>().photos;
    final latest = photos.isNotEmpty ? photos.first : null;
    final first = photos.isNotEmpty ? photos.last : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.photo_camera_outlined,
                  size: 18,
                  color: AppTheme.emerald,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openProgressPhotos(context),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.progressPhotos,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (latest != null)
                        Text(
                          l10n.totalPhotos(photos.length),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (latest != null) ...[
                IconButton(
                  icon: Icon(
                    _revealPhotos ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  tooltip: _revealPhotos ? 'Hide Photos' : 'Reveal Photos',
                  onPressed: _toggleReveal,
                ),
                IconButton(
                  icon: const Icon(Icons.add_a_photo_outlined, size: 20),
                  onPressed: () => _showAddSheet(context),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (latest == null)
            _buildEmptyState(context, l10n, theme)
          else if (photos.length == 1)
            _buildSinglePhotoPreview(context, latest, l10n, theme)
          else
            _buildComparisonPreview(context, first!, latest, l10n, theme, photos.length),
        ],
      ),
    );
  }

  Future<void> _toggleReveal() async {
    if (!_revealPhotos) {
      final unlocked = await ProgressPhotoLockGuard.requireUnlock(context);
      if (!mounted || !unlocked) return;
      setState(() => _revealPhotos = true);
    } else {
      setState(() => _revealPhotos = false);
    }
  }

  Future<void> _openProgressPhotos(BuildContext context) async {
    final unlocked = await ProgressPhotoLockGuard.requireUnlock(context);
    if (!context.mounted || !unlocked) return;

    await Navigator.push(
      context,
      AppTheme.slideRoute(const ProgressPhotosScreen()),
    );
  }

  Future<void> _showAddSheet(BuildContext context) async {
    final unlocked = await ProgressPhotoLockGuard.requireUnlock(context);
    if (!context.mounted || !unlocked) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddPhotoSheet(),
    );
  }

  Widget _buildBlurredThumbnail(ProgressPhoto photo, String label, ThemeData theme) {
    final thumbPath = '${photo.imagePath.replaceAll('.jpg', '')}_thumb.jpg';
    final thumbFile = File(thumbPath);
    final fileToUse = thumbFile.existsSync() ? thumbFile : File(photo.imagePath);

    return Column(
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: () => _openProgressPhotos(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: _revealPhotos ? 0 : 25,
                      sigmaY: _revealPhotos ? 0 : 25,
                    ),
                    child: Image.file(
                      fileToUse,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            if (!_revealPhotos)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.blur_on,
                      color: Colors.white70,
                      size: 24,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 9,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.05),
            theme.colorScheme.primary.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.camera_alt_outlined,
              size: 28,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.noPhotosSubtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => _showAddSheet(context),
            icon: const Icon(Icons.add_a_photo_outlined, size: 18),
            label: Text(l10n.takePhoto),
          ),
        ],
      ),
    );
  }

  Widget _buildSinglePhotoPreview(
    BuildContext context,
    ProgressPhoto photo,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Row(
      children: [
        _buildBlurredThumbnail(photo, l10n.front, theme),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDate(photo.timestamp),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (photo.weightKg != null)
                Text(
                  '${photo.weightKg!.toStringAsFixed(1)} kg',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                'Add another photo to unlock progression comparison!',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonPreview(
    BuildContext context,
    ProgressPhoto first,
    ProgressPhoto latest,
    AppLocalizations l10n,
    ThemeData theme,
    int count,
  ) {
    final diff = latest.timestamp.difference(first.timestamp);
    final days = diff.inDays;

    String? weightDelta;
    bool isLoss = false;
    if (first.weightKg != null && latest.weightKg != null) {
      final delta = latest.weightKg! - first.weightKg!;
      isLoss = delta < 0;
      final sign = delta >= 0 ? '+' : '';
      weightDelta = '$sign${delta.toStringAsFixed(1)} kg';
    }

    return Row(
      children: [
        _buildBlurredThumbnail(first, l10n.before, theme),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _openProgressPhotos(context),
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  days == 0 ? 'First Day' : l10n.daysSinceFirstPhoto(days),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (weightDelta != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isLoss ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      weightDelta,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isLoss ? AppTheme.success : AppTheme.warning,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  'Tap to compare',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        _buildBlurredThumbnail(latest, l10n.after, theme),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
