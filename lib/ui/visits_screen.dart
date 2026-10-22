import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../visits/visits_controller.dart';
import 'visit_row.dart';
import 'visit_theme.dart';

class VisitsScreen extends HookConsumerWidget {
  const VisitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visits = ref.watch(visitsProvider);
    final actions = ref.read(visitsProvider.notifier);
    final search = useTextEditingController();
    final focus = useFocusNode();
    final scroll = useScrollController();
    final lifecycle = useAppLifecycleState();
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 20;

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
    }, [lifecycle]);

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

    final headerChildren = [
      const Text('My visits', style: VisitType.heading),
      if (visits.changes.isNotEmpty)
        Semantics(
          label: '${visits.changes.length} unsynced changes',
          liveRegion: true,
          child: ExcludeSemantics(
            child: VisitBadge('${visits.changes.length} unsynced'),
          ),
        ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: largeText ? 8 : 0,
              ),
              child: largeText
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: headerChildren.first,
                        ),
                        if (headerChildren.length > 1) ...[
                          const SizedBox(height: 4),
                          headerChildren.last,
                        ],
                      ],
                    )
                  : SizedBox(
                      height: 56,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: headerChildren,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: _SearchField(
                controller: search,
                focus: focus,
                onChanged: queryChanged,
                onClear: () {
                  search.clear();
                  queryChanged('');
                  focus.requestFocus();
                },
              ),
            ),
            if (visits.storageError != null)
              _MessageBanner(
                visits.storageError!,
                onRetry: actions.retryStorage,
                error: true,
              ),
            if (visits.firstError != null && visits.ids.isNotEmpty)
              _MessageBanner(
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
                      if (visits.loading && visits.ids.isEmpty)
                        const SliverToBoxAdapter(child: _SkeletonList())
                      else if (!visits.initialized &&
                          visits.storageError != null)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: SizedBox.shrink(),
                        )
                      else if (visits.firstError != null && visits.ids.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _FirstPageError(onRetry: actions.refresh),
                        )
                      else if (visits.ids.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(32, 96, 32, 24),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Text(
                                visits.query.isEmpty
                                    ? 'No visits assigned yet'
                                    : 'No visits match "${visits.query}"',
                                textAlign: TextAlign.center,
                                style: VisitType.title.copyWith(
                                  color: VisitColors.secondary,
                                ),
                              ),
                            ),
                          ),
                        )
                      else ...[
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
                                  onToggle: () => actions.toggle(id),
                                  onRetry: () => actions.retry(id),
                                ),
                                if (index < visits.ids.length - 1)
                                  const ColoredBox(
                                    color: Colors.white,
                                    child: Padding(
                                      padding: EdgeInsets.only(left: 56),
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
                            child: visits.pageError
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: Wrap(
                                      alignment: WrapAlignment.center,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 4,
                                      children: [
                                        const Text(
                                          'Couldn’t load more',
                                          style: VisitType.timestamp,
                                        ),
                                        TextButton(
                                          onPressed: actions.loadMore,
                                          child: const Text('Retry'),
                                        ),
                                      ],
                                    ),
                                  )
                                : visits.nextCursor != null
                                ? SizedBox(
                                    height: 64,
                                    child: Center(
                                      child: visits.loadingMore
                                          ? const _PageSpinner()
                                          : TextButton(
                                              onPressed: actions.loadMore,
                                              child: const Text(
                                                'Load more visits',
                                              ),
                                            ),
                                    ),
                                  )
                                : const SizedBox(height: 24),
                          ),
                        ),
                      ],
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

class _SearchField extends HookWidget {
  const _SearchField({
    required this.controller,
    required this.focus,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    useListenable(controller);
    useListenable(focus);
    // Figma's visible field grows from 44dp to 66dp at 200% text.
    // Keep 2dp above/below it inside the real 48dp minimum tap region.
    final height = math.max(
      48.0,
      48 + (MediaQuery.textScalerOf(context).scale(16) - 16) * 22 / 16,
    );
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            top: 2,
            bottom: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: focus.hasFocus
                      ? VisitColors.accent
                      : VisitColors.border,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          TextField(
            key: const ValueKey('search-visits'),
            controller: controller,
            focusNode: focus,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(
              fontSize: 16,
              height: 21 / 16,
              letterSpacing: 0,
              color: VisitColors.ink,
            ),
            decoration: InputDecoration(
              hintText: 'Search visits',
              hintStyle: const TextStyle(color: VisitColors.secondary),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.fromLTRB(
                40,
                12,
                controller.text.isEmpty ? 12 : 48,
                12,
              ),
            ),
          ),
          Positioned(
            left: 12,
            child: IgnorePointer(
              child: SvgPicture.asset(
                'assets/icons/search.svg',
                width: 20,
                height: 20,
                excludeFromSemantics: true,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            Positioned(
              right: 0,
              child: Semantics(
                label: 'Clear search',
                button: true,
                child: InkResponse(
                  onTap: onClear,
                  child: SizedBox(
                    width: 48,
                    height: math.max(48, height),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/icons/clear.svg',
                        width: 20,
                        height: 20,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner(
    this.message, {
    required this.onRetry,
    this.error = false,
  });
  final String message;
  final Future<void> Function() onRetry;
  final bool error;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: ColoredBox(
      color: error
          ? VisitColors.errorBackground
          : VisitColors.pendingBackground,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 8),
        child: Row(
          children: [
            Expanded(child: Text(message, style: VisitType.timestamp)),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    ),
  );
}

class _FirstPageError extends StatelessWidget {
  const _FirstPageError({required this.onRetry});
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 120, 32, 24),
    child: Column(
      children: [
        SvgPicture.asset(
          'assets/icons/error.svg',
          width: 40,
          height: 40,
          excludeFromSemantics: true,
        ),
        const SizedBox(height: 16),
        const Text(
          'Couldn’t load your visits',
          style: VisitType.title,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Check your connection and try again.',
          style: VisitType.timestamp,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _PageSpinner extends HookWidget {
  const _PageSpinner();
  @override
  Widget build(BuildContext context) {
    final rotation = useAnimationController(
      duration: const Duration(milliseconds: 900),
    );
    final disable = MediaQuery.disableAnimationsOf(context);
    useEffect(() {
      if (!disable) {
        rotation.repeat();
      } else {
        rotation.stop();
      }
      return null;
    }, [rotation, disable]);
    return Semantics(
      label: 'Loading more visits',
      liveRegion: true,
      child: RotationTransition(
        turns: rotation,
        child: SvgPicture.asset(
          'assets/icons/spinner.svg',
          width: 24,
          height: 24,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading visits',
    liveRegion: true,
    child: ExcludeSemantics(
      child: ColoredBox(
        color: Colors.white,
        child: Column(
          children: [
            for (final (index, widths) in const [
              (197.16, 120.83),
              (152.63, 108.11),
              (222.59, 127.19),
              (174.89, 114.47),
              (209.88, 101.75),
              (139.91, 120.83),
            ].indexed) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: VisitColors.border,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: math.min(widths.$1, constraints.maxWidth),
                              height: 16,
                              decoration: BoxDecoration(
                                color: VisitColors.border,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: math.min(widths.$2, constraints.maxWidth),
                              height: 12,
                              decoration: BoxDecoration(
                                color: VisitColors.skeletonLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (index < 5)
                const Padding(
                  padding: EdgeInsets.only(left: 56),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: VisitColors.border,
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
