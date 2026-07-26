package users

import (
	"context"
	"errors"

	"github.com/SipiczkiMartin/chat-app/internal/auth"
	db "github.com/SipiczkiMartin/chat-app/internal/database/sqlc"
	"github.com/jackc/pgx/v5"
)

type Service struct {
	repo *Repository
}

func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

type RegisterInput struct {
	Email    string
	Password string
}

type LoginInput struct {
	Email    string
	Password string
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

func (s *Service) Login(ctx context.Context, input LoginInput) (db.User, error) {
	user, err := s.repo.GetByEmail(ctx, input.Email)
	if err != nil {
		return db.User{}, ErrInvalidCredentials
	}

	if err := auth.CheckPassword(input.Password, user.PasswordHash); err != nil {
		return db.User{}, ErrInvalidCredentials
	}

	return user, nil
}
