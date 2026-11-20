import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/core/widgets/app_shell.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/authenticated_api_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/pekerjaan_provider.dart';
import 'package:frontend_notaris/repositories/materai_repository.dart';
import 'package:frontend_notaris/repositories/materai_stock_repository.dart';
import 'package:frontend_notaris/repositories/pendapatan_repository.dart';
import 'package:frontend_notaris/repositories/pengeluaran_repository.dart';
import 'package:frontend_notaris/repositories/penghasilan_repository.dart';
import 'package:frontend_notaris/repositories/piutang_repository.dart';
import 'package:frontend_notaris/repositories/recycle_bin_repository.dart';
import 'package:frontend_notaris/screens/groups_desktop_screen.dart';
import 'package:frontend_notaris/services/auth_service.dart';
import 'package:frontend_notaris/services/group_api_service.dart';
import 'package:frontend_notaris/services/group_sidebar_access_api_service.dart';

import '../services/administration_auth_test.dart' show ReadyAuth;
import 'groups_v1_http_test.dart' show click;
import 'users_v1_http_test.dart' show network;

class _Http extends HttpOverrides {}

void main() {
  final base = Platform.environment['NOTARIS_GROUPS_V2_HTTP'];
  testWidgets(
    'full catalog UI HTTP save/revoke -> refreshed local repository and shell enforcement',
    (t) async {
      t.view.physicalSize = const Size(1366, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final font = FontLoader('FullCatalog')
        ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
      await font.load();
      final clients = <Dio>[];
      Dio client([String? token]) {
        final d = Dio(
          BaseOptions(
            baseUrl: base!,
            followRedirects: false,
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
            headers: {if (token != null) 'Authorization': 'Bearer $token'},
          ),
        );
        d.httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () =>
              _Http().createHttpClient(null)..findProxy = (_) => 'DIRECT',
        );
        clients.add(d);
        addTearDown(() => d.close(force: true));
        return d;
      }

      final dio = client(), auth = AuthService(dio: dio);
      final actor = (await t.runAsync(
        () => auth.refreshPermissions(
          Platform.environment['NOTARIS_GROUPS_V2_TOKEN']!,
        ),
      ))!;
      final memberToken = Platform.environment['NOTARIS_GROUPS_V2_MEMBER']!;
      final memberClient = client(memberToken);
      Future<AuthSession> refresh() =>
          AuthService(dio: client(memberToken)).refreshPermissions(memberToken);
      final controller = ReadyAuth(auth, actor);
      installAuthenticatedSessionInterceptor(
        dio,
        baseUrl: base!,
        currentSession: () => controller.state.session,
        onRejected: controller.handleApiRejection,
      );
      final api = GroupSidebarAccessApiService(dio),
          db = MateraiProfileDatabase(NativeDatabase.memory());
      final auditApi = GroupSidebarAccessApiService(client(actor.token));
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          authControllerProvider.overrideWith((_) => controller),
          groupApiServiceProvider.overrideWithValue(GroupApiService(dio)),
          groupSidebarAccessApiServiceProvider.overrideWithValue(api),
        ],
      );
      var disposed = false;
      var detached = false;
      Future<void> detach() async {
        if (detached) return;
        detached = true;
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
        container.dispose();
        for (final client in clients) {
          client.close(force: true);
        }
        await t.pumpAndSettle();
      }

      Future<void> cleanup() async {
        if (disposed) return;
        disposed = true;
        await detach();
        await t.runAsync(db.close);
        await t.pump();
      }

      addTearDown(cleanup);
      await db.customSelect('SELECT 1').get();
      await db.customStatement('PRAGMA foreign_keys=ON');
      // No financial, master or sync mutation is necessary to prove read gates.
      await db.customStatement('PRAGMA query_only=ON');
      final sqliteBefore =
          (await db
                  .customSelect(
                    "SELECT name,sql FROM sqlite_master ORDER BY name",
                  )
                  .get())
              .map((r) => r.data)
              .toList();
      AuthSession? current = (await t.runAsync(refresh))!;
      final expense = PengeluaranRepository(db, () => current);
      const filter = (
        from: null,
        through: null,
        jenisId: null,
        search: '',
        page: 0,
      );
      await expectLater(
        expense.readExport(filter),
        throwsA(isA<PengeluaranFailure>()),
      );
      await t.runAsync(() async {
        await expectLater(
          PiutangRepository(
            db,
            () => current,
          ).read((domain: 'all', from: null, through: null, search: '')),
          throwsStateError,
        );
        await expectLater(
          PenghasilanRepository(db, () => current).read(),
          throwsStateError,
        );
        await expectLater(
          MateraiRepository(db, () => current).read(),
          throwsStateError,
        );
        await expectLater(
          PendapatanRepository(
            db,
            () => current,
          ).read((from: DateTime.utc(2026), through: DateTime.utc(2027))),
          throwsStateError,
        );
      });
      final before = (await t.runAsync(() => auditApi.getByGroup(2)))!;
      expect(before.entries.length, 21);
      expect(before.entries.where((r) => r.editable).length, 19);
      Future<void> groups() async {
        await t.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: ThemeData(fontFamily: 'FullCatalog'),
              home: const Scaffold(body: GroupsDesktopScreen()),
            ),
          ),
        );
        await network(t);
      }

      await groups();
      await click(t, find.byTooltip('Atur Akses Operator'));
      for (final row in before.entries.where((r) => r.editable)) {
        expect(find.byKey(ValueKey('access-row-${row.id}')), findsOneWidget);
        await click(t, find.byKey(ValueKey('access-${row.id}-0')));
        final extra = {4, 11, 22, 24, 27, 28, 29, 30}.contains(row.id)
            ? 3
            : row.id == 32
            ? 1
            : 0;
        for (var c = 1; c <= extra; c++) {
          await click(t, find.byKey(ValueKey('access-${row.id}-$c')));
        }
      }
      await click(t, find.text('Simpan Perubahan'));
      debugPrint(
        'full-catalog: UI save completed, verifying persisted snapshot',
      );
      final saved = (await t.runAsync(() => auditApi.getByGroup(2)))!;
      debugPrint('full-catalog: persisted snapshot received');
      expect(saved.revision, 2);
      for (final row in saved.entries.where((r) => !r.editable)) {
        expect(
          row.flags,
          before.entries.firstWhere((r) => r.id == row.id).flags,
        );
      }
      current = (await t.runAsync(refresh))!;
      debugPrint('full-catalog: member permissions refreshed');
      expect(current.token, memberToken);
      expect(current.canUseOnlineAdministration, false);
      expect(current.canExportMonitoring, true);
      expect(canCreateMaterai(current), true);
      expect(canReadPendapatan(current), true);
      await t.runAsync(() async {
        expect(await expense.readExport(filter), isEmpty);
        await PiutangRepository(
          db,
          () => current,
        ).read((domain: 'all', from: null, through: null, search: ''));
        await PenghasilanRepository(db, () => current).read();
        await PendapatanRepository(
          db,
          () => current,
        ).read((from: DateTime.utc(2026), through: DateTime.utc(2027)));
        await MateraiRepository(db, () => current).read();
        expect(
          RecycleBinRepository(db, () => current).canRead(RecycleModule.ppat),
          true,
        );
        // CREATE flag alone cannot manufacture the verified offline actor/profile.
        await expectLater(
          MateraiStockRepository(
            MateraiStockBinding(
              db,
              '0123456789abcdef0123456789abcdef',
              '0' * 64,
            ),
            () => current,
          ).context(),
          throwsA(isA<MateraiStockException>()),
        );
      });
      debugPrint('full-catalog: local read and actor boundaries verified');
      await t.runAsync(() async {
        for (final path in ['/users', '/groups']) {
          await expectLater(
            memberClient.get(path),
            throwsA(
              isA<DioException>().having(
                (e) => e.response?.statusCode,
                'ordinary group cannot administer',
                403,
              ),
            ),
          );
        }
        expect((await memberClient.get('/sidebars')).statusCode, 200);
        expect(
          (await memberClient.get('/petugas/references/users/1')).statusCode,
          200,
        );
      });
      // Dependency checks operate at the real local boundary, not checkbox state.
      final granted = current;
      AuthSession without(String code) => AuthSession(
        token: granted.token,
        userId: granted.userId,
        groupId: granted.groupId,
        userName: granted.userName,
        groupName: granted.groupName,
        groupType: granted.groupType,
        user: granted.user,
        verifiedAt: granted.verifiedAt,
        sidebars: granted.sidebars
            .where((a) => (a['sidebar'] as Map)['sidebar_kode'] != code)
            .toList(),
      );
      current = without('transaksi');
      expect(current.canExportMonitoring, false);
      for (final dependency in [
        'penghasilan',
        'pengeluaran',
        'laporan_pendapatan',
      ]) {
        current = without(dependency);
        await t.runAsync(() async {
          await expectLater(
            PendapatanRepository(
              db,
              () => current,
            ).read((from: DateTime.utc(2026), through: DateTime.utc(2027))),
            throwsStateError,
          );
        });
      }
      current = granted;
      await t.pumpWidget(const SizedBox());
      await t.pump();
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'FullCatalog'),
            home: AppShell(session: current),
          ),
        ),
      );
      await network(t);
      expect(find.text('Pengeluaran'), findsWidgets);
      await click(t, find.text('Master').first);
      expect(find.text('Pekerjaan PPAT'), findsWidgets);
      await click(t, find.text('System').first);
      expect(find.text('Recycle Bin'), findsWidgets);
      expect(find.text('Konfigurasi Umum'), findsNothing);
      await t.pumpWidget(const SizedBox());
      await t.pump();
      await groups();
      await click(t, find.byTooltip('Atur Akses Operator'));
      for (final row in saved.entries.where((r) => r.editable)) {
        expect(
          t.widget<Checkbox>(find.byKey(ValueKey('access-${row.id}-0'))).value,
          true,
        );
        await click(t, find.byKey(ValueKey('access-${row.id}-0')));
      }
      await click(t, find.text('Simpan Perubahan'));
      current = (await t.runAsync(refresh))!;
      expect(current.token, memberToken);
      expect(current.canExportMonitoring, false);
      expect(canReadPiutang(current), false);
      expect(canReadPenghasilan(current), false);
      expect(canReadMaterai(current), false);
      expect(
        RecycleBinRepository(db, () => current).canRead(RecycleModule.notaris),
        false,
      );
      await expectLater(
        expense.readExport(filter),
        throwsA(isA<PengeluaranFailure>()),
      );
      await t.runAsync(() async {
        await expectLater(
          memberClient.get('/petugas/references/users/1'),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'revoked',
              403,
            ),
          ),
        );
      });
      await t.pumpWidget(const SizedBox());
      await t.pump();
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'FullCatalog'),
            home: AppShell(session: current),
          ),
        ),
      );
      await network(t);
      expect(find.text('Pengeluaran'), findsNothing);
      expect(find.text('Master'), findsNothing);
      await click(t, find.text('System').first);
      expect(find.text('Log Sinkronisasi'), findsWidgets);
      expect(find.text('Monitoring Sinkronisasi'), findsWidgets);
      expect(find.text('Recycle Bin'), findsNothing);
      // Detach reactive Dashboard reads before the independent native SQLite
      // postcheck; their cancellation belongs to the widget clock.
      await detach();
      debugPrint('full-catalog: views detached before SQLite postcheck');
      await t.runAsync(() async {
        expect(
          (await db
                  .customSelect(
                    "SELECT name,sql FROM sqlite_master ORDER BY name",
                  )
                  .get())
              .map((r) => r.data)
              .toList(),
          sqliteBefore,
        );
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(
          (await db.customSelect('PRAGMA integrity_check').getSingle())
              .data
              .values
              .single,
          'ok',
        );
      });
      expect(t.takeException(), isNull);
      await cleanup();
    },
    skip: base == null,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
