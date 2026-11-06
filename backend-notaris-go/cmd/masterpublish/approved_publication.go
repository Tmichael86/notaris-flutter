package main

import (
	"backend-notaris-go/repositories"
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"os"
	"strings"
)

type publicationAllowlist struct {
	Target string `json:"target"`
	Events []struct {
		Kind string `json:"kind"`
		repositories.TransactionPublicationExpectation
	} `json:"events"`
}

func approvedPublication(o options, target, kind string, event repositories.TransactionPublicationExpectation) error {
	raw, err := os.ReadFile(o.allowlist)
	if err != nil {
		return errors.New("publication allowlist unavailable")
	}
	if len(raw) > 65536 {
		return errors.New("publication allowlist too large")
	}
	digest := sha256.Sum256(raw)
	if !strings.EqualFold(hex.EncodeToString(digest[:]), o.allowlistHash) {
		return errors.New("publication allowlist hash mismatch")
	}
	d := json.NewDecoder(bytes.NewReader(raw))
	d.DisallowUnknownFields()
	var list publicationAllowlist
	if d.Decode(&list) != nil || d.Decode(new(any)) != io.EOF || list.Target != target || len(list.Events) == 0 || len(list.Events) > 10 || !event.Valid() {
		return errors.New("invalid publication allowlist or event")
	}
	seen := map[string]bool{}
	matched := false
	transactions, masters := 0, 0
	for _, entry := range list.Events {
		if !entry.Valid() || (entry.Kind != "master" && entry.Kind != "transaction") {
			return errors.New("invalid allowlist entry")
		}
		key := entry.Kind + ":" + entry.Domain + ":" + entry.UUID + ":" + entry.Operation
		if seen[key] {
			return errors.New("duplicate allowlist entry")
		}
		seen[key] = true
		if entry.Kind == "master" {
			masters++
		} else {
			transactions++
		}
		if entry.Kind == kind && entry.TransactionPublicationExpectation == event {
			matched = true
		}
	}
	if transactions > 6 || masters > 4 || !matched {
		return errors.New("event outside reviewed allowlist or write budget")
	}
	return nil
}
