package main

import "strings"

// New H02 profile, no old profile, operational endpoint or arbitrary target.
func runH02(args []string) error {
	oldPG, oldHTTP, oldMode := profileV1PG, profileV1HTTP, profileV1H02
	defer func() { profileV1PG, profileV1HTTP, profileV1H02 = oldPG, oldHTTP, oldMode }()
	profileV1PG, profileV1HTTP, profileV1H02 = 55802, 55890, true
	if len(args) == 0 || !strings.HasPrefix(args[0], "h02-") {
		return rejected
	}
	mapped := append([]string(nil), args...)
	mapped[0] = "profile-v1-" + strings.TrimPrefix(mapped[0], "h02-")
	return runProfileV1(mapped)
}
