// Command masterpublish drains only the selected Master outbox on explicit invocation.
// It is never started by the HTTP server or a background worker.
package main

import (
	"backend-notaris-go/repositories"
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"net"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/stdlib"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

type options struct {
	domain, confirm          string
	onlyUUID, operation      string
	revision                 int64
	batch, maxBatches        int
	timeout                  time.Duration
	apply, liveApproved      bool
	transaction              bool
	allowlist, allowlistHash string
	expectedLastSeq          int64
}

func (o options) validate(target string) error {
	if o.domain != "notaris" && o.domain != "ppat" && o.domain != "both" {
		return errors.New("domain must be notaris, ppat, or both")
	}
	if o.batch < 1 || o.batch > 500 || o.maxBatches < 1 || o.maxBatches > 100 || o.timeout < time.Second || o.timeout > 5*time.Minute {
		return errors.New("batch, max-batches, or timeout outside bounded range")
	}
	if o.apply && o.confirm != target {
		return errors.New("apply requires exact confirm-target")
	}
	if o.transaction && o.apply && (o.domain == "both" || o.batch != 1 || o.maxBatches != 1 || o.onlyUUID == "" || o.allowlist == "" || len(o.allowlistHash) != 64 || o.expectedLastSeq < 0) {
		return errors.New("transaction publication requires one allowlisted event, pinned allowlist hash and expected cursor")
	}
	if target == "127.0.0.1:5432/notarisdev" && o.apply && !o.liveApproved {
		return errors.New("permanent development apply requires separate live approval and --live-approved")
	}
	if target == "127.0.0.1:5432/notarisdev" && o.apply &&
		(o.domain == "both" || o.batch != 1 || o.maxBatches != 1 || o.onlyUUID == "" || o.revision < 1 || o.operation == "") {
		return errors.New("live apply requires one domain and one exact synthetic event")
	}
	if o.onlyUUID != "" && (o.domain == "both" || o.batch != 1 || o.maxBatches != 1 || o.revision < 1 || o.operation == "") {
		return errors.New("expected-event publication requires one domain, batch and revision")
	}
	return nil
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run() error {
	var o options
	flag.StringVar(&o.domain, "domain", "both", "notaris, ppat, or both")
	flag.IntVar(&o.batch, "batch-size", 2, "events per committed batch, 1..500")
	flag.IntVar(&o.maxBatches, "max-batches", 10, "maximum batches per domain, 1..100")
	flag.DurationVar(&o.timeout, "timeout", time.Minute, "whole operation deadline, 1s..5m")
	flag.BoolVar(&o.apply, "apply", false, "explicitly publish pending events")
	flag.BoolVar(&o.liveApproved, "live-approved", false, "separately approved notarisdev publication")
	flag.StringVar(&o.confirm, "confirm-target", "", "exact host:port/database required for apply")
	flag.StringVar(&o.onlyUUID, "only-uuid", "", "publish exactly one event for this aggregate UUID")
	flag.StringVar(&o.operation, "expected-operation", "", "expected create, update, or delete event")
	flag.Int64Var(&o.revision, "expected-revision", 0, "expected event revision")
	flag.BoolVar(&o.transaction, "transaction", false, "use the shared Transaction feed, never a background worker")
	flag.StringVar(&o.allowlist, "allowlist", "", "reviewed publication allowlist JSON")
	flag.StringVar(&o.allowlistHash, "allowlist-sha256", "", "approved allowlist SHA-256")
	flag.Int64Var(&o.expectedLastSeq, "expected-last-seq", -1, "expected publication baseline cursor")
	flag.Parse()
	if flag.NArg() != 0 {
		return errors.New("unexpected positional arguments")
	}
	config, err := pgx.ParseConfig(os.Getenv("MASTER_PUBLISH_DSN"))
	if err != nil || os.Getenv("MASTER_PUBLISH_DSN") == "" {
		return errors.New("MASTER_PUBLISH_DSN is required")
	}
	if ip := net.ParseIP(config.Host); ip == nil || !ip.Equal(net.ParseIP("127.0.0.1")) {
		return errors.New("only explicit loopback PostgreSQL is permitted")
	}
	target := net.JoinHostPort(config.Host, strconv.Itoa(int(config.Port))) + "/" + config.Database
	live := target == "127.0.0.1:5432/notarisdev"
	if !live && !(config.Port >= 55400 && config.Port <= 55999 && strings.HasPrefix(config.Database, "notaris_publish_test")) {
		return errors.New("target must be notarisdev or an owned disposable Master publication database")
	}
	if err := o.validate(target); err != nil {
		return err
	}
	if live && config.User != "nd_app_14af5452144b" {
		return errors.New("notarisdev requires its restricted app role")
	}
	config.Fallbacks = nil
	config.ConnectTimeout = 5 * time.Second
	config.RuntimeParams = map[string]string{
		"search_path": "public,pg_catalog", "application_name": "manual-master-publisher",
		"statement_timeout": "15000", "lock_timeout": "5000",
		"idle_in_transaction_session_timeout": "15000", "default_transaction_read_only": "on",
	}
	if o.apply {
		config.RuntimeParams["default_transaction_read_only"] = "off"
	}
	pool := stdlib.OpenDB(*config)
	defer pool.Close()
	pool.SetMaxOpenConns(1)
	pool.SetMaxIdleConns(1)
	db, err := gorm.Open(postgres.New(postgres.Config{Conn: pool}), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent), DisableAutomaticPing: true})
	if err != nil {
		return errors.New("unable to initialize publisher connection")
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	ctx, cancel := context.WithTimeout(ctx, o.timeout)
	defer cancel()
	if live {
		var marker string
		if err := db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
			return tx.Raw("SELECT notaris_bersangkutan FROM konfigurasi_umum WHERE id=1").Row().Scan(&marker)
		}, &sql.TxOptions{ReadOnly: true}); err != nil || marker != "NOTARISDEV SYNTHETIC v1" {
			return errors.New("notarisdev synthetic marker mismatch")
		}
	}
	if o.transaction {
		var pending, last int64
		if err := db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
			return tx.Raw("SELECT (SELECT count(*) FROM transaction_cloud_outbox WHERE publication_seq IS NULL),last_seq FROM transaction_cloud_publication WHERE id=1").Row().Scan(&pending, &last)
		}, &sql.TxOptions{ReadOnly: true}); err != nil {
			return err
		}
		if !o.apply {
			return json.NewEncoder(os.Stdout).Encode(map[string]any{"target": target, "mode": "read_only", "feed": "transactions", "pending": pending, "last_seq": last})
		}
		expected := repositories.TransactionPublicationExpectation{Domain: o.domain, UUID: o.onlyUUID, Operation: o.operation, Revision: o.revision, ExpectedLastSeq: o.expectedLastSeq}
		if err := approvedPublication(o, target, "transaction", expected); err != nil {
			return err
		}
		result, err := repositories.NewTransactionCloudRepository(db).PublishExpected(ctx, expected)
		if err != nil {
			return fmt.Errorf("transaction publication stopped; inspect database read-only before retry: %w", err)
		}
		return json.NewEncoder(os.Stdout).Encode(map[string]any{"target": target, "mode": "apply_expected", "feed": "transactions", "domain": o.domain, "aggregate_uuid": o.onlyUUID, "operation": o.operation, "revision": o.revision, "published": result.Published, "sequence": result.Sequence, "last_seq": result.LastSeq, "replay": result.Replay})
	}
	for _, domain := range []string{"notaris", "ppat"} {
		if o.domain != "both" && o.domain != domain {
			continue
		}
		var publisher interface {
			Publish(context.Context, int) (int, error)
		}
		var table string
		if domain == "notaris" {
			publisher = repositories.NewNotarisCloudRepository(db)
			table = "pekerjaan_notaris_sync_outbox"
		} else {
			publisher = repositories.NewPpatCloudRepository(db)
			table = "pekerjaan_ppat_sync_outbox"
		}
		var pending int64
		if err := db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
			return tx.Raw("SELECT count(*) FROM " + table + " WHERE publication_seq IS NULL").Row().Scan(&pending)
		}, &sql.TxOptions{ReadOnly: true}); err != nil {
			return fmt.Errorf("%s pending count failed: %w", domain, err)
		}
		if !o.apply {
			_ = json.NewEncoder(os.Stdout).Encode(map[string]any{"domain": domain, "target": target, "mode": "read_only", "pending": pending})
			continue
		}
		if o.onlyUUID != "" {
			if o.allowlist != "" {
				if err := approvedPublication(o, target, "master", repositories.TransactionPublicationExpectation{Domain: domain, UUID: o.onlyUUID, Operation: o.operation, Revision: o.revision, ExpectedLastSeq: o.expectedLastSeq}); err != nil {
					return err
				}
			}
			seq, err := repositories.PublishExpectedMaster(ctx, db, domain, o.onlyUUID, o.operation, o.revision)
			if err != nil {
				return fmt.Errorf("%s expected publication stopped; inspect database before any retry: %w", domain, err)
			}
			_ = json.NewEncoder(os.Stdout).Encode(map[string]any{"domain": domain, "target": target, "mode": "apply_expected", "published": 1, "last_seq": seq, "aggregate_uuid": o.onlyUUID, "operation": o.operation, "revision": o.revision})
			continue
		}
		published := 0
		for batch := 0; batch < o.maxBatches; batch++ {
			n, err := publisher.Publish(ctx, o.batch)
			if err != nil {
				return fmt.Errorf("%s publication stopped after %d confirmed events; inspect database before any retry: %w", domain, published, err)
			}
			published += n
			if n == 0 || n < o.batch {
				break
			}
		}
		var remaining, lastSeq int64
		publicationTable := "pekerjaan_" + domain + "_sync_publication"
		if err := db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
			return tx.Raw("SELECT (SELECT count(*) FROM "+table+" WHERE publication_seq IS NULL),last_seq FROM "+publicationTable+" WHERE id=1").Row().Scan(&remaining, &lastSeq)
		}, &sql.TxOptions{ReadOnly: true}); err != nil {
			return fmt.Errorf("%s post-publication inspection failed; inspect database before any retry: %w", domain, err)
		}
		_ = json.NewEncoder(os.Stdout).Encode(map[string]any{"domain": domain, "target": target, "mode": "apply", "published": published, "remaining": remaining, "last_seq": lastSeq})
	}
	return nil
}
