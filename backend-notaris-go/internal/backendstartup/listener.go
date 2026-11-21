// Package backendstartup owns the normal backend's pre-listen security gate.
package backendstartup

import (
	"context"
	"errors"
	"net"

	"backend-notaris-go/config"
	"backend-notaris-go/services"
	"gorm.io/gorm"
)

// Open validates configuration and the live P0 prerequisites BEFORE binding a
// socket. The injected listen function is net.Listen in the normal entrypoint;
// tests can prove it is never called when any prerequisite fails.
func Open(ctx context.Context, cfg config.Config, db *gorm.DB, listen func(string, string) (net.Listener, error)) (net.Listener, error) {
	if err := cfg.ValidateStartup(); err != nil {
		return nil, err
	}
	if db == nil {
		return nil, errors.New("backend security database is unavailable")
	}
	var actual string
	if err := db.WithContext(ctx).Raw("SELECT current_database()").Scan(&actual).Error; err != nil || actual != cfg.DBName {
		return nil, errors.New("backend database identity mismatch")
	}
	if err := (services.Administration{DB: db, Enabled: cfg.UsersSecurityEnabled}).Ready(ctx); err != nil {
		return nil, errors.New("backend P0 schema/recovery prerequisites not satisfied")
	}
	return listen("tcp", cfg.ListenAddress())
}
