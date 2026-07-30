package conversations

import (
	"context"
	"errors"

	db "github.com/SipiczkiMartin/chat-app/internal/database/sqlc"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
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

type CreateConversationInput struct {
	CreatorID uuid.UUID
	MemberID  uuid.UUID
}

func (s *Service) CreateConversation(ctx context.Context, input CreateConversationInput) (db.Conversation, error) {
	creatorID := pgtype.UUID{
		Bytes: input.CreatorID,
		Valid: true,
	}

	memberID := pgtype.UUID{
		Bytes: input.MemberID,
		Valid: true,
	}

	//no conversation with myself
	if input.CreatorID == input.MemberID {
		return db.Conversation{}, errors.New("Can't chat with yourself!")
	}

	//check if direct conversation exists
	conversation, err := s.repo.GetDirectConversation(
		ctx,
		creatorID,
		memberID,
	)

	if err == nil {
		return conversation, nil
	}

	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return db.Conversation{}, err
	}

	tx, err := s.repo.BeginTx(ctx)
	if err != nil {
		return db.Conversation{}, err
	}

	defer tx.Rollback(ctx)

	repo := s.repo.WithTx(tx)

	conversation, err = repo.CreateConversation(ctx, "direct")
	if err != nil {
		return db.Conversation{}, err
	}

	err = repo.AddMember(
		ctx,
		conversation.ID,
		creatorID,
	)

	if err != nil {
		return db.Conversation{}, err
	}

	err = repo.AddMember(
		ctx,
		conversation.ID,
		memberID,
	)

	if err != nil {
		return db.Conversation{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return db.Conversation{}, err
	}

	return conversation, nil

}

func (s *Service) ListConversations(
	ctx context.Context,
	userID uuid.UUID,
) ([]db.Conversation, error) {
	dbUserID := pgtype.UUID{
		Bytes: userID,
		Valid: true,
	}

	return s.repo.ListConversations(ctx, dbUserID)
}
