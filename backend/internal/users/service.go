package users

import (
	"context"
	"errors"
	"time"

	"github.com/SipiczkiMartin/chat-app/internal/auth"
	db "github.com/SipiczkiMartin/chat-app/internal/database/sqlc"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

type Service struct {
	repo      *Repository
	jwtSecret string
	authRepo  *auth.Repository
}

func NewService(repo *Repository, authRepo *auth.Repository, jwtSecret string) *Service {
	return &Service{repo: repo, authRepo: authRepo, jwtSecret: jwtSecret}
}

type RegisterInput struct {
	Email    string
	Password string
}

type LoginInput struct {
	Email    string
	Password string
}

type TokenResult struct {
	AccessToken  string
	ExpiresIn    int
	RefreshToken string
}

type LoginResult struct {
	TokenResult
}

func (s *Service) Register(ctx context.Context, input RegisterInput) (db.User, error) {
	//exists check
	_, err := s.repo.GetByEmail(ctx, input.Email)
	switch {
	case err == nil:
		return db.User{}, errors.New(
			"user already exists",
		)

	case !errors.Is(err, pgx.ErrNoRows):
		return db.User{}, err
	}

	passwordHash, err := auth.HashPassword(input.Password)

	if err != nil {
		return db.User{}, err
	}

	return s.repo.Create(ctx, input.Email, passwordHash)
}

func (s *Service) Login(ctx context.Context, input LoginInput) (LoginResult, error) {
	user, err := s.repo.GetByEmail(ctx, input.Email)
	if err != nil {
		return LoginResult{}, ErrInvalidCredentials
	}

	if err := auth.CheckPassword(input.Password, user.PasswordHash); err != nil {
		return LoginResult{}, ErrInvalidCredentials
	}

	accessToken, err := auth.GenerateAccessToken(user.ID.Bytes, s.jwtSecret)
	if err != nil {
		return LoginResult{}, err
	}

	refreshToken, err := auth.GenerateRefreshToken()
	if err != nil {
		return LoginResult{}, err
	}

	refreshHash := auth.HashRefreshToken(refreshToken)

	_, err = s.authRepo.CreateRefreshToken(ctx, user.ID, refreshHash,
		pgtype.Timestamptz{
			Time:  time.Now().Add(auth.RefreshTokenDuration),
			Valid: true,
		})
	if err != nil {
		return LoginResult{}, err
	}

	return LoginResult{
		TokenResult: TokenResult{
			AccessToken:  accessToken,
			ExpiresIn:    int(auth.AccessTokenDuration.Seconds()),
			RefreshToken: refreshToken,
		},
	}, nil
}

func (s *Service) GetByID(ctx context.Context, id uuid.UUID) (db.User, error) {
	return s.repo.GetByID(ctx, id)
}

func (s *Service) RefreshToken(ctx context.Context, refreshToken string) (TokenResult, error) {
	hash := auth.HashRefreshToken(refreshToken)

	storedToken, err := s.authRepo.GetRefreshTokenByHash(ctx, hash)
	if err != nil {
		return TokenResult{}, ErrInvalidRefreshToken
	}

	if storedToken.RevokedAt.Valid {
		return TokenResult{}, ErrInvalidRefreshToken
	}

	if !storedToken.ExpiresAt.Valid || time.Now().After(storedToken.ExpiresAt.Time) {
		return TokenResult{}, ErrInvalidRefreshToken
	}

	accessToken, err := auth.GenerateAccessToken(
		storedToken.UserID.Bytes,
		s.jwtSecret,
	)

	if err != nil {
		return TokenResult{}, err
	}

	newRefreshToken, err := auth.GenerateRefreshToken()
	if err != nil {
		return TokenResult{}, err
	}

	newHash := auth.HashRefreshToken(newRefreshToken)

	//transactional
	tx, err := s.authRepo.BeginTx(ctx)
	if err != nil {
		return TokenResult{}, err
	}

	defer tx.Rollback(ctx)
	txAuthRepo := s.authRepo.WithTx(tx)

	//revoke old refreshToken
	err = txAuthRepo.RevokeRefreshToken(ctx, storedToken.ID)
	if err != nil {
		return TokenResult{}, err
	}

	//store new refresh token
	_, err = txAuthRepo.CreateRefreshToken(
		ctx,
		storedToken.UserID,
		newHash,
		pgtype.Timestamptz{
			Time:  time.Now().Add(auth.RefreshTokenDuration),
			Valid: true,
		},
	)
	if err != nil {
		return TokenResult{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return TokenResult{}, err
	}

	return TokenResult{
		AccessToken:  accessToken,
		ExpiresIn:    int(auth.AccessTokenDuration.Seconds()),
		RefreshToken: newRefreshToken,
	}, nil

}

func (s *Service) Logout(ctx context.Context, refreshToken string) error {
	hash := auth.HashRefreshToken(refreshToken)
	return s.authRepo.RevokeRefreshTokenByHash(ctx, hash)
}

func (s *Service) LogoutAll(ctx context.Context, userID uuid.UUID) error {
	return s.authRepo.RevokeAllRefreshTokensByUserID(
		ctx,
		pgtype.UUID{
			Bytes: userID,
			Valid: true,
		},
	)
}
