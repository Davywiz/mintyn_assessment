import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mintyn_assessment/data/visit_store.dart';
import 'package:mintyn_assessment/visits/visit.dart';

import 'support/fakes.dart';

void main() {
  test('atomic file store survives a fresh instance and ignores interrupted temp files', () async {
    final dir = await Directory.systemTemp.createTemp('mintyn-store-');
    addTearDown(() => dir.delete(recursive: true));
    final store = FileVisitStore(directory: dir);
    expect((await store.read()).visits, isEmpty);
    await store.write(
      VisitSnapshot(
        visits: {'1': Visit.fromJson(task('1'))},
        changes: {
          '1': const PendingChange(
            id: '1',
            target: VisitStatus.done,
            revision: 2,
            phase: SyncPhase.uncertain,
          ),
        },
      ),
    );
    await File('${dir.path}/visits-v1.json.tmp').writeAsString('{interrupted');
    final restored = await FileVisitStore(directory: dir).read();
    expect(restored.visits['1']!.status, VisitStatus.open);
    expect(restored.changes['1']!.target, VisitStatus.done);
    expect(restored.changes['1']!.phase, SyncPhase.uncertain);
    await store.write(VisitSnapshot(visits: restored.visits));
    expect((await store.read()).changes, isEmpty);
  });
}
