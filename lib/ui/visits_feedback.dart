import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'visit_theme.dart';

class VisitMessageBanner extends StatelessWidget {
  const VisitMessageBanner(
    this.message, {
    super.key,
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

class VisitsLoadError extends StatelessWidget {
  const VisitsLoadError({super.key, required this.onRetry});
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

class VisitsEmptyState extends StatelessWidget {
  const VisitsEmptyState({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 96, 32, 24),
    child: Align(
      alignment: Alignment.topCenter,
      child: Text(
        query.isEmpty ? 'No visits assigned yet' : 'No visits match "$query"',
        textAlign: TextAlign.center,
        style: VisitType.title.copyWith(color: VisitColors.secondary),
      ),
    ),
  );
}
