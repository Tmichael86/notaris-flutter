package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"regexp"
	"time"

	"backend-notaris-go/internal/devfixture"
	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
func run() error {
	mode := flag.String("mode", "generate", "generate or validate")
	out := flag.String("out", "", "new SQL output file")
	flag.Parse()
	if *mode == "references" {
		pairs := []map[string]any{}
		for _, row := range devfixture.Build("unused") {
			if row.Table == "jenis_kelamin" {
				pairs = append(pairs, map[string]any{"server_id": row.Values["id"], "local_uuid": fmt.Sprintf("notarisdev-smoke-gender-%v", row.Values["id"]), "label": row.Values["nama"], "state": "verified"})
			}
		}
		return json.NewEncoder(os.Stdout).Encode(map[string]any{"fixture": "smoke-v1", "genders": pairs})
	}
	if *mode == "generate" {
		password := os.Getenv("NOTARIS_DEV_FIXTURE_PASSWORD")
		if len(password) < 16 {
			return fmt.Errorf("fresh fixture password (>=16 chars) required in process environment")
		}
		hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
		if err != nil {
			return err
		}
		rows := devfixture.Build(string(hash))
		text, err := devfixture.SQL(rows)
		if err != nil {
			return err
		}
		file, err := os.OpenFile(*out, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
		if err != nil {
			return fmt.Errorf("refusing existing/missing output path")
		}
		defer file.Close()
		if _, err = file.WriteString(text); err != nil {
			return err
		}
		counts := map[string]int{}
		for _, r := range rows {
			counts[r.Table]++
		}
		return json.NewEncoder(os.Stdout).Encode(counts)
	}
	if *mode != "validate" {
		return fmt.Errorf("unknown fixture mode")
	}
	cfg, err := pgx.ParseConfig("")
	if err != nil {
		return fmt.Errorf("invalid local test connection configuration")
	}
	if (cfg.Host != "localhost" && cfg.Host != "127.0.0.1") || (cfg.Database != "notarisdev" && !regexp.MustCompile(`^notaris_fixture_test_[a-f0-9]+$`).MatchString(cfg.Database)) {
		return fmt.Errorf("fixture validation target refused")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	db, err := pgx.ConnectConfig(ctx, cfg)
	if err != nil {
		return fmt.Errorf("fixture connection failed")
	}
	defer db.Close(ctx)
	tx, err := db.BeginTx(ctx, pgx.TxOptions{AccessMode: pgx.ReadOnly, IsoLevel: pgx.RepeatableRead})
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	for _, e := range devfixture.Edges {
		var n int
		query := fmt.Sprintf("SELECT count(*) FROM public.%s l WHERE l.%s IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.%s r WHERE r.%s=l.%s)", devfixture.Quote(e.Table), devfixture.Quote(e.Column), devfixture.Quote(e.Parent), devfixture.Quote(e.Key), devfixture.Quote(e.Column))
		if err := tx.QueryRow(ctx, query).Scan(&n); err != nil {
			return fmt.Errorf("reference validation query failed: %s.%s", e.Table, e.Column)
		}
		if n != 0 {
			return fmt.Errorf("broken references: %s.%s count=%d", e.Table, e.Column, n)
		}
	}
	counts := map[string]int{}
	for _, r := range devfixture.Build("unused") {
		counts[r.Table]++
	}
	for table, want := range counts {
		var n int
		if err := tx.QueryRow(ctx, "SELECT count(*) FROM public."+devfixture.Quote(table)).Scan(&n); err != nil {
			return err
		}
		if n != want {
			return fmt.Errorf("fixture count mismatch %s got=%d expected=%d", table, n, want)
		}
	}
	for _, table := range []string{"sessions", "password_resets", "personal_access_tokens", "failed_jobs", "transaksi_old"} {
		var n int
		if err := tx.QueryRow(ctx, "SELECT count(*) FROM public."+devfixture.Quote(table)).Scan(&n); err != nil {
			return err
		}
		if n != 0 {
			return fmt.Errorf("unexpected rows in %s", table)
		}
	}
	var marker string
	if err := tx.QueryRow(ctx, "SELECT notaris_bersangkutan FROM public.konfigurasi_umum WHERE id=1").Scan(&marker); err != nil || marker != "NOTARISDEV SYNTHETIC v1" {
		return fmt.Errorf("synthetic marker missing")
	}
	fmt.Printf("PASS: synthetic counts and %d reference edges; no constraints added\n", len(devfixture.Edges))
	return tx.Commit(ctx)
}
