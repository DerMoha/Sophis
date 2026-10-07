import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/models/social/social_snapshot.dart';
import 'package:sophis/providers/social_provider.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/social/social_repository.dart';
import 'package:sophis/ui/components/common/app_surface.dart';
import 'package:sophis/ui/components/settings/settings_tiles.dart';

class SocialPublishScreen extends StatefulWidget {
  final SocialSnapshot snapshot;
  final bool isRecipe;
  final SocialPost? editing;
  const SocialPublishScreen({
    super.key,
    required this.snapshot,
    required this.isRecipe,
    this.editing,
  });

  @override
  State<SocialPublishScreen> createState() => _SocialPublishScreenState();
}

class _SocialPublishScreenState extends State<SocialPublishScreen> {
  final _form = GlobalKey<FormState>();
  final _operationId = const Uuid().v4();
  late final TextEditingController _title;
  late final TextEditingController _caption;
  late bool _nutritionVisible;
  int? _sessionVersion;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.snapshot.title);
    _caption = TextEditingController(text: widget.editing?.caption ?? '');
    _nutritionVisible =
        widget.editing?.nutritionVisible ?? widget.snapshot.nutritionAvailable;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sessionVersion ??= context.read<SocialProvider>().sessionVersion;
  }

  @override
  void dispose() {
    _title.dispose();
    _caption.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_busy || !_form.currentState!.validate()) return;
    final social = context.read<SocialProvider>();
    final runtime = social.runtime;
    if (runtime == null || social.sessionVersion != _sessionVersion) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final snapshot = SocialSnapshot(
        title: _title.text.trim(),
        servings: widget.snapshot.servings,
        nutritionAvailable: widget.snapshot.nutritionAvailable,
        items: widget.snapshot.items,
      );
      final editing = widget.editing;
      final ServiceResult<Object?> result;
      if (editing == null) {
        result = await runtime.repository.publish(
          operationId: _operationId,
          snapshot: snapshot,
          nutritionVisible: _nutritionVisible,
          isRecipe: widget.isRecipe,
          caption: _caption.text.trim(),
        );
      } else {
        result = await runtime.repository.editPost(
          post: editing,
          operationId: _operationId,
          snapshot: snapshot,
          nutritionVisible: _nutritionVisible,
          caption: _caption.text.trim(),
        );
      }
      if (!mounted || social.sessionVersion != _sessionVersion) return;
      if (result is Failure<Object?>) {
        final message = result.message;
        setState(() => _message = message);
        return;
      }
      // Saving is durable. Network failures remain queued rather than being
      // misrepresented as a published post or losing the accepted snapshot.
      await social.refresh();
      if (!mounted || social.sessionVersion != _sessionVersion) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Saved to send. Refresh People to check delivery.'),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not save this post. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialProvider>();
    if (social.sessionVersion != _sessionVersion || social.profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Share with followers')),
        body: const Center(
          child: Text('Sign in to People and open this preview again.'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editing == null ? 'Share with followers' : 'Edit shared post',
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const AppSurface(
              child: Text(
                'Audience: your approved followers. Newly approved followers can see this post too. Partner sharing has separate settings.',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              enabled: !_busy,
              maxLength: 160,
              decoration: const InputDecoration(labelText: 'Post title'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Add a title' : null,
            ),
            TextFormField(
              controller: _caption,
              enabled: !_busy,
              maxLength: 1000,
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Caption (optional)'),
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.snapshot.servings} servings in this ${widget.isRecipe ? 'recipe' : 'meal'}',
            ),
            const SizedBox(height: 12),
            for (final item in widget.snapshot.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.name),
                subtitle: Text(
                  [
                    if (item.portionGrams != null)
                      '${item.portionGrams} ${item.portionUnit?.symbol ?? ''}',
                    if (_nutritionVisible) '${item.calories.round()} kcal',
                  ].join(' · '),
                ),
              ),
            SwitchTile(
              title: 'Include nutrition',
              subtitle: widget.snapshot.nutritionAvailable
                  ? 'Share the calorie and macro amounts in this preview.'
                  : 'Nutrition was hidden and is unavailable.',
              icon: Icons.restaurant_outlined,
              value: _nutritionVisible,
              onChanged: (value) {
                if (!_busy && widget.snapshot.nutritionAvailable) {
                  setState(() => _nutritionVisible = value);
                }
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Publishing makes a separate social copy. Your private diary and future diary edits are not uploaded through this action.',
            ),
            const SizedBox(height: 16),
            if (_message != null) Text(_message!),
            FilledButton(
              onPressed: _busy ? null : _publish,
              child: Text(
                _busy
                    ? 'Saving…'
                    : widget.editing == null
                        ? 'Publish to followers'
                        : 'Save post changes',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
