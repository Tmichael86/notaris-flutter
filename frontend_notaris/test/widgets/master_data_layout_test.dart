import 'dart:ui' as ui;

import 'package:frontend_notaris/models/auth_session.dart';

import 'package:flutter/rendering.dart';

import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/screens/pekerjaan_ppat_desktop_screen.dart';
import 'package:drift/native.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/core/widgets/master_data_viewport.dart';
import 'package:frontend_notaris/core/widgets/app_shell.dart';
import 'package:frontend_notaris/screens/pemohon_desktop_screen.dart';
import 'package:frontend_notaris/screens/petugas_desktop_screen.dart';
import 'package:frontend_notaris/screens/kategori_pekerjaan_desktop_screen.dart';
import 'package:frontend_notaris/screens/jenis_pengeluaran_desktop_screen.dart';
import 'package:frontend_notaris/screens/pekerjaan_notaris_desktop_screen.dart';

const pages = <String, Widget>{
  'Pemohon': PemohonDesktopScreen(),
  'Petugas': PetugasDesktopScreen(),
  'Kategori': KategoriPekerjaanDesktopScreen(),
  'Pengeluaran': JenisPengeluaranDesktopScreen(),
  'Notaris': PekerjaanNotarisDesktopScreen(),
  'PPAT': PekerjaanPPATDesktopScreen(),
};
Future<AppDatabase> fixture(int count) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  for (final table in [
    'pemohons',
    'petugas',
    'pekerjaan_kategori',
    'pengeluaran_jenis',
    'pekerjaan_notaris',
    'pekerjaan_ppat',
  ]) {
    for (var i = 0; i < count; i++) {
      await db.customStatement(
        'INSERT INTO $table(uuid,nama${table == 'petugas' ? ',email' : ''}) VALUES(?,?${table == 'petugas' ? ',?' : ''})',
        [
          '$table-$i',
          'Fixture ${i.toString().padLeft(2, '0')}',
          if (table == 'petugas') 'fixture$i@example.invalid',
        ],
      );
    }
  }
  return db;
}

