package services

import (
	"context"
	"errors"
	"time"
)

type PetugasPublisher interface {
	Publish(context.Context, int) (int, error)
}
type PublicationLogger interface{ Printf(string, ...any) }
type PublicationWorkerOptions struct {
	BatchSize      int
	Interval       time.Duration
	AttemptTimeout time.Duration
	MaxBackoff     time.Duration
}
type PetugasPublicationWorker struct {
	publisher PetugasPublisher
	options   PublicationWorkerOptions
	logger    PublicationLogger
	wait      func(context.Context, time.Duration) bool
}

func NewPetugasPublicationWorker(p PetugasPublisher, o PublicationWorkerOptions, l PublicationLogger) (*PetugasPublicationWorker, error) {
	if p == nil || o.BatchSize < 1 || o.BatchSize > 500 || o.Interval < time.Millisecond || o.AttemptTimeout <= 0 || o.MaxBackoff < o.Interval {
		return nil, errors.New("invalid Petugas publication worker configuration")
	}
	return &PetugasPublicationWorker{publisher: p, options: o, logger: l, wait: publicationWait}, nil
}
func publicationWait(ctx context.Context, delay time.Duration) bool {
	timer := time.NewTimer(delay)
	defer timer.Stop()
	select {
	case <-ctx.Done():
		return false
	case <-timer.C:
		return true
	}
}

// Run owns no detached goroutines. The caller cancels its context and waits
// for Run to return before closing the database pool. Every attempt is bounded.
func (w *PetugasPublicationWorker) Run(ctx context.Context) {
	delay := w.options.Interval
	for ctx.Err() == nil {
		attempt, cancel := context.WithTimeout(ctx, w.options.AttemptTimeout)
		n, err := w.publisher.Publish(attempt, w.options.BatchSize)
		cancel()
		if ctx.Err() != nil {
			return
		}
		if err != nil {
			if w.logger != nil {
				w.logger.Printf("petugas publication failed; retry_in=%s", delay)
			}
			if !w.wait(ctx, delay) {
				return
			}
			if delay >= w.options.MaxBackoff/2 {
				delay = w.options.MaxBackoff
			} else {
				delay *= 2
			}
			continue
		}
		delay = w.options.Interval
		if n > 0 && w.logger != nil {
			w.logger.Printf("petugas publication published=%d", n)
		}
		// Even a full or empty batch waits. Counter serialization is delegated
		// unchanged to the repository; no outbox deletion or cursor allocation here.
		if !w.wait(ctx, delay) {
			return
		}
	}
}
