package server

import (
	"net/http"

	"github.com/SipiczkiMartin/chat-app/internal/config"
	db "github.com/SipiczkiMartin/chat-app/internal/database/sqlc"
	"github.com/SipiczkiMartin/chat-app/internal/users"
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

func NewRouter(pool *pgxpool.Pool, cfg config.Config) *chi.Mux {
	r := chi.NewRouter()

	queries := db.New(pool)

	userRepo := users.NewRepository(queries)
	userService := users.NewService(userRepo)
	userHandler := users.NewHandler(userService, cfg.JWTSecret)

	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("OK"))
	})

	r.Post("/auth/register", userHandler.Register)
	r.Post("/auth/login", userHandler.Login)
	return r
}
