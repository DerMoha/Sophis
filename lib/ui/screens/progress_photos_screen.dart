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
            child: Text(l10n.delete, style: const TextStyle(color: AppTheme.error)),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.progressPhotos),
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
    );
  }

  Widget _buildFilterBar(AppLocalizations l10n, ThemeData theme) {
    final labels = [l10n.all, l10n.front, l10n.side, l10n.back, l10n.other];
    final values = [null, PhotoCategory.front, PhotoCategory.side, PhotoCategory.back, PhotoCategory.other];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(labels.length, (index) {
            final isSelected = _showAll
                ? values[index] == null
                : values[index] == _filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(labels[index]),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    if (values[index] == null) {
                      _showAll = true;
                    } else {
                      _showAll = false;
                      _filter = values[index]!;
                    }
                  });
                },
                selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
        childAspectRatio: 0.85,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return FadeInSlide(
          index: index,
          child: _PhotoTile(
            photo: photo,
            onTap: () => _openViewer(context, photos, index),
            onLongPress: () => _deletePhoto(photo.id),
          ),
        );
      },
    );
  }

  void _openViewer(BuildContext context, List<ProgressPhoto> photos, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProgressPhotoViewer(
          photos: photos,
          initialIndex: index,
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddPhotoSheet(),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final ProgressPhoto photo;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PhotoTile({
    required this.photo,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbPath = '${photo.imagePath.replaceAll('.jpg', '')}_thumb.jpg';
    final thumbFile = File(thumbPath);
    final hasThumb = thumbFile.existsSync();

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
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: hasThumb
                      ? Image.file(
                          thumbFile,
                          fit: BoxFit.cover,
                        )
                      : Image.file(
                          File(photo.imagePath),
                          fit: BoxFit.cover,
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(photo.timestamp),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (photo.weightKg != null)
                        Text(
                          '${photo.weightKg!.toStringAsFixed(1)} kg',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
