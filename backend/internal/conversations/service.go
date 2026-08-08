package conversations

import (
	"context"
	"errors"

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

func (s *Service) CreateConversation(
	ctx context.Context,
	input CreateConversationInput,
) (Conversation, error) {

	creatorID := pgtype.UUID{
		Bytes: input.CreatorID,
		Valid: true,
	}

	memberID := pgtype.UUID{
		Bytes: input.MemberID,
		Valid: true,
	}

	if input.CreatorID == input.MemberID {
		return Conversation{}, errors.New("can't chat with yourself")
	}

	// check existing direct conversation
	conversation, err := s.repo.GetDirectConversation(
		ctx,
		creatorID,
		memberID,
	)

	if err == nil {

		return s.repo.GetConversationDetails(
			ctx,
			conversation.ID,
			creatorID,
		)
	}

	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return Conversation{}, err
	}

	tx, err := s.repo.BeginTx(ctx)

	if err != nil {
		return Conversation{}, err
	}

	defer tx.Rollback(ctx)

	repo := s.repo.WithTx(tx)

	conversation, err = repo.CreateConversation(
		ctx,
		"direct",
	)

	if err != nil {
		return Conversation{}, err
	}

	if err := repo.AddMember(
		ctx,
		conversation.ID,
		creatorID,
	); err != nil {
		return Conversation{}, err
	}

	if err := repo.AddMember(
		ctx,
		conversation.ID,
		memberID,
	); err != nil {
		return Conversation{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return Conversation{}, err
	}

	// load full conversation with participant
	return s.repo.GetConversationDetails(
		ctx,
		conversation.ID,
		creatorID,
	)
}

func (s *Service) ListConversations(
	ctx context.Context,
	userID uuid.UUID,
) ([]Conversation, error) {

	dbUserID := pgtype.UUID{
		Bytes: userID,
		Valid: true,
	}

	return s.repo.ListConversations(
		ctx,
		dbUserID,
	)
}
