import 'package:flutter/material.dart';

import '../visits/visits_state.dart';
import 'visit_row.dart';
import 'visit_theme.dart';
import 'visits_feedback.dart';
import 'visits_pagination.dart';
import 'visits_skeleton.dart';

/// Sliver presentation only: state and actions are supplied by the screen.
class VisitsContent extends StatelessWidget {
  const VisitsContent({
    super.key,
    required this.visits,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onToggle,
    required this.onRetry,
  });

  final VisitsState visits;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onRetry;

  @override
  Widget build(BuildContext context) {
    if (visits.ids.isEmpty) {
      if (visits.loading) {
        return const SliverToBoxAdapter(child: VisitsSkeleton());
      }
      if (!visits.initialized && visits.storageError != null) {
        // The screen's storage banner owns recovery; no network request is active.
        return const SliverFillRemaining(
          hasScrollBody: false,
          child: SizedBox.shrink(),
        );
      }
      return SliverFillRemaining(
        hasScrollBody: false,
        child: visits.firstError != null
            ? VisitsLoadError(onRetry: onRefresh)
            : VisitsEmptyState(query: visits.query),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        if (visits.loading)
          const SliverToBoxAdapter(
            child: LinearProgressIndicator(
              minHeight: 2,
              color: VisitColors.accent,
              backgroundColor: VisitColors.border,
            ),
          ),
        SliverList.builder(
          itemCount: visits.ids.length,
          itemBuilder: (context, index) {
            final id = visits.ids[index];
            return Column(
              key: ValueKey(id),
              children: [
                VisitRow(
                  visit: visits.visits[id]!,
                  status: visits.displayedStatus(id),
                  change: visits.changes[id],
                  enabled: visits.storageError == null,
                  onToggle: () => onToggle(id),
                  onRetry: () => onRetry(id),
                ),
                if (index < visits.ids.length - 1)
                  const ColoredBox(
                    color: Colors.white,
                    child: Padding(
                      padding: EdgeInsets.only(left: VisitLayout.rowTextInset),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: VisitColors.border,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        SliverToBoxAdapter(
          child: ColoredBox(
            color: Colors.white,
            child: VisitsPagination(
              hasMore: visits.nextCursor != null,
              loading: visits.loadingMore,
              failed: visits.pageError,
              onLoadMore: onLoadMore,
            ),
          ),
        ),
      ],
    );
  }
}
