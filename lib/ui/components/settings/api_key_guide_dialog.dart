import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';

class ApiKeyGuideDialog extends StatelessWidget {
  const ApiKeyGuideDialog({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = [
      (
        '1',
        'Go to Google AI Studio',
        'Visit aistudio.google.com in your browser',
        'aistudio.google.com'
      ),
      (
        '2',
        'Sign in',
        'Sign in with your Google account (or create one)',
        null
      ),
      ('3', 'Get API Key', 'Click the "Get API Key" button at the top', null),
      ('4', 'Create Key', 'Click "Create API Key" and copy your new key', null),
      (
        '5',
        'Paste in App',
        'Return here and paste your key in the field above',
        null
      ),
    ];

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.key_outlined,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          const Text('How to Get Your API Key'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Get a free Gemini API key from Google AI Studio:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.spaceLG2),
            ...steps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          step.$1,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.$2,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (step.$4 != null)
                            GestureDetector(
                              onTap: () => _launchUrl('https://${step.$4}'),
                              child: Text(
                                step.$3,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            )
                          else
                            Text(
                              step.$3,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The API key is stored securely on your device only.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
        ElevatedButton.icon(
          onPressed: () => _launchUrl('https://aistudio.google.com'),
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('Open AI Studio'),
        ),
      ],
    );
  }
}
