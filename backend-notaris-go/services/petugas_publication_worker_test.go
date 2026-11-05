package services

import (
	"bytes"
	"context"
	"errors"
	"log"
	"strings"
	"testing"
	"time"
)

type publishFunc func(context.Context, int) (int, error)

func (f publishFunc) Publish(ctx context.Context, n int) (int, error) { return f(ctx, n) }
func workerOptions() PublicationWorkerOptions {
	return PublicationWorkerOptions{BatchSize: 2, Interval: time.Second, AttemptTimeout: time.Second, MaxBackoff: 4 * time.Second}
}
func TestPublicationWorkerIdleAndBackoff(t *testing.T) {
	calls := 0
	w, err := NewPetugasPublicationWorker(publishFunc(func(context.Context, int) (int, error) {
		calls++
		if calls <= 4 {
			return 0, errors.New("transient secret must not be logged")
		}
		return 0, nil
	}), workerOptions(), nil)
	if err != nil {
		t.Fatal(err)
	}
	var waits []time.Duration
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	w.wait = func(_ context.Context, d time.Duration) bool {
		waits = append(waits, d)
		if len(waits) == 6 {
			cancel()
			return false
		}
		return true
	}
	w.Run(ctx)
	want := []time.Duration{time.Second, 2 * time.Second, 4 * time.Second, 4 * time.Second, time.Second, time.Second}
	if calls != 6 {
		t.Fatalf("calls=%d", calls)
	}
	for i, d := range waits {
		if d != want[i] {
			t.Fatalf("delay %d: %s", i, d)
		}
	}
}
func TestPublicationWorkerCancellation(t *testing.T) {
	entered := make(chan struct{})
	done := make(chan struct{})
	w, _ := NewPetugasPublicationWorker(publishFunc(func(ctx context.Context, _ int) (int, error) { close(entered); <-ctx.Done(); return 0, ctx.Err() }), workerOptions(), nil)
	ctx, cancel := context.WithCancel(context.Background())
	go func() { defer close(done); w.Run(ctx) }()
	<-entered
	cancel()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("attempt did not cancel")
	}
	if publicationWait(ctx, time.Hour) {
		t.Fatal("idle wait ignored cancellation")
	}
}
func TestPublicationWorkerDeadline(t *testing.T) {
	options := workerOptions()
	options.AttemptTimeout = 5 * time.Millisecond
	timedOut := false
	w, _ := NewPetugasPublicationWorker(publishFunc(func(ctx context.Context, _ int) (int, error) {
		<-ctx.Done()
		timedOut = errors.Is(ctx.Err(), context.DeadlineExceeded)
		return 0, ctx.Err()
	}), options, nil)
	w.wait = func(context.Context, time.Duration) bool { return false }
	w.Run(context.Background())
	if !timedOut {
		t.Fatal("attempt timeout missing")
	}
}
func TestPublicationWorkerRejectsInvalidOptions(t *testing.T) {
	options := workerOptions()
	options.Interval = 0
	if _, err := NewPetugasPublicationWorker(publishFunc(func(context.Context, int) (int, error) { return 0, nil }), options, nil); err == nil {
		t.Fatal("busy-loop configuration accepted")
	}
}

func TestPublicationWorkerLogsNoErrorDetails(t *testing.T) {
	var output bytes.Buffer
	calls := 0
	w, _ := NewPetugasPublicationWorker(publishFunc(func(context.Context, int) (int, error) {
		calls++
		if calls == 1 {
			return 0, errors.New("credential=secret payload=private")
		}
		return 2, nil
	}), workerOptions(), log.New(&output, "", 0))
	w.wait = func(context.Context, time.Duration) bool { return calls < 2 }
	w.Run(context.Background())
	text := output.String()
	if strings.Contains(text, "secret") || strings.Contains(text, "private") || !strings.Contains(text, "published=2") || !strings.Contains(text, "retry_in=") {
		t.Fatalf("unsafe or missing worker logs: %q", text)
	}
}
