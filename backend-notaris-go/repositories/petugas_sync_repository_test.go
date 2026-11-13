package repositories

import (
	"errors"
	"testing"

	"backend-notaris-go/models"
	"backend-notaris-go/synccontract"
)

func testMutation(id string) synccontract.PetugasMutation {
	return synccontract.PetugasMutation{MutationID: id, PetugasUUID: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", Operation: synccontract.PetugasUpsert, Payload: &synccontract.PetugasPayload{Nama: "Sari", Email: "sari@example.com"}}
}

func TestMutationFingerprint(t *testing.T) {
	m := testMutation("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
	_, first, err := preparePetugasMutation(m, 1)
	if err != nil {
		t.Fatal(err)
	}
	m.PetugasUUID = "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA"
	_, retry, _ := preparePetugasMutation(m, 1)
	if first != retry {
		t.Fatal("UUID case changed retry identity")
	}
	_, otherActor, _ := preparePetugasMutation(m, 2)
	if first == otherActor {
		t.Fatal("fingerprint must bind authenticated actor")
	}
	m.Payload.Email = "changed@example.com"
	_, changed, _ := preparePetugasMutation(m, 1)
	if first == changed {
		t.Fatal("fingerprint must detect changed request")
	}
	m.MutationID = "not-a-uuid"
	if _, _, err := preparePetugasMutation(m, 1); !errors.Is(err, synccontract.ErrInvalidMutation) {
		t.Fatal("invalid SQL UUID accepted")
	}
}

func TestPetugasVersionRules(t *testing.T) {
	version := int64(4)
	stale := int64(3)
	for _, tc := range []struct {
		name     string
		exists   bool
		expected *int64
		op       synccontract.PetugasOperation
		status   int16
		conflict bool
	}{
		{"create", false, nil, synccontract.PetugasUpsert, 1, false},
		{"missing update", false, &version, synccontract.PetugasUpsert, 1, true},
		{"duplicate create", true, nil, synccontract.PetugasUpsert, 1, true},
		{"matching update", true, &version, synccontract.PetugasUpsert, 1, false},
		{"stale update", true, &stale, synccontract.PetugasUpsert, 1, true},
		{"resurrection", true, &version, synccontract.PetugasUpsert, 0, true},
		{"repeated delete", true, &version, synccontract.PetugasDelete, 0, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			m := testMutation("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
			m.ExpectedRowVersion, m.Operation = tc.expected, tc.op
			current := &models.Petugas{ID: 17, RowVersion: version, Status: tc.status}
			err := checkPetugasVersion(m, tc.exists, current)
			var conflict *PetugasVersionConflict
			if errors.As(err, &conflict) != tc.conflict {
				t.Fatalf("unexpected conflict: %v", err)
			}
			if tc.conflict && tc.exists && conflict.Current.ID != 17 {
				t.Fatal("missing canonical server identity")
			}
		})
	}
}
