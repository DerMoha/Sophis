import 'package:flutter/material.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/ui/theme/app_theme.dart';

class WaterSizesDialog extends StatefulWidget {
  final SettingsProvider settings;
  final AppLocalizations l10n;

  const WaterSizesDialog({
    super.key,
    required this.settings,
    required this.l10n,
  });

  @override
  State<WaterSizesDialog> createState() => _WaterSizesDialogState();
}

class _WaterSizesDialogState extends State<WaterSizesDialog> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    final sizes = widget.settings.waterSizes;
    _controllers = [
      TextEditingController(text: sizes[0].toString()),
      TextEditingController(text: sizes[1].toString()),
      TextEditingController(text: sizes[2].toString()),
      TextEditingController(text: sizes[3].toString()),
    ];
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final labels = [
      l10n.waterSizeSmall,
      l10n.waterSizeMedium,
      l10n.waterSizeLarge,
      l10n.waterSizeExtraLarge,
    ];

    return AlertDialog(
      title: Text(l10n.waterSizes),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _controllers[i],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: labels[i],
                  suffixText: 'ml',
                  prefixIcon: const Icon(
                    Icons.water_drop_outlined,
                    color: AppTheme.water,
                    size: 20,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            final newSizes =
                _controllers.map((c) => int.tryParse(c.text) ?? 250).toList();
            widget.settings.setWaterSizes(
              newSizes[0],
              newSizes[1],
              newSizes[2],
              newSizes[3],
            );
            Navigator.pop(context);
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
