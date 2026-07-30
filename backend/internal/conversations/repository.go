package conversations

import (
	"context"

	db "github.com/SipiczkiMartin/chat-app/internal/database/sqlc"
	"github.com/jackc/pgx/v5"
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

func (r *Repository) CreateConversation(ctx context.Context, conversationType string) (db.Conversation, error) {
	return r.queries.CreateConversation(ctx, conversationType)
}

func (r *Repository) AddMember(
	ctx context.Context,
	conversationID pgtype.UUID,
	userID pgtype.UUID,
) error {
	return r.queries.AddConversationMember(
		ctx,
		db.AddConversationMemberParams{
			ConversationID: conversationID,
			UserID:         userID,
		},
	)
}

func (r *Repository) WithTx(tx pgx.Tx) *Repository {
	return &Repository{
		pool:    r.pool,
		queries: db.New(tx),
	}
}

func (r *Repository) BeginTx(ctx context.Context) (pgx.Tx, error) {
	return r.pool.Begin(ctx)
}

func (r *Repository) GetDirectConversation(
	ctx context.Context,
	userID, user2ID pgtype.UUID,
) (db.Conversation, error) {
	return r.queries.GetDirectConversation(ctx, db.GetDirectConversationParams{
		UserID:   userID,
		UserID_2: user2ID,
	})
}

func (r *Repository) ListConversations(
	ctx context.Context,
	userID pgtype.UUID,
) ([]db.Conversation, error) {
	return r.queries.ListConversations(ctx, userID)
}
