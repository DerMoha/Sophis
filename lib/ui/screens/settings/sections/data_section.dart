import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/services/data_export_service.dart';
import 'package:sophis/services/nutrition_provider.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/components/settings/settings_tiles.dart';

class DataSection extends StatefulWidget {
  const DataSection({super.key});

  @override
  State<DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends State<DataSection> {
  bool _isExporting = false;
  bool _isImporting = false;

  Future<void> _handleExport(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    setState(() => _isExporting = true);

    try {
      final nutritionProvider = context.read<NutritionProvider>();
      final messenger = ScaffoldMessenger.of(context);
      final success = await DataExportService.exportData(nutritionProvider);

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(success ? l10n.exportSuccess : l10n.exportFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _handleImport(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final nutritionProvider = context.read<NutritionProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.importData),
        content: Text(l10n.importConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.importData),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isImporting = true);

    try {
      final result = await DataExportService.importData(nutritionProvider);

      if (!mounted) return;

      if (result.success) {
        await nutritionProvider.reloadAll();
      }

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(result.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      children: [
        DataActionTile(
          title: l10n.exportData,
          subtitle: l10n.exportDataSubtitle,
          icon: Icons.upload_outlined,
          isLoading: _isExporting,
          onTap: () => _handleExport(context, l10n),
        ),
        const SizedBox(height: AppTheme.spaceSM2),
        DataActionTile(
          title: l10n.importData,
          subtitle: l10n.importDataSubtitle,
          icon: Icons.download_outlined,
          isLoading: _isImporting,
          onTap: () => _handleImport(context, l10n),
        ),
        const SizedBox(height: AppTheme.spaceSM2),
        Text(
          l10n.autoRestoreBackupNote,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
