import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/progress_photo.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/screens/progress_photos_screen.dart';
import 'package:sophis/ui/components/add_photo_sheet.dart';

class ProgressPhotosDashboardCard extends StatelessWidget {
  const ProgressPhotosDashboardCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final photos = context.watch<NutritionProvider>().photos;
    final latest = photos.isNotEmpty ? photos.first : null;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        AppTheme.slideRoute(const ProgressPhotosScreen()),
      ),
      child: Container(
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
                  child: Text(
                    l10n.progressPhotos,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (latest != null)
                  Text(
                    l10n.totalPhotos(photos.length),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (latest != null)
              _buildLatestPreview(context, latest, theme)
            else
              _buildEmptyState(context, l10n, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestPreview(BuildContext context, ProgressPhoto photo, ThemeData theme) {
    final thumbPath = '${photo.imagePath.replaceAll('.jpg', '')}_thumb.jpg';
    final thumbFile = File(thumbPath);
    final hasThumb = thumbFile.existsSync();

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          child: hasThumb
              ? Image.file(
                  thumbFile,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                )
              : Image.file(
                  File(photo.imagePath),
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
        ),
        const SizedBox(width: 12),
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
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_a_photo_outlined),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const AddPhotoSheet(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.noPhotosSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const AddPhotoSheet(),
            );
          },
          icon: const Icon(Icons.camera_alt_outlined, size: 18),
          label: Text(l10n.takePhoto),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
