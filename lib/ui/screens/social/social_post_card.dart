import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sophis/providers/social_provider.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/social/social_repository.dart';
import 'package:sophis/ui/components/common/app_surface.dart';
import 'package:sophis/ui/screens/social/social_import_screen.dart';
import 'package:sophis/ui/screens/social/social_publish_screen.dart';
import 'package:sophis/ui/theme/app_theme.dart';

class SocialPostCard extends StatelessWidget {
  final SocialPost post;
  const SocialPostCard({super.key, required this.post});

  Future<void> _react(BuildContext context, String? kind) async {
    final social = context.read<SocialProvider>();
    final epoch = social.sessionVersion;
    final result = await social.runtime?.repository.react(post.id, kind);
    if (!context.mounted || epoch != social.sessionVersion) return;
    final message =
        result is Failure<void> ? result.message : 'Reaction saved to send.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    await social.refresh();
  }

  Future<void> _delete(BuildContext context) async {
    final social = context.read<SocialProvider>();
    final epoch = social.sessionVersion;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this post?'),
        content: const Text(
          'Followers will lose server access when deletion is delivered. Diary entries and recipes they already imported remain their own copies.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete post'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !context.mounted ||
        epoch != social.sessionVersion) {
      return;
    }
    await social.deletePost(post.id);
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialProvider>();
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.snapshot.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(post.isRecipe ? 'Recipe' : 'Meal'),
          if (post.caption != null) Text(post.caption!),
          const SizedBox(height: 8),
          for (final item in post.snapshot.items) Text(item.name),
          if (post.nutritionVisible)
            Text(
              '${post.snapshot.items.fold(0.0, (sum, item) => sum + item.calories).round()} kcal · ${post.snapshot.servings} servings',
            )
          else
            const Text(
              'Nutrition is hidden. You can enter it when making your copy.',
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: social.busy
                    ? null
                    : () => Navigator.push(
                          context,
                          AppTheme.slideRoute(SocialImportScreen(post: post)),
                        ),
                icon: const Icon(Icons.add),
                label: const Text('Add to diary'),
              ),
              if (post.isRecipe)
                TextButton.icon(
                  onPressed: social.busy
                      ? null
                      : () => Navigator.push(
                            context,
                            AppTheme.slideRoute(
                              SocialImportScreen(
                                post: post,
                                saveRecipe: true,
                              ),
                            ),
                          ),
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Save recipe'),
                ),
              PopupMenuButton<String>(
                enabled: !social.busy,
                tooltip: 'React',
                onSelected: (kind) =>
                    _react(context, kind == 'remove' ? null : kind),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'heart', child: Text('Love it')),
                  PopupMenuItem(value: 'encourage', child: Text('Well done')),
                  PopupMenuItem(value: 'yum', child: Text('Looks delicious')),
                  PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove my reaction'),
                  ),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('React'),
                ),
              ),
              if (post.authorId == social.accountId) ...[
                TextButton(
                  onPressed: social.busy
                      ? null
                      : () => Navigator.push(
                            context,
                            AppTheme.slideRoute(
                              SocialPublishScreen(
                                snapshot: post.snapshot,
                                isRecipe: post.isRecipe,
                                editing: post,
                              ),
                            ),
                          ),
                  child: const Text('Edit post'),
                ),
                TextButton(
                  onPressed: social.busy ? null : () => _delete(context),
                  child: const Text('Delete post'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
