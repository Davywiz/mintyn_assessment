// flaky_task_api.dart
// Add this file to your project unchanged. Treat it as a backend you do not
// control: you may read it, but do not modify it.
import 'dart:async';
import 'dart:math';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => 'ApiException: $message';
}

/// One page of results. [items] are raw JSON-like maps, as a real HTTP
/// client would give you after jsonDecode.
class TaskPage {
  TaskPage(this.items, this.nextCursor);
  final List<Map<String, dynamic>> items;

  /// Pass this to the next fetchTasks call. Null when there are no more pages.
  final String? nextCursor;
}

class FlakyTaskApi {
  FlakyTaskApi({int seed = 42}) : _rng = Random(seed) {
    for (var i = 0; i < 137; i++) {
      _db.add(<String, dynamic>{
        'id': 'task_${i + 1}',
        'title': 'Site visit #${i + 1}',
        'status': i % 4 == 0 ? 'done' : 'open',
        'updatedAt': DateTime.utc(
          2026,
          1,
          1,
        ).add(Duration(minutes: 37 * i)).toIso8601String(),
      });
    }
    _db[52]['title'] = null;
    _db[88]['status'] = 'archived';
  }
  final Random _rng;
  final List<Map<String, dynamic>> _db = [];
  Future<TaskPage> fetchTasks({
    String? cursor,
    String query = '',
    int limit = 20,
  }) async {
    final latency = query.isEmpty ? 300 : 200 + _rng.nextInt(1800);
    await Future<void>.delayed(Duration(milliseconds: latency));
    _maybeFail(0.15);
    final q = query.toLowerCase();
    final matches = _db
        .where((t) => ((t['title'] as String?) ?? '').toLowerCase().contains(q))
        .toList();
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = min(start + limit, matches.length);
    final from = start == 0 ? 0 : start - 1;
    return TaskPage([
      for (final t in matches.sublist(from, end)) Map<String, dynamic>.from(t),
    ], end < matches.length ? '$end' : null);
  }

  Future<Map<String, dynamic>> updateStatus(String id, String status) async {
    await Future<void>.delayed(Duration(milliseconds: 400 + _rng.nextInt(600)));
    _maybeFail(0.2);
    final task = _db.firstWhere(
      (t) => t['id'] == id,
      orElse: () => throw ApiException('Task not found: $id'),
    );
    task['status'] = status;
    task['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    if (_rng.nextDouble() < 0.1) {
      throw TimeoutException('No response from server');
    }
    return Map<String, dynamic>.from(task);
  }

  void _maybeFail(double probability) {
    if (_rng.nextDouble() < probability) {
      throw ApiException('Server error (simulated)');
    }
  }
}
