package server

import (
	"net/http"

	db "github.com/SipiczkiMartin/chat-app/internal/database/sqlc"
	"github.com/SipiczkiMartin/chat-app/internal/users"
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

func NewRouter(pool *pgxpool.Pool) *chi.Mux {
	r := chi.NewRouter()

	queries := db.New(pool)

	userRepo := users.NewRepository(queries)
	userService := users.NewService(userRepo)
	userHandler := users.NewHandler(userService)

	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("OK"))
	})

	r.Post("/auth/register", userHandler.Register)

	return r
}
