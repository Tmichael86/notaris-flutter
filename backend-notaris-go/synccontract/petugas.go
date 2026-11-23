// Package synccontract defines transport-neutral Petugas synchronization data.
package synccontract

import (
	"errors"
	"strings"
)

type PetugasOperation string

const (
	PetugasUpsert PetugasOperation = "upsert"
	PetugasDelete PetugasOperation = "delete"
)

var ErrInvalidMutation = errors.New("invalid petugas sync mutation")

// PetugasMutation uses four separate identifiers: MutationID is client retry
// identity, PetugasUUID is stable server record identity, ExpectedRowVersion
// controls write conflicts, and PullCursor belongs only to a pull request.
type PetugasMutation struct {
	MutationID         string           `json:"mutation_id"`
	Operation          PetugasOperation `json:"operation"`
	PetugasUUID        string           `json:"petugas_uuid"`
	ExpectedRowVersion *int64           `json:"expected_row_version"`
	Payload            *PetugasPayload  `json:"payload,omitempty"`
}

// PetugasPayload deliberately uses server IDs for the two existing references.
// The source schema exposes no portable UUID for jenis_kelamin or users.
type PetugasPayload struct {
	NIK            *string `json:"nik,omitempty"`
	Nama           string  `json:"nama"`
	Alamat         *string `json:"alamat,omitempty"`
	TempatLahir    *string `json:"tempat_lahir,omitempty"`
	TanggalLahir   *string `json:"tanggal_lahir,omitempty"`
	JenisKelaminID *uint   `json:"jenis_kelamin_id,omitempty"`
	NoTelp         *string `json:"no_telp,omitempty"`
	Email          string  `json:"email"`
	UserID         *uint   `json:"user_id,omitempty"`
}

type PetugasAcknowledgement struct {
	MutationID  string `json:"mutation_id"`
	PetugasUUID string `json:"petugas_uuid"`
	ServerID    uint   `json:"server_id"`
	RowVersion  int64  `json:"row_version"`
	Tombstone   bool   `json:"tombstone"`
}

type PetugasPullRequest struct {
	Cursor int64 `json:"cursor"`
	Limit  int   `json:"limit"`
}

type PetugasChange struct {
	PublicationSequence int64           `json:"publication_sequence"`
	PetugasUUID         string          `json:"petugas_uuid"`
	ServerID            uint            `json:"server_id"`
	RowVersion          int64           `json:"row_version"`
	Tombstone           bool            `json:"tombstone"`
	Payload             *PetugasPayload `json:"payload,omitempty"`
}

func (m PetugasMutation) Validate() error {
	if strings.TrimSpace(m.MutationID) == "" || strings.TrimSpace(m.PetugasUUID) == "" {
		return ErrInvalidMutation
	}
	if m.Operation != PetugasUpsert && m.Operation != PetugasDelete {
		return ErrInvalidMutation
	}
	if m.ExpectedRowVersion != nil && *m.ExpectedRowVersion < 1 {
		return ErrInvalidMutation
	}
	if m.Operation == PetugasDelete {
		if m.ExpectedRowVersion == nil || m.Payload != nil {
			return ErrInvalidMutation
		}
		return nil
	}
	if m.Payload == nil || strings.TrimSpace(m.Payload.Nama) == "" || strings.TrimSpace(m.Payload.Email) == "" {
		return ErrInvalidMutation
	}
	return nil
}

func (r PetugasPullRequest) Validate() error {
	if r.Cursor < 0 || r.Limit < 1 || r.Limit > 500 {
		return ErrInvalidMutation
	}
	return nil
}
