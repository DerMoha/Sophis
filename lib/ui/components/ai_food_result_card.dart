import 'package:flutter/material.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/components/ai_food_result.dart';

class AiFoodResultCard extends StatelessWidget {
  final EditableFoodResult result;
  final VoidCallback onEdit;
  final VoidCallback onShare;
  final VoidCallback onAdd;
  final bool allowComments;

  const AiFoodResultCard({
    super.key,
    required this.result,
    required this.onEdit,
    required this.onShare,
    required this.onAdd,
    this.allowComments = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final food = result.currentAnalysis;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    food.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    result.isModified ? Icons.edit : Icons.edit_outlined,
                    size: 20,
                    color: result.isModified
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onEdit,
                  tooltip: l10n.edit,
                ),
              ],
            ),
            if (result.isModified)
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit,
                      size: 12,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.aiEstimateModified,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              '${food.portionDisplay} • ${food.caloriesDisplay}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            ExpansionTile(
              key: PageStorageKey(result),
              maintainState: true,
              onExpansionChanged: (expanded) {
                if (!expanded) FocusScope.of(context).unfocus();
              },
              initiallyExpanded: result.commentController.text.isNotEmpty,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              dense: true,
              minTileHeight: 40,
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                allowComments ? l10n.foodResultDetails : l10n.nutrition,
                style: theme.textTheme.bodySmall,
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    food.macrosDisplay,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (allowComments) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: result.commentController,
                    minLines: 1,
                    maxLines: 2,
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: l10n.aiFoodComment,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                        borderSide:
                            BorderSide(color: theme.colorScheme.primary),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppTheme.spaceSM,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.share_outlined,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: onShare,
                      tooltip: l10n.share,
                    ),
                    result.isAdded
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.success,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMD),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check,
                                  color: theme.colorScheme.onPrimary,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.added,
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: onAdd,
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(l10n.add),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                          ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
