package messages

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/SipiczkiMartin/chat-app/internal/auth"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

type Handler struct {
	service *Service
}

func NewHandler(servicer *Service) *Handler {
	return &Handler{
		service: servicer,
	}
}

type createMessageRequest struct {
	Content string `json:"content"`
}

func (h *Handler) CreateMessage(
	w http.ResponseWriter,
	r *http.Request,
) {
	userID := auth.UserIDFromContext(r.Context())
	if userID == uuid.Nil {
		http.Error(
			w,
			"unauthorized",
			http.StatusUnauthorized,
		)
		return
	}

	conversationID, err := uuid.Parse(
		chi.URLParam(r, "conversationID"),
	)

	if err != nil {
		http.Error(
			w,
			"invalid conversation id",
			http.StatusBadRequest,
		)
		return
	}

	var req createMessageRequest

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(
			w,
			"invalid request body",
			http.StatusBadRequest,
		)
		return
	}

	message, err := h.service.SendMessage(
		r.Context(),
		SendMessageInput{
			ConversationID: conversationID,
			SenderID:       userID,
			Content:        req.Content,
		},
	)

	if err != nil {
		http.Error(
			w,
			err.Error(),
			http.StatusBadRequest,
		)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(message)
}

func (h *Handler) ListMessages(
	w http.ResponseWriter,
	r *http.Request,
) {
	userID := auth.UserIDFromContext(r.Context())
	if userID == uuid.Nil {
		http.Error(
			w, "unauthorized", http.StatusUnauthorized,
		)
		return
	}

	conversationID, err := uuid.Parse(
		chi.URLParam(r, "conversationID"),
	)

	if err != nil {
		http.Error(
			w,
			"invalid conversation id",
			http.StatusBadRequest,
		)
		return
	}

	limit := int32(50)

	if value := r.URL.Query().Get("limit"); value != "" {
		parsed, err := strconv.Atoi(value)
		if err == nil && parsed > 0 && parsed <= 100 {
			limit = int32(parsed)
		}
	}

	messages, err := h.service.ListMessages(
		r.Context(),
		conversationID,
		limit,
	)

	if err != nil {
		http.Error(
			w,
			"internal server error",
			http.StatusInternalServerError,
		)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(messages)
}
