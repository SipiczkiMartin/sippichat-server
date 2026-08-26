package middleware

import (
	"net"
	"net/http"
	"strconv"
	"time"

	"github.com/SipiczkiMartin/chat-app/internal/auth"
	"github.com/google/uuid"
	"github.com/slashdevops/ratelimiter"
	"golang.org/x/time/rate"
)

type RateLimitMiddleware struct {
	loginLimiter    *ratelimiter.BucketLimiter[string]
	registerLimiter *ratelimiter.BucketLimiter[string]
	refreshLimiter  *ratelimiter.BucketLimiter[string]
	messageLimiter  *ratelimiter.BucketLimiter[string]
	uploadLimiter   *ratelimiter.BucketLimiter[string]
}

func NewRateLimitMiddleware() *RateLimitMiddleware {
	return &RateLimitMiddleware{
		loginLimiter: newLimiter(
			rate.Every(12*time.Second), // 5/min
			5,
		),
		registerLimiter: newLimiter(
			rate.Every(20*time.Second), // 3/min
			3,
		),
		refreshLimiter: newLimiter(
			rate.Every(3*time.Second), // 20/min
			20,
		),
		messageLimiter: newLimiter(
			rate.Every(time.Duration(10)*time.Second/30), // 30/10 sec
			30,
		),
		uploadLimiter: newLimiter(
			rate.Every(6*time.Second), // 10/min
			10,
		),
	}
}

func newLimiter(
	limit rate.Limit,
	burst int,
) *ratelimiter.BucketLimiter[string] {
	storage := ratelimiter.NewInMemoryStorage[string, ratelimiter.Limiter]()

	return ratelimiter.NewBucketLimiter(
		ratelimiter.NewRateLimiterFunc(limit, burst),
		10*time.Minute,
		storage,
	)
}

func (m *RateLimitMiddleware) Close() {
	_ = m.loginLimiter.Close()
	_ = m.registerLimiter.Close()
	_ = m.refreshLimiter.Close()
	_ = m.messageLimiter.Close()
	_ = m.uploadLimiter.Close()
}

func (m *RateLimitMiddleware) Login(next http.Handler) http.Handler {
	return m.limitByIP(m.loginLimiter, next)
}

func (m *RateLimitMiddleware) Register(next http.Handler) http.Handler {
	return m.limitByIP(m.registerLimiter, next)
}

func (m *RateLimitMiddleware) Refresh(next http.Handler) http.Handler {
	return m.limitByIP(m.refreshLimiter, next)
}

func (m *RateLimitMiddleware) Messages(next http.Handler) http.Handler {
	return m.limitByUser(m.messageLimiter, next)
}

func (m *RateLimitMiddleware) Uploads(next http.Handler) http.Handler {
	return m.limitByUser(m.uploadLimiter, next)
}

func (m *RateLimitMiddleware) limitByIP(
	manager *ratelimiter.BucketLimiter[string],
	next http.Handler,
) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		key := clientIP(r)

		if !allow(manager, key, w) {
			return
		}

		next.ServeHTTP(w, r)
	})
}

func (m *RateLimitMiddleware) limitByUser(
	manager *ratelimiter.BucketLimiter[string],
	next http.Handler,
) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserIDFromContext(r.Context())

		if userID == uuid.Nil {
			http.Error(
				w,
				"unauthorized",
				http.StatusUnauthorized,
			)
			return
		}

		if !allow(manager, userID.String(), w) {
			return
		}

		next.ServeHTTP(w, r)
	})
}

func allow(
	manager *ratelimiter.BucketLimiter[string],
	key string,
	w http.ResponseWriter,
) bool {
	limiter := manager.GetOrAdd(key)

	reserver, ok := limiter.(ratelimiter.Reserver)
	if !ok {
		// The default limiter supports reservations, but keep
		// a safe fallback for any future custom limiter.
		if limiter.Allow() {
			return true
		}

		w.Header().Set("Retry-After", "1")
		http.Error(
			w,
			"rate limit exceeded",
			http.StatusTooManyRequests,
		)
		return false
	}

	reservation := reserver.Reserve()

	if !reservation.OK() {
		w.Header().Set("Retry-After", "1")
		http.Error(
			w,
			"rate limit exceeded",
			http.StatusTooManyRequests,
		)
		return false
	}

	delay := reservation.Delay()

	if delay <= 0 {
		// The token is available now.
		return true
	}

	// We are rejecting the request, so return the reserved token.
	reservation.Cancel()

	retryAfter := max(1, int(delay.Seconds()+0.999))

	w.Header().Set("Retry-After", strconv.Itoa(retryAfter))
	http.Error(
		w,
		"rate limit exceeded",
		http.StatusTooManyRequests,
	)

	return false
}

func clientIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err == nil {
		return host
	}

	return r.RemoteAddr
}
