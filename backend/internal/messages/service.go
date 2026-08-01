package messages

import (
	"context"
	"errors"

	db "github.com/SipiczkiMartin/chat-app/internal/database/sqlc"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

type Service struct {
	repo *Repository
}

func NewService(repo *Repository) *Service {
	return &Service{
		repo: repo,
	}
}

type SendMessageInput struct {
	ConversationID uuid.UUID
	SenderID       uuid.UUID
	Content        string
}

func (s *Service) SendMessage(
	ctx context.Context,
	input SendMessageInput,
) (db.Message, error) {
	if input.Content == "" {
		return db.Message{}, errors.New("no message content!")
	}

	conversationID := pgtype.UUID{
		Bytes: input.ConversationID,
		Valid: true,
	}

	senderID := pgtype.UUID{
		Bytes: input.SenderID,
		Valid: true,
	}

	isMember, err := s.repo.IsConversationMember(
		ctx,
		conversationID,
		senderID,
	)

	if err != nil {
		return db.Message{}, err
	}

	if !isMember {
		return db.Message{}, errors.New("user is not a conversation member!")
	}

	return s.repo.CreateMessage(
		ctx,
		conversationID,
		senderID,
		input.Content,
	)
}

func (s *Service) ListMessages(
	ctx context.Context,
	conversationID uuid.UUID,
	limit int32,
) ([]db.Message, error) {
	id := pgtype.UUID{
		Bytes: conversationID,
		Valid: true,
	}

	return s.repo.ListMessages(
		ctx,
		id,
		limit,
	)
}
