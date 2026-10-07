import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:sophis/models/social/social_snapshot.dart';
import 'package:sophis/providers/social_provider.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/social/social_partner_repository.dart';
import 'package:sophis/services/social/social_repository.dart';
import 'package:sophis/ui/components/organic_components.dart';
import 'package:sophis/ui/screens/social/social_visuals.dart';
import 'package:sophis/ui/components/settings/settings_tiles.dart';
import 'package:sophis/ui/screens/social/social_import_screen.dart';
import 'package:sophis/ui/theme/app_theme.dart';

class SocialPartnersScreen extends StatefulWidget {
  const SocialPartnersScreen({super.key});
  @override
  State<SocialPartnersScreen> createState() => _SocialPartnersScreenState();
}

class _SocialPartnersScreenState extends State<SocialPartnersScreen> {
  bool _busy = false;
  String? _message;
  int? _epoch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refresh());
    });
  }

  Future<void> _refresh() async {
    if (_busy) return;
    final social = context.read<SocialProvider>();
    setState(() {
      _busy = true;
      _epoch = social.sessionVersion;
    });
    await social.refreshPartners();
    if (mounted) {
      setState(() {
        _busy = false;
        _message = social.message;
      });
    }
  }

  Future<void> _accept(PartnerConnection connection) async {
    final social = context.read<SocialProvider>();
    setState(() => _busy = true);
    final result = await social.runtime!.partners
        .request('acceptPartner', {'connectionId': connection.id});
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message =
          result is Failure<Map<String, dynamic>> ? result.message : null;
    });
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialProvider>();
    final valid = social.profile != null &&
        (_epoch == null || _epoch == social.sessionVersion);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partners'),
        actions: [
          IconButton(
            tooltip: 'Refresh partners',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SocialIdentity(
              name: 'Better together',
              subtitle: 'Your private circle, one day at a time',
              icon: Icons.favorite_outline,),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null) Text(_message!),
          if (!valid)
            const Text('Your account changed. Return to People.')
          else if (social.partners.isEmpty && !_busy)
            const Text(
              'No partner connections yet. Invite a partner from Connections.',
            )
          else
            for (final connection in social.partners)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SocialIdentity(
                          name: connection.displayName,
                          subtitle: connection.accepted
                              ? 'Connected privately'
                              : 'Partner invitation',
                          icon: Icons.favorite_outline,),
                      const SizedBox(height: 16),
                      if (connection.accepted)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.push(
                                    context,
                                    AppTheme.slideRoute(
                                      SocialPartnerDetailScreen(
                                        connectionId: connection.id,
                                      ),
                                    ),
                                  ),
                          child: const Text('Goals, progress and meals'),
                        )
                      else if (connection.inviterId == social.accountId)
                        FilledButton(
                          onPressed: _busy ? null : () => _accept(connection),
                          child: const Text('Accept partner'),
                        )
                      else
                        const Text(
                          'Waiting for partner approval. No data is shared yet.',
                        ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class SocialPartnerDetailScreen extends StatefulWidget {
  final String connectionId;
  const SocialPartnerDetailScreen({super.key, required this.connectionId});
  @override
  State<SocialPartnerDetailScreen> createState() =>
      _SocialPartnerDetailScreenState();
}

class _SocialPartnerDetailScreenState extends State<SocialPartnerDetailScreen> {
  PartnerConnection? _connection;
  Map<String, dynamic>? _goals;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _meals = [];
  Map<String, dynamic>? _cursor;
  String? _message;
  String? _dateLabel;
  bool _busy = false;
  bool _sharingExpanded = false;
  int? _epoch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refresh());
    });
  }

  Future<void> _refresh() async {
    if (_busy) return;
    final social = context.read<SocialProvider>();
    final epoch = social.sessionVersion;
    setState(() {
      _busy = true;
      _epoch = epoch;
      _goals = null;
      _summary = null;
      _meals = [];
      _message = null;
    });
    try {
      await social.refreshPartners();
      if (!mounted || epoch != social.sessionVersion) return;
      _connection = social.partners
          .where((c) => c.id == widget.connectionId && c.accepted)
          .firstOrNull;
      final connection = _connection;
      if (connection == null) {
        _message = 'This partner connection is unavailable.';
        return;
      }
      final repository = social.runtime!.partners;
      final goalResult = await repository
          .request('partnerGoals', {'connectionId': connection.id});
      if (goalResult is Failure<Map<String, dynamic>>) {
        _message = goalResult.message;
        return;
      }
      final goals = (goalResult.value['goals'] as List)
          .cast<Map<String, dynamic>>()
          .where((g) => g['authorId'] == connection.otherId)
          .firstOrNull;
      final timeZone = goals?['timeZone'] as String? ??
          connection.otherSettings['summaryTimeZone'] as String? ??
          (await FlutterTimezone.getLocalTimezone()).identifier;
      final date = DateFormat('yyyy-MM-dd')
          .format(tz.TZDateTime.now(tz.getLocation(timeZone)));
      final summaryResult = await repository.request('partnerSummaries', {
        'connectionId': connection.id,
        'localDate': date,
        'timeZone': timeZone,
      });
      final mealResult = await repository
          .request('partnerMeals', {'connectionId': connection.id});
      if (!mounted || epoch != social.sessionVersion) return;
      if (summaryResult is Failure<Map<String, dynamic>> ||
          mealResult is Failure<Map<String, dynamic>>) {
        _message = 'Could not refresh partner data. Try again.';
        return;
      }
      _goals = goals;
      _dateLabel = '$date · $timeZone';
      _summary = (summaryResult.value['summaries'] as List)
          .cast<Map<String, dynamic>>()
          .where((s) => s['authorId'] == connection.otherId)
          .firstOrNull;
      _meals = (mealResult.value['meals'] as List)
          .cast<Map<String, dynamic>>()
          .where((m) => m['authorId'] == connection.otherId)
          .toList();
      _cursor = mealResult.value['cursor'] as Map<String, dynamic>?;
    } catch (_) {
      _message = 'Could not refresh partner data. Try again.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _change(String field, bool value) async {
    final connection = _connection;
    if (_busy || connection == null) return;
    final social = context.read<SocialProvider>();
    final epoch = social.sessionVersion;
    setState(() => _busy = true);
    final result =
        await social.runtime!.partners.settings(connection, field, value);
    if (!mounted || epoch != social.sessionVersion) return;
    if (result is Success<Map<String, dynamic>>) {
      final session = await social.runtime!.accounts.client.captureSession();
      if (session != null) {
        await social.runtime!.store
            .cancelPartnerUpdates(session, connection.id);
      }
    }
    setState(() {
      _busy = false;
      _message =
          result is Failure<Map<String, dynamic>> ? result.message : null;
    });
    if (result is Success<Map<String, dynamic>>) await _refresh();
  }

  Future<void> _disconnect() async {
    final social = context.read<SocialProvider>();
    final epoch = social.sessionVersion;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect partner?'),
        content: const Text(
          'Both people lose access to shared partner data. Imported diary entries and recipes remain independent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || epoch != social.sessionVersion) return;
    setState(() => _busy = true);
    final result = await social.runtime!.partners
        .request('disconnectPartner', {'connectionId': widget.connectionId});
    if (!mounted || epoch != social.sessionVersion) return;
    setState(() => _busy = false);
    if (result is Success<Map<String, dynamic>>) {
      await _refresh();
    } else {
      setState(
        () => _message = result is Failure<Map<String, dynamic>>
            ? result.message
            : 'Could not disconnect.',
      );
    }
  }

  Future<void> _more() async {
    if (_busy || _cursor == null) return;
    final social = context.read<SocialProvider>();
    final epoch = social.sessionVersion;
    setState(() => _busy = true);
    final result = await social.runtime!.partners.request(
      'partnerMeals',
      {'connectionId': widget.connectionId, 'cursor': _cursor},
    );
    if (!mounted || epoch != social.sessionVersion) return;
    setState(() {
      _busy = false;
      if (result is Success<Map<String, dynamic>>) {
        _meals.addAll(
          (result.value['meals'] as List)
              .cast<Map<String, dynamic>>()
              .where((m) => m['authorId'] == _connection?.otherId),
        );
        _cursor = result.value['cursor'] as Map<String, dynamic>?;
      } else {
        _message = 'Could not load more meals.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialProvider>();
    final valid = social.profile != null &&
        (_epoch == null || _epoch == social.sessionVersion);
    final connection = valid ? _connection : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(connection?.displayName ?? 'Partner'),
        actions: [
          IconButton(
            tooltip: 'Refresh partner',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_message != null) Text(_message!),
          if (!valid) const Text('Your account changed. Return to People.'),
          if (connection != null) ...[
            SocialIdentity(
                name: connection.displayName,
                subtitle: 'Your private partner space',
                icon: Icons.favorite_outline,),
            const SizedBox(height: 24),
            if (connection.otherSettings['paused'] == true)
              const SocialNotice(
                  message:
                      'Partner sharing is paused. Previously shared values are frozen.',
                  icon: Icons.pause_circle_outline,),
            if (_goals == null)
              const SocialNotice(
                  message: 'Your partner has not shared nutrition goals.',),
            if (connection.otherSettings['summaries'] != true)
              const SocialNotice(
                  message: 'Your partner has not shared daily progress.',),
            PartnerTodayCard(
                key: const ValueKey('partner_today'),
                goals: _goals,
                summary: _summary,
                progressShared: connection.otherSettings['summaries'] == true,
                dateLabel: _dateLabel,),
            const SocialNotice(
                message:
                    'Progress includes only entries shared from activation onward. Earlier meals and meals logged during a pause are excluded.',),
            const SizedBox(height: 12),
            Text(
              'Partner meals',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (_meals.isEmpty)
              const GlassCard(
                  child: SocialIdentity(
                      name: 'A little inspiration',
                      subtitle: 'No shared partner meals yet.',
                      icon: Icons.restaurant_outlined,),),
            for (final meal in _meals)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SocialIdentity(
                          name: (meal['snapshot'] as Map)['title'] as String,
                          subtitle: '${meal['localDate']} · Shared meal',
                          icon: Icons.restaurant_outlined,),
                      const SizedBox(height: 12),
                      Text(
                          '${SocialSnapshot.fromJson(meal['snapshot'] as Map<String, dynamic>, nutritionVisible: true).items.fold(0.0, (sum, item) => sum + item.calories).round()} kcal',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: AppTheme.fire),),
                      TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () => Navigator.push(
                                  context,
                                  AppTheme.slideRoute(
                                    SocialImportScreen(
                                      post: SocialPost(
                                        id: meal['id'] as String,
                                        authorId: connection.otherId,
                                        snapshot: SocialSnapshot.fromJson(
                                          meal['snapshot']
                                              as Map<String, dynamic>,
                                          nutritionVisible: true,
                                        ),
                                        nutritionVisible: true,
                                        isRecipe: false,
                                        revision: meal['sourceRevision'] as int,
                                        publishedAt:
                                            DateTime.fromMillisecondsSinceEpoch(
                                          (meal['publishedAt'] as num).toInt(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add to diary'),
                      ),
                    ],
                  ),
                ),
              ),
            if (_cursor != null)
              TextButton(
                onPressed: _busy ? null : _more,
                child: const Text('Load more meals'),
              ),
            const SizedBox(height: 24),
            GlassCard(
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  key: const ValueKey('partner_sharing_settings'),
              initiallyExpanded: _sharingExpanded,
              onExpansionChanged: (expanded) => _sharingExpanded = expanded,
                  leading: Icon(Icons.tune,
                      color: Theme.of(context).colorScheme.primary,),
                  title: const Text('Sharing settings'),
                  subtitle:
                      Text('Choose what ${connection.displayName} receives'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  children: [
                    IgnorePointer(
                      ignoring: _busy,
                      child: Column(
                        children: [
                          for (final setting in [
                            (
                              'goals',
                              'Share nutrition goals',
                              'Your calorie, protein, carbohydrate and fat targets.'
                            ),
                            (
                              'summaries',
                              'Share daily progress',
                              'Only eligible logged entries contribute to totals.'
                            ),
                            (
                              'meals',
                              'Share logged meals',
                              'Automatically share newly logged meals from activation onward.'
                            ),
                            (
                              'paused',
                              'Pause sharing',
                              'Freeze shared values. Turning an individual permission off revokes that data.'
                            ),
                          ])
                            SwitchTile(
                              title: setting.$2,
                              subtitle: setting.$3,
                              icon: Icons.share_outlined,
                              value: connection.ownSettings[setting.$1] == true,
                              onChanged: (value) => _change(setting.$1, value),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                        onPressed: _busy ? null : _disconnect,
                        child: const Text('Disconnect partner'),),
                  ],
                ),),
          ],
        ],
      ),
    );
  }
}
