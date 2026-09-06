package conversations

import (
	"encoding/json"
	"net/http"
	"time"

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

	memberID, err := uuid.Parse(req.UserID)

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
			MemberID:  memberID,
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

	response := toConversationResponse(conversation)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)

	json.NewEncoder(w).Encode(response)
}

type ParticipantResponse struct {
	ID          string  `json:"id"`
	Username    string  `json:"username"`
	DisplayName string  `json:"display_name"`
	AvatarURL   *string `json:"avatar_url,omitempty"`
}

type LastMessageResponse struct {
	Content   string    `json:"content"`
	CreatedAt time.Time `json:"created_at"`
}

type ConversationResponse struct {
	ID          string               `json:"id"`
	Type        string               `json:"type"`
	CreatedAt   time.Time            `json:"created_at"`
	Participant *ParticipantResponse `json:"participant,omitempty"`
	LastMessage *LastMessageResponse `json:"last_message,omitempty"`
	UnreadCount int64                `json:"unread_count"`
}

func toConversationResponse(conversation Conversation) ConversationResponse {
	return ConversationResponse{
		ID:          conversation.ID.String(),
		Type:        conversation.Type,
		CreatedAt:   conversation.CreatedAt,
		UnreadCount: conversation.UnreadCount,

		Participant: &ParticipantResponse{
			ID:          conversation.Participant.ID.String(),
			Username:    conversation.Participant.Username,
			DisplayName: conversation.Participant.DisplayName,
			AvatarURL:   conversation.Participant.AvatarURL,
		},
	}
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

	conversations, err := h.service.ListConversations(
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

	responses := make([]ConversationResponse, 0, len(conversations))

	for _, c := range conversations {
		responses = append(responses, toConversationResponse(c))
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(responses)
}
