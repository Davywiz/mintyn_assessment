import 'dart:async';

import 'package:mintyn_assessment/data/flaky_task_api.dart';
import 'package:mintyn_assessment/data/visit_store.dart';

Map<String, dynamic> task(
  String id, {
  String? title,
  String status = 'open',
  String time = '2026-01-01T00:00:00Z',
}) => {
  'id': id,
  'title': title ?? 'Site visit #$id',
  'status': status,
  'updatedAt': time,
};

class MemoryStore implements VisitStore {
  MemoryStore([VisitSnapshot? initial]) : saved = initial ?? VisitSnapshot();
  VisitSnapshot saved;
  bool failRead = false, failWrite = false;
  Completer<void>? writeGate;

  @override
  Future<VisitSnapshot> read() async {
    if (failRead) throw StateError('Disk unreadable');
    return saved;
  }

  @override
  Future<void> write(VisitSnapshot snapshot) async {
    await writeGate?.future;
    if (failWrite) throw StateError('Disk full');
    saved = VisitSnapshot.fromJson(snapshot.toJson());
  }
}

class FakeApi extends FlakyTaskApi {
  Future<TaskPage> Function(String? cursor, String query)? onFetch;
  Future<Map<String, dynamic>> Function(String id, String status)? onUpdate;
  final updates = <(String, String)>[];
  final fetches = <(String?, String)>[];

  @override
  Future<TaskPage> fetchTasks({
    String? cursor,
    String query = '',
    int limit = 20,
  }) {
    fetches.add((cursor, query));
    return onFetch?.call(cursor, query) ??
        Future.value(TaskPage([task('1'), task('2')], null));
  }

  @override
  Future<Map<String, dynamic>> updateStatus(String id, String status) {
    updates.add((id, status));
    return onUpdate?.call(id, status) ??
        Future.value(task(id, status: status, time: '2026-10-22T10:00:00Z'));
  }
}

Future<void> flushAsync() async {
  for (var i = 0; i < 15; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
