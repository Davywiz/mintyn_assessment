import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mintyn_assessment/data/flaky_task_api.dart';
import 'package:mintyn_assessment/data/visit_store.dart';
import 'package:mintyn_assessment/main.dart';
import 'package:mintyn_assessment/visits/visit.dart';
import 'package:mintyn_assessment/visits/visits_controller.dart';
import 'package:path_provider/path_provider.dart';

class RejectingApi extends FlakyTaskApi {
  @override
  Future<Map<String, dynamic>> updateStatus(String id, String status) async {
    throw ApiException('Deterministic rejection for restart test');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native disk survives a fresh app scope; retry syncs the retained intent',
    (tester) async {
      final support = await getApplicationSupportDirectory();
      final dir = Directory(
        '${support.path}/integration-${DateTime.now().microsecondsSinceEpoch}',
      );
      final store = FileVisitStore(directory: dir);
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });

      Future<void> mount(FlakyTaskApi api) async {
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              taskApiProvider.overrideWithValue(api),
              visitStoreProvider.overrideWithValue(store),
            ],
            child: const VisitsApp(),
          ),
        );
      }

      ProviderContainer container() =>
          ProviderScope.containerOf(tester.element(find.byType(VisitsApp)));
      Future<void> waitFor(bool Function() condition) async {
        for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(condition(), isTrue);
        await tester.pump();
      }

      await mount(RejectingApi());
      await waitFor(() => container().read(visitsProvider).ids.isNotEmpty);
      final actions = container().read(visitsProvider.notifier);
      await actions.toggle('task_2');
      await waitFor(
        () =>
            container().read(visitsProvider).changes['task_2']?.phase ==
            SyncPhase.failed,
      );
      expect((await store.read()).changes['task_2']!.target, VisitStatus.done);

      await tester.pumpWidget(const SizedBox.shrink());
      await mount(FlakyTaskApi());
      await waitFor(
        () =>
            container().read(visitsProvider).initialized &&
            !container().read(visitsProvider).loading,
      );
      expect(find.text('1 unsynced'), findsOneWidget);
      expect(find.text('Not saved · Retry'), findsOneWidget);

      for (
        var attempt = 0;
        attempt < 8 && container().read(visitsProvider).changes.isNotEmpty;
        attempt++
      ) {
        await tester.tap(find.textContaining('Retry').first);
        await tester.pump(const Duration(seconds: 2));
      }
      await waitFor(() => container().read(visitsProvider).changes.isEmpty);
      expect(
        container().read(visitsProvider).displayedStatus('task_2'),
        VisitStatus.done,
      );
      await waitFor(() => !container().read(visitsProvider).loading);
      expect((await store.read()).changes, isEmpty);

      // Use the real backend's query behavior and archived record.
      await tester.enterText(
        find.byKey(const ValueKey('search-visits')),
        'visit #89',
      );
      await tester.pump(const Duration(seconds: 3));
      for (
        var attempt = 0;
        attempt < 4 &&
            !container().read(visitsProvider).ids.contains('task_89');
        attempt++
      ) {
        await container().read(visitsProvider.notifier).refresh();
        await tester.pump();
      }
      expect(find.text('Archived'), findsOneWidget);
      expect(find.text('Site visit #2'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
