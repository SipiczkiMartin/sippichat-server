package messages

import (
	"context"

	db "github.com/SipiczkiMartin/chat-app/internal/database/sqlc"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	pool    *pgxpool.Pool
	queries *db.Queries
}

func NewRepository(pool *pgxpool.Pool) *Repository {
	return &Repository{
		pool:    pool,
		queries: db.New(pool),
	}
}

func (r *Repository) CreateMessage(
	ctx context.Context,
	conversationID pgtype.UUID,
	senderID pgtype.UUID,
	content string,
) (db.Message, error) {
	return r.queries.CreateMessage(
		ctx,
		db.CreateMessageParams{
			ConversationID: conversationID,
			SenderID:       senderID,
			Content:        content,
		},
	)
}

func (r *Repository) IsConversationMember(
	ctx context.Context,
	conversationID pgtype.UUID,
	userID pgtype.UUID,
) (bool, error) {
	return r.queries.IsConversationMember(
		ctx,
		db.IsConversationMemberParams{
			ConversationID: conversationID,
			UserID:         userID,
		},
	)
}

func (r *Repository) ListMessages(
	ctx context.Context,
	conversationID pgtype.UUID,
	limit int32,
) ([]db.Message, error) {
	return r.queries.ListMessages(
		ctx,
		db.ListMessagesParams{
			ConversationID: conversationID,
			Limit:          limit,
		},
	)
}
