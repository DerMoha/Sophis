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
import 'package:sophis/ui/screens/social/social_import_screen.dart';
import 'package:sophis/ui/screens/social/social_connections_screen.dart';
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
    try {
      await social.refreshPartners();
      _message = social.message;
    } catch (_) {
      _message = 'Could not refresh partner data. Try again.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept(PartnerConnection connection) =>
      _changeConnection(connection, 'acceptPartner');

  Future<void> _dismiss(PartnerConnection connection) =>
      _changeConnection(connection, 'disconnectPartner');

  Future<void> _changeConnection(
    PartnerConnection connection,
    String action,
  ) async {
    if (_busy) return;
    final social = context.read<SocialProvider>();
    final repository = social.runtime?.partners;
    if (repository == null) return;
    final epoch = social.sessionVersion;
    var succeeded = false;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await repository.request(
        action,
        {'connectionId': connection.id},
      );
      if (!mounted || epoch != social.sessionVersion) return;
      succeeded = result is Success<Map<String, dynamic>>;
      if (result is Failure<Map<String, dynamic>>) _message = result.message;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (succeeded) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialProvider>();
    final valid = social.profile != null &&
        (_epoch == null || _epoch == social.sessionVersion);
    if (valid &&
        social.partners.length == 1 &&
        social.partners.single.accepted) {
      return SocialPartnerDetailScreen(
        key: ValueKey(social.partners.single.id),
        connectionId: social.partners.single.id,
        embedded: widget.embedded,
      );
    }
    final content = ListView(
      shrinkWrap: widget.embedded,
      physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
      padding: widget.embedded ? EdgeInsets.zero : AppTheme.pagePadding,
      children: [
        const SocialIdentity(
          name: 'Your partners',
          subtitle: 'Meals, goals and progress, shared automatically',
          icon: Icons.favorite_outline,
        ),
        const SizedBox(height: 16),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null) Text(_message!),
        if (!valid)
          const Text('Your account changed. Return to Partner sharing.')
        else if (social.partners.isEmpty && !_busy)
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connect to see each other’s meals, goals and progress.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    AppTheme.slideRoute(const SocialConnectionsScreen()),
                  ),
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Connect a partner'),
                ),
              ],
            ),
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
                          ? 'Meals, goals and progress shared'
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
                    if (!connection.accepted)
                      TextButton(
                        onPressed: _busy ? null : () => _dismiss(connection),
                        child: Text(
                          connection.inviterId == social.accountId
                              ? 'Decline request'
                              : 'Cancel request',
                        ),
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
  final bool embedded;
  const SocialPartnerDetailScreen({
    super.key,
    required this.connectionId,
    this.embedded = false,
  });
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
  bool _showingSaved = false;
  bool _busy = false;
  int? _epoch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refresh());
    });
  }

  Future<bool> _loadDay(
    PartnerConnection connection, {
    required bool cached,
  }) async {
    final social = context.read<SocialProvider>();
    final epoch = social.sessionVersion;
    final repository = social.runtime?.partners;
    if (repository == null) return false;
    Future<Map<String, dynamic>?> read(
      String action,
      Map<String, dynamic> payload,
    ) async {
      if (cached) return (await repository.cached(action, payload))?.data;
      final result = await repository.request(action, payload);
      if (result is Failure<Map<String, dynamic>>) {
        throw StateError(result.message);
      }
      return result.value;
    }

    final goalData =
        await read('partnerGoals', {'connectionId': connection.id});
    if (goalData == null) return false;
    final goals = (goalData['goals'] as List)
        .cast<Map<String, dynamic>>()
        .where((g) => g['authorId'] == connection.otherId)
        .firstOrNull;
    final timeZone = goals?['timeZone'] as String? ??
        connection.otherSettings['summaryTimeZone'] as String? ??
        connection.otherSettings['mealTimeZone'] as String? ??
        (await FlutterTimezone.getLocalTimezone()).identifier;
    final date = DateFormat('yyyy-MM-dd')
        .format(_selectedDate ?? tz.TZDateTime.now(tz.getLocation(timeZone)));
    final payload = {
      'connectionId': connection.id,
      'localDate': date,
      'timeZone': timeZone,
    };
    final results = await Future.wait([
      read('partnerSummaries', payload),
      read('partnerMeals', payload),
    ]);
    if (!mounted ||
        epoch != social.sessionVersion ||
        results.any((r) => r == null)) {
      return false;
    }
    // A denied read may have removed this connection while sibling reads ran.
    if (!cached &&
        await repository.cached('partners', {}) != null &&
        !(await repository.cachedConnections() ?? [])
            .any((c) => c.id == connection.id && c.accepted)) {
      return false;
    }
    if (!mounted || epoch != social.sessionVersion) return false;
    final summary = (results[0]!['summaries'] as List)
        .cast<Map<String, dynamic>>()
        .where((item) => item['authorId'] == connection.otherId)
        .firstOrNull;
    final meals = (results[1]!['meals'] as List)
        .cast<Map<String, dynamic>>()
        .where((item) => item['authorId'] == connection.otherId)
        .toList();
    final cursor = results[1]!['cursor'] as Map<String, dynamic>?;
    setState(() {
      _connection = connection;
      _goals = goals;
      _summary = summary;
      _meals = meals;
      _cursor = cursor;
      _localDate = date;
      _timeZone = timeZone;
      _showingSaved = cached;
    });
    return true;
  }

  void _clearDay() {
    _connection = null;
    _goals = null;
    _summary = null;
    _meals = [];
    _cursor = null;
    _showingSaved = false;
  }

  Future<void> _refresh() async {
    if (_busy) return;
    final social = context.read<SocialProvider>();
    final epoch = social.sessionVersion;
    setState(() {
      _busy = true;
      if (_epoch != null && _epoch != epoch ||
          _selectedDate != null &&
              DateFormat('yyyy-MM-dd').format(_selectedDate!) != _localDate) {
        _clearDay();
      }
      _epoch = epoch;
      _message = null;
    });
    try {
      final existing = social.partners
          .where((c) => c.id == widget.connectionId && c.accepted)
          .firstOrNull;
      if (existing != null) await _loadDay(existing, cached: true);
      final refreshed = await social.refreshPartners();
      if (!mounted || epoch != social.sessionVersion) return;
      final connection = social.partners
          .where((c) => c.id == widget.connectionId && c.accepted)
          .firstOrNull;
      if (connection == null) {
        _clearDay();
        _message = social.message ?? 'This partner connection is unavailable.';
        return;
      }
      if (!refreshed) {
        _showingSaved = _connection != null;
        _message = social.message;
        return;
      }
      // Updated connection settings invalidate saved content before new reads.
      final savedGoals = await social.runtime!.partners.cached(
        'partnerGoals',
        {'connectionId': connection.id},
      );
      if (!mounted || epoch != social.sessionVersion) return;
      if (_connection != null && savedGoals == null) {
        setState(_clearDay);
      }
      await _loadDay(connection, cached: false);
    } catch (_) {
      if (mounted && epoch == social.sessionVersion) {
        final cachedConnections =
            await social.runtime?.partners.cachedConnections();
        if (!mounted || epoch != social.sessionVersion) return;
        if (cachedConnections != null &&
            !cachedConnections
                .any((c) => c.id == widget.connectionId && c.accepted)) {
          _clearDay();
        }
        _showingSaved = _connection != null;
        _message = 'Could not refresh partner data. Try again.';
      }
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
    setState(() {
      _busy = true;
      _message = null;
    });
    var succeeded = false;
    try {
      final result = await social.runtime!.partners
          .request('disconnectPartner', {'connectionId': widget.connectionId});
      if (!mounted || epoch != social.sessionVersion) return;
      succeeded = result is Success<Map<String, dynamic>>;
      if (result is Failure<Map<String, dynamic>>) _message = result.message;
    } catch (_) {
      if (mounted && epoch == social.sessionVersion) {
        _message = 'Could not disconnect. Try again.';
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (succeeded) await _refresh();
  }

  Future<void> _more() async {
    if (_busy || _cursor == null) return;
    final social = context.read<SocialProvider>();
    final epoch = social.sessionVersion;
    setState(() {
      _busy = true;
      _message = null;
    });
    final payload = {
      'connectionId': widget.connectionId,
      'cursor': _cursor,
      'localDate': _localDate,
      'timeZone': _timeZone,
    };
    final start = _meals.length;
    void applyPage(Map<String, dynamic> data) {
      final meals = (data['meals'] as List)
          .cast<Map<String, dynamic>>()
          .where((m) => m['authorId'] == _connection?.otherId)
          .toList();
      final cursor = data['cursor'] as Map<String, dynamic>?;
      _meals = [..._meals.take(start), ...meals];
      _cursor = cursor;
    }

    try {
      final repository = social.runtime!.partners;
      final cached = await repository.cached('partnerMeals', payload);
      if (!mounted || epoch != social.sessionVersion) return;
      if (cached != null) {
        setState(() {
          applyPage(cached.data);
          _showingSaved = true;
        });
      }
      final result = await repository.request('partnerMeals', payload);
      if (!mounted || epoch != social.sessionVersion) return;
      if (result is Success<Map<String, dynamic>>) {
        applyPage(result.value);
      } else {
        final failure = result as Failure<Map<String, dynamic>>;
        if (failure.errorType == ServiceErrorType.authFailed ||
            failure.errorType == ServiceErrorType.notFound) {
          _clearDay();
        }
        _message = failure.message;
      }
    } catch (_) {
      if (mounted && epoch == social.sessionVersion) {
        _message = 'Could not load more meals. Try again.';
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialProvider>();
    final valid = social.profile != null &&
        (_epoch == null || _epoch == social.sessionVersion);
    final connection = valid ? _connection : null;
    final partner = valid
        ? connection ??
            social.partners
                .where((c) => c.id == widget.connectionId && c.accepted)
                .firstOrNull
        : null;
    final content = ListView(
      shrinkWrap: widget.embedded,
      physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
      padding: widget.embedded ? EdgeInsets.zero : AppTheme.pagePadding,
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_showingSaved && valid)
          const Text(
            'Showing saved partner data. Refresh to get the latest updates.',
          ),
        if (_message != null) Text(_message!),
        if (!valid)
          const Text('Your account changed. Return to Partner sharing.'),
        if (widget.embedded && partner != null)
          Row(
            children: [
              Expanded(
                child: SocialIdentity(
                  name: partner.displayName,
                  subtitle: 'Your partner’s day',
                  icon: Icons.favorite_outline,
                ),
              ),
              ..._buildActions(),
            ],
          ),
        if (connection != null) ...[
          TextButton.icon(
            onPressed: _busy ? null : _chooseDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              _localDate == null
                  ? 'Today'
                  : DateFormat.yMMMMEEEEd().format(DateTime.parse(_localDate!)),
            ),
          ),
          PartnerTodayCard(
            key: const ValueKey('partner_today'),
            goals: _goals,
            summary: _summary,
            progressShared: true,
          ),
          const SizedBox(height: 16),
          if (_meals.isNotEmpty && _cursor == null)
            FilledButton.icon(
              onPressed: _busy ? null : _importDay,
              icon: const Icon(Icons.playlist_add),
              label: const Text('Choose items from this day'),
            ),
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
          Text(
            'You both share your full food diary, nutrition goals and daily progress automatically.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(
        title: Text(partner?.displayName ?? 'Partner'),
        actions: _buildActions(),
      ),
      body: content,
    );
  }

  List<Widget> _buildActions() => [
        IconButton(
          tooltip: 'Refresh partner',
          onPressed: _busy ? null : _refresh,
          icon: const Icon(Icons.refresh),
        ),
        PopupMenuButton<String>(
          enabled: !_busy && _connection != null,
          tooltip: 'Partner options',
          onSelected: (_) => unawaited(_disconnect()),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'disconnect',
              child: Text('Disconnect partner'),
            ),
          ],
        ),
      ];
}
