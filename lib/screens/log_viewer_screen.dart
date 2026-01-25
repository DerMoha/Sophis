import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../services/log_service.dart';
import '../theme/app_theme.dart';
import '../widgets/organic_components.dart';
import 'log_detail_screen.dart';

/// Screen for viewing and sharing debug log files
class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  List<LogFile>? _logFiles;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogFiles();
  }

  Future<void> _loadLogFiles() async {
    setState(() => _isLoading = true);
    try {
      final files = await LogService.instance.getLogFiles();
      setState(() {
        _logFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load logs: $e')),
        );
      }
    }
  }

  Future<void> _shareAllLogs() async {
    if (_logFiles == null || _logFiles!.isEmpty) return;

    try {
      final files = _logFiles!.map((f) => XFile(f.file.path)).toList();

      await Share.shareXFiles(
        files,
        subject: 'Sophis Debug Logs - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
        text: 'Debug logs from Sophis nutrition tracker',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share logs: $e')),
        );
      }
    }
  }

  Future<void> _shareLog(LogFile logFile) async {
    try {
      await Share.shareXFiles(
        [XFile(logFile.file.path)],
        subject: 'Sophis Debug Log - ${logFile.formattedDate}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share log: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Logs'),
        actions: [
          if (_logFiles != null && _logFiles!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: _shareAllLogs,
              tooltip: 'Share All Logs',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logFiles == null || _logFiles!.isEmpty
              ? _buildEmptyState(theme)
              : _buildLogList(theme),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No logs available',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enable logging in Settings to start recording app activity',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogList(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadLogFiles,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _logFiles!.length,
        itemBuilder: (context, index) {
          final logFile = _logFiles![index];
          return _buildLogCard(logFile, theme);
        },
      ),
    );
  }

  Widget _buildLogCard(LogFile logFile, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: () {
          Navigator.of(context).push(
            AppTheme.slideRoute(LogDetailScreen(logFile: logFile)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.description_outlined,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // File info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      logFile.formattedDate,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.data_usage_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          logFile.formattedSize,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.format_list_numbered_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${logFile.entryCount} entries',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Share button
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () => _shareLog(logFile),
                tooltip: 'Share',
              ),

              // Arrow
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
