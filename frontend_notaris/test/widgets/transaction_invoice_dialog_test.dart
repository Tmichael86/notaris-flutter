import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/screens/transaction_desktop_screen.dart';
import 'package:frontend_notaris/widgets/transaction_invoice_dialog.dart';
import 'package:printing/printing.dart';

import '../repositories/recycle_bin_repository_test.dart'
    show recoverySession, seedTransaction;
import '../support/transaction_ui_test_support.dart'
    show TransactionUiAuth, uiSession;

void main() {
  testWidgets(
    'saved PPAT opens preview and prints the exact preview PDF as a reader',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await seedTransaction(db, 'notaris');
      final id = await seedTransaction(db, 'ppat');
      Future<int> changes() async =>
          (await db.customSelect('SELECT total_changes() AS n').getSingle())
              .read<int>('n');
      final before = await changes();
      final session = recoverySession(update: false, only: 'transaksi');
      const channel = MethodChannel('net.nfet.printing');
      const codec = StandardMethodCodec();
      final messenger = tester.binding.defaultBinaryMessenger;
      Uint8List? preview;
      Uint8List? printed;
      int prints = 0;
      Future<ByteData?> callback(
        String name,
        Map<Object?, Object?> args,
      ) async {
        ByteData? result;
        await messenger.handlePlatformMessage(
          channel.name,
          codec.encodeMethodCall(MethodCall(name, args)),
          (reply) => result = reply,
        );
        return result;
      }

      messenger.setMockMethodCallHandler(channel, (call) async {
        final args = Map<Object?, Object?>.from(call.arguments as Map);
        switch (call.method) {
          case 'printingInfo':
            return {'canPrint': true, 'canRaster': true};
          case 'rasterPdf':
            preview = args['doc'] as Uint8List;
            await callback('onPageRasterized', {
              'job': args['job'],
              'width': 1,
              'height': 1,
              'image': Uint8List.fromList([255, 255, 255, 255]),
            });
            await callback('onPageRasterEnd', {'job': args['job']});
          case 'printPdf':
            prints++;
            expect(args['name'], 'Invoice 2000611260001');
            expect(args['dynamic'], isFalse);
            printed = codec.decodeEnvelope(
              (await callback('onLayout', args))!,
            ) as Uint8List;
            await callback('onCompleted', {
              'job': args['job'],
              'completed': false,
            });
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authControllerProvider.overrideWith(
              (_) => TransactionUiAuth(session),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: TransactionDesktopScreen()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lihat Invoice'), findsNothing);
      await tester.tap(find.text('PPAT').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cari No. Transaksi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2000611260001').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lihat Invoice'));
      for (var frame = 0; frame < 25 && preview == null; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final widget = tester.widget<TransactionInvoiceDialog>(
        find.byType(TransactionInvoiceDialog),
      );
      expect(widget.transactionId, id);
      final pdf = tester.widget<PdfPreview>(find.byType(PdfPreview));
      expect(pdf.allowSharing, isFalse);
      expect(preview, isNotNull);
      expect(prints, 0);
      await tester.tap(find.text('Cetak'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(prints, 1);
      expect(printed, orderedEquals(preview!));
      expect(await changes(), before);
      expect(
        find.text('Pencetakan dibatalkan atau tidak selesai.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'invoice dialog exposes neither preview nor print without read access',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              (_) => TransactionUiAuth(uiSession(permission: false)),
            ),
          ],
          child: const MaterialApp(
            home: TransactionInvoiceDialog(transactionId: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Izin baca Transaksi diperlukan.'), findsOneWidget);
      expect(find.byType(PdfPreview), findsNothing);
      expect(find.text('Cetak'), findsNothing);
    },
  );
}
