package server

import (
	"net/http"

	"github.com/SipiczkiMartin/chat-app/internal/auth"
	"github.com/SipiczkiMartin/chat-app/internal/config"
	"github.com/SipiczkiMartin/chat-app/internal/conversations"
	"github.com/SipiczkiMartin/chat-app/internal/messages"
	"github.com/SipiczkiMartin/chat-app/internal/readreceipts"
	"github.com/SipiczkiMartin/chat-app/internal/typing"
	"github.com/SipiczkiMartin/chat-app/internal/users"
	"github.com/SipiczkiMartin/chat-app/internal/websocket"
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

func NewRouter(pool *pgxpool.Pool, cfg config.Config) *chi.Mux {
	r := chi.NewRouter()

	userRepo := users.NewRepository(pool)
	authRepo := auth.NewRepository(pool)
	userService := users.NewService(userRepo, authRepo, cfg.JWTSecret)
	userHandler := users.NewHandler(userService)

	conversationRepo := conversations.NewRepository(pool)
	conversationService := conversations.NewService(conversationRepo)
	conversationHandler := conversations.NewHandler(conversationService)

	hub := websocket.NewHub()
	typingService := typing.NewService(conversationRepo, hub)
	wsHandler := websocket.NewHandler(hub, typingService)

	messageRepo := messages.NewRepository(pool)
	messageService := messages.NewService(messageRepo, conversationRepo, hub)
	messageHandler := messages.NewHandler(messageService)

	readReceiptRepo := readreceipts.NewRepository(pool)
	readReceiptService := readreceipts.NewService(
		readReceiptRepo,
		messageRepo,
		conversationRepo,
		hub,
	)
	readReceiptHandler := readreceipts.NewHanler(readReceiptService)

	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("OK"))
	})

	r.Post("/auth/register", userHandler.Register)
	r.Post("/auth/login", userHandler.Login)
	r.Post("/auth/refresh", userHandler.RefreshToken)
	r.Post("/auth/logout", userHandler.Logout)

	r.Group(func(r chi.Router) {
		r.Use(auth.JWTMiddleware(cfg.JWTSecret))
		r.Get("/ws", wsHandler.ServeHTTP)
		r.Get("/me", userHandler.Me)
		r.Patch("/me", userHandler.UpdateMe)
		r.Post("/auth/logout-all", userHandler.LogoutAll)

		r.Post("/conversations", conversationHandler.CreateConversation)
		r.Get("/conversations", conversationHandler.ListConversations)

		r.Post("/conversations/{conversationID}/messages", messageHandler.CreateMessage)
		r.Get("/conversations/{conversationID}/messages", messageHandler.ListMessages)

		r.Post("/messages/{messageID}/read", readReceiptHandler.MarkRead)
	})

	return r
}
