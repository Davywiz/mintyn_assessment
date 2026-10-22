import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'visit_theme.dart';

class VisitsPagination extends StatelessWidget {
  const VisitsPagination({
    super.key,
    required this.hasMore,
    required this.loading,
    required this.failed,
    required this.onLoadMore,
  });

  final bool hasMore;
  final bool loading;
  final bool failed;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            const Text('Couldn’t load more', style: VisitType.timestamp),
            TextButton(onPressed: onLoadMore, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (!hasMore) return const SizedBox(height: 24);
    return SizedBox(
      height: 64,
      child: Center(
        child: loading
            ? const _PageSpinner()
            : TextButton(
                onPressed: onLoadMore,
                child: const Text('Load more visits'),
              ),
      ),
    );
  }
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
