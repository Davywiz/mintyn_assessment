import 'package:flutter/material.dart';

import 'visit_theme.dart';

class VisitBadge extends StatelessWidget {
  const VisitBadge(
    this.label, {
    super.key,
    this.failed = false,
    this.neutral = false,
  });
  final String label;
  final bool failed, neutral;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: neutral
          ? VisitColors.background
          : failed
          ? VisitColors.errorBackground
          : VisitColors.pendingBackground,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Text(
        label,
        style: VisitType.badge.copyWith(
          color: neutral
              ? VisitColors.secondary
              : failed
              ? VisitColors.error
              : VisitColors.pending,
        ),
      ),
    ),
  );
}
