package readreceipts

import (
	"context"

	db "github.com/SipiczkiMartin/chat-app/internal/database/sqlc"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	queries *db.Queries
}

func NewRepository(pool *pgxpool.Pool) *Repository {
	return &Repository{
		queries: db.New(pool),
	}
}

func (r *Repository) MarkMessageRead(
	ctx context.Context,
	messageID pgtype.UUID,
	userID pgtype.UUID,
) error {
	return r.queries.MarkMessageRead(
		ctx, db.MarkMessageReadParams{
			MessageID: messageID,
			UserID:    userID,
		},
	)
}
