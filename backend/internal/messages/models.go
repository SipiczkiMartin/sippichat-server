package messages

import (
	"time"

	"github.com/google/uuid"
)

type Message struct {
	ID             uuid.UUID
	ConversationID uuid.UUID
	Content        string
	CreatedAt      time.Time
	Sender         Sender
}

type Sender struct {
	ID          uuid.UUID
	Username    string
	DisplayName string
	AvatarURL   *string
}
