package main

import (
	"testing"
	"time"
)

func TestManualPublisherOptions(t *testing.T) {
	target := "127.0.0.1:5432/notarisdev"
	base := options{domain: "both", batch: 2, maxBatches: 10, timeout: time.Minute}
	if err := base.validate(target); err != nil {
		t.Fatal(err)
	}
	base.apply = true
	if err := base.validate(target); err == nil {
		t.Fatal("apply without target confirmation accepted")
	}
	base.confirm = target
	if err := base.validate(target); err == nil {
		t.Fatal("permanent apply without separate live flag accepted")
	}
	base.liveApproved = true
	if err := base.validate(target); err != nil {
		t.Fatal(err)
	}
	for _, invalid := range []options{
		{domain: "petugas", batch: 2, maxBatches: 10, timeout: time.Minute},
		{domain: "both", batch: 0, maxBatches: 10, timeout: time.Minute},
		{domain: "both", batch: 2, maxBatches: 0, timeout: time.Minute},
		{domain: "both", batch: 2, maxBatches: 10, timeout: 10 * time.Minute},
	} {
		if err := invalid.validate(target); err == nil {
			t.Fatalf("invalid options accepted: %+v", invalid)
		}
	}
}
