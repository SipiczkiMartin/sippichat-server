package events

import (
	"time"

	"github.com/google/uuid"
)

const (
	EventMessageCreated = "message.created"
	EventMessageRead    = "message.read"
	EventMessageSend    = "message.send"

	EventTypingStarted = "typing.started"
	EventTypingStopped = "typing.stopped"
)

type Event struct {
	Type    string `json:"type"`
	Payload any    `json:"payload"`
}

type TypingPayload struct {
	ConversationID uuid.UUID `json:"conversation_id"`
}

type SendMessagePayload struct {
	ConversationID uuid.UUID `json:"conversation_id"`
	Content        string    `json:"content"`
}

type MessageCreatedPayload struct {
	ID             uuid.UUID            `json:"id"`
	ConversationID uuid.UUID            `json:"conversation_id"`
	Content        string               `json:"content"`
	CreatedAt      time.Time            `json:"created_at"`
	Sender         MessageCreatedSender `json:"sender"`
}

type MessageCreatedSender struct {
	ID          uuid.UUID `json:"id"`
	Username    string    `json:"username"`
	DisplayName string    `json:"display_name"`
	AvatarURL   *string   `json:"avatar_url"`
}
