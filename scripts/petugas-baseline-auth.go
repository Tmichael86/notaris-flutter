// Local-only credential verification using the existing production Login
// service. Stdout is a private parent-process pipe, never a file or console log.
package main

import (
	"backend-notaris-go/config"
	"backend-notaris-go/database"
	"backend-notaris-go/services"
	"encoding/json"
	"fmt"
	"os"
)

func main() {
	if run() != nil {
		fmt.Fprintln(os.Stderr, "Fixture credential/target verification failed; no bypass performed")
		os.Exit(1)
	}
}
func run() error {
	if os.Getenv("DB_HOST") != "127.0.0.1" || os.Getenv("DB_PORT") != "5432" || os.Getenv("DB_NAME") != "notarisdev" || os.Getenv("DB_USER") == "postgres" || os.Getenv("DB_PASSWORD") == "" || os.Getenv("JWT_SECRET") == "" || os.Getenv("PETUGAS_PUBLISHER_ENABLED") != "false" || os.Getenv("NOTARIS_FIXTURE_LOGIN") != "fixture.operator" || os.Getenv("NOTARIS_FIXTURE_PASSWORD") == "" {
		return fmt.Errorf("explicit fixture config required")
	}
	cfg := config.Config{DBHost: "127.0.0.1", DBPort: "5432", DBName: "notarisdev", DBUser: os.Getenv("DB_USER"), DBPass: os.Getenv("DB_PASSWORD"), DBSSLMode: "disable", JWTSecret: os.Getenv("JWT_SECRET"), JWTExpireMinutes: 5}
	if err := database.ConnectDB(cfg); err != nil {
		return err
	}
	pool, err := database.DB.DB()
	if err != nil {
		return err
	}
	defer pool.Close()
	pool.SetMaxOpenConns(1)
	var safe bool
	if err := database.DB.Raw(`SELECT current_database()='notarisdev' AND inet_server_addr()='127.0.0.1'::inet AND inet_server_port()=5432 AND current_setting('default_transaction_read_only')='on' AND current_setting('transaction_read_only')='on' AND (SELECT notaris_bersangkutan FROM konfigurasi_umum WHERE id=1)='NOTARISDEV SYNTHETIC v1'`).Scan(&safe).Error; err != nil || !safe {
		return fmt.Errorf("read-only deployment identity mismatch")
	}
	if err := database.DB.Raw(`SELECT
      (SELECT count(*)=4 AND count(DISTINCT publication_seq)=4
        AND min(publication_seq)=1 AND max(publication_seq)=4
        AND bool_and(published_at IS NOT NULL AND NOT tombstone AND row_version=1)
        FROM petugas_sync_outbox)
      AND (SELECT count(*)=1 AND bool_and(last_seq=4 AND min_cursor=0) FROM petugas_sync_publication)
      AND (SELECT count(*)=0 FROM petugas_sync_mutations)
      AND NOT EXISTS (SELECT 1 FROM pg_stat_activity WHERE datname=current_database() AND pid<>pg_backend_pid())`).Scan(&safe).Error; err != nil || !safe {
		return fmt.Errorf("published baseline/maintenance state mismatch")
	}
	user, token, err := services.NewAuthService(cfg).Login(os.Getenv("NOTARIS_FIXTURE_LOGIN"), os.Getenv("NOTARIS_FIXTURE_PASSWORD"))
	if err != nil {
		return err
	}
	if user.ID != 2001 || user.GroupID != 11 || user.Status != 1 {
		return fmt.Errorf("unexpected fixture account")
	}
	return json.NewEncoder(os.Stdout).Encode(struct {
		Token              string `json:"token"`
		Account            uint   `json:"account_id"`
		Group              uint   `json:"group_id"`
		CredentialVerified bool   `json:"credential_verified"`
	}{token, user.ID, user.GroupID, true})
}
