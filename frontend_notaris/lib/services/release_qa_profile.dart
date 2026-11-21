import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/auth_session.dart';
import 'auth_service.dart';
import 'windows_qa_profile_io.dart';

const releaseQaEndpoint = 'https://qa-endpoint-unconfigured.invalid/api/v1';

class ReleaseQaConfiguration {
  const ReleaseQaConfiguration({
    required this.environment,
    required this.deployment,
    required this.endpoint,
    required this.schema,
  });
  final String environment, deployment, endpoint, schema;

  void validate() {
    if (environment != 'qa-disconnected' ||
        endpoint != releaseQaEndpoint ||
        schema != '27' ||
        !RegExp(r'^qa-[a-z0-9-]{3,48}$').hasMatch(deployment)) {
      throw StateError('qa_configuration_required');
    }
  }
}

class ReleaseQaDatabase extends AppDatabase {
  ReleaseQaDatabase(super.executor) : super.forBoundProfile();
  @override
  int get schemaVersion => 27;
}

/// Only a new application-owned QA namespace is accepted. No user DB pathname,
/// imported fixture, historical secure storage, or online activation is accepted.
class ReleaseQaProfile {
  ReleaseQaProfile._(
    this.configuration,
    this.root,
    this.directory,
    this.binding,
    this.database,
    this._lock,
  );
  final ReleaseQaConfiguration configuration;
  final Directory root, directory;
  final Map<String, dynamic> binding;
  final ReleaseQaDatabase database;
  final RandomAccessFile _lock;
  bool _closed = false;
  String get databasePath => p.join(directory.path, 'offline.sqlite');
  String get scopeDigest => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            configuration.environment,
            configuration.deployment,
            configuration.endpoint,
            binding['installation_id'],
            binding['device_id'],
            binding['generation'],
            binding['profile_id'],
          ]),
        ),
      )
      .toString();
  String get authKey => 'notaris.qa.v1.$scopeDigest.session';
  File get authFile => File(p.join(directory.path, 'session.dpapi'));

  static final _uuid = RegExp(
    r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
  );
  static const _keys = {
    'format',
    'schema',
    'environment',
    'deployment',
    'endpoint',
    'installation_id',
    'device_id',
    'generation',
    'profile_id',
    'phase',
    'database_file_id',
  };

  static void _plain(String path, {required bool directory}) {
    var current = p.normalize(p.absolute(path));
    while (true) {
      if (FileSystemEntity.typeSync(current, followLinks: false) ==
          FileSystemEntityType.link) {
        throw StateError('qa_link_rejected');
      }
      WindowsQaProfileIo.identity(
        current,
        directory: current == path ? directory : true,
      );
      final parent = p.dirname(current);
      if (p.equals(parent, current)) break;
      current = parent;
    }
  }

  static void _json(File target, Map<String, dynamic> value) {
    if (target.existsSync()) _plain(target.path, directory: false);
    final next = File('${target.path}.next');
    next.createSync(exclusive: true);
    next.writeAsStringSync(jsonEncode(value), flush: true);
    next.renameSync(target.path);
  }

  static Future<ReleaseQaProfile> open(
    ReleaseQaConfiguration config, {
    required Directory applicationSupport,
  }) async {
    config.validate(); // before directory/plugin/SQLite access
    if (!Platform.isWindows) throw StateError('qa_windows_required');
    _plain(applicationSupport.path, directory: true);
    final root = Directory(
      p.join(applicationSupport.path, 'qa-release-v1', config.deployment),
    );
    // Check existing components before creating anything beneath them.
    for (final dir in [root.parent, root]) {
      if (dir.existsSync()) {
        _plain(dir.path, directory: true);
      } else {
        dir.createSync();
        _plain(dir.path, directory: true);
      }
    }
    final lockFile = File(p.join(root.path, 'profile.lock'));
    if (!lockFile.existsSync()) lockFile.createSync(exclusive: true);
    _plain(lockFile.path, directory: false);
    final lock = await lockFile.open(mode: FileMode.append);
    var locked = false;
    ReleaseQaDatabase? db;
    try {
      await lock.lock(FileLock.exclusive);
      locked = true;
      final marker = File(p.join(root.path, 'binding.json'));
      late Map<String, dynamic> b;
      if (!marker.existsSync()) {
        if (root.listSync().any((f) => p.basename(f.path) != 'profile.lock')) {
          throw StateError('qa_unbound_existing_data');
        }
        b = {
          'format': 1,
          'schema': 27,
          'environment': config.environment,
          'deployment': config.deployment,
          'endpoint': config.endpoint,
          for (final k in [
            'installation_id',
            'device_id',
            'generation',
            'profile_id',
          ])
            k: const Uuid().v4(),
          'phase': 'allocated',
          'database_file_id': null,
        };
        _json(marker, b);
      } else {
        _plain(marker.path, directory: false);
        if (marker.lengthSync() > 16384) throw StateError('qa_binding_invalid');
        b = Map<String, dynamic>.from(
          jsonDecode(marker.readAsStringSync()) as Map,
        );
      }
      if (b.keys.toSet().difference(_keys).isNotEmpty ||
          b.length != _keys.length ||
          b['format'] != 1 ||
          b['schema'] != 27 ||
          b['environment'] != config.environment ||
          b['deployment'] != config.deployment ||
          b['endpoint'] != config.endpoint ||
          [
            'installation_id',
            'device_id',
            'generation',
            'profile_id',
          ].any((k) => !_uuid.hasMatch(b[k]?.toString() ?? '')) ||
          !['allocated', 'initializing', 'ready'].contains(b['phase'])) {
        throw StateError('qa_binding_mismatch');
      }
      final directory = Directory(p.join(root.path, b['profile_id'] as String));
      if (root.listSync().any(
        (f) => !{
          'binding.json',
          'profile.lock',
          b['profile_id'],
        }.contains(p.basename(f.path)),
      )) {
        throw StateError('qa_unexpected_profile_object');
      }
      final file = File(p.join(directory.path, 'offline.sqlite'));
      if (b['phase'] == 'allocated') {
        if (directory.existsSync() || file.existsSync()) {
          throw StateError('qa_allocation_ambiguous');
        }
        directory.createSync();
        file.createSync(exclusive: true);
        b['database_file_id'] = WindowsQaProfileIo.identity(
          file.path,
          directory: false,
        );
        b['phase'] = 'initializing';
        _json(marker, b);
      }
      _plain(directory.path, directory: true);
      _plain(file.path, directory: false);
      if (WindowsQaProfileIo.identity(file.path, directory: false) !=
          b['database_file_id']) {
        throw StateError('qa_database_identity_changed');
      }
      // Initialization uses exactly the existing Drift onCreate v27 path.
      // Existing non-v27 DBs are rejected BEFORE Drift could upgrade/downgrade.
      db = ReleaseQaDatabase(
        NativeDatabase(
          file,
          setup: (sqlite) {
            final version = sqlite
                .select('PRAGMA user_version')
                .single
                .values
                .single;
            final count = sqlite
                .select("SELECT count(*) FROM sqlite_master WHERE type='table'")
                .single
                .values
                .single;
            if (version != 27 &&
                !(b['phase'] == 'initializing' && version == 0 && count == 0)) {
              throw StateError('qa_schema_upgrade_not_authorized');
            }
            sqlite.execute('PRAGMA foreign_keys=ON');
            if (sqlite.select('PRAGMA foreign_keys').single.values.single !=
                1) {
              throw StateError('qa_fk_required');
            }
          },
        ),
      );
      await db.customSelect('SELECT 1').get();
      final tables =
          (await db
                  .customSelect(
                    "SELECT name FROM sqlite_master WHERE type='table'",
                  )
                  .get())
              .map((r) => r.read<String>('name'))
              .toSet();
      final required = {
        ...db.allTables.map((t) => t.actualTableName),
        'transaction_document_store',
        'transaction_documents',
        'transaction_document_versions',
        'transaction_document_operations',
        'transaction_document_audit',
        'materai_movements',
        'transaksi_serah_terima',
        'transaksi_pembayaran_audit',
        'transaction_cloud_identity',
        'transaction_cloud_pending',
        'transaction_cloud_feed',
        'recycle_bin_events',
      };
      if (!tables.containsAll(required) ||
          (await db.customSelect('PRAGMA integrity_check').getSingle())
                  .data
                  .values
                  .single !=
              'ok' ||
          (await db.customSelect('PRAGMA foreign_key_check').get())
              .isNotEmpty) {
        throw StateError('qa_schema_integrity_failed');
      }
      b['phase'] = 'ready';
      _json(marker, b);
      final result = ReleaseQaProfile._(config, root, directory, b, db, lock);
      result.record('startup', {
        'schema': 27,
        'foreign_keys': 1,
        'integrity': 'ok',
        'fk_violations': 0,
        'profile': b['profile_id'],
        'device': b['device_id'],
        'generation': b['generation'],
        'deployment': config.deployment,
        'database_path': file.path,
        'auth_namespace': result.authKey,
        'global_sync': 'DISABLED_BY_POLICY',
        'backend': 'DISCONNECTED',
        'account': null,
      });
      return result;
    } catch (_) {
      await db?.close();
      if (locked) await lock.unlock();
      await lock.close();
      rethrow;
    }
  }

  void assertBound() {
    if (_closed ||
        WindowsQaProfileIo.identity(databasePath, directory: false) !=
            binding['database_file_id']) {
      throw StateError('qa_profile_closed_or_changed');
    }
  }

  void record(String event, Map<String, Object?> fields) {
    final file = File(p.join(directory.path, 'runtime-events.jsonl'));
    if (file.existsSync()) _plain(file.path, directory: false);
    file.writeAsStringSync(
      '${jsonEncode({'at': DateTime.now().toUtc().toIso8601String(), 'event': event, ...fields})}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await database.close();
    await _lock.unlock();
    await _lock.close();
  }
}

