import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/progress_photo.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/ui/theme/app_theme.dart';

class AddPhotoSheet extends StatefulWidget {
  const AddPhotoSheet({super.key});

  @override
  State<AddPhotoSheet> createState() => _AddPhotoSheetState();
}

class _AddPhotoSheetState extends State<AddPhotoSheet> {
  PhotoCategory _category = PhotoCategory.front;
  DateTime _timestamp = DateTime.now();
  double? _weightKg;
  String? _note;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<NutritionProvider>();
    _weightKg = provider.latestWeight?.weightKg;
  }

  Future<void> _pickImage(ImageSource source) async {
    final provider = context.read<NutritionProvider>();
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked == null) return;

    setState(() => _isLoading = true);
    try {
      final file = File(picked.path);
      await provider.addProgressPhoto(
        imageFile: file,
        timestamp: _timestamp,
        weightKg: _weightKg,
        note: _note,
        category: _category,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _timestamp,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _timestamp = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.addProgressPhoto,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Text(l10n.category, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _buildCategorySelector(l10n, theme),
            const SizedBox(height: 16),
            _buildDateRow(l10n, theme),
            const SizedBox(height: 16),
            _buildWeightField(l10n, theme),
            const SizedBox(height: 16),
            _buildNoteField(l10n, theme),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(l10n.takePhoto),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(l10n.chooseFromGallery),
                  ),
                ),
              ],
            ),
            if (_isLoading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector(AppLocalizations l10n, ThemeData theme) {
    final categories = [
      (PhotoCategory.front, l10n.front),
      (PhotoCategory.side, l10n.side),
      (PhotoCategory.back, l10n.back),
      (PhotoCategory.other, l10n.other),
    ];

    return Wrap(
      spacing: 8,
      children: categories.map((item) {
        final isSelected = _category == item.$1;
        return ChoiceChip(
          label: Text(item.$2),
          selected: isSelected,
          onSelected: (_) => setState(() => _category = item.$1),
          selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
          labelStyle: TextStyle(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateRow(AppLocalizations l10n, ThemeData theme) {
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Text(
              l10n.photoDate,
              style: theme.textTheme.bodyMedium,
            ),
            const Spacer(),
            Text(
              _formatDate(_timestamp),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightField(AppLocalizations l10n, ThemeData theme) {
    return TextField(
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: '${l10n.photoWeight} (kg)',
        prefixIcon: const Icon(Icons.monitor_weight_outlined),
      ),
      controller: TextEditingController(
        text: _weightKg?.toStringAsFixed(1) ?? '',
      ),
      onChanged: (value) {
        _weightKg = double.tryParse(value);
      },
    );
  }

  Widget _buildNoteField(AppLocalizations l10n, ThemeData theme) {
    return TextField(
      decoration: InputDecoration(
        labelText: l10n.photoNote,
        prefixIcon: const Icon(Icons.notes_outlined),
      ),
      maxLines: 2,
      onChanged: (value) => _note = value.isEmpty ? null : value,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
