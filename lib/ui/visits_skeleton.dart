import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'visit_theme.dart';

class VisitsSkeleton extends StatelessWidget {
  const VisitsSkeleton({super.key});
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
                  padding: EdgeInsets.only(left: VisitLayout.rowTextInset),
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
