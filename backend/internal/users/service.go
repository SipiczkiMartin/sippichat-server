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

func (s *Service) Register(ctx context.Context, input RegisterInput) (TokenResult, error) {
	//exists check
	_, err := s.repo.GetByEmail(ctx, input.Email)
	switch {
	case err == nil:
		return TokenResult{}, errors.New(
			"user already exists",
		)

	case !errors.Is(err, pgx.ErrNoRows):
		return TokenResult{}, err
	}

	passwordHash, err := auth.HashPassword(input.Password)

	if err != nil {
		return TokenResult{}, err
	}

	tx, err := s.repo.BeginTx(ctx)
	if err != nil {
		return TokenResult{}, err
	}

	defer tx.Rollback(ctx)

	txUserRepo := s.repo.WithTx(tx)
	txAuthRepo := s.authRepo.WithTx(tx)

	user, err := txUserRepo.Create(ctx, input.Email, passwordHash)

	if err != nil {
		return TokenResult{}, err
	}

	_, err = txUserRepo.CreateProfile(
		ctx,
		user.ID,
		input.Email,
		input.Email,
	)

	if err != nil {
		return TokenResult{}, err
	}

	tokens, err := s.issueTokens(ctx, user, txAuthRepo)
	if err != nil {
		return TokenResult{}, nil
	}

	if err := tx.Commit(ctx); err != nil {
		return TokenResult{}, err
	}

	return tokens, nil
}

func (s *Service) Login(ctx context.Context, input LoginInput) (LoginResult, error) {
	user, err := s.repo.GetByEmail(ctx, input.Email)
	if err != nil {
		return LoginResult{}, ErrInvalidCredentials
	}

	if err := auth.CheckPassword(input.Password, user.PasswordHash); err != nil {
		return LoginResult{}, ErrInvalidCredentials
	}

	tokens, err := s.issueTokens(ctx, user, s.authRepo)
	if err != nil {
		return LoginResult{}, err
	}

	return LoginResult{
		TokenResult: tokens,
	}, nil

}

func (s *Service) issueTokens(ctx context.Context, user db.User, authRepo *auth.Repository) (TokenResult, error) {
	accessToken, err := auth.GenerateAccessToken(user.ID.Bytes, s.jwtSecret)
	if err != nil {
		return TokenResult{}, err
	}

	refreshToken, err := auth.GenerateRefreshToken()
	if err != nil {
		return TokenResult{}, err
	}

	refreshHash := auth.HashRefreshToken(refreshToken)

	_, err = authRepo.CreateRefreshToken(ctx, user.ID, refreshHash,
		pgtype.Timestamptz{
			Time:  time.Now().Add(auth.RefreshTokenDuration),
			Valid: true,
		})
	if err != nil {
		return TokenResult{}, err
	}

	return TokenResult{
		AccessToken:  accessToken,
		ExpiresIn:    int(auth.AccessTokenDuration.Seconds()),
		RefreshToken: refreshToken,
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

func (s *Service) GetCurrentUser(ctx context.Context, id uuid.UUID) (db.GetCurrentUserRow, error) {
	return s.repo.GetCurrentUser(ctx, id)
}

type UpdateProfileInput struct {
	DisplayName string
	Bio         string
}

func (s *Service) UpdateProfile(ctx context.Context, userID uuid.UUID, input UpdateProfileInput) (db.Profile, error) {

	if len(input.DisplayName) < 2 {
		return db.Profile{}, errors.New("display name too short")
	}

	if len(input.DisplayName) > 50 {
		return db.Profile{}, errors.New("display name too long")
	}

	if len(input.Bio) > 160 {
		return db.Profile{}, errors.New("bio too long")
	}

	return s.repo.UpdateProfile(ctx, userID, input.DisplayName, input.Bio)
}
