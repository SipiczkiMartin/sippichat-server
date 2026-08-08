package users

import (
	"context"

	db "github.com/SipiczkiMartin/chat-app/internal/database/sqlc"
	"github.com/google/uuid"
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

func (r *Repository) Create(ctx context.Context, email string, passwordHash string) (db.User, error) {
	return r.queries.CreateUser(
		ctx,
		db.CreateUserParams{
			Email:        email,
			PasswordHash: passwordHash,
		},
	)
}

func (r *Repository) CreateProfile(
	ctx context.Context,
	userID pgtype.UUID,
	username string,
	displayName string,
) (db.Profile, error) {
	return r.queries.CreateProfile(
		ctx,
		db.CreateProfileParams{
			UserID:      userID,
			Username:    username,
			DisplayName: displayName,
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

func (r *Repository) UpdateProfile(
	ctx context.Context,
	userID uuid.UUID,
	displayName string,
	bio string,
) (db.Profile, error) {
	return r.queries.UpdateProfile(ctx, db.UpdateProfileParams{
		UserID: pgtype.UUID{
			Bytes: userID,
			Valid: true,
		},
		DisplayName: displayName,
		Bio: pgtype.Text{
			String: bio,
			Valid:  true,
		},
	})
}

func (r *Repository) GetCurrentUser(ctx context.Context, id uuid.UUID) (db.GetCurrentUserRow, error) {
	return r.queries.GetCurrentUser(ctx, pgtype.UUID{
		Bytes: id,
		Valid: true,
	})
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
