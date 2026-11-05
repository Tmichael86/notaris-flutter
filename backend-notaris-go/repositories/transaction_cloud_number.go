package repositories

import (
	"context"
	"errors"
	"fmt"
	"gorm.io/gorm"
	"time"
	_ "time/tzdata"
)

var ErrTransactionNumberExhausted = errors.New("transaction administrative numbering exhausted for this domain and Jakarta date")

// allocateTransactionNumber is intentionally private: accepted CREATE must call
// it after the durable mutation receipt probe, in the SAME database transaction
// as aggregate, receipt and outbox. Never call it on an autocommit connection.
// The server issuance clock is PostgreSQL, never a supplied transaction date.
func allocateTransactionNumber(ctx context.Context, tx *gorm.DB, domain string) (string, error) {
	if domain != "notaris" && domain != "ppat" {
		return "", ErrTransactionCloudReference
	}
	var issued time.Time
	if err := tx.WithContext(ctx).Raw("SELECT clock_timestamp()").Row().Scan(&issued); err != nil {
		return "", err
	}
	return allocateTransactionNumberAt(ctx, tx, domain, issued)
}

// The explicit instant is a test seam, not part of the wire protocol.
func allocateTransactionNumberAt(ctx context.Context, tx *gorm.DB, domain string, issued time.Time) (string, error) {
	if _, ok := tx.Statement.ConnPool.(gorm.TxCommitter); !ok {
		return "", ErrTransactionCloudTransactionRequired
	}
	prefix := "1"
	if domain == "ppat" {
		prefix = "2"
	} else if domain != "notaris" {
		return "", ErrTransactionCloudReference
	}
	jakarta, err := time.LoadLocation("Asia/Jakarta")
	if err != nil {
		return "", err
	}
	day := issued.In(jakarta)
	var values []int
	err = tx.WithContext(ctx).Raw(`INSERT INTO transaction_cloud_number_counter(domain,issue_date,last_number)
 VALUES(?,?::date,1) ON CONFLICT(domain,issue_date) DO UPDATE
 SET last_number=transaction_cloud_number_counter.last_number+1
 WHERE transaction_cloud_number_counter.last_number<9999 RETURNING last_number`, domain, day.Format("2006-01-02")).Scan(&values).Error
	if err != nil {
		return "", err
	}
	if len(values) != 1 {
		return "", ErrTransactionNumberExhausted
	}
	return fmt.Sprintf("%s00%s%04d", prefix, day.Format("020106"), values[0]), nil
}
