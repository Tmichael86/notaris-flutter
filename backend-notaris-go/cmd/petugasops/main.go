// Explicit development operations only; never invoked by normal backend startup.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net"
	"os"
	"os/signal"
	"syscall"
	"time"

	"backend-notaris-go/internal/petugasops"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/stdlib"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func main() {
	if err := run(); err != nil {
		// No configuration or credentials are printed, including on connect errors.
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run() error {
	baselineFile := flag.String("baseline", "", "verified grants receipt baseline JSON")
	apply := flag.Bool("apply", false, "explicitly authorize the selected development writes")
	confirm := flag.String("confirm-target", "", "required exact target for apply")
	maintenance := flag.Bool("maintenance-confirmed", false, "operator has stopped backend and all development clients")
	operation := flag.String("operation", "bootstrap-and-drain", "bootstrap, drain, bootstrap-and-drain")
	batch := flag.Int("batch-size", 100, "publication batch size (1..500)")
	maxBatches := flag.Int("max-batches", 10, "maximum committed publication batches (1..100)")
	timeout := flag.Duration("timeout", 60*time.Second, "whole operation deadline (1s..5m)")
	requirePublished := flag.Bool("require-published-baseline", false, "read-only gate for later development worker startup")
	flag.Parse()
	if flag.NArg() != 0 {
		return errors.New("unexpected positional arguments")
	}
	if *timeout < time.Second || *timeout > 5*time.Minute {
		return errors.New("timeout must be between 1s and 5m")
	}
	if *apply && (*confirm != "127.0.0.1:5432/notarisdev" || !*maintenance) {
		return errors.New("apply requires exact confirm-target and maintenance-confirmed; separate permanent-write approval required")
	}
	options := petugasops.Options{Apply: *apply, Operation: *operation, BatchSize: *batch, MaxBatches: *maxBatches, RequirePublishedBaseline: *requirePublished}
	if err := options.Validate(); err != nil {
		return err
	}
	file, err := os.Open(*baselineFile)
	if err != nil {
		return errors.New("verified baseline file required")
	}
	defer file.Close()
	var baseline petugasops.Baseline
	decoder := json.NewDecoder(io.LimitReader(file, 16384))
	decoder.DisallowUnknownFields()
	if err = decoder.Decode(&baseline); err != nil {
		return errors.New("invalid baseline JSON")
	}
	var trailing any
	if decoder.Decode(&trailing) != io.EOF {
		return errors.New("baseline must contain one JSON object")
	}
	if err = baseline.Validate(); err != nil {
		return err
	}
	// Hold the development HTTP port for the entire maintenance operation. This
	// prevents a backend launch racing the wrapper's earlier availability probe.
	probe, err := net.Listen("tcp4", "127.0.0.1:8081")
	if err != nil {
		return errors.New("maintenance required: development backend port 8081 is occupied")
	}
	defer probe.Close()
	// Never load normal .env, service files, PGOPTIONS, or a caller-supplied DSN.
	if os.Getenv("DB_HOST") != "127.0.0.1" || os.Getenv("DB_PORT") != "5432" || os.Getenv("DB_NAME") != "notarisdev" || os.Getenv("DB_USER") != baseline.AppRole || os.Getenv("DB_PASSWORD") == "" || os.Getenv("PETUGAS_PUBLISHER_ENABLED") != "false" {
		return errors.New("explicit development config with publisher OFF required")
	}
	cfg, err := pgx.ParseConfig("host=127.0.0.1 port=5432 dbname=notarisdev sslmode=disable")
	if err != nil {
		return errors.New("invalid development connection")
	}
	cfg.User = baseline.AppRole
	cfg.Password = os.Getenv("DB_PASSWORD")
	cfg.ConnectTimeout = 5 * time.Second
	// ParseConfig also considers PG* defaults: replace every runtime/fallback setting.
	cfg.Fallbacks = nil
	cfg.RuntimeParams = map[string]string{"search_path": "public,pg_catalog", "application_name": "notarisdev-petugas-operations", "statement_timeout": "15000", "lock_timeout": "5000", "idle_in_transaction_session_timeout": "15000", "timezone": "UTC", "default_transaction_read_only": "on"}
	if *apply {
		cfg.RuntimeParams["default_transaction_read_only"] = "off"
	}
	pool := stdlib.OpenDB(*cfg)
	defer pool.Close()
	pool.SetMaxOpenConns(1)
	pool.SetMaxIdleConns(1)
	db, err := gorm.Open(postgres.New(postgres.Config{Conn: pool}), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent), DisableAutomaticPing: true})
	if err != nil {
		return errors.New("unable to initialize development connection")
	}
	signalCtx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	ctx, cancel := context.WithTimeout(signalCtx, *timeout)
	defer cancel()
	emit := func(event petugasops.Event) { _ = json.NewEncoder(os.Stdout).Encode(event) }
	_, err = petugasops.Run(ctx, db, baseline, options, emit)
	if err != nil {
		emit(petugasops.Event{Stage: "failed_requires_inspection"})
		return fmt.Errorf("Petugas operation stopped; inspect receipt, no automatic retry/restore: %w", err)
	}
	return nil
}
