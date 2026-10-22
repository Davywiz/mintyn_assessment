import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../visits/visit.dart';

class VisitSnapshot {
  VisitSnapshot({
    Map<String, Visit> visits = const {},
    Map<String, PendingChange> changes = const {},
  }) : visits = Map.unmodifiable(visits),
       changes = Map.unmodifiable(changes);
  final Map<String, Visit> visits;
  final Map<String, PendingChange> changes;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'visits': visits.values.map((t) => t.toJson()).toList(),
    'changes': changes.values.map((c) => c.toJson()).toList(),
  };

  factory VisitSnapshot.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported cache version');
    }
    final visits = (json['visits'] as List).map(
      (j) => Visit.fromJson(Map<String, dynamic>.from(j as Map)),
    );
    final changes = (json['changes'] as List).map(
      (j) => PendingChange.fromJson(Map<String, dynamic>.from(j as Map)),
    );
    return VisitSnapshot(
      visits: {for (final t in visits) t.id: t},
      changes: {for (final c in changes) c.id: c},
    );
  }
}

abstract interface class VisitStore {
  Future<VisitSnapshot> read();
  Future<void> write(VisitSnapshot snapshot);
}

/// Atomic replacement keeps a killed process from leaving half a JSON document.
/// The controller serializes writes; the temporary file is in the same directory.
class FileVisitStore implements VisitStore {
  FileVisitStore({this.directory});
  final Directory? directory;

  Future<File> _file() async {
    final dir = directory ?? await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}/visits-v1.json');
  }

  @override
  Future<VisitSnapshot> read() async {
    final file = await _file();
    if (!await file.exists()) return VisitSnapshot();
    return VisitSnapshot.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> write(VisitSnapshot snapshot) async {
    final file = await _file();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(snapshot.toJson()), flush: true);
    await temporary.rename(file.path);
  }
}
