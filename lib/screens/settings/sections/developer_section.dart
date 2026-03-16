import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/log_service.dart';
import '../../../services/settings_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/settings/settings_tiles.dart';
import '../../log_viewer_screen.dart';

class DeveloperSection extends StatelessWidget {
  final SettingsProvider settings;

  const DeveloperSection({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        SwitchTile(
          title: 'Enable Debug Logging',
          subtitle: 'Help diagnose issues by recording app activity',
          icon: Icons.terminal_outlined,
          value: settings.debugLoggingEnabled,
          onChanged: settings.setDebugLoggingEnabled,
        ),
        const SizedBox(height: 12),
        NavigationTile(
          title: 'View Debug Logs',
          subtitle: 'Export logs for troubleshooting',
          icon: Icons.list_alt_outlined,
          onTap: () {
            Navigator.of(context).push(
              AppTheme.slideRoute(const LogViewerScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        NavigationTile(
          title: 'Clear Debug Logs',
          subtitle: 'Delete all diagnostic logs',
          icon: Icons.delete_outline,
          onTap: () => _handleClearLogs(context),
        ),
      ],
    );
  }

  Future<void> _handleClearLogs(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearDebugLogs),
        content: Text(l10n.clearDebugLogsConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await LogService.instance.clearLogs();

      if (!context.mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.debugLogsCleared),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.clearLogsFailed(e.toString())),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