void main() {
  setUpAll(() async {
    // Use the SDK's real Roboto rather than Ahem: the unchanged shell brand
    // has fixed intrinsic text sizing that Ahem artificially overflows.
    final config = jsonDecode(
      await File('.dart_tool/package_config.json').readAsString(),
    ) as Map;
    final flutter = (config['packages'] as List).singleWhere(
      (p) => p['name'] == 'flutter',
    );
    final root = Uri.parse(flutter['rootUri'] as String);
    final font = File.fromUri(
      Uri.parse(
        '$root/',
      ).resolve('../../bin/cache/artifacts/material_fonts/Roboto-Regular.ttf'),
    );
    final loader = FontLoader('Roboto')
      ..addFont(font.readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final size in [
    const Size(1440, 900),
    const Size(980, 600),
    const Size(1920, 1080),
  ]) {
    for (final entry in pages.entries) {
      for (final count in [0, 20]) {
        testWidgets(
          '${entry.key} $size count=$count fills content and keeps pagination bounded',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final db = await fixture(count);
            addTearDown(db.close);
            final wrapped = entry.key == 'Pemohon' || entry.key == 'Petugas';
            await tester.pumpWidget(
              ProviderScope(
                overrides: [appDatabaseProvider.overrideWithValue(db)],
                child: MaterialApp(
                  theme: ThemeData(
                    platform: TargetPlatform.windows,
                    fontFamily: 'Roboto',
                  ),
                  home: Scaffold(
                    body: Column(
                      children: [
                        const SizedBox(height: 60, child: Text('Header')),
                        Expanded(
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 220,
                                child: Text('Sidebar'),
                              ),
                              Expanded(
                                child: wrapped
                                    ? SingleChildScrollView(child: entry.value)
                                    : entry.value,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          height: 60,
                          child: Center(
                            child: Text('Footer', key: Key('footer')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final pageRect = tester.getRect(find.byType(MasterDataViewport));
            expect(pageRect.height, closeTo(size.height - 120, 1));
            expect(find.text('Footer'), findsOneWidget);
            if (count > 0) {
              expect(
                tester.widget<DataTable>(find.byType(DataTable)).rows.length,
                10,
              );
              final viewport = tester.getRect(
                find.byType(MasterDataTableViewport),
              );
              expect(viewport.bottom, lessThan(size.height - 60));
              final widget = tester.widget<MasterDataTableViewport>(
                find.byType(MasterDataTableViewport),
              );
              final bars = tester.widgetList<Scrollbar>(
                find.descendant(
                  of: find.byType(MasterDataTableViewport),
                  matching: find.byType(Scrollbar),
                ),
              );
              expect(
                bars
                    .where((b) => b.controller == widget.verticalController)
                    .length,
                1,
              );
              expect(
                bars
                    .where((b) => b.controller == widget.horizontalController)
                    .length,
                1,
              );
              final vertical = tester
                  .widget<MasterDataTableViewport>(
                    find.byType(MasterDataTableViewport),
                  )
                  .verticalController;
              if (size.height == 600) {
                expect(vertical.position.maxScrollExtent, greaterThan(0));
                vertical.jumpTo(vertical.position.maxScrollExtent);
                await tester.pump();
              }
              expect(tester.takeException(), isNull);
              // Pagination is outside both scrollbars and remains hit-testable.
              final next =
                  find.byIcon(Icons.chevron_right).evaluate().isNotEmpty
                  ? find.byIcon(Icons.chevron_right)
                  : find.text('Next');
              if (next.evaluate().isNotEmpty) {
                await tester.tap(next);
                await tester.pumpAndSettle();
                expect(
                  tester.widget<DataTable>(find.byType(DataTable)).rows.length,
                  10,
                );
              }
            } else {
              expect(find.byType(DataTable), findsNothing);
            }
            tester.view.physicalSize = Size(size.width, size.height + 120);
            await tester.pumpAndSettle();
            expect(
              tester.getRect(find.byType(MasterDataViewport)).height,
              closeTo(size.height, 1),
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          },
        );
      }
    }
  }
  for (final width in [1440.0, 980.0, 899.0, 600.0, 400.0]) {
    testWidgets('Job master search layouts match at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = await fixture(0);
      addTearDown(db.close);
      Rect? referenceSearch;
      Rect? referenceCount;
      InputDecoration? referenceDecoration;
      for (final page in [
        const PekerjaanNotarisDesktopScreen(),
        const PekerjaanPPATDesktopScreen(),
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              theme: ThemeData(
                platform: TargetPlatform.windows,
                fontFamily: 'Roboto',
              ),
              home: Scaffold(body: page),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final search = tester.getRect(find.byType(TextField));
        final count = tester.getRect(find.text('0 data'));
        final decoration = tester
            .widget<TextField>(find.byType(TextField))
            .decoration!;
        final card = tester.getRect(
          find
              .ancestor(
                of: find.byType(TextField),
                matching: find.byType(Container),
              )
              .first,
        );
        // Container includes its 1px border in addition to the 16px padding.
        const inset = 17.0;
        expect(search.left - card.left, closeTo(inset, .01));
        expect(search.top - card.top, closeTo(inset, .01));
        if (width >= 900) {
          expect(count.left - search.right, closeTo(14, .01));
          expect(count.right, closeTo(card.right - inset, .01));
          expect(count.center.dy, closeTo(search.center.dy, .01));
        } else {
          expect(search.right, closeTo(card.right - inset, .01));
          expect(count.left, search.left);
          expect(count.top - search.bottom, closeTo(8, .01));
        }
        if (referenceSearch != null) {
          expect(search, referenceSearch);
          expect(count, referenceCount);
          expect(decoration.border, referenceDecoration!.border);
          expect(decoration.contentPadding, referenceDecoration.contentPadding);
          expect(decoration.constraints, referenceDecoration.constraints);
          expect(decoration.hintText, referenceDecoration.hintText);
          expect(
            (decoration.prefixIcon! as Icon).icon,
            (referenceDecoration.prefixIcon! as Icon).icon,
          );
          expect(
            (decoration.prefixIcon! as Icon).size,
            (referenceDecoration.prefixIcon! as Icon).size,
          );
        }
        referenceSearch = search;
        referenceCount = count;
        referenceDecoration = decoration;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    });
  }
  for (final allowed in [false, true]) {
    testWidgets('Fixture PPAT sidebar read permission $allowed', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = await fixture(0);
      addTearDown(db.close);
      final session = AuthSession(
        token: 'fixture',
        userId: 2001,
        groupId: 11,
        userName: 'Fixture',
        groupName: 'Fixture Operators',
        user: const {},
        verifiedAt: DateTime.now(),
        sidebars: [
          {
            'sidebar': {'sidebar_nama': 'Pekerjaan Notaris'},
            'read': 1,
          },
          {
            'sidebar': {'sidebar_nama': 'Pekerjaan PPAT'},
            'read': allowed ? 1 : 0,
          },
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'Roboto'),
            home: AppShell(session: session),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Master').first);
      await tester.pumpAndSettle();
      expect(find.text('Pekerjaan Notaris'), findsOneWidget);
      expect(
        find.text('Pekerjaan PPAT'),
        allowed ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('persistent shell navigation between masters retains footer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = await fixture(21);
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: RepaintBoundary(
          key: Key('capture'),
          child: MaterialApp(
            theme: ThemeData(
              platform: TargetPlatform.windows,
              fontFamily: 'Roboto',
            ),
            home: const AppShell(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Master').first);
    await tester.pumpAndSettle();
    for (final label in [
      'Pekerjaan Notaris',
      'Kategori Pekerjaan',
      'Jenis Pengeluaran',
      'Petugas',
      'Pemohon',
    ]) {
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
      expect(find.byType(MasterDataViewport), findsOneWidget);
      expect(find.textContaining('Copyright Blitaris'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    final capture = Platform.environment['MASTER_LAYOUT_CAPTURE'];
    if (capture != null) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('capture')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(capture).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
