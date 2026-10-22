import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mintyn_assessment/data/flaky_task_api.dart';
import 'package:mintyn_assessment/data/visit_store.dart';
import 'package:mintyn_assessment/visits/visit.dart';
import 'package:mintyn_assessment/visits/visits_controller.dart';
import 'package:mintyn_assessment/visits/visits_state.dart';

import 'support/fakes.dart';

void main() {
  late FakeApi api;
  late MemoryStore store;
  late ProviderContainer container;
  VisitsController controller() => container.read(visitsProvider.notifier);

  setUp(() {
    api = FakeApi();
    store = MemoryStore();
    container = ProviderContainer(
      overrides: [
        taskApiProvider.overrideWithValue(api),
        visitStoreProvider.overrideWithValue(store),
      ],
    );
  });
  tearDown(() => container.dispose());
  VisitsState current() => container.read(visitsProvider);

  test(
    'initialization callers await the same first fetch after restore',
    () async {
      final response = Completer<TaskPage>();
      api.onFetch = (_, _) => response.future;
      final first = controller().initialize();
      await flushAsync();
      expect(current().initialized, isTrue);
      var secondFinished = false;
      final second = controller().initialize().then(
        (_) => secondFinished = true,
      );
      await flushAsync();
      expect(secondFinished, isFalse);
      response.complete(TaskPage([task('1')], null));
      await Future.wait([first, second]);
      expect(current().loading, isFalse);
      expect(store.reads, 1);
      expect(api.fetches, [(null, '')]);
    },
  );

  test(
    'concurrent storage retries share one restore and first fetch',
    () async {
      store.failRead = true;
      await controller().initialize();
      store.failRead = false;
      store.readGate = Completer<void>();
      final first = controller().retryStorage();
      final second = controller().retryStorage();
      store.readGate!.complete();
      await Future.wait([first, second]);
      expect(store.reads, 2); // One failed read, then one shared recovery.
      expect(api.fetches, [(null, '')]);
      expect(current().initialized, isTrue);
    },
  );

  test(
    'disposal before scheduled initialization does not access dependencies',
    () async {
      controller();
      container.dispose();
      await flushAsync();
      expect(store.reads, 0);
      expect(api.fetches, isEmpty);
    },
  );

  test(
    'disposal finishes already queued writes without sending new work',
    () async {
      await controller().initialize();
      store.writeGate = Completer<void>();
      final first = controller().toggle('1');
      final second = controller().toggle('1');
      await flushAsync();
      container.dispose();
      store.writeGate!.complete();
      await Future.wait([first, second]);
      expect(store.saved.changes['1']!.target, VisitStatus.open);
      expect(store.saved.changes['1']!.revision, 2);
      expect(api.updates, isEmpty);
    },
  );

  test('optimistic changes reach disk before the API', () async {
    await controller().initialize();
    store.writeGate = Completer<void>();
    final toggle = controller().toggle('1');
    expect(current().displayedStatus('1'), VisitStatus.done);
    await flushAsync();
    expect(api.updates, isEmpty);
    store.writeGate!.complete();
    await toggle;
    await flushAsync();
    expect(api.updates, [('1', 'done')]);
    expect(store.saved.changes, isEmpty);
    expect(store.saved.visits['1']!.status, VisitStatus.done);
  });

  test('known rejection rolls back display but keeps the intended change for retry', () async {
    await controller().initialize();
    api.onUpdate = (_, _) => Future.error(ApiException('Rejected'));
    await controller().toggle('1');
    await flushAsync();
    expect(current().displayedStatus('1'), VisitStatus.open);
    expect(current().changes['1']!.target, VisitStatus.done);
    expect(store.saved.changes['1']!.phase, SyncPhase.failed);
    expect(current().notice!.taskId, '1');
    api.onUpdate = null;
    await controller().retry('1');
    await flushAsync();
    expect(current().displayedStatus('1'), VisitStatus.done);
    expect(current().changes, isEmpty);
  });

  test('accepted then timed-out writes stay uncertain and retry the absolute status', () async {
    await controller().initialize();
    var serverStatus = 'open';
    api.onUpdate = (id, status) async {
      serverStatus = status;
      throw TimeoutException('Saved, but response lost');
    };
    await controller().toggle('1');
    await flushAsync();
    expect(serverStatus, 'done');
    expect(current().displayedStatus('1'), VisitStatus.done);
    expect(store.saved.changes['1']!.phase, SyncPhase.uncertain);
    api.onUpdate = (id, status) async {
      serverStatus = status;
      return task(id, status: serverStatus, time: '2026-10-22T11:00:00Z');
    };
    await controller().retry('1');
    await flushAsync();
    expect(api.updates, [('1', 'done'), ('1', 'done')]);
    expect(current().changes, isEmpty);
  });

  test('rapid toggles serialize writes and an old acknowledgement cannot erase the latest intent', () async {
    await controller().initialize();
    final first = Completer<Map<String, dynamic>>();
    final second = Completer<Map<String, dynamic>>();
    api.onUpdate = (id, status) =>
        status == 'done' ? first.future : second.future;
    await controller().toggle('1');
    await flushAsync();
    await controller().toggle('1');
    expect(current().displayedStatus('1'), VisitStatus.open);
    expect(api.updates, [('1', 'done')]);
    first.complete(task('1', status: 'done', time: '2026-10-22T10:00:00Z'));
    await flushAsync();
    expect(current().displayedStatus('1'), VisitStatus.open);
    expect(current().changes['1']!.target, VisitStatus.open);
    expect(api.updates, [('1', 'done'), ('1', 'open')]);
    second.complete(task('1', time: '2026-10-22T10:01:00Z'));
    await flushAsync();
    expect(current().changes, isEmpty);
  });

  test('a newer tap is not sent while its disk write is pending', () async {
    await controller().initialize();
    final first = Completer<Map<String, dynamic>>();
    api.onUpdate = (_, _) => first.future;
    await controller().toggle('1');
    await flushAsync();
    store.writeGate = Completer<void>();
    final secondToggle = controller().toggle('1');
    first.complete(task('1', status: 'done', time: '2026-10-22T10:00:00Z'));
    await flushAsync();
    expect(api.updates.length, 1);
    api.onUpdate = null;
    store.writeGate!.complete();
    await secondToggle;
    await flushAsync();
    expect(api.updates.last, ('1', 'open'));
    expect(current().displayedStatus('1'), VisitStatus.open);
  });

  test(
    'an old ambiguous timeout is carried through a newer rejected intent',
    () async {
      await controller().initialize();
      final first = Completer<Map<String, dynamic>>();
      api.onUpdate = (id, status) => status == 'done'
          ? first.future
          : Future.error(ApiException('Newer write rejected'));
      await controller().toggle('1');
      await flushAsync();
      await controller().toggle('1');
      first.completeError(TimeoutException('Older done may have been saved'));
      await flushAsync();
      expect(current().displayedStatus('1'), VisitStatus.open);
      expect(current().changes['1']!.phase, SyncPhase.uncertain);
      expect(store.saved.changes['1']!.serverUncertain, isTrue);
      api.onUpdate = null;
      await controller().retry('1');
      await flushAsync();
      expect(current().changes, isEmpty);
      expect(api.updates.last, ('1', 'open'));
    },
  );

  test(
    'changing search clears old rows immediately and ignores late responses',
    () async {
      await controller().initialize();
      final old = Completer<TaskPage>();
      final latest = Completer<TaskPage>();
      api.onFetch = (_, query) => query == 'first' ? old.future : latest.future;
      controller().search('first');
      expect(current().ids, isEmpty);
      final oldFetch = controller().refresh();
      controller().search('second');
      final newFetch = controller().refresh();
      latest.complete(TaskPage([task('second')], null));
      await newFetch;
      old.complete(TaskPage([task('first')], '20'));
      await oldFetch;
      expect(current().query, 'second');
      expect(current().ids, ['second']);
      expect(current().nextCursor, isNull);
    },
  );

  test('overlapping pages are deduplicated and page failure preserves rows and cursor', () async {
    api.onFetch = (cursor, _) async {
      if (cursor == null) return TaskPage([task('1'), task('2')], '20');
      if (cursor == '20') return TaskPage([task('2'), task('3')], '40');
      throw ApiException('Page 3 unavailable');
    };
    await controller().initialize();
    await controller().loadMore();
    expect(current().ids, ['1', '2', '3']);
    await controller().loadMore();
    expect(current().ids, ['1', '2', '3']);
    expect(current().nextCursor, '40');
    expect(current().pageError, isTrue);
    api.onFetch = (cursor, _) async => TaskPage([task('3'), task('4')], null);
    await controller().loadMore();
    expect(current().ids, ['1', '2', '3', '4']);
    expect(api.fetches.last.$1, '40');
  });

  test(
    'refresh invalidates a pending page and preserves pending mutations',
    () async {
      api.onFetch = (_, _) async => TaskPage([task('1')], '20');
      await controller().initialize();
      final page = Completer<TaskPage>();
      api.onFetch = (cursor, _) => cursor == null
          ? Future.value(TaskPage([task('1')], '20'))
          : page.future;
      final more = controller().loadMore();
      api.onUpdate = (_, _) => Completer<Map<String, dynamic>>().future;
      await controller().toggle('1');
      await controller().refresh();
      page.complete(TaskPage([task('old-page')], '40'));
      await more;
      expect(current().ids, ['1']);
      expect(current().displayedStatus('1'), VisitStatus.done);
      expect(current().nextCursor, '20');
    },
  );

  test(
    'relaunch restores pending work even if first fetch and update fail',
    () async {
      store.saved = VisitSnapshot(
        visits: {'1': Visit.fromJson(task('1'))},
        changes: {
          '1': const PendingChange(
            id: '1',
            target: VisitStatus.done,
            revision: 9,
          ),
        },
      );
      api.onFetch = (_, _) => Future.error(ApiException('Offline'));
      api.onUpdate = (_, _) => Future.error(TimeoutException('Offline'));
      await controller().initialize();
      await flushAsync();
      expect(current().ids, ['1']);
      expect(current().displayedStatus('1'), VisitStatus.done);
      expect(current().firstError, isNotNull);
      expect(store.saved.changes['1']!.target, VisitStatus.done);
      expect(api.updates, [('1', 'done')]);
    },
  );

  test('a stale fetch cannot roll back an acknowledged status', () async {
    await controller().initialize();
    final stale = Completer<TaskPage>();
    api.onFetch = (_, _) => stale.future;
    final refresh = controller().refresh();
    await controller().toggle('1');
    await flushAsync();
    stale.complete(TaskPage([task('1')], null));
    await refresh;
    expect(current().displayedStatus('1'), VisitStatus.done);
  });

  test('storage failure is visible and blocks network until storage retry succeeds', () async {
    await controller().initialize();
    store.failWrite = true;
    await controller().toggle('1');
    await flushAsync();
    expect(api.updates, isEmpty);
    expect(current().storageError, isNotNull);
    store.failWrite = false;
    await controller().retryStorage();
    await flushAsync();
    expect(api.updates, [('1', 'done')]);
    expect(current().storageError, isNull);
  });

  test('unreadable storage is not overwritten and can be retried', () async {
    store.failRead = true;
    await controller().initialize();
    expect(current().initialized, isFalse);
    expect(current().storageError, isNotNull);
    expect(api.fetches, isEmpty);
    store.failRead = false;
    await controller().retryStorage();
    expect(current().initialized, isTrue);
    expect(current().ids, ['1', '2']);
  });

  test(
    'refresh resumes pending sends when it recovers a failed local write',
    () async {
      await controller().initialize();
      store.failWrite = true;
      await controller().toggle('1');
      expect(current().storageError, isNotNull);
      expect(api.updates, isEmpty);
      store.failWrite = false;
      await controller().refresh();
      await flushAsync();
      expect(current().storageError, isNull);
      expect(api.updates, [('1', 'done')]);
      expect(current().changes, isEmpty);
    },
  );

  test(
    'search during a blocked storage read does not start a phantom load',
    () async {
      store.failRead = true;
      await controller().initialize();
      controller().search('visit');
      expect(current().query, 'visit');
      expect(current().loading, isFalse);
      expect(current().storageError, isNotNull);
      expect(api.fetches, isEmpty);
      store.failRead = false;
      await controller().retryStorage();
      expect(api.fetches.last.$2, 'visit');
      expect(current().loading, isFalse);
    },
  );

  test(
    'missing titles and archived tasks are handled without coercing status',
    () async {
      api.onFetch = (_, _) async => TaskPage([
        {...task('53'), 'title': null},
        task('89', status: 'archived'),
        task('x', status: 'new-server-status'),
      ], null);
      await controller().initialize();
      expect(current().visits['53']!.displayTitle, 'Untitled visit');
      expect(current().visits['89']!.status, VisitStatus.archived);
      expect(current().visits['x']!.status, VisitStatus.unknown);
      await controller().toggle('89');
      await controller().toggle('x');
      expect(api.updates, isEmpty);
    },
  );
}
