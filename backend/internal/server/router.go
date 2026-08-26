package server

import (
	"context"
	"net/http"

	"github.com/SipiczkiMartin/chat-app/internal/auth"
	"github.com/SipiczkiMartin/chat-app/internal/config"
	"github.com/SipiczkiMartin/chat-app/internal/conversations"
	"github.com/SipiczkiMartin/chat-app/internal/messages"
	"github.com/SipiczkiMartin/chat-app/internal/middleware"
	"github.com/SipiczkiMartin/chat-app/internal/readreceipts"
	"github.com/SipiczkiMartin/chat-app/internal/storage"
	"github.com/SipiczkiMartin/chat-app/internal/typing"
	"github.com/SipiczkiMartin/chat-app/internal/uploads"
	"github.com/SipiczkiMartin/chat-app/internal/users"
	"github.com/SipiczkiMartin/chat-app/internal/websocket"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/cors"
	"github.com/jackc/pgx/v5/pgxpool"
)

func NewRouter(pool *pgxpool.Pool, cfg config.Config) *chi.Mux {
	r := chi.NewRouter()

	rateLimiter := middleware.NewRateLimitMiddleware()

	r.Use(cors.Handler(cors.Options{
		AllowedOrigins: []string{
			"http://localhost:*",
		},
		AllowedMethods: []string{
			"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS",
		},
		AllowedHeaders: []string{
			"Accept",
			"Authorization",
			"Content-Type",
		},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	objectStorage, err := storage.NewMinIOStorage(
		cfg.StorageEndpoint,
		cfg.StorageAccessKey,
		cfg.StorageSecretKey,
		cfg.StorageBucket,
		cfg.StorageUseSSL,
		cfg.StoragePublicURL,
	)

	if err != nil {
		panic(err)
	}

	if err := objectStorage.EnsureBucket(context.Background()); err != nil {
		panic(err)
	}

	userRepo := users.NewRepository(pool)
	authRepo := auth.NewRepository(pool)
	userService := users.NewService(userRepo, authRepo, cfg.JWTSecret)
	userHandler := users.NewHandler(userService)

	conversationRepo := conversations.NewRepository(pool)
	conversationService := conversations.NewService(conversationRepo)
	conversationHandler := conversations.NewHandler(conversationService)

	hub := websocket.NewHub()

	messageRepo := messages.NewRepository(pool)
	messageService := messages.NewService(
		messageRepo,
		conversationRepo,
		hub,
	)
	messageHandler := messages.NewHandler(messageService)

	typingService := typing.NewService(conversationRepo, hub)
	wsHandler := websocket.NewHandler(
		hub,
		typingService,
		messageService,
		cfg.JWTSecret,
	)

	readReceiptRepo := readreceipts.NewRepository(pool)
	readReceiptService := readreceipts.NewService(
		readReceiptRepo,
		messageRepo,
		conversationRepo,
		hub,
	)
	readReceiptHandler := readreceipts.NewHanler(readReceiptService)

	uploadService := uploads.NewService(objectStorage)
	uploadHandler := uploads.NewHandler(uploadService)

	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("OK"))
	})

	// Public authentication routes.
	r.With(rateLimiter.Register).Post(
		"/auth/register",
		userHandler.Register,
	)

	r.With(rateLimiter.Login).Post(
		"/auth/login",
		userHandler.Login,
	)

	r.With(rateLimiter.Refresh).Post(
		"/auth/refresh",
		userHandler.RefreshToken,
	)

	r.Post(
		"/auth/logout",
		userHandler.Logout,
	)

	r.Get("/ws", wsHandler.ServeHTTP)

	// Authenticated routes.
	r.Group(func(r chi.Router) {
		r.Use(auth.JWTMiddleware(cfg.JWTSecret))

		r.Get("/me", userHandler.Me)
		r.Patch("/me", userHandler.UpdateMe)
		r.Post("/auth/logout-all", userHandler.LogoutAll)

		r.Post(
			"/conversations",
			conversationHandler.CreateConversation,
		)

		r.Get(
			"/conversations",
			conversationHandler.ListConversations,
		)

		r.With(rateLimiter.Messages).Post(
			"/conversations/{conversationID}/messages",
			messageHandler.CreateMessage,
		)

		r.Get(
			"/conversations/{conversationID}/messages",
			messageHandler.ListMessages,
		)

		r.Post(
			"/messages/{messageID}/read",
			readReceiptHandler.MarkRead,
		)

		r.Get(
			"/users/search",
			userHandler.Search,
		)

		r.With(rateLimiter.Uploads).Post(
			"/uploads",
			uploadHandler.Upload,
		)

		r.Get(
			"/uploads/attachments/{filename}",
			uploadHandler.Download,
		)
	})

	return r
}
