import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/windows_powershell.dart';

void main() {
  test('native Windows PowerShell executes File arguments and parses publisher without write', () async {
    final folder = await Directory.systemTemp.createTemp(
      'powershell invocation ',
    );
    addTearDown(() => folder.delete(recursive: true));
    final script = File('${folder.path}/non write check.ps1');
    await script.writeAsString(r'''
param([string]$Repo,[string]$Value)
$ErrorActionPreference='Stop'
foreach($path in @('scripts/invoke-notarisdev-master-publisher.ps1','scripts/petugas-operations-common.ps1','scripts/run-notarisdev-monitor-acceptance.ps1')) {
 $tokens=$null;$errors=$null
 [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Repo $path),[ref]$tokens,[ref]$errors)|Out-Null
 if($errors.Count){throw 'Publisher/launcher is not compatible'}
}
@{version=$PSVersionTable.PSVersion.Major;value=$Value}|ConvertTo-Json -Compress
''');
    final executable = windowsPowerShellExecutable();
    expect(File(executable).existsSync(), isTrue);
    final result = await Process.run(executable, [
      '-NoProfile',
      '-NonInteractive',
      '-File',
      script.path,
      '-Repo',
      Directory.current.parent.path,
      '-Value',
      'argument with spaces',
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final parsed = jsonDecode(result.stdout.toString().trim()) as Map;
    expect(parsed['version'], greaterThanOrEqualTo(5));
    expect(parsed['value'], 'argument with spaces');
  }, skip: !Platform.isWindows);
  test('resume requires same durable ACK identity revision and mutation', () {
    final ack = {'uuid': 'approved', 'mutation_id': 'original', 'revision': 1};
    final id = {
      'local_uuid': 'approved',
      'cloud_uuid': 'approved',
      'revision': 1,
    };
    final pending = {'mutation_id': 'original', 'state': 'acked'};
    expect(resumeAcknowledgementMatches(id, pending, ack), isTrue);
    expect(
      resumeAcknowledgementMatches(id, {...pending, 'state': 'pending'}, ack),
      isFalse,
    );
    expect(
      resumeAcknowledgementMatches(id, pending, {
        ...ack,
        'mutation_id': 'different',
      }),
      isFalse,
    );
    expect(
      resumeAcknowledgementMatches(
        {...id, 'cloud_uuid': 'different'},
        pending,
        ack,
      ),
      isFalse,
    );
    expect(
      resumeAcknowledgementMatches(id, pending, {...ack, 'revision': 2}),
      isFalse,
    );
  });
}
