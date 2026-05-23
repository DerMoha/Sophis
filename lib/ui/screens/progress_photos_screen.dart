import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/progress_photo.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/theme/animations.dart';
import 'package:sophis/ui/components/add_photo_sheet.dart';
import 'package:sophis/ui/screens/progress_photo_viewer.dart';
import 'package:sophis/ui/screens/progress_photo_compare.dart';
import 'package:sophis/ui/screens/progress_photo_lock_guard.dart';

class ProgressPhotosScreen extends StatefulWidget {
  const ProgressPhotosScreen({super.key});

  @override
  State<ProgressPhotosScreen> createState() => _ProgressPhotosScreenState();
}

class _ProgressPhotosScreenState extends State<ProgressPhotosScreen> {
  PhotoCategory _filter = PhotoCategory.front;
  bool _showAll = true;

  List<ProgressPhoto> _getFilteredPhotos(List<ProgressPhoto> photos) {
    if (_showAll) return photos;
    return photos.where((p) => p.category == _filter).toList();
  }

  Future<void> _deletePhoto(String id) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deletePhotoConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.delete,
              style: const TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<NutritionProvider>().deleteProgressPhoto(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.photoDeleted)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final photos = context.watch<NutritionProvider>().photos;
    final filtered = _getFilteredPhotos(photos);

    return ProgressPhotoLockScope(
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.progressPhotos),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          actions: [
            if (photos.length >= 2)
              IconButton(
                icon: const Icon(Icons.compare_outlined),
                tooltip: l10n.compare,
                onPressed: () => Navigator.push(
                  context,
                  AppTheme.slideRoute(const ProgressPhotoCompare()),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.add_a_photo_outlined),
              tooltip: l10n.addProgressPhoto,
              onPressed: () => _showAddSheet(context),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildFilterBar(l10n, theme),
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState(l10n, theme)
                    : _buildPhotoGrid(filtered, theme),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddSheet(context),
          child: const Icon(Icons.camera_alt),
        ),
      ),
    );
  }

  Widget _buildFilterBar(AppLocalizations l10n, ThemeData theme) {
    final labels = [l10n.all, l10n.front, l10n.side, l10n.back, l10n.other];
    final values = [
      null,
      PhotoCategory.front,
      PhotoCategory.side,
      PhotoCategory.back,
      PhotoCategory.other,
    ];

    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(labels.length, (index) {
            final isSelected =
                _showAll ? values[index] == null : values[index] == _filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (values[index] == null) {
                      _showAll = true;
                    } else {
                      _showAll = false;
                      _filter = values[index]!;
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: AppTheme.animFast,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_camera_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noPhotosYet,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noPhotosSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGrid(List<ProgressPhoto> photos, ThemeData theme) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];

        // Calculate weight delta relative to the chronologically prior photo (which is at index + 1)
        double? weightDelta;
        if (index < photos.length - 1) {
          final prior = photos[index + 1];
          if (photo.weightKg != null && prior.weightKg != null) {
            weightDelta = photo.weightKg! - prior.weightKg!;
          }
        }

        return FadeInSlide(
          index: index,
          child: _PhotoTile(
            photo: photo,
            weightDelta: weightDelta,
            onTap: () => _openViewer(context, photos, index),
            onLongPress: () => _deletePhoto(photo.id),
          ),
        );
      },
    );
  }

  void _openViewer(
    BuildContext context,
    List<ProgressPhoto> photos,
    int index,
  ) {
    Navigator.push(
      context,
      AppTheme.slideRoute(
        ProgressPhotoViewer(
          photos: photos,
          initialIndex: index,
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddPhotoSheet(),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final ProgressPhoto photo;
  final double? weightDelta;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PhotoTile({
    required this.photo,
    this.weightDelta,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final thumbPath = '${photo.imagePath.replaceAll('.jpg', '')}_thumb.jpg';
    final thumbFile = File(thumbPath);
    final hasThumb = thumbFile.existsSync();
    final fileToUse = hasThumb ? thumbFile : File(photo.imagePath);

    String? deltaText;
    bool isLoss = false;
    if (weightDelta != null) {
      isLoss = weightDelta! < 0;
      final sign = weightDelta! >= 0 ? '+' : '';
      deltaText = '$sign${weightDelta!.toStringAsFixed(1)} kg';
    }

    return Hero(
      tag: 'photo_${photo.id}',
      child: Material(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.file(
                          fileToUse,
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Category Overlay Badge
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            _getCategoryLabel(photo.category, l10n).toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(photo.timestamp),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (photo.weightKg != null)
                            Text(
                              '${photo.weightKg!.toStringAsFixed(1)} kg',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          if (deltaText != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isLoss ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                deltaText,
                                style: TextStyle(
                                  color: isLoss ? AppTheme.success : AppTheme.warning,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getCategoryLabel(PhotoCategory category, AppLocalizations l10n) {
    switch (category) {
      case PhotoCategory.front:
        return l10n.front;
      case PhotoCategory.side:
        return l10n.side;
      case PhotoCategory.back:
        return l10n.back;
      case PhotoCategory.other:
        return l10n.other;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
