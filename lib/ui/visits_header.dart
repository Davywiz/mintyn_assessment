import 'package:flutter/material.dart';

import 'visit_badge.dart';
import 'visit_theme.dart';

class VisitsHeader extends StatelessWidget {
  const VisitsHeader({super.key, required this.unsyncedCount});

  final int unsyncedCount;

  @override
  Widget build(BuildContext context) {
    final largeText = VisitLayout.stackForLargeText(context);
    const title = Text('My visits', style: VisitType.heading);
    final count = Semantics(
      label: '$unsyncedCount unsynced changes',
      liveRegion: true,
      child: ExcludeSemantics(child: VisitBadge('$unsyncedCount unsynced')),
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: VisitLayout.pageInset,
        vertical: largeText ? 8 : 0,
      ),
      child: largeText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: double.infinity, child: title),
                if (unsyncedCount > 0) ...[const SizedBox(height: 4), count],
              ],
            )
          : SizedBox(
              height: 56,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [title, if (unsyncedCount > 0) count],
              ),
            ),
    );
  }
}
