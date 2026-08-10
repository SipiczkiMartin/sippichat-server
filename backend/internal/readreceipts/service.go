package readreceipts

import (
	"context"

	"github.com/SipiczkiMartin/chat-app/internal/conversations"
	"github.com/SipiczkiMartin/chat-app/internal/events"
	"github.com/SipiczkiMartin/chat-app/internal/messages"
	"github.com/SipiczkiMartin/chat-app/internal/websocket"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

type Service struct {
	repo             *Repository
	messageRepo      *messages.Repository
	conversationRepo *conversations.Repository
	hub              *websocket.Hub
}

func NewService(
	repo *Repository,
	messageRepo *messages.Repository,
	conversationRepo *conversations.Repository,
	hub *websocket.Hub,
) *Service {
	return &Service{
		repo:             repo,
		messageRepo:      messageRepo,
		conversationRepo: conversationRepo,
		hub:              hub,
	}
}

func (s *Service) MarkRead(
	ctx context.Context,
	messageID uuid.UUID,
	userID uuid.UUID,
) error {
	msgID := pgtype.UUID{
		Bytes: messageID,
		Valid: true,
	}

	userUUID := pgtype.UUID{
		Bytes: userID,
		Valid: true,
	}

	message, err := s.messageRepo.GetMessageByID(ctx, msgID)
	if err != nil {
		return err
	}

	isMember, err := s.conversationRepo.IsMember(
		ctx,
		message.ConversationID,
		userUUID,
	)

	if err != nil {
		return err
	}

	if !isMember {
		return err
	}

	err = s.repo.MarkMessageRead(
		ctx, msgID, userUUID,
	)
	if err != nil {
		return err
	}

	event := events.Event{
		Type: events.EventMessageRead,
		Payload: map[string]any{
			"message_id": messageID,
			"user_id":    userID,
		},
	}

	s.hub.SendToUser(message.SenderID.Bytes, event)
	return nil

}
