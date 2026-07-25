package users

import (
	"context"

	db "github.com/SipiczkiMartin/chat-app/internal/database/sqlc"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

type Repository struct {
	queries *db.Queries
}

func NewRepository(queries *db.Queries) *Repository {
	return &Repository{queries: queries}
}

func (r *Repository) Create(ctx context.Context, email string, passwordHash string) (db.User, error) {
	return r.queries.CreateUser(
		ctx,
		db.CreateUserParams{
			Email:        email,
			PasswordHash: passwordHash,
		},
	)
}

func (r *Repository) GetByEmail(ctx context.Context, email string) (db.User, error) {
	return r.queries.GetUserByEmail(ctx, email)
}

func (r *Repository) GetByID(ctx context.Context, id uuid.UUID) (db.User, error) {

	return r.queries.GetUserByID(
		ctx,
		pgtype.UUID{
			Bytes: id,
			Valid: true,
		},
	)
}