/// Per-profile current-user DPAPI file. AuthService still owns login, expiry,
/// online verification, logout and the pre-existing offline authorization policy.
class ReleaseQaSessionCache implements AuthSessionCache {
  ReleaseQaSessionCache(this.profile);
  final ReleaseQaProfile profile;
  void _key(String key) {
    profile.assertBound();
    if (key != profile.authKey) throw StateError('qa_auth_namespace_mismatch');
  }

  @override
  Future<String?> read({required String key}) async {
    _key(key);
    final f = profile.authFile;
    if (!f.existsSync()) {
      profile.record('auth_cache', {'outcome': 'missing'});
      return null;
    }
    ReleaseQaProfile._plain(f.path, directory: false);
    final value = jsonDecode(
      utf8.decode(
        WindowsQaProfileIo.unprotect(f.readAsBytesSync(), profile.scopeDigest),
      ),
    ) as Map;
    final raw = value['session'];
    if (value['binding'] != profile.scopeDigest || raw is! String) {
      throw StateError('qa_auth_profile_mismatch');
    }
    final session = AuthSession.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
    if (value['account'] != session.userId ||
        value['group'] != session.groupId) {
      throw StateError('qa_auth_account_mismatch');
    }
    profile.record('auth_cache', {'outcome': 'present'});
    return raw;
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _key(key);
    final session = AuthSession.fromJson(
      Map<String, dynamic>.from(jsonDecode(value) as Map),
    );
    final bytes = WindowsQaProfileIo.protect(
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'binding': profile.scopeDigest,
            'account': session.userId,
            'group': session.groupId,
            'session': value,
          }),
        ),
      ),
      profile.scopeDigest,
    );
    final target = profile.authFile;
    if (target.existsSync()) {
      ReleaseQaProfile._plain(target.path, directory: false);
    }
    final next = File('${target.path}.next');
    next.createSync(exclusive: true);
    next.writeAsBytesSync(bytes, flush: true);
    next.renameSync(target.path);
  }

  @override
  Future<void> delete({required String key}) async {
    _key(key);
    if (profile.authFile.existsSync()) {
      ReleaseQaProfile._plain(profile.authFile.path, directory: false);
      profile.authFile.deleteSync();
    }
  }
}
