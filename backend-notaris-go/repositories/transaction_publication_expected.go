package repositories

import (
	"encoding/json"
	"errors"
	"gorm.io/gorm"
	"regexp"
)

var ErrUnexpectedTransactionOutbox = errors.New("unexpected transaction publication baseline or event")

type TransactionPublicationExpectation struct {
	Domain          string `json:"domain"`
	UUID            string `json:"uuid"`
	Operation       string `json:"operation"`
	Revision        int64  `json:"revision"`
	ExpectedLastSeq int64  `json:"expected_last_seq"`
}
type TransactionPublicationResult struct {
	Published int   `json:"published"`
	Sequence  int64 `json:"sequence"`
	LastSeq   int64 `json:"last_seq"`
	Replay    bool  `json:"replay"`
}

func (e TransactionPublicationExpectation) Valid() bool {
	return (e.Domain == "notaris" || e.Domain == "ppat") && notarisCloudUUID.MatchString(e.UUID) && e.Revision > 0 && e.ExpectedLastSeq >= 0 &&
		((e.Operation == "create" && e.Revision == 1) || (e.Operation == "update" && e.Revision > 1) || (e.Operation == "delete" && e.Revision > 1))
}

// Called under the existing publication counter row lock. It never drains an
// arbitrary pending row; even retry refuses an unrelated pending event.
func expectedTransactionPublication(tx *gorm.DB, e TransactionPublicationExpectation, last int64) (int64, bool, error) {
	var pending int64
	if err := tx.Raw("SELECT count(*) FROM transaction_cloud_outbox WHERE publication_seq IS NULL").Row().Scan(&pending); err != nil {
		return 0, false, err
	}
	var row struct {
		ID, Revision   int64
		Operation      string
		Payload        []byte
		PublicationSeq *int64
	}
	probe := tx.Raw("SELECT o.id,o.revision,o.operation,o.payload,o.publication_seq FROM transaction_cloud_outbox o JOIN transaction_cloud t ON t.uuid=o.aggregate_uuid WHERE o.aggregate_uuid=?::uuid AND o.revision=? AND t.domain=? FOR UPDATE OF o", e.UUID, e.Revision, e.Domain).Scan(&row)
	if probe.Error != nil {
		return 0, false, probe.Error
	}
	if probe.RowsAffected != 1 || row.Operation != e.Operation {
		return 0, false, ErrUnexpectedTransactionOutbox
	}
	var a TransactionCloudAggregate
	if json.Unmarshal(row.Payload, &a) != nil {
		return 0, false, ErrUnexpectedTransactionOutbox
	}
	if a.Domain == "" {
		a.Domain = "notaris"
	}
	copy := a.TransactionCloudCreate
	copy.ExpectedRevision = 0
	if !notarisCloudUUID.MatchString(a.PemohonUUID) || !notarisCloudUUID.MatchString(a.PetugasUUID) {
		return 0, false, ErrUnexpectedTransactionOutbox
	}
	for _, detail := range a.Details {
		if !notarisCloudUUID.MatchString(detail.JobUUID) || !notarisCloudUUID.MatchString(detail.PriceUUID) || !notarisCloudUUID.MatchString(detail.CategoryUUID) {
			return 0, false, ErrUnexpectedTransactionOutbox
		}
	}
	prefix := "100"
	if e.Domain == "ppat" {
		prefix = "200"
	}
	if a.UUID != e.UUID || a.Domain != e.Domain || row.Revision != e.Revision || a.ExpectedRevision != e.Revision-1 || copy.validate() != nil ||
		!regexp.MustCompile("^"+prefix+`\d{10}$`).MatchString(a.FinalNumber) || ((e.Operation == "delete") != (a.DeletedAt != nil)) {
		return 0, false, ErrUnexpectedTransactionOutbox
	}
	if row.PublicationSeq != nil {
		if pending != 0 || *row.PublicationSeq != e.ExpectedLastSeq+1 || last < *row.PublicationSeq {
			return 0, false, ErrUnexpectedTransactionOutbox
		}
		return *row.PublicationSeq, true, nil
	}
	if pending != 1 || last != e.ExpectedLastSeq {
		return 0, false, ErrUnexpectedTransactionOutbox
	}
	return row.ID, false, nil
}
