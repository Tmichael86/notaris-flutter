package main

import "strings"

// H01 owns a new DPAPI profile and fixed ports. Reuses the reviewed Profile V1
// provisioning/read-only identity primitives; never opens an old profile.
// Only the demo helper binary has this dispatch, not the operational Go API.
func runH01(args []string) error {
	oldPG, oldHTTP, oldMode := profileV1PG, profileV1HTTP, profileV1H01
	defer func() { profileV1PG, profileV1HTTP, profileV1H01 = oldPG, oldHTTP, oldMode }()
	profileV1PG, profileV1HTTP, profileV1H01 = 55801, 55889, true
	if len(args) == 0 || !strings.HasPrefix(args[0], "h01-") {
		return rejected
	}
	mapped := append([]string(nil), args...)
	mapped[0] = "profile-v1-" + strings.TrimPrefix(mapped[0], "h01-")
	return runProfileV1(mapped)
}
