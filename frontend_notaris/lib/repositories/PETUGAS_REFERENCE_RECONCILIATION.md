# Verified references and legacy reconciliation

Schema v12 adds private SQL tables petugas_gender_reference and
petugas_user_reference. The additive migration leaves local IDs/UUIDs, transaction
links, mutation journal, acknowledged versions and cursor untouched. SQLite-backed
migration tests explicitly verify the v11 upgrade with pending work.

VerifiedPetugasReferences implements the existing payload/pull resolver interface.
Use the same stable deployment/account scope as PetugasLocalSyncRepository.
The latter rejects a resolver with another scope. Never use a JWT as the scope.

Gender mapping is an explicit operator-attested pair: local reference UUID ->
server row ID in that deployment. Local UUID is only a local key; dev-* is never
sent as a cloud UUID or used to infer a pair. confirmGender requires a positive
server ID and reviewed evidence from a trusted server/operator source. It is NOT
an automatic server lookup, nor proof that a label is canonical. It supports an
independently verified selection today, while the backend contract remains limited.
An active server ID maps to only one local UUID per scope. Repeated confirmation
is safe; reassigning a verified local reference to a different server ID is blocked.
markGenderAmbiguous withdraws the mapping so subsequent resolution fails closed.

Repository evidence: Go PetugasPayload uses jenis_kelamin_id; DATABASE_STRUCTURE.md
section 7.1 defines only integer ID and name plus metadata; routes/routes.go has
no jenis-kelamin read route. No unique immutable label/code is established by this
source. Therefore automatic canonical gender discovery remains blocked. Minimal
future contract: an authenticated server reference catalog with server ID, active
status and a documented unique immutable canonical code/UUID plus deployment
identity. Do not invent it in the Flutter client or use equality of labels/IDs.

verifyUserFromServer consumes the existing authenticated UserApiService GET /users,
selecting exactly one active row by server ID. The caller must supply the service
bound to the same authenticated deployment/account; scope strings are a binding,
not cryptographic server attestation. No username/name/email matching and no user
creation occurs. Cached provenance is removed before refresh; failed refresh or
revocation leaves the reference blocked. A users-read permission failure cannot
be bypassed with local IDs. This cache proves selection origin, not perpetual
authorization: refresh before manual operation/session changes. Server validation
remains authoritative. No automatic refresh scheduler is enabled.

Missing, ambiguous, inactive, unproven and wrong-scope reference decisions raise
PetugasSyncFailure with code blocked_reference. Non-null references must pass
resolution before preparing any mutation. Pending requests are preserved exactly
on retry but their referenced server rows must still have verified mappings.

PetugasIdentityReconciliation is the future UI's explicit confirmation boundary:
confirmVerified, confirmLocalOnly, confirmServerOnly, markAmbiguous, markDevelopment.
PetugasServerIdentity.fromRecord accepts a selected authenticated canonical server
record (uuid/id/row_version) and scope; it rejects dev/non-UUID cloud identities.
The caller supplies reviewed pairing evidence. Confirmation establishes row_version
without clearing dirty or copying server fields over local content. Server-only
confirmation accepts only already materialized clean local rows. Normal pull remains
responsible for safe materialization by explicit cloud UUID and server ID.

All decisions are transactional. Pending mutation blocks reclassification. Existing
active cloud identities cannot be replaced/demoted by this facade; changing an
established version requires sync/conflict resolution. Duplicate UUID/server-ID
pairs are rejected by the existing mapping invariants. Same-pair/version confirmation
is repeatable. No local UUID, integer ID or transaction reference is rewritten.
Low-level mapping repository remains for trusted sync acknowledgements/imports;
future UI must use this reconciliation facade, not bypass its pending-work guard.

Legacy dirty/unlinked data requires explicit operator decisions; name/email/NIK
never auto-match. Ambiguous/development mappings do not enter push. Dirty pull
conflicts roll back that page/cursor. No conflict resolution, full-resync reset,
UI, automatic sync or production migration is introduced in this checkpoint.
