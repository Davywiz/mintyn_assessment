import 'visit.dart';

class VisitNotice {
  const VisitNotice(this.sequence, this.message, {this.taskId});
  final int sequence;
  final String message;
  final String? taskId;
}

/// Immutable view of the cache, visible query results, and local intentions.
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

  /// Confirmed records, including records outside the current search/page.
  final Map<String, Visit> visits;

  /// Latest unsynced intention per visit, independent of query membership.
  final Map<String, PendingChange> changes;

  /// Visible records in server order, deduplicated across overlapping pages.
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
