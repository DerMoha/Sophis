import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:sophis/models/social/social_snapshot.dart';
import 'package:sophis/ui/screens/social/partner_meals.dart';
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
  final bool embedded;
  const SocialPartnersScreen({super.key, this.embedded = false});
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
    final content = ListView(
      shrinkWrap: widget.embedded,
      physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
      padding: widget.embedded ? EdgeInsets.zero : AppTheme.pagePadding,
      children: [
        const SocialIdentity(
          name: 'Your partners',
          subtitle: 'View a day and copy the meals you shared',
          icon: Icons.favorite_outline,
        ),
        const SizedBox(height: 16),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null) Text(_message!),
        if (!valid)
          const Text('Your account changed. Return to Partner sharing.')
        else if (social.partners.isEmpty && !_busy)
          const Text(
            'No partner connections yet. Use Invite a partner above to connect.',
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
                      icon: Icons.favorite_outline,
                    ),
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
                        child: const Text('View today'),
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
    );
    if (widget.embedded) return content;
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
      body: content,
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
  String? _localDate;
  String? _timeZone;
  DateTime? _selectedDate;
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
      _cursor = null;
      _connection = null;
      _goals = null;
      _summary = null;
      _meals = [];
      _message = null;
    });
    try {
      await social.refreshPartners();
      if (!mounted || epoch != social.sessionVersion) return;
      final connection = social.partners
          .where((c) => c.id == widget.connectionId && c.accepted)
          .firstOrNull;
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
          connection.otherSettings['mealTimeZone'] as String? ??
          (await FlutterTimezone.getLocalTimezone()).identifier;
      final date = DateFormat('yyyy-MM-dd')
          .format(_selectedDate ?? tz.TZDateTime.now(tz.getLocation(timeZone)));
      _localDate = date;
      _timeZone = timeZone;
      final summaryResult = await repository.request('partnerSummaries', {
        'connectionId': connection.id,
        'localDate': date,
        'timeZone': timeZone,
      });
      final mealResult = await repository.request('partnerMeals', {
        'connectionId': connection.id,
        'localDate': date,
        'timeZone': timeZone,
      });
      if (!mounted || epoch != social.sessionVersion) return;
      if (summaryResult is Failure<Map<String, dynamic>> ||
          mealResult is Failure<Map<String, dynamic>>) {
        _message = 'Could not refresh partner data. Try again.';
        return;
      }
      _connection = connection;
      _goals = goals;
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

  void _importMeal(Map<String, dynamic> meal) {
    final connection = _connection;
    if (connection == null) return;
    Navigator.push(
      context,
      AppTheme.slideRoute(
        SocialImportScreen(
          post: SocialPost(
            id: meal['id'] as String,
            authorId: connection.otherId,
            snapshot: SocialSnapshot.fromJson(
              meal['snapshot'] as Map<String, dynamic>,
              nutritionVisible: true,
            ),
            nutritionVisible: true,
            isRecipe: false,
            revision: meal['sourceRevision'] as int,
            publishedAt: DateTime.fromMillisecondsSinceEpoch(
              (meal['publishedAt'] as num).toInt(),
            ),
          ),
        ),
      ),
    );
  }

  void _importDay() {
    final connection = _connection;
    if (connection == null || _meals.isEmpty || _cursor != null) return;
    final items = _meals
        .expand(
          (meal) => SocialSnapshot.fromJson(
            meal['snapshot'] as Map<String, dynamic>,
            nutritionVisible: true,
          ).items,
        )
        .toList();
    if (items.length > 50) {
      setState(
        () => _message =
            'This day has more than 50 items. Add meals individually.',
      );
      return;
    }
    Navigator.push(
      context,
      AppTheme.slideRoute(
        SocialImportScreen(
          post: SocialPost(
            id: 'partner-day',
            authorId: connection.otherId,
            snapshot: SocialSnapshot(
              title: 'Shared meals · $_localDate',
              servings: 1,
              items: items,
            ),
            nutritionVisible: true,
            isRecipe: false,
            revision: 1,
            publishedAt: DateTime.now(),
          ),
        ),
      ),
    );
  }

  Future<void> _chooseDate() async {
    final initial = DateTime.tryParse(_localDate ?? '') ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    _selectedDate = date;
    await _refresh();
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
          'Both people lose access to shared partner data. Imported diary entries remain independent.',
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
      {
        'connectionId': widget.connectionId,
        'cursor': _cursor,
        'localDate': _localDate,
        'timeZone': _timeZone,
      },
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
          if (!valid)
            const Text('Your account changed. Return to Partner sharing.'),
          if (connection != null) ...[
            TextButton.icon(
              onPressed: _busy ? null : _chooseDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                _localDate == null
                    ? 'Today'
                    : DateFormat.yMMMMEEEEd()
                        .format(DateTime.parse(_localDate!)),
              ),
            ),
            if (connection.otherSettings['paused'] == true)
              const SocialNotice(
                message:
                    'Partner sharing is paused. Previously shared values are frozen.',
                icon: Icons.pause_circle_outline,
              ),
            if (_goals == null)
              const SocialNotice(
                message: 'Your partner has not shared nutrition goals.',
              ),
            if (connection.otherSettings['summaries'] != true)
              const SocialNotice(
                message: 'Your partner has not shared daily progress.',
              ),
            PartnerTodayCard(
              key: const ValueKey('partner_today'),
              goals: _goals,
              summary: _summary,
              progressShared: connection.otherSettings['summaries'] == true,
            ),
            const SizedBox(height: 16),
            if (_meals.isNotEmpty && _cursor == null)
              FilledButton.icon(
                onPressed: _busy ? null : _importDay,
                icon: const Icon(Icons.playlist_add),
                label: const Text('Choose items from this day'),
              ),
            if (connection.otherSettings['meals'] != true)
              const SocialNotice(message: 'Your partner has not shared meals.')
            else
              PartnerMeals(
                meals: _meals,
                onImport: _busy ? null : _importMeal,
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
                leading: Icon(
                  Icons.tune,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Sharing settings'),
                subtitle:
                    Text('Choose what ${connection.displayName} receives'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                shape: const Border(),
                collapsedShape: const Border(),
                children: [
                  const SocialNotice(
                    message:
                        'Only food logged after sharing starts is included. Food logged during a pause is excluded.',
                  ),
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
                    child: const Text('Disconnect partner'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
