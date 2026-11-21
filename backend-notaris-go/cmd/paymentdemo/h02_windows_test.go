package main

import "testing"

func TestH02UnownedProfilesAndIsolation(t *testing.T) {
	before := profileV1ManifestFor("00000000000000000000000000000000")
	for _, args := range [][]string{nil, {"h02-validate", "../notarisdev"}, {"h02-validate", "00000000000000000000000000000000"}} {
		if runH02(args) == nil {
			t.Fatal("unowned accepted")
		}
		if profileV1ManifestFor("00000000000000000000000000000000") != before || profileV1H02 {
			t.Fatal("mode leaked")
		}
	}
}
