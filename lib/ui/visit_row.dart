import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../visits/visit.dart';
import 'visit_badge.dart';
import 'visit_theme.dart';

class VisitRow extends StatelessWidget {
  const VisitRow({
    super.key,
    required this.visit,
    required this.status,
    this.change,
    required this.onToggle,
    required this.onRetry,
    this.enabled = true,
  });
  final Visit visit;
  final VisitStatus status;
  final PendingChange? change;
  final VoidCallback onToggle, onRetry;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final largeText = VisitLayout.stackForLargeText(context);
    final icon = switch (status) {
      VisitStatus.done => 'done',
      VisitStatus.archived => 'archived',
      VisitStatus.open || VisitStatus.unknown => 'open',
    };
    final statusDescription = switch (change?.phase) {
      SyncPhase.pending => 'Pending sync',
      SyncPhase.failed => 'Not saved',
      SyncPhase.uncertain => 'Save not confirmed',
      null => status.name,
    };
    Widget? badge;
    if (change != null) {
      badge = VisitBadge(switch (change!.phase) {
        SyncPhase.pending => 'Pending',
        SyncPhase.failed => 'Not saved · Retry',
        SyncPhase.uncertain => 'Unconfirmed · Retry',
      }, failed: change!.phase != SyncPhase.pending);
      if (change!.phase != SyncPhase.pending) {
        badge = Semantics(
          label: 'Retry saving ${visit.displayTitle}',
          button: true,
          child: InkWell(
            onTap: enabled ? onRetry : null,
            borderRadius: BorderRadius.circular(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: VisitLayout.minTapTarget,
                minWidth: VisitLayout.minTapTarget,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                heightFactor: 1,
                child: ExcludeSemantics(child: badge),
              ),
            ),
          ),
        );
      }
    } else if (!visit.canToggle) {
      badge = VisitBadge(
        status == VisitStatus.archived ? 'Archived' : 'Unknown status',
        neutral: true,
      );
    }

    final title = Text(
      visit.displayTitle,
      style: VisitType.title.copyWith(
        color: visit.canToggle ? VisitColors.ink : VisitColors.secondary,
        fontStyle: visit.title == null || visit.title!.trim().isEmpty
            ? FontStyle.italic
            : FontStyle.normal,
      ),
    );
    final timestamp = Text(
      visit.updatedAt == null
          ? 'Update time unavailable'
          : 'Updated ${DateFormat('d MMM, HH:mm').format(visit.updatedAt!.toLocal())}',
      style: VisitType.timestamp,
    );

    // Give the entire 48dp box a hit region, while keeping the icon at x=16
    // and the text at x=56 as in Figma.
    final toggle = SizedBox(
      width: VisitLayout.minTapTarget,
      height: VisitLayout.minTapTarget,
      child: Semantics(
        button: visit.canToggle,
        enabled: visit.canToggle && enabled,
        label: visit.canToggle
            ? '${status == VisitStatus.done ? 'Reopen' : 'Mark done'} ${visit.displayTitle}, $statusDescription'
            : '${visit.displayTitle}, $statusDescription',
        child: InkResponse(
          onTap: visit.canToggle && enabled ? onToggle : null,
          radius: 24,
          child: Center(
            child: SvgPicture.asset(
              'assets/icons/$icon.svg',
              width: 24,
              height: 24,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );

    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          4,
          largeText ? 12 : 11,
          16,
          largeText ? 12 : 11,
        ),
        child: Row(
          crossAxisAlignment: largeText
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            toggle,
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: 4),
                  timestamp,
                  if (largeText && badge != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: badge,
                    ),
                ],
              ),
            ),
            if (!largeText && badge != null) ...[
              const SizedBox(width: 16),
              badge,
            ],
          ],
        ),
      ),
    );
  }
}
