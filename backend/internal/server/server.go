package server

import (
	"log"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
)

func Run(addr string, db *pgxpool.Pool) error {
	log.Printf("Server listening on %s", addr)

	return http.ListenAndServe(addr, NewRouter(db))
}
