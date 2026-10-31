/// Local contract for a future Petugas cloud-sync transport.
///
/// This layer intentionally has no endpoint or Dio dependency. The server
/// contract is not implemented yet, so these types only make identity and
/// acknowledgement boundaries explicit in Flutter.
enum PetugasIdentityState {
  localOnly('local_only'),
  verified('verified'),
  ambiguous('ambiguous'),
  serverOnly('server_only'),
  development('development');

  const PetugasIdentityState(this.databaseValue);

  final String databaseValue;

  bool get hasActiveCloudIdentity => this == verified || this == serverOnly;

  static PetugasIdentityState fromDatabaseValue(String value) {
    return PetugasIdentityState.values.firstWhere(
      (state) => state.databaseValue == value,
      orElse: () =>
          throw FormatException('State mapping Petugas tidak dikenal: $value'),
    );
  }
}

/// Separates immutable local identity from server identity.
class PetugasSyncIdentity {
  const PetugasSyncIdentity({
    required this.localId,
    required this.localUuid,
    required this.state,
    this.cloudUuid,
    this.serverId,
    this.rowVersion,
  });

  final int localId;
  final String localUuid;
  final String? cloudUuid;
  final int? serverId;
  final int? rowVersion;
  final PetugasIdentityState state;
}

/// Cursor for a pull feed. It is distinct from a record's [rowVersion].
class PetugasPullCursor {
  const PetugasPullCursor({required this.scope, required this.sequence});

  final String scope;
  final int sequence;
}

/// Acknowledgement data expected from a future Petugas sync endpoint.
class PetugasSyncAcknowledgement {
  const PetugasSyncAcknowledgement({
    required this.cloudUuid,
    required this.serverId,
    required this.rowVersion,
    this.publishedSequence,
  });

  final String cloudUuid;
  final int serverId;
  final int rowVersion;
  final int? publishedSequence;
}
