package synccontract

import "testing"

func TestPetugasMutationValidateSeparatesMutationAndRecordIdentity(t *testing.T) {
	version := int64(3)
	mutation := PetugasMutation{
		MutationID:         "client-retry-id",
		Operation:          PetugasUpsert,
		PetugasUUID:        "server-record-id",
		ExpectedRowVersion: &version,
		Payload:            &PetugasPayload{Nama: "Sari", Email: "sari@example.com"},
	}
	if err := mutation.Validate(); err != nil {
		t.Fatalf("Validate() error = %v", err)
	}
}

func TestPetugasMutationRejectsDeleteWithoutVersion(t *testing.T) {
	mutation := PetugasMutation{
		MutationID:  "client-retry-id",
		Operation:   PetugasDelete,
		PetugasUUID: "server-record-id",
	}
	if err := mutation.Validate(); err != ErrInvalidMutation {
		t.Fatalf("Validate() error = %v, want %v", err, ErrInvalidMutation)
	}
}

func TestPetugasPullRequestValidate(t *testing.T) {
	if err := (PetugasPullRequest{Cursor: 10, Limit: 50}).Validate(); err != nil {
		t.Fatalf("valid pull request: %v", err)
	}
	if err := (PetugasPullRequest{Cursor: -1, Limit: 50}).Validate(); err != ErrInvalidMutation {
		t.Fatalf("negative cursor error = %v", err)
	}
}
