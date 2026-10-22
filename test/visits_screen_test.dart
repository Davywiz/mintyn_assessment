import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mintyn_assessment/data/flaky_task_api.dart';
import 'package:mintyn_assessment/data/visit_store.dart';
import 'package:mintyn_assessment/ui/visit_row.dart';
import 'package:mintyn_assessment/ui/visit_theme.dart';
import 'package:mintyn_assessment/ui/visits_screen.dart';
import 'package:mintyn_assessment/visits/visit.dart';
import 'package:mintyn_assessment/visits/visits_controller.dart';

import 'support/fakes.dart';

const surfaceKey = ValueKey('golden-surface');

void main() {
  setUpAll(() async {
    final font = FontLoader('IBM Plex Sans');
    for (final face in ['Regular', 'Medium', 'SemiBold', 'MediumItalic']) {
      font.addFont(rootBundle.load('assets/fonts/IBMPlexSans-$face.ttf'));
    }
    await font.load();
  });

  Future<void> mount(
    WidgetTester tester,
    FakeApi api,
    MemoryStore store, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskApiProvider.overrideWithValue(api),
          visitStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          theme: visitTheme(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: const RepaintBoundary(
                key: surfaceKey,
                child: VisitsScreen(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  (FakeApi, MemoryStore) rowStates({bool large = false}) {
    final rows = [
      for (var i = 1; i <= 10; i++)
        task(
          '$i',
          status: [1, 2, 9].contains(i) ? 'done' : 'open',
          time: DateTime.utc(
            2026,
            1,
            1,
          ).add(Duration(minutes: (i - 1) * 37)).toIso8601String(),
        ),
    ];
    final api = FakeApi();
    api.onFetch = (_, _) async =>
        TaskPage(large ? [rows[1], rows[3]] : rows, null);
    api.onUpdate = (_, _) => Completer<Map<String, dynamic>>().future;
    final store = MemoryStore(
      VisitSnapshot(
        visits: {for (final j in rows) j['id'] as String: Visit.fromJson(j)},
        changes: {
          '2': const PendingChange(
            id: '2',
            target: VisitStatus.done,
            revision: 1,
          ),
          '4': const PendingChange(
            id: '4',
            target: VisitStatus.done,
            revision: 2,
            phase: SyncPhase.failed,
          ),
          '5': const PendingChange(
            id: '5',
            target: VisitStatus.open,
            revision: 3,
          ),
        },
      ),
    );
    return (api, store);
  }

  testWidgets(
    'Figma list states fit 390dp and keep retry controls accessible',
    (tester) async {
      final (api, store) = rowStates();
      await mount(tester, api, store);
      expect(find.text('3 unsynced'), findsOneWidget);
      expect(find.text('Pending'), findsNWidgets(2));
      expect(find.text('Not saved · Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(surfaceKey),
        matchesGoldenFile('goldens/list_390.png'),
      );
    },
  );

  testWidgets(
    '320dp at 200% text stacks badges and remains scrollable without overflow',
    (tester) async {
      final (api, store) = rowStates(large: true);
      await mount(tester, api, store, size: const Size(320, 568), textScale: 2);
      final title = tester.getRect(find.text('My visits'));
      final count = tester.getRect(find.text('3 unsynced'));
      expect(count.top, greaterThanOrEqualTo(title.bottom));
      final pending = tester.getRect(find.text('Pending'));
      final timestamp = tester.getRect(find.text('Updated 1 Jan, 01:37'));
      expect(pending.top, greaterThanOrEqualTo(timestamp.bottom));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(surfaceKey),
        matchesGoldenFile('goldens/list_320_text_200.png'),
      );
      await tester.drag(
        find.byKey(const ValueKey('visits-scroll')),
        const Offset(0, -260),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not saved · Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Not saved · Retry'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search hides previous rows immediately, displays no results and clears',
    (tester) async {
      final api = FakeApi();
      await mount(tester, api, MemoryStore());
      api.onFetch = (_, _) async => TaskPage([], null);
      await tester.enterText(
        find.byKey(const ValueKey('search-visits')),
        'visit #900',
      );
      await tester.pump();
      expect(find.text('Site visit #1'), findsNothing);
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(find.text('No visits match "visit #900"'), findsOneWidget);
      await expectLater(
        find.byKey(surfaceKey),
        matchesGoldenFile('goldens/no_matches.png'),
      );
      final clear = find.bySemanticsLabel('Clear search');
      expect(tester.getSize(clear).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(clear).height, greaterThanOrEqualTo(48));
      api.onFetch = null;
      await tester.tap(clear);
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(find.text('Site visit #1'), findsOneWidget);
    },
  );

  testWidgets('first page errors and empty assignments have honest states', (
    tester,
  ) async {
    final api = FakeApi()
      ..onFetch = (_, _) => Future.error(ApiException('Unavailable'));
    await mount(tester, api, MemoryStore());
    expect(find.text('Couldn’t load your visits'), findsOneWidget);
    await expectLater(
      find.byKey(surfaceKey),
      matchesGoldenFile('goldens/first_error.png'),
    );
    api.onFetch = (_, _) async => TaskPage([], null);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No visits assigned yet'), findsOneWidget);
  });

  testWidgets('toggle responds to taps on both edges of its 48dp target', (
    tester,
  ) async {
    var toggles = 0;
    final visit = Visit.fromJson(task('1'));
    await tester.pumpWidget(
      MaterialApp(
        theme: visitTheme(),
        home: Scaffold(
          body: VisitRow(
            visit: visit,
            status: VisitStatus.open,
            onToggle: () => toggles++,
            onRetry: () {},
          ),
        ),
      ),
    );
    final target = find.bySemanticsLabel('Mark done Site visit #1, open');
    final box = tester.getRect(target);
    expect(box.size, const Size(48, 48));
    await tester.tapAt(Offset(box.left + 1, box.center.dy));
    await tester.tapAt(Offset(box.right - 1, box.center.dy));
    expect(toggles, 2);
  });

  testWidgets('page loading keeps rows visible and its failure offers retry', (
    tester,
  ) async {
    final response = Completer<TaskPage>();
    final api = FakeApi();
    api.onFetch = (cursor, _) => cursor == null
        ? Future.value(TaskPage([task('1')], '20'))
        : response.future;
    await mount(tester, api, MemoryStore());
    await tester.tap(find.text('Load more visits'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.bySemanticsLabel('Loading more visits'), findsOneWidget);
    expect(find.text('Site visit #1'), findsOneWidget);
    response.completeError(ApiException('Page unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load more'), findsOneWidget);
    expect(find.text('Site visit #1'), findsOneWidget);
    api.onFetch = (_, _) async => TaskPage([task('1'), task('2')], null);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Site visit #2'), findsOneWidget);
  });

  testWidgets(
    'archived and untitled variants use the supplied assets and styles',
    (tester) async {
      final api = FakeApi();
      api.onFetch = (_, _) async => TaskPage([
        task('89', status: 'archived'),
        {...task('53', status: 'done'), 'title': null},
      ], null);
      await mount(tester, api, MemoryStore());
      expect(find.text('Archived'), findsOneWidget);
      expect(find.text('Untitled visit'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Untitled visit')).style!.fontStyle,
        FontStyle.italic,
      );
      await expectLater(
        find.byKey(surfaceKey),
        matchesGoldenFile('goldens/row_variants.png'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('first load uses skeleton rows while its request is pending', (
    tester,
  ) async {
    final api = FakeApi();
    api.onFetch = (_, _) => Completer<TaskPage>().future;
    await mount(tester, api, MemoryStore());
    expect(find.bySemanticsLabel('Loading visits'), findsOneWidget);
    await expectLater(
      find.byKey(surfaceKey),
      matchesGoldenFile('goldens/first_load.png'),
    );
  });
}
