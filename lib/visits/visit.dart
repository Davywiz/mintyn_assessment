enum VisitStatus { open, done, archived, unknown }

class Visit {
  const Visit({
    required this.id,
    required this.title,
    required this.status,
    required this.updatedAt,
  });

  final String id;
  // Keep the raw nullable title: searching a missing title must behave like the API.
  final String? title;
  final VisitStatus status;
  final DateTime? updatedAt;

  String get displayTitle =>
      title == null || title!.trim().isEmpty ? 'Untitled visit' : title!;
  bool get canToggle =>
      status == VisitStatus.open || status == VisitStatus.done;

  factory Visit.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Visit has no ID');
    }
    return Visit(
      id: id,
      title: json['title'] is String ? json['title'] as String : null,
      status: VisitStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => VisitStatus.unknown,
      ),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'status': status.name,
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };
}

enum SyncPhase { pending, failed, uncertain }

class PendingChange {
  const PendingChange({
    required this.id,
    required this.target,
    required this.revision,
    this.phase = SyncPhase.pending,
  });
  final String id;
  final VisitStatus target;
  final int revision;
  final SyncPhase phase;

  PendingChange withPhase(SyncPhase value) =>
      PendingChange(id: id, target: target, revision: revision, phase: value);
  Map<String, dynamic> toJson() => {
    'id': id,
    'target': target.name,
    'revision': revision,
    'phase': phase.name,
  };
  factory PendingChange.fromJson(Map<String, dynamic> json) => PendingChange(
    id: json['id'] as String,
    target: VisitStatus.values.byName(json['target'] as String),
    revision: json['revision'] as int,
    phase: SyncPhase.values.byName(json['phase'] as String),
  );
}
