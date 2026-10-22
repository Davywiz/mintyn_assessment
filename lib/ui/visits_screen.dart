import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../visits/visits_controller.dart';
import 'visit_search_field.dart';
import 'visit_theme.dart';
import 'visits_content.dart';
import 'visits_feedback.dart';
import 'visits_header.dart';

class VisitsScreen extends HookConsumerWidget {
  const VisitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visits = ref.watch(visitsProvider);
    final actions = ref.read(visitsProvider.notifier);
    final scroll = useScrollController();
    final lifecycle = useAppLifecycleState();

    useEffect(() {
      void loadNearBottom() {
        if (scroll.hasClients &&
            scroll.position.extentAfter < 240 &&
            !ref.read(visitsProvider).pageError) {
          unawaited(actions.loadMore());
        }
      }

      scroll.addListener(loadNearBottom);
      return () => scroll.removeListener(loadNearBottom);
    }, [scroll, actions]);

    useEffect(() {
      if (lifecycle == AppLifecycleState.resumed) actions.resume();
      return null;
    }, [lifecycle, actions]);

    ref.listen(visitsProvider.select((s) => s.notice), (previous, next) {
      if (next == null || previous?.sequence == next.sequence) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(next.message),
            action: next.taskId == null
                ? null
                : SnackBarAction(
                    label: 'Retry',
                    onPressed: () => actions.retry(next.taskId!),
                  ),
            duration: const Duration(seconds: 6),
          ),
        );
    });

    void queryChanged(String value) {
      if (scroll.hasClients) scroll.jumpTo(0);
      actions.search(value);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            VisitsHeader(unsyncedCount: visits.changes.length),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                VisitLayout.pageInset,
                6,
                VisitLayout.pageInset,
                10,
              ),
              child: VisitSearchField(
                query: visits.query,
                onChanged: queryChanged,
              ),
            ),
            if (visits.storageError != null)
              VisitMessageBanner(
                visits.storageError!,
                onRetry: actions.retryStorage,
                error: true,
              ),
            if (visits.firstError != null && visits.ids.isNotEmpty)
              VisitMessageBanner(
                'Couldn’t refresh. Showing saved visits.',
                onRetry: actions.refresh,
              ),
            Expanded(
              child: RefreshIndicator(
                color: VisitColors.accent,
                onRefresh: actions.refresh,
                child: ColoredBox(
                  color: visits.ids.isNotEmpty || visits.loading
                      ? Colors.white
                      : VisitColors.background,
                  child: CustomScrollView(
                    key: const ValueKey('visits-scroll'),
                    controller: scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      VisitsContent(
                        visits: visits,
                        onRefresh: actions.refresh,
                        onLoadMore: actions.loadMore,
                        onToggle: actions.toggle,
                        onRetry: actions.retry,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
