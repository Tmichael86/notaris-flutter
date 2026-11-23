import 'dart:io';

/// Use the native Windows PowerShell executable, not a PATH alias which may
/// exist in an IDE shell but be unavailable to Dart's child process.
String windowsPowerShellExecutable() {
  if (!Platform.isWindows) throw UnsupportedError('Windows acceptance only');
  final root = Platform.environment['SystemRoot'];
  if (root == null || root.isEmpty) throw StateError('SystemRoot unavailable');
  final file = File('$root/System32/WindowsPowerShell/v1.0/powershell.exe');
  if (!file.existsSync()) throw StateError('Windows PowerShell unavailable');
  return file.resolveSymbolicLinksSync();
}

bool resumeAcknowledgementMatches(Map identity, Map pending, Map ack) =>
    pending['state'] == 'acked' &&
    identity['local_uuid'] == ack['uuid'] &&
    identity['cloud_uuid'] == ack['uuid'] &&
    identity['revision'] == 1 &&
    ack['revision'] == 1 &&
    pending['mutation_id'] == ack['mutation_id'];
