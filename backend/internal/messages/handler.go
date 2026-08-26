package messages

import (
	"encoding/base64"
	"encoding/json"
	"net/http"
	"strconv"
	"time"

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

type MessageResponse struct {
	ID             string               `json:"id"`
	ConversationID string               `json:"conversation_id"`
	Content        string               `json:"content"`
	CreatedAt      time.Time            `json:"created_at"`
	Sender         SenderResponse       `json:"sender"`
	Attachments    []AttachmentResponse `json:"attachments"`
}

type AttachmentResponse struct {
	ID          string  `json:"id"`
	Type        string  `json:"type"`
	Filename    *string `json:"filename,omitempty"`
	MimeType    *string `json:"mime_type,omitempty"`
	Size        *int64  `json:"size,omitempty"`
	StorageKey  *string `json:"storage_key,omitempty"`
	ExternalURL string  `json:"external_url,omitempty"`
	Metadata    []byte  `json:"metadata,omitempty"`
	SortOrder   int     `json:"sort_order"`
}

type SenderResponse struct {
	ID          string  `json:"id"`
	Username    string  `json:"username"`
	DisplayName string  `json:"display_name"`
	AvatarURL   *string `json:"avatar_url,omitempty"`
}

func toMessageResponse(message Message) MessageResponse {
	attachments := make(
		[]AttachmentResponse,
		0,
		len(message.Attachments),
	)

	for _, attachment := range message.Attachments {
		attachments = append(
			attachments,
			AttachmentResponse{
				ID:          attachment.ID.String(),
				Type:        attachment.Type,
				Filename:    attachment.Filename,
				MimeType:    attachment.MimeType,
				Size:        attachment.Size,
				StorageKey:  attachment.StorageKey,
				ExternalURL: attachment.ExternalURL,
				Metadata:    attachment.Metadata,
				SortOrder:   attachment.SortOrder,
			},
		)
	}

	return MessageResponse{
		ID:             message.ID.String(),
		ConversationID: message.ConversationID.String(),
		Content:        message.Content,
		CreatedAt:      message.CreatedAt,
		Attachments:    attachments,

		Sender: SenderResponse{
			ID:          message.Sender.ID.String(),
			Username:    message.Sender.Username,
			DisplayName: message.Sender.DisplayName,
			AvatarURL:   message.Sender.AvatarURL,
		},
	}
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
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(toMessageResponse(message))
}

type messageCursor struct {
	CreatedAt time.Time `json:"created_at"`
	ID        uuid.UUID `json:"id"`
}

type ListMessagesResponse struct {
	Messages   []MessageResponse `json:"messages"`
	NextCursor *string           `json:"next_cursor,omitempty"`
	HasMore    bool              `json:"has_more"`
}

func (h *Handler) ListMessages(
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

	limit := int32(50)

	if value := r.URL.Query().Get("limit"); value != "" {
		parsed, err := strconv.Atoi(value)
		if err != nil || parsed <= 0 || parsed > 100 {
			http.Error(
				w,
				"invalid limit",
				http.StatusBadRequest,
			)
			return
		}

		limit = int32(parsed)
	}

	var beforeCreatedAt *time.Time
	var beforeID *uuid.UUID

	if value := r.URL.Query().Get("before"); value != "" {
		decoded, err := base64.URLEncoding.DecodeString(value)
		if err != nil {
			http.Error(
				w,
				"invalid cursor",
				http.StatusBadRequest,
			)
			return
		}

		var cursor messageCursor

		if err := json.Unmarshal(decoded, &cursor); err != nil {
			http.Error(
				w,
				"invalid cursor",
				http.StatusBadRequest,
			)
			return
		}

		beforeCreatedAt = &cursor.CreatedAt
		beforeID = &cursor.ID
	}

	messages, err := h.service.ListMessages(
		r.Context(),
		ListMessagesInput{
			ConversationID:  conversationID,
			Limit:           limit,
			BeforeCreatedAt: beforeCreatedAt,
			BeforeID:        beforeID,
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

	responses := make([]MessageResponse, 0, len(messages))

	for _, message := range messages {
		responses = append(
			responses,
			toMessageResponse(message),
		)
	}

	response := ListMessagesResponse{
		Messages: responses,
		HasMore:  len(messages) == int(limit),
	}

	if len(messages) > 0 && response.HasMore {
		oldest := messages[0]

		cursor := messageCursor{
			CreatedAt: oldest.CreatedAt,
			ID:        oldest.ID,
		}

		cursorJSON, err := json.Marshal(cursor)
		if err != nil {
			http.Error(
				w,
				"internal server error",
				http.StatusInternalServerError,
			)
			return
		}

		nextCursor := base64.URLEncoding.EncodeToString(cursorJSON)
		response.NextCursor = &nextCursor
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)

	if err := json.NewEncoder(w).Encode(response); err != nil {
		return
	}
}
