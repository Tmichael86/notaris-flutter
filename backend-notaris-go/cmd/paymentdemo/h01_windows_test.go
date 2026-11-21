package main

import "testing"

func TestH01NoOldProfileOrArbitraryTarget(t *testing.T) {
	before := profileV1ManifestFor("00000000000000000000000000000000")
	for _, args := range [][]string{nil, {"h01-validate", "../notarisdev"}, {"h01-validate", "00000000000000000000000000000000"}, {"h01-serve", "../promotional"}} {
		if runH01(args) == nil {
			t.Fatal("unowned profile accepted")
		}
		if profileV1ManifestFor("00000000000000000000000000000000") != before || profileV1H01 {
			t.Fatal("H01 mode leaked into accepted Profile V1")
		}
	}
	profileV1PG, profileV1HTTP, profileV1H01 = 55801, 55889, true
	defer func() { profileV1PG, profileV1HTTP, profileV1H01 = 55800, 55888, false }()
	h := profileV1ManifestFor("00000000000000000000000000000000")
	if h.Port == before.Port || h.BaseURL == before.BaseURL {
		t.Fatal("accepted profile ports reused")
	}
}
