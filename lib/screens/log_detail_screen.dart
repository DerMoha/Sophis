import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/log_service.dart';

/// Screen for viewing the contents of a single log file
class LogDetailScreen extends StatefulWidget {
  final LogFile logFile;

  const LogDetailScreen({super.key, required this.logFile});

  @override
  State<LogDetailScreen> createState() => _LogDetailScreenState();
}

class _LogDetailScreenState extends State<LogDetailScreen> {
  String? _content;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() => _isLoading = true);
    try {
      final content = await widget.logFile.file.readAsString();
      setState(() {
        _content = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load log: $e')),
        );
      }
    }
  }

  Future<void> _shareLog() async {
    try {
      await Share.shareXFiles(
        [XFile(widget.logFile.file.path)],
        subject: 'Sophis Debug Log - ${widget.logFile.formattedDate}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share log: $e')),
        );
      }
    }
  }

  Future<void> _copyToClipboard() async {
    if (_content == null) return;

    await Clipboard.setData(ClipboardData(text: _content!));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Log copied to clipboard'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.logFile.formattedDate),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            onPressed: _content != null ? _copyToClipboard : null,
            tooltip: 'Copy to Clipboard',
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareLog,
            tooltip: 'Share',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _content == null || _content!.isEmpty
              ? _buildEmptyState(theme)
              : _buildContent(theme),
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
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Log file is empty',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    // Split content into lines and apply color coding
    final lines = _content!.split('\n');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText.rich(
        TextSpan(
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: theme.colorScheme.onSurface,
          ),
          children: lines.map((line) {
            return TextSpan(
              text: '$line\n',
              style: TextStyle(
                color: _getColorForLine(line, theme),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _getColorForLine(String line, ThemeData theme) {
    // Color-code by log level
    if (line.contains('ERROR') || line.contains('FATAL')) {
      return Colors.red.shade400;
    } else if (line.contains('WARNING') || line.contains('WARN')) {
      return Colors.orange.shade400;
    } else if (line.contains('INFO')) {
      return Colors.blue.shade400;
    } else if (line.contains('DEBUG')) {
      return theme.colorScheme.onSurfaceVariant;
    } else {
      return theme.colorScheme.onSurface;
    }
  }
}
