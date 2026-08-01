package server

import (
	"net/http"

	"github.com/SipiczkiMartin/chat-app/internal/auth"
	"github.com/SipiczkiMartin/chat-app/internal/config"
	"github.com/SipiczkiMartin/chat-app/internal/conversations"
	"github.com/SipiczkiMartin/chat-app/internal/messages"
	"github.com/SipiczkiMartin/chat-app/internal/users"
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

	messageRepo := messages.NewRepository(pool)
	messageService := messages.NewService(messageRepo)
	messageHandler := messages.NewHandler(messageService)

	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("OK"))
	})

	r.Post("/auth/register", userHandler.Register)
	r.Post("/auth/login", userHandler.Login)
	r.Post("/auth/refresh", userHandler.RefreshToken)
	r.Post("/auth/logout", userHandler.Logout)

	r.Group(func(r chi.Router) {
		r.Use(auth.JWTMiddleware(cfg.JWTSecret))
		r.Get("/me", userHandler.Me)
		r.Post("/auth/logout-all", userHandler.LogoutAll)

		r.Post("/conversations", conversationHandler.CreateConversation)
		r.Get("/conversations", conversationHandler.ListConversations)

		r.Post("/conversations/{conversationID}/messages", messageHandler.CreateMessage)
		r.Get("/conversations/{conversationID}/messages", messageHandler.ListMessages)
	})

	return r
}
