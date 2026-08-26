package middleware

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/SipiczkiMartin/chat-app/internal/auth"
	"github.com/google/uuid"
	"github.com/slashdevops/ratelimiter"
	"golang.org/x/time/rate"
)

func testLimiter(limit rate.Limit, burst int) *ratelimiter.BucketLimiter[string] {
	storage := ratelimiter.NewInMemoryStorage[string, ratelimiter.Limiter]()

	return ratelimiter.NewBucketLimiter(
		ratelimiter.NewRateLimiterFunc(limit, burst),
		time.Minute,
		storage,
	)
}

func testHandler(called *bool) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		*called = true
		w.WriteHeader(http.StatusOK)
	})
}

func TestLimitByIP_AllowsWithinLimit(t *testing.T) {
	manager := testLimiter(rate.Limit(0), 2)
	defer manager.Close()

	middleware := &RateLimitMiddleware{}

	called := false

	handler := middleware.limitByIP(
		manager,
		testHandler(&called),
	)

	req := httptest.NewRequest(
		http.MethodPost,
		"/auth/login",
		nil,
	)
	req.RemoteAddr = "192.168.1.10:12345"

	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d", http.StatusOK, rec.Code)
	}

	if !called {
		t.Fatal("expected handler to be called")
	}
}

func TestLimitByIP_RejectsAfterBurst(t *testing.T) {
	manager := testLimiter(1, 2)
	defer manager.Close()

	middleware := &RateLimitMiddleware{}

	called := 0

	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called++
		w.WriteHeader(http.StatusOK)
	})

	handler := middleware.limitByIP(manager, next)

	for i := 0; i < 3; i++ {
		req := httptest.NewRequest(
			http.MethodPost,
			"/auth/login",
			nil,
		)
		req.RemoteAddr = "192.168.1.10:12345"

		rec := httptest.NewRecorder()

		handler.ServeHTTP(rec, req)

		if i < 2 {
			if rec.Code != http.StatusOK {
				t.Fatalf(
					"request %d: expected status %d, got %d",
					i+1,
					http.StatusOK,
					rec.Code,
				)
			}
		} else {
			if rec.Code != http.StatusTooManyRequests {
				t.Fatalf(
					"request %d: expected status %d, got %d",
					i+1,
					http.StatusTooManyRequests,
					rec.Code,
				)
			}
		}
	}

	if called != 2 {
		t.Fatalf("expected handler to be called 2 times, got %d", called)
	}
}

func TestLimitByIP_SetsRetryAfter(t *testing.T) {
	manager := testLimiter(1, 1)
	defer manager.Close()

	middleware := &RateLimitMiddleware{}

	handler := middleware.limitByIP(
		manager,
		http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
		}),
	)

	// Consume the only available token.
	req1 := httptest.NewRequest(
		http.MethodPost,
		"/auth/login",
		nil,
	)
	req1.RemoteAddr = "192.168.1.10:12345"

	rec1 := httptest.NewRecorder()

	handler.ServeHTTP(rec1, req1)

	if rec1.Code != http.StatusOK {
		t.Fatalf("expected first request to succeed, got %d", rec1.Code)
	}

	// This request should be rejected.
	req2 := httptest.NewRequest(
		http.MethodPost,
		"/auth/login",
		nil,
	)
	req2.RemoteAddr = "192.168.1.10:12345"

	rec2 := httptest.NewRecorder()

	handler.ServeHTTP(rec2, req2)

	if rec2.Code != http.StatusTooManyRequests {
		t.Fatalf(
			"expected status %d, got %d",
			http.StatusTooManyRequests,
			rec2.Code,
		)
	}

	retryAfter := rec2.Header().Get("Retry-After")

	if retryAfter == "" {
		t.Fatal("expected Retry-After header")
	}
}

func TestLimitByIP_DifferentIPsAreIndependent(t *testing.T) {
	manager := testLimiter(rate.Inf, 1)
	defer manager.Close()

	middleware := &RateLimitMiddleware{}

	handler := middleware.limitByIP(
		manager,
		http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
		}),
	)

	ips := []string{
		"192.168.1.10:12345",
		"192.168.1.11:12345",
	}

	for _, ip := range ips {
		req := httptest.NewRequest(
			http.MethodPost,
			"/auth/login",
			nil,
		)
		req.RemoteAddr = ip

		rec := httptest.NewRecorder()

		handler.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf(
				"IP %s: expected status %d, got %d",
				ip,
				http.StatusOK,
				rec.Code,
			)
		}
	}
}

func TestLimitByUser_RejectsUnauthenticatedRequest(t *testing.T) {
	manager := testLimiter(rate.Limit(0), 2)
	defer manager.Close()

	middleware := &RateLimitMiddleware{}

	called := false

	handler := middleware.limitByUser(
		manager,
		testHandler(&called),
	)

	req := httptest.NewRequest(
		http.MethodPost,
		"/messages",
		nil,
	)

	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf(
			"expected status %d, got %d",
			http.StatusUnauthorized,
			rec.Code,
		)
	}

	if called {
		t.Fatal("expected handler not to be called")
	}
}

func TestLimitByUser_DifferentUsersAreIndependent(t *testing.T) {
	manager := testLimiter(rate.Inf, 1)
	defer manager.Close()

	middleware := &RateLimitMiddleware{}

	handler := middleware.limitByUser(
		manager,
		http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
		}),
	)

	users := []uuid.UUID{
		uuid.New(),
		uuid.New(),
	}

	for _, userID := range users {
		req := httptest.NewRequest(
			http.MethodPost,
			"/messages",
			nil,
		)

		ctx := auth.WithUserID(
			context.Background(),
			userID,
		)

		req = req.WithContext(ctx)

		rec := httptest.NewRecorder()

		handler.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf(
				"user %s: expected status %d, got %d",
				userID,
				http.StatusOK,
				rec.Code,
			)
		}
	}
}

func TestLimitByUser_RejectsAfterBurst(t *testing.T) {
	manager := testLimiter(rate.Limit(0), 2)
	defer manager.Close()

	middleware := &RateLimitMiddleware{}

	userID := uuid.New()

	called := 0

	handler := middleware.limitByUser(
		manager,
		http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			called++
			w.WriteHeader(http.StatusOK)
		}),
	)

	for i := 0; i < 3; i++ {
		req := httptest.NewRequest(
			http.MethodPost,
			"/messages",
			nil,
		)

		ctx := auth.WithUserID(
			context.Background(),
			userID,
		)

		req = req.WithContext(ctx)

		rec := httptest.NewRecorder()

		handler.ServeHTTP(rec, req)

		if i < 2 {
			if rec.Code != http.StatusOK {
				t.Fatalf(
					"request %d: expected status %d, got %d",
					i+1,
					http.StatusOK,
					rec.Code,
				)
			}
		} else {
			if rec.Code != http.StatusTooManyRequests {
				t.Fatalf(
					"request %d: expected status %d, got %d",
					i+1,
					http.StatusTooManyRequests,
					rec.Code,
				)
			}
		}
	}

	if called != 2 {
		t.Fatalf("expected handler to be called 2 times, got %d", called)
	}
}
