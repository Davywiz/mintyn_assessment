import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/flaky_task_api.dart';
import '../data/visit_store.dart';
import 'visit.dart';

final taskApiProvider = Provider<FlakyTaskApi>(
  (ref) => FlakyTaskApi(
    seed: const int.fromEnvironment('API_SEED', defaultValue: 42),
  ),
);
final visitStoreProvider = Provider<VisitStore>((ref) => FileVisitStore());
final visitsProvider = NotifierProvider<VisitsController, VisitsState>(
  VisitsController.new,
);

class VisitNotice {
  const VisitNotice(this.sequence, this.message, {this.taskId});
  final int sequence;
  final String message;
  final String? taskId;
}

class VisitsState {
  VisitsState({
    required Map<String, Visit> visits,
    required Map<String, PendingChange> changes,
    required List<String> ids,
    this.query = '',
    this.initialized = false,
    this.loading = true,
    this.loadingMore = false,
    this.nextCursor,
    this.firstError,
    this.pageError = false,
    this.storageError,
    this.notice,
  }) : visits = Map.unmodifiable(visits),
       changes = Map.unmodifiable(changes),
       ids = List.unmodifiable(ids);

  final Map<String, Visit> visits;
  final Map<String, PendingChange> changes;
  final List<String> ids;
  final String query;
  final bool initialized, loading, loadingMore, pageError;
  final String? nextCursor, firstError, storageError;
  final VisitNotice? notice;

  VisitStatus displayedStatus(String id) {
    final change = changes[id];
    return change != null && change.phase != SyncPhase.failed
        ? change.target
        : visits[id]!.status;
  }
}

class VisitsController extends Notifier<VisitsState> {
  final _visits = <String, Visit>{};
  final _changes = <String, PendingChange>{};
  final _durableRevisions = <String, int>{};
  List<String> _ids = [];
  String _query = '';
  String? _cursor, _firstError, _storageError;
  bool _initialized = false,
      _loading = true,
      _loadingMore = false,
      _pageError = false;
  bool _syncing = false, _disposed = false;
  int _generation = 0, _revision = 0, _noticeSequence = 0;
  VisitNotice? _notice;
  Timer? _debounce;
  Future<void>? _initialization;
  Future<void> _writes = Future.value();

  FlakyTaskApi get _api => ref.read(taskApiProvider);
  VisitStore get _store => ref.read(visitStoreProvider);

  @override
  VisitsState build() {
    ref.onDispose(() {
      _disposed = true;
      _debounce?.cancel();
    });
    Future.microtask(initialize);
    return _snapshot();
  }

  VisitsState _snapshot() => VisitsState(
    visits: _visits,
    changes: _changes,
    ids: _ids,
    query: _query,
    initialized: _initialized,
    loading: _loading,
    loadingMore: _loadingMore,
    nextCursor: _cursor,
    firstError: _firstError,
    pageError: _pageError,
    storageError: _storageError,
    notice: _notice,
  );
  void _emit() {
    if (!_disposed) state = _snapshot();
  }

