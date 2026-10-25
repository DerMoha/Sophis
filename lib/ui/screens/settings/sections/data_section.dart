import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/services/data_export_service.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/providers/supplements_provider.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/ui/components/common/app_surface.dart';

class DataSection extends StatefulWidget {
  const DataSection({super.key});

  @override
  State<DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends State<DataSection> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isDeleting = false;

  Future<void> _handleExport(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    setState(() => _isExporting = true);

    final nutritionProvider = context.read<NutritionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final exportResult = await DataExportService.exportData(nutritionProvider);

    if (!mounted) return;

    final message = switch (exportResult) {
      Success<void>() => l10n.exportSuccess,
      Failure<void>() => l10n.exportFailed,
    };

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (mounted) {
      setState(() => _isExporting = false);
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

    final importResult = await DataExportService.importData(nutritionProvider);

    if (!mounted) return;

    switch (importResult) {
      case Success<ImportResult>(value: final result):
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
      case Failure<ImportResult>(message: final message):
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }

    if (mounted) {
      setState(() => _isImporting = false);
    }
  }

  Future<void> _handleDeleteAll(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteAllDataTitle),
        content: Text(l10n.deleteAllDataConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    final nutrition = this.context.read<NutritionProvider>();
    final settings = this.context.read<SettingsProvider>();
    final supplements = this.context.read<SupplementsProvider>();
    final messenger = ScaffoldMessenger.of(this.context);
    await nutrition.clearAllData();
    await supplements.refresh();
    await settings.resetAfterDataDeletion();
    if (!mounted) return;
    setState(() => _isDeleting = false);
    messenger.showSnackBar(SnackBar(content: Text(l10n.deleteAllDataSuccess)));
    Navigator.of(this.context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        AppSection(
          title: l10n.backup,
          footer: l10n.autoRestoreBackupNote,
          children: [
            AppRow(
              title: l10n.exportData,
              subtitle: l10n.exportDataSubtitle,
              icon: Icons.ios_share_outlined,
              isLoading: _isExporting,
              onTap: () => _handleExport(context, l10n),
            ),
            AppRow(
              title: l10n.importData,
              subtitle: l10n.importDataSubtitle,
              icon: Icons.download_outlined,
              isLoading: _isImporting,
              showDivider: false,
              onTap: () => _handleImport(context, l10n),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AppSection(
          title: l10n.dangerZone,
          children: [
            AppRow(
              title: l10n.deleteAllData,
              subtitle: l10n.deleteAllDataSubtitle,
              icon: Icons.delete_forever_outlined,
              isLoading: _isDeleting,
              destructive: true,
              showDivider: false,
              onTap: () => _handleDeleteAll(context, l10n),
            ),
          ],
        ),
      ],
    );
  }
}
