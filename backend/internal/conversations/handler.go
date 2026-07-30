package conversations

import (
	"encoding/json"
	"net/http"

	"github.com/SipiczkiMartin/chat-app/internal/auth"
	"github.com/google/uuid"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{
		service: service,
	}
}

type createConversationRequest struct {
	UserID string `json:"user_id"`
}

type createConversationResponse struct {
	ID string `json:"id"`
}

func (h *Handler) CreateConversation(w http.ResponseWriter, r *http.Request) {
	creatorID := auth.UserIDFromContext(r.Context())

	if creatorID == uuid.Nil {
		http.Error(
			w,
			"unauthorized",
			http.StatusUnauthorized,
		)
		return
	}

	var req createConversationRequest

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(
			w,
			"invalid request body",
			http.StatusBadRequest,
		)
		return
	}

	memberId, err := uuid.Parse(req.UserID)
	if err != nil {
		http.Error(
			w,
			"invalid user id",
			http.StatusBadRequest,
		)
		return
	}

	conversation, err := h.service.CreateConversation(
		r.Context(),
		CreateConversationInput{
			CreatorID: creatorID,
			MemberID:  memberId,
		},
	)

	if err != nil {
		http.Error(
			w,
			"internal server error",
			http.StatusInternalServerError,
		)
		return
	}

	response := createConversationResponse{
		ID: conversation.ID.String(),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)

	json.NewEncoder(w).Encode(response)
}

func (h *Handler) ListConversations(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserIDFromContext(r.Context())

	if userID == uuid.Nil {
		http.Error(
			w,
			"unauthorized",
			http.StatusUnauthorized,
		)
		return
	}

	conversation, err := h.service.ListConversations(
		r.Context(),
		userID,
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
	json.NewEncoder(w).Encode(conversation)
}
