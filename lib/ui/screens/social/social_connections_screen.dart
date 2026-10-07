import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sophis/providers/social_provider.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/social/social_account_repository.dart';
import 'package:sophis/ui/components/common/app_surface.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/screens/social/social_partners_screen.dart';

class SocialConnectionsScreen extends StatefulWidget {
  final String? invitationToken;
  const SocialConnectionsScreen({super.key, this.invitationToken});
  @override
  State<SocialConnectionsScreen> createState() =>
      _SocialConnectionsScreenState();
}

class _SocialConnectionsScreenState extends State<SocialConnectionsScreen> {
  final _token = TextEditingController();
  String _direction = 'incoming';
  List<SocialRelationship> _relationships = [];
  Map<String, dynamic>? _cursor;
  SocialInvitation? _invitation;
  SocialInvitationPreview? _preview;
  String? _previewToken;
  String? _message;
  bool _busy = false;
  int? _loadedEpoch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_load());
      if (widget.invitationToken != null) _token.text = widget.invitationToken!;
    });
  }

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _perform(
    Future<void> Function(SocialAccountRepository) action,
  ) async {
    if (_busy) return;
    final social = context.read<SocialProvider>();
    final accounts = social.runtime?.accounts;
    if (accounts == null || social.profile == null) return;
    final epoch = social.sessionVersion;
    setState(() {
      _loadedEpoch ??= epoch;
      _busy = true;
      _message = null;
    });
    try {
      await action(accounts);
    } catch (_) {
      if (mounted) _message = 'Could not complete this connection action.';
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          if (social.sessionVersion != epoch) {
            _relationships = [];
            _invitation = null;
            _preview = null;
            _message = 'Your account changed. Refresh Connections.';
          }
        });
      }
    }
  }

  Future<void> _load({bool more = false}) => _perform((accounts) async {
        final social = context.read<SocialProvider>();
        final epoch = social.sessionVersion;
        final result = await accounts.relationships(
          _direction,
          cursor: more ? _cursor : null,
        );
        if (!mounted || epoch != social.sessionVersion) return;
        if (result is Success<SocialRelationshipPage>) {
          _relationships = more
              ? [..._relationships, ...result.value.relationships]
              : result.value.relationships;
          _cursor = result.value.cursor;
          _loadedEpoch = epoch;
        } else if (result is Failure<SocialRelationshipPage>) {
          _message = result.message;
        }
      });

  Future<void> _createInvitation(String audience) => _perform((accounts) async {
        final result = await accounts.invite(audience);
        if (!mounted) return;
        if (result is Success<SocialInvitation>) _invitation = result.value;
        if (result is Failure<SocialInvitation>) _message = result.message;
      });

  Future<void> _previewInvitation() => _perform((accounts) async {
        final input = _token.text.trim();
        final token = input.contains('://')
            ? Uri.tryParse(input)?.queryParameters['token']
            : input;
        if (token == null || !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token)) {
          _message = 'Paste a valid invitation link or code.';
          return;
        }
        final result = await accounts.preview(token);
        if (!mounted) return;
        if (result is Success<SocialInvitationPreview>) {
          _preview = result.value;
          _previewToken = token;
        } else if (result is Failure<SocialInvitationPreview>) {
          _preview = null;
          _message = result.message;
        }
      });

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialProvider>();
    final current = social.profile != null &&
        (_loadedEpoch == null || _loadedEpoch == social.sessionVersion);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connections'),
        actions: [
          IconButton(
            tooltip: 'Refresh connections',
            onPressed: _busy ? null : () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: AppTheme.pagePadding,
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_message!),
              ),
            if (!current)
              const Text('Sign in and refresh to view your connections.')
            else ...[
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => Navigator.push(
                          context,
                          AppTheme.slideRoute(const SocialPartnersScreen()),
                        ),
                icon: const Icon(Icons.favorite_outline),
                label: const Text('Partners · goals and meals'),
              ),
              const Text(
                'Follows show deliberate posts, including earlier posts after approval. Partner connections require mutual acceptance and separate outgoing sharing consent.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _createInvitation('follow'),
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Invite a friend'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        _busy ? null : () => _createInvitation('partner'),
                    icon: const Icon(Icons.favorite_outline),
                    label: const Text('Invite a partner'),
                  ),
                ],
              ),
              if (_invitation != null) ...[
                const SizedBox(height: 16),
                AppSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _invitation!.audience == 'partner'
                            ? 'Partner invitation'
                            : 'Follow invitation',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Text(
                        'One person can use this invitation. It expires after 48 hours.',
                      ),
                      Center(
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(8),
                          child: QrImageView(
                            data: _invitation!.link.toString(),
                            size: 200,
                          ),
                        ),
                      ),
                      SelectableText(_invitation!.link.toString()),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(
                                  text: _invitation!.link.toString(),
                                ),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Invitation copied'),
                                  ),
                                );
                              }
                            },
                            child: const Text('Copy link'),
                          ),
                          Builder(
                            builder: (buttonContext) => TextButton(
                              onPressed: () {
                                final box = buttonContext.findRenderObject()
                                    as RenderBox;
                                unawaited(
                                  SharePlus.instance.share(
                                    ShareParams(
                                      text: _invitation!.link.toString(),
                                      sharePositionOrigin:
                                          box.localToGlobal(Offset.zero) &
                                              box.size,
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Share'),
                            ),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _perform((accounts) async {
                                      final result = await accounts
                                          .revoke(_invitation!.token);
                                      if (result.isSuccess) {
                                        _invitation = null;
                                      } else {
                                        _message =
                                            (result as Failure<void>).message;
                                      }
                                    }),
                            child: const Text('Revoke'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              TextField(
                controller: _token,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Invitation link or code',
                ),
              ),
              TextButton(
                onPressed: _busy ? null : _previewInvitation,
                child: const Text('Preview invitation'),
              ),
              if (_preview != null)
                AppSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _preview!.displayName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        _preview!.audience == 'partner'
                            ? 'Request a partner connection. Sharing starts only after acceptance and consent.'
                            : 'Request to follow this person. They must approve before you can see their posts.',
                      ),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _perform((accounts) async {
                                  final result = await accounts.request(
                                    _preview!,
                                    _previewToken!,
                                  );
                                  if (result.isSuccess) {
                                    _preview = null;
                                    _token.clear();
                                    _message =
                                        'Request sent. Waiting for approval.';
                                  } else {
                                    _message =
                                        (result as Failure<void>).message;
                                  }
                                }),
                        child: const Text('Send request'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'incoming', label: Text('Followers')),
                  ButtonSegment(value: 'outgoing', label: Text('Following')),
                ],
                selected: {
                  _direction,
                },
                onSelectionChanged: _busy
                    ? null
                    : (values) {
                        setState(() {
                          _direction = values.single;
                          _relationships = [];
                          _cursor = null;
                        });
                        unawaited(_load());
                      },
              ),
              const SizedBox(height: 12),
              if (_relationships.isEmpty && !_busy)
                const Text('No connections in this list yet.'),
              for (final relationship in _relationships)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          relationship.displayName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          relationship.status == 'pending'
                              ? 'Waiting for approval'
                              : 'Approved',
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (_direction == 'incoming' &&
                                relationship.status == 'pending')
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () async {
                                        await _perform((accounts) async {
                                          final result = await accounts
                                              .approve(relationship.accountId);
                                          if (result is Failure<void>) {
                                            _message = result.message;
                                          }
                                        });
                                        await _load();
                                      },
                                child: const Text('Approve'),
                              ),
                            if (_direction == 'incoming' &&
                                relationship.status == 'accepted' &&
                                relationship.reciprocalStatus == null)
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () async {
                                        await _perform((accounts) async {
                                          final result =
                                              await accounts.requestReciprocal(
                                            relationship.accountId,
                                          );
                                          if (result is Failure<void>) {
                                            _message = result.message;
                                          }
                                        });
                                        await _load();
                                      },
                                child: const Text('Request to follow back'),
                              ),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _remove(relationship, block: false),
                              child: Text(
                                _direction == 'incoming'
                                    ? 'Remove'
                                    : 'Unfollow',
                              ),
                            ),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _remove(relationship, block: true),
                              child: const Text('Block'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (_cursor != null)
                TextButton(
                  onPressed: _busy ? null : () => _load(more: true),
                  child: const Text('Load more connections'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _remove(
    SocialRelationship relationship, {
    required bool block,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          block
              ? 'Block ${relationship.displayName}?'
              : 'Remove this connection?',
        ),
        content: const Text(
          'Server access is revoked. Diary copies already imported remain independent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _perform((_) async {
      final repository = context.read<SocialProvider>().runtime!.repository;
      final result = block
          ? await repository.block(relationship.accountId)
          : _direction == 'incoming'
              ? await repository.removeFollower(relationship.accountId)
              : await repository.unfollow(relationship.accountId);
      if (result is Failure<void>) _message = result.message;
    });
    if (mounted) {
      await _load();
      if (mounted) await context.read<SocialProvider>().refresh();
    }
  }
}
