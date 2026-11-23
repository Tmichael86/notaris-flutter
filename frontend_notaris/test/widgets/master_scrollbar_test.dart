import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/core/widgets/master_data_viewport.dart';

void main() {
  testWidgets('automatic Windows scrollbars outside table remain enabled', (
    tester,
  ) async {
    final v = ScrollController(),
        h = ScrollController(),
        outside = ScrollController();
    addTearDown(v.dispose);
    addTearDown(h.dispose);
    addTearDown(outside.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: MasterDataTableViewport(
                  verticalController: v,
                  horizontalController: h,
                  child: const SizedBox(height: 1000, width: 1200),
                ),
              ),
              SizedBox(
                height: 100,
                child: SingleChildScrollView(
                  controller: outside,
                  child: const SizedBox(height: 500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<Scrollbar>(find.byType(Scrollbar))
          .where((b) => b.controller == outside)
          .length,
      1,
    );
    expect(
      tester
          .widgetList<Scrollbar>(find.byType(Scrollbar))
          .where((b) => b.controller == v)
          .length,
      1,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(v.hasClients, isFalse);
    expect(h.hasClients, isFalse);
    expect(outside.hasClients, isFalse);
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(980, 600),
    const Size(1440, 900),
    const Size(1920, 1080),
  ]) {
    testWidgets('Windows single controller scrollbar per axis $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vertical = ScrollController();
      final horizontal = ScrollController();
      final primary = ScrollController();
      addTearDown(vertical.dispose);
      addTearDown(horizontal.dispose);
      addTearDown(primary.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.windows),
          home: PrimaryScrollController(
            controller: primary,
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Expanded(
                      child: MasterDataTableViewport(
                        horizontalController: horizontal,
                        verticalController: vertical,
                        child: DataTable(
                          dataRowMinHeight: 96,
                          dataRowMaxHeight: 96,
                          columns: const [
                            DataColumn(
                              label: SizedBox(width: 700, child: Text('Name')),
                            ),
                            DataColumn(
                              label: SizedBox(
                                width: 400,
                                child: Text('Actions'),
                              ),
                            ),
                          ],
                          rows: List.generate(
                            10,
                            (i) => DataRow(
                              cells: [
                                DataCell(Text('row $i')),
                                const DataCell(Text('edit')),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 60,
                      child: Center(child: Text('Pagination')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bars = tester
          .widgetList<Scrollbar>(
            find.descendant(
              of: find.byType(MasterDataTableViewport),
              matching: find.byType(Scrollbar),
            ),
          )
          .toList();
      expect(bars.where((b) => identical(b.controller, vertical)).length, 1);
      expect(bars.where((b) => identical(b.controller, horizontal)).length, 1);
      expect(bars.length, 2);
      expect(vertical.positions.length, 1);
      expect(horizontal.positions.length, 1);
      expect(primary.hasClients, isFalse);
      expect(vertical.position.axis, Axis.vertical);
      expect(horizontal.position.axis, Axis.horizontal);
      final pagination = tester.getRect(find.text('Pagination'));
      final headerBefore = tester.getRect(find.text('Actions'));
      expect(vertical.position.maxScrollExtent, greaterThan(0));
      // Mouse drag the manual thumb in its reserved right-hand rail.
      final rect = tester.getRect(find.byType(MasterDataTableViewport));
      await tester.dragFrom(
        Offset(rect.right - 4, rect.top + 24),
        const Offset(0, 150),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(vertical.offset, greaterThan(0));
      expect(horizontal.offset, 0);
      expect(tester.getRect(find.text('Pagination')), pagination);
      vertical.jumpTo(0);
      await tester.pump();
      if (horizontal.position.maxScrollExtent > 0) {
        await tester.dragFrom(
          Offset(rect.left + 24, rect.bottom - 4),
          const Offset(150, 0),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        expect(horizontal.offset, greaterThan(0));
        expect(vertical.offset, 0);
        horizontal.jumpTo(horizontal.position.maxScrollExtent);
        await tester.pump();
        expect(
          tester.getRect(find.text('Actions')).left,
          lessThan(headerBefore.left),
        );
        expect(
          tester.getRect(find.text('edit').first).left,
          tester.getRect(find.text('Actions')).left,
        );
      }
      tester.view.physicalSize = Size(size.width - 100, size.height - 80);
      await tester.pumpAndSettle();
      expect(vertical.positions.length, 1);
      expect(horizontal.positions.length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
