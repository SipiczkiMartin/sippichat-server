package conversations

import (
	"time"

	"github.com/google/uuid"
)

type Conversation struct {
	ID          uuid.UUID
	Type        string
	CreatedAt   time.Time
	Participant Participant
	UnreadCount int64
}

type Participant struct {
	ID          uuid.UUID
	Username    string
	DisplayName string
	AvatarURL   *string
}
