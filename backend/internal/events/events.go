package events

import (
	"time"

	"github.com/google/uuid"
)

const (
	EventConversationCreated = "conversation.created"

	EventMessageCreated = "message.created"
	EventMessageSend    = "message.send"

	EventTypingStarted = "typing.started"
	EventTypingStopped = "typing.stopped"

	EventMessageDelivered = "message.delivered"
	EventMessageRead      = "message.read"
)

type Event struct {
	Type    string `json:"type"`
	Payload any    `json:"payload"`
}

type TypingPayload struct {
	ConversationID uuid.UUID `json:"conversation_id"`
	UserID         uuid.UUID `json:"user_id"`
}

type SendMessagePayload struct {
	ConversationID uuid.UUID               `json:"conversation_id"`
	Content        string                  `json:"content"`
	Attachments    []SendAttachmentPayload `json:"attachments"`
}

type SendAttachmentPayload struct {
	Type        string         `json:"type"`
	ExternalURL *string        `json:"external_url,omitempty"`
	Filename    *string        `json:"filename,omitempty"`
	StorageKey  *string        `json:"storage_key"`
	MimeType    *string        `json:"mime_type,omitempty"`
	Size        *int64         `json:"size,omitempty"`
	Metadata    map[string]any `json:"metadata,omitempty"`
}

type MessageCreatedPayload struct {
	ID             uuid.UUID                  `json:"id"`
	ConversationID uuid.UUID                  `json:"conversation_id"`
	Content        string                     `json:"content"`
	CreatedAt      time.Time                  `json:"created_at"`
	Sender         MessageCreatedSender       `json:"sender"`
	Attachments    []MessageCreatedAttachment `json:"attachments"`
}

type MessageCreatedSender struct {
	ID          uuid.UUID `json:"id"`
	Username    string    `json:"username"`
	DisplayName string    `json:"display_name"`
	AvatarURL   *string   `json:"avatar_url"`
}

type MessageDeliveredPayload struct {
	MessageID uuid.UUID `json:"message_id"`
}

type MessageReadPayload struct {
	MessageID uuid.UUID `json:"message_id"`
}

type MessageCreatedAttachment struct {
	ID          uuid.UUID      `json:"id"`
	Type        string         `json:"type"`
	Filename    *string        `json:"filename,omitempty"`
	MimeType    *string        `json:"mime_type,omitempty"`
	Size        *int64         `json:"size,omitempty"`
	StorageKey  *string        `json:"storage_key,omitempty"`
	ExternalURL string         `json:"external_url,omitempty"`
	Metadata    map[string]any `json:"metadata,omitempty"`
	SortOrder   int            `json:"sort_order"`
}

type ConversationCreatedPayload struct {
	ConversationID uuid.UUID `json:"conversation_id"`
}
