package server

import (
	"log"
	"net/http"

	"github.com/SipiczkiMartin/chat-app/internal/config"
	"github.com/jackc/pgx/v5/pgxpool"
)

func Run(addr string, db *pgxpool.Pool, cfg config.Config) error {
	log.Printf("Server listening on %s", addr)

	return http.ListenAndServe(addr, NewRouter(db, cfg))
}
