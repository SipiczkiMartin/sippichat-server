package websocket

import (
	"net/http"

	"github.com/SipiczkiMartin/chat-app/internal/auth"
	"github.com/coder/websocket"
	"github.com/google/uuid"
)

type Handler struct {
	hub *Hub
}

func NewHandler(hub *Hub) *Handler {
	return &Handler{
		hub: hub,
	}
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserIDFromContext(r.Context())

	if userID == uuid.Nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	conn, err := websocket.Accept(w, r, nil)
	if err != nil {
		return
	}

	client := &WSClient{
		UserID: userID,
		Conn:   conn,
	}

	h.hub.Register(client)

	defer func() {
		h.hub.Unregister(client)
		client.Close()
	}()

	for {
		_, _, err := conn.Read(r.Context())
		if err != nil {
			break
		}
	}
}
