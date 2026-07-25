package main

import (
	"context"
	"log"

	"github.com/SipiczkiMartin/chat-app/internal/config"
	"github.com/SipiczkiMartin/chat-app/internal/database"
	"github.com/SipiczkiMartin/chat-app/internal/server"
)

func main() {
	ctx := context.Background()
	cfg := config.Load()

	db, err := database.Connect(ctx, cfg.DatabaseURL())
	if err != nil {
		log.Fatal("database connection failed:", err)
	}

	defer db.Close()

	log.Println("Connected to Database!")

	if err := server.Run(":"+cfg.Port, db); err != nil {
		log.Fatal(err)
	}
}
