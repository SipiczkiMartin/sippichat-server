package users

import (
	"encoding/json"
	"net/http"

	"github.com/SipiczkiMartin/chat-app/internal/auth"
	"github.com/google/uuid"
)

type Handler struct {
	service   *Service
	jwtSecret string
}

func NewHandler(service *Service, jwtSecret string) *Handler {
	return &Handler{service: service, jwtSecret: jwtSecret}
}

type registerRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type registerResponse struct {
	ID    string `json:"id"`
	Email string `json:"email"`
}

func (h *Handler) Register(w http.ResponseWriter, r *http.Request) {
	var req registerRequest

	err := json.NewDecoder(r.Body).Decode(&req)
	if err != nil {
		http.Error(
			w,
			"invalid request body",
			http.StatusBadRequest,
		)
		return
	}

	user, err := h.service.Register(
		r.Context(),
		RegisterInput{
			Email:    req.Email,
			Password: req.Password,
		},
	)

	if err != nil {
		http.Error(
			w,
			err.Error(),
			http.StatusBadRequest,
		)
		return
	}

	response := registerResponse{
		ID:    user.ID.String(),
		Email: user.Email,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

//LOGIN

type loginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type loginResponse struct {
	AccessToken string `json:"access_token"`
	ExpiresIn   int    `json:"expires_in"`
}

func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
	var req loginRequest

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	user, err := h.service.Login(
		r.Context(),
		LoginInput{
			Email:    req.Email,
			Password: req.Password,
		},
	)

	if err != nil {
		switch err {
		case ErrInvalidCredentials:
			http.Error(w, err.Error(), http.StatusUnauthorized)
		default:
			http.Error(w, "internal server error", http.StatusInternalServerError)
		}
		return
	}

	userID := uuid.UUID(user.ID.Bytes)

	token, err := auth.GenerateAccessToken(userID, h.jwtSecret)

	if err != nil {
		http.Error(w, "could not generate token", http.StatusInternalServerError)
	}

	response := loginResponse{
		AccessToken: token,
		ExpiresIn:   900,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}