  void _notify(String message, {String? taskId}) {
    _notice = VisitNotice(++_noticeSequence, message, taskId: taskId);
  }

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      final saved = await _store.read();
      if (_disposed) return;
      _visits.addAll(saved.visits);
      _changes.addAll(saved.changes);
      for (final c in _changes.values) {
        _durableRevisions[c.id] = c.revision;
        if (c.revision > _revision) _revision = c.revision;
      }
      _initialized = true;
      _storageError = null;
      _ids = _matchingCachedIds();
      _emit();
      // Replaying an absolute status is safe after an unacknowledged write.
      unawaited(_drain());
      await refresh();
    } catch (_) {
      if (_disposed) return;
      _loading = false;
      _storageError =
          'Couldn’t read saved visits. Retry before making changes.';
      _emit();
    }
  }

  List<String> _matchingCachedIds() => _visits.values
      .where(
        (t) => (t.title ?? '').toLowerCase().contains(_query.toLowerCase()),
      )
      .map((t) => t.id)
      .toList();

  /// Changes the query immediately, before the debounce, to hide stale results.
  void search(String query) {
    if (query == _query) return;
    _debounce?.cancel();
    _query = query;
    ++_generation;
    _ids = [];
    _cursor = null;
    _firstError = null;
    _pageError = false;
    _loadingMore = false;
    _loading = _initialized || _storageError == null;
    _emit();
    // Initialization fetches the latest query after restoring the outbox. A
    // blocked storage read must not start a spinner with no request behind it.
    if (!_initialized) return;
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(refresh()),
    );
  }

  Future<void> refresh() async {
    if (!_initialized || _disposed) return;
    _debounce?.cancel();
    final generation = ++_generation;
    final query = _query;
    _loading = true;
    _loadingMore = false;
    _pageError = false;
    _firstError = null;
    _emit();
    try {
      final page = await _api.fetchTasks(query: query, limit: 20);
      if (_disposed || generation != _generation) return;
      _merge(page.items);
      _ids = page.items.map((j) => j['id'] as String).toSet().toList();
      _cursor = page.nextCursor;
      await _saveSafely();
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _firstError = 'Couldn’t load your visits';
      // Previously cached rows are useful offline, but are explicitly labelled.
      if (_ids.isEmpty) _ids = _matchingCachedIds();
    }
    if (_disposed || generation != _generation) return;
    _loading = false;
    _emit();
  }

  Future<void> loadMore() async {
    if (!_initialized ||
        _loading ||
        _loadingMore ||
        _cursor == null ||
        _disposed) {
      return;
    }
    final generation = _generation;
    final cursor = _cursor;
    _loadingMore = true;
    _pageError = false;
    _emit();
    try {
      final page = await _api.fetchTasks(
        cursor: cursor,
        query: _query,
        limit: 20,
      );
      if (_disposed || generation != _generation) return;
      _merge(page.items);
      _ids = {..._ids, ...page.items.map((j) => j['id'] as String)}.toList();
      _cursor = page.nextCursor;
      await _saveSafely();
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _pageError = true;
    }
    if (_disposed || generation != _generation) return;
    _loadingMore = false;
    _emit();
  }

  void _merge(List<Map<String, dynamic>> items) {
    for (final json in items) {
      final incoming = Visit.fromJson(json);
      final current = _visits[incoming.id];
      // A fetch started before an acknowledged update may arrive after it.
      if (current?.updatedAt != null &&
          incoming.updatedAt != null &&
          current!.updatedAt!.isAfter(incoming.updatedAt!)) {
        continue;
      }
      _visits[incoming.id] = incoming;
    }
  }

  Future<void> toggle(String id) async {
    if (!_initialized || _storageError != null || !_visits[id]!.canToggle) {
      return;
    }
    final displayed = state.displayedStatus(id);
    final previous = _changes[id];
    _changes[id] = PendingChange(
      id: id,
      target: displayed == VisitStatus.done
          ? VisitStatus.open
          : VisitStatus.done,
      revision: ++_revision,
      serverUncertain:
          previous?.serverUncertain == true ||
          previous?.phase == SyncPhase.uncertain,
    );
    _emit();
    if (await _saveSafely()) unawaited(_drain());
  }

  Future<void> retry(String id) async {
    final change = _changes[id];
    if (change == null || _storageError != null) return;
    _changes[id] = PendingChange(
      id: id,
      target: change.target,
      revision: ++_revision,
      serverUncertain:
          change.serverUncertain || change.phase == SyncPhase.uncertain,
    );
    _emit();
    if (await _saveSafely()) unawaited(_drain());
  }

  Future<void> retryStorage() async {
    if (!_initialized) {
      _initialization = null;
      _loading = true;
      _emit();
      await initialize();
    } else if (await _saveSafely()) {
      unawaited(_drain());
    }
  }

  void resume() {
    if (_initialized && _storageError == null) unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_syncing || _disposed || _storageError != null) return;
    _syncing = true;
    try {
      while (!_disposed && _storageError == null) {
        PendingChange? next;
        for (final c in _changes.values) {
          if (c.phase == SyncPhase.pending &&
              _durableRevisions[c.id] == c.revision) {
            next = c;
            break;
          }
        }
        if (next == null) break;
        final sent = next;
        try {
          final json = await _api.updateStatus(sent.id, sent.target.name);
          if (_disposed) return;
          _merge([json]);
          // Never let an older response erase a newer tap.
          if (_changes[sent.id]?.revision == sent.revision) {
            _changes.remove(sent.id);
          } else if (_changes[sent.id] != null) {
            _changes[sent.id] = _changes[sent.id]!.withUncertainServer(false);
          }
        } catch (error) {
          if (_disposed) return;
          final latest = _changes[sent.id];
          if (latest?.revision == sent.revision) {
            final uncertain = error is! ApiException || sent.serverUncertain;
            _changes[sent.id] = sent
                .withUncertainServer(uncertain)
                .withPhase(uncertain ? SyncPhase.uncertain : SyncPhase.failed);
            _notify(
              uncertain
                  ? 'Couldn’t confirm ${_visits[sent.id]!.displayTitle}'
                  : 'Couldn’t update ${_visits[sent.id]!.displayTitle}',
              taskId: sent.id,
            );
          } else if (latest != null && error is! ApiException) {
            // Even a newer request's rejection cannot establish the server's
            // status after an earlier response was lost.
            _changes[sent.id] = latest.withUncertainServer(true);
          }
        }
        _emit();
        if (!await _saveSafely()) break;
      }
    } finally {
      _syncing = false;
    }
  }

  Future<bool> _saveSafely() async {
    if (!_initialized) return false;
    final snapshot = VisitSnapshot(visits: _visits, changes: _changes);
    final operation = _writes.then((_) => _store.write(snapshot));
    // Keep a failed write from poisoning all later write attempts.
    _writes = operation.catchError((Object _) {});
    try {
      await operation;
      if (_disposed) return false;
      _durableRevisions
        ..clear()
        ..addEntries(
          snapshot.changes.values.map((c) => MapEntry(c.id, c.revision)),
        );
      _storageError = null;
      _emit();
      // A refresh can recover storage too; resume any newly durable intents.
      unawaited(_drain());
      return true;
    } catch (_) {
      if (_disposed) return false;
      _storageError =
          'Couldn’t save on this device. Keep the app open and retry.';
      _notify('Change is not saved on this device. Retry storage.');
      _emit();
      return false;
    }
  }
}
