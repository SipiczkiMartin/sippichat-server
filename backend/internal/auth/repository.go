package auth

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

func (r *Repository) CreateRefreshToken(
	ctx context.Context,
	userID pgtype.UUID,
	tokenHash string,
	expiresAt pgtype.Timestamptz,
) (db.RefreshToken, error) {
	return r.queries.CreateRefreshToken(
		ctx,
		db.CreateRefreshTokenParams{
			UserID:    userID,
			TokenHash: tokenHash,
			ExpiresAt: expiresAt,
		},
	)
}

func (r *Repository) GetRefreshTokenByHash(
	ctx context.Context,
	hash string,
) (db.RefreshToken, error) {
	return r.queries.GetRefreshTokenByHash(ctx, hash)
}

func (r *Repository) RevokeRefreshToken(
	ctx context.Context,
	id pgtype.UUID,
) error {
	return r.queries.RevokeRefreshToken(ctx, id)
}

func (r *Repository) BeginTx(ctx context.Context) (pgx.Tx, error) {
	return r.pool.Begin(ctx)
}

func (r *Repository) WithTx(tx pgx.Tx) *Repository {
	return &Repository{
		pool:    r.pool,
		queries: db.New(tx),
	}
}

func (r *Repository) RevokeRefreshTokenByHash(ctx context.Context, hash string) error {
	return r.queries.RevokeRefreshTokenByHash(ctx, hash)
}

func (r *Repository) RevokeAllRefreshTokensByUserID(ctx context.Context, userID pgtype.UUID) error {
	return r.queries.RevokeAllRefreshTokensByUserID(ctx, userID)
}
