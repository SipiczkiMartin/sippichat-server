package readreceipts

import (
	"net/http"

	"github.com/SipiczkiMartin/chat-app/internal/auth"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

type Handler struct {
	service *Service
}

func NewHanler(service *Service) *Handler {
	return &Handler{
		service: service,
	}
}

func (h *Handler) MarkRead(
	w http.ResponseWriter,
	r *http.Request,
) {
	userID := auth.UserIDFromContext(r.Context())
	if userID == uuid.Nil {
		http.Error(
			w,
			"unauthorized",
			http.StatusUnauthorized,
		)
		return
	}

	messageID, err := uuid.Parse(
		chi.URLParam(r, "messageID"),
	)

	if err != nil {
		http.Error(
			w,
			"invalid message id",
			http.StatusBadRequest,
		)
		return
	}

	err = h.service.MarkRead(
		r.Context(),
		messageID,
		userID,
	)

	if err != nil {
		http.Error(
			w,
			err.Error(),
			http.StatusBadRequest,
		)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
