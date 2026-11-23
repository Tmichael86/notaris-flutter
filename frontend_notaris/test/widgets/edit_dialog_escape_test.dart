import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/core/widgets/edit_dialog.dart';
import 'package:frontend_notaris/core/widgets/searchable_dropdown.dart';

void main() {
  for (final dirty in [false, true]) {
    testWidgets('ESC cancel nested overlay repeated close dirty=$dirty', (
      tester,
    ) async {
      var saving = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final controller = TextEditingController();
                  await showEditDialog<void>(
                    context: context,
                    dirty: () => dirty,
                    saving: () => saving,
                    builder: (c) => AlertDialog(
                      title: const Text('Editor'),
                      content: SizedBox(
                        width: 300,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(controller: controller),
                            SearchableDropdown<int>(
                              items: List.generate(8, (i) => i),
                              value: 1,
                              label: 'Dropdown',
                              onChanged: (_) {},
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => cancelEditDialog(c),
                          child: const Text('Batal'),
                        ),
                      ],
                    ),
                  );
                  controller.dispose();
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SearchableDropdown<int>));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Editor'), findsOneWidget);
      saving = true;
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Editor'), findsOneWidget);
      saving = false;
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      if (dirty) {
        expect(find.text('Buang perubahan?'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Editor'), findsOneWidget);
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Buang perubahan').last);
        await tester.pumpAndSettle();
      }
      expect(find.text('Editor'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
