package typing

import (
	"context"

	"github.com/SipiczkiMartin/chat-app/internal/events"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

type ConversationRepository interface {
	ListConversationMembers(
		ctx context.Context,
		conversationID pgtype.UUID,
	) ([]pgtype.UUID, error)
}

type Broadcaster interface {
	SendToUser(userID uuid.UUID, event any)
}

type Service struct {
	conversations ConversationRepository
	hub           Broadcaster
}

func NewService(conversations ConversationRepository, hub Broadcaster) *Service {
	return &Service{
		conversations: conversations,
		hub:           hub,
	}
}

func (s *Service) TypingStarted(
	ctx context.Context,
	userID uuid.UUID,
	conversationID uuid.UUID,
) error {
	conversationUUID := pgtype.UUID{
		Bytes: conversationID,
		Valid: true,
	}

	members, err := s.conversations.ListConversationMembers(ctx, conversationUUID)
	if err != nil {
		return err
	}

	event := events.Event{
		Type: events.EventTypingStarted,
		Payload: events.TypingPayload{
			ConversationID: conversationID,
		},
	}

	for _, member := range members {
		memberUUID := uuid.UUID(member.Bytes)
		if memberUUID == userID {
			continue
		}
		s.hub.SendToUser(memberUUID, event)
	}

	return nil
}

func (s *Service) TypingStopped(
	ctx context.Context,
	userID uuid.UUID,
	conversationID uuid.UUID,
) error {
	conversationUUID := pgtype.UUID{
		Bytes: conversationID,
		Valid: true,
	}

	members, err := s.conversations.ListConversationMembers(ctx, conversationUUID)
	if err != nil {
		return err
	}

	event := events.Event{
		Type: events.EventTypingStopped,
		Payload: events.TypingPayload{
			ConversationID: conversationID,
		},
	}

	for _, member := range members {
		memberUUID := uuid.UUID(member.Bytes)
		if memberUUID == userID {
			continue
		}
		s.hub.SendToUser(memberUUID, event)
	}

	return nil
}
