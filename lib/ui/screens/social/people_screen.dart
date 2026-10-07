import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sophis/providers/social_provider.dart';
import 'package:sophis/ui/components/common/app_surface.dart';
import 'package:sophis/ui/screens/social/social_connections_screen.dart';
import 'package:sophis/ui/screens/social/social_source_screen.dart';
import 'package:sophis/ui/screens/social/social_post_card.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/screens/social/social_partners_screen.dart';

class PeopleScreen extends StatefulWidget {
  final String? invitationToken;
  const PeopleScreen({super.key, this.invitationToken});
  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen>
    with WidgetsBindingObserver {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _creating = false;
  bool _hidePassword = true;
  bool _invitationOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<SocialProvider>().open());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(context.read<SocialProvider>().refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialProvider>();
    if (social.profile != null &&
        widget.invitationToken != null &&
        !_invitationOpened) {
      _invitationOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.push(
            context,
            AppTheme.slideRoute(
              SocialConnectionsScreen(
                invitationToken: widget.invitationToken,
              ),
            ),
          );
        }
      });
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('People'),
        actions: [
          if (social.profile != null)
            IconButton(
              tooltip: 'Connections',
              onPressed: () => Navigator.push(
                context,
                AppTheme.slideRoute(const SocialConnectionsScreen()),
              ),
              icon: const Icon(Icons.people_outline),
            ),
          if (social.accountId != null)
            IconButton(
              tooltip: 'Sign out',
              onPressed: social.busy ? null : () => _confirmSignOut(social),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: AppTheme.pagePadding,
          children: [
            if (social.busy) const LinearProgressIndicator(),
            if (social.message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  social.message!,
                  semanticsLabel: social.message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (!social.configured) ...[
              _buildIntroduction(),
              const SizedBox(height: 16),
              const Text(
                'People is not available in this build yet. Your local tracking remains available.',
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Continue tracking'),
              ),
            ] else if (!social.ready) ...[
              if (!social.busy)
                FilledButton(
                  onPressed: social.open,
                  child: const Text('Try again'),
                ),
            ] else if (social.accountId == null)
              _buildAccountForm(social)
            else if (social.profile == null)
              social.needsProfile
                  ? _buildProfileForm(social)
                  : FilledButton(
                      onPressed: social.busy ? null : social.refreshAccount,
                      child: const Text('Retry account'),
                    )
            else ...[
              TextButton.icon(
                onPressed: social.busy
                    ? null
                    : () => Navigator.push(
                          context,
                          AppTheme.slideRoute(const SocialPartnersScreen()),
                        ),
                icon: const Icon(Icons.favorite_outline),
                label: const Text('Partners · goals and meals'),
              ),
              Text(
                'Hello, ${social.profile!.displayName}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Meals and recipes deliberately shared with you appear here. Partner sharing has separate consent settings.',
              ),
              const SizedBox(height: 12),
              if (social.showingCache)
                const Text(
                  'Saved feed · connect to refresh access and new posts',
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: social.busy ? null : social.refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh feed'),
                ),
              ),
              if (social.posts.isEmpty)
                const AppSurface(
                  child: Text(
                    'No shared meals yet. Invite a friend or partner from Connections.',
                  ),
                ),
              FilledButton.icon(
                onPressed: social.busy
                    ? null
                    : () => Navigator.push(
                          context,
                          AppTheme.slideRoute(const SocialSourceScreen()),
                        ),
                icon: const Icon(Icons.ios_share_outlined),
                label: const Text('Share a meal or recipe'),
              ),
              const SizedBox(height: 16),
              for (final post in social.posts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SocialPostCard(post: post),
                ),
              if (social.cursor != null)
                TextButton(
                  onPressed: social.busy ? null : social.loadMore,
                  child: const Text('Load more'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIntroduction() => AppSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.people_outline, size: 40),
            const SizedBox(height: 12),
            Text(
              'Cook, share, encourage',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Connect privately with invited friends and partners. Share meals deliberately, choose what your partners receive, and log your own portions.',
            ),
            const SizedBox(height: 8),
            const Text(
              'An account is optional. Your diary stays on this device and is not automatically uploaded.',
            ),
          ],
        ),
      );

  Widget _buildAccountForm(SocialProvider social) => Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildIntroduction(),
            const SizedBox(height: 20),
            Text(
              _creating ? 'Create an account' : 'Sign in',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              autofillHints: const [AutofillHints.email],
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) => value == null || !value.contains('@')
                  ? 'Enter a valid email address'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: _hidePassword,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: [
                _creating ? AutofillHints.newPassword : AutofillHints.password,
              ],
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'Enter your password'
                  : _creating && value.length < 6
                      ? 'Use at least 6 characters'
                      : null,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: social.busy
                  ? null
                  : () {
                      if (_form.currentState!.validate()) {
                        unawaited(
                          social.authenticate(
                            _email.text,
                            _password.text,
                            create: _creating,
                          ),
                        );
                      }
                    },
              child: Text(_creating ? 'Create account' : 'Sign in'),
            ),
            TextButton(
              onPressed: social.busy
                  ? null
                  : () => setState(() => _creating = !_creating),
              child: Text(
                _creating
                    ? 'Already have an account? Sign in'
                    : 'Create an account',
              ),
            ),
            TextButton(
              onPressed: social.busy
                  ? null
                  : () {
                      if (_email.text.contains('@')) {
                        unawaited(social.recover(_email.text));
                      } else {
                        _form.currentState!.validate();
                      }
                    },
              child: const Text('Forgot password?'),
            ),
            const Text(
              'On a shared device, sign out when finished. Social caches and pending work are cleared; your local diary stays on the device.',
            ),
          ],
        ),
      );

  Widget _buildProfileForm(SocialProvider social) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your private profile',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Text(
            'Choose a display name for your invited connections. You can change it later.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
          FilledButton(
            onPressed: social.busy
                ? null
                : () {
                    if (_name.text.trim().isNotEmpty) {
                      unawaited(social.saveProfile(_name.text));
                    }
                  },
            child: const Text('Save profile'),
          ),
        ],
      );

  Future<void> _confirmSignOut(SocialProvider social) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'This clears your saved social feed and pending social actions. Your local diary remains on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      _email.clear();
      _password.clear();
      _name.clear();
      _creating = false;
      await social.signOut();
    }
  }
}
