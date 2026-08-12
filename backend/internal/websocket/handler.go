package websocket

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/SipiczkiMartin/chat-app/internal/auth"
	"github.com/SipiczkiMartin/chat-app/internal/events"
	"github.com/SipiczkiMartin/chat-app/internal/messages"
	"github.com/SipiczkiMartin/chat-app/internal/typing"
	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	"github.com/google/uuid"
)

type Handler struct {
	hub      *Hub
	typing   *typing.Service
	messages *messages.Service
}

func NewHandler(
	hub *Hub,
	typing *typing.Service,
	messages *messages.Service,
) *Handler {
	return &Handler{
		hub:      hub,
		typing:   typing,
		messages: messages,
	}
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserIDFromContext(r.Context())
	ctx := r.Context()

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
	client.StartHeartbeat()

	defer func() {
		h.hub.Unregister(client)
		client.Close()
	}()

	for {
		var event events.Event

		err := wsjson.Read(ctx, conn, &event)
		if err != nil {
			break
		}

		switch event.Type {
		case events.EventMessageSend:
			payloadBytes, err := json.Marshal(event.Payload)
			if err != nil {
				continue
			}

			var payload events.SendMessagePayload

			err = json.Unmarshal(payloadBytes, &payload)
			if err != nil {
				continue
			}

			_, err = h.messages.SendMessage(
				ctx,
				messages.SendMessageInput{
					ConversationID: payload.ConversationID,
					SenderID:       userID,
					Content:        payload.Content,
				},
			)

			if err != nil {
				continue
			}

		case events.EventTypingStarted:
			payloadBytes, err := json.Marshal(event.Payload)
			if err != nil {
				continue
			}

			var payload events.TypingPayload

			err = json.Unmarshal(payloadBytes, &payload)
			if err != nil {
				continue
			}

			log.Printf(
				"WS TYPING STARTED: user=%s conversation=%s",
				userID,
				payload.ConversationID,
			)

			err = h.typing.TypingStarted(
				ctx,
				userID,
				payload.ConversationID,
			)

			if err != nil {
				continue
			}

		case events.EventTypingStopped:
			payloadBytes, err := json.Marshal(event.Payload)
			if err != nil {
				continue
			}

			var payload events.TypingPayload

			err = json.Unmarshal(payloadBytes, &payload)
			if err != nil {
				continue
			}

			err = h.typing.TypingStopped(
				ctx,
				userID,
				payload.ConversationID,
			)

			if err != nil {
				continue
			}

		case events.EventMessageDelivered:
			payloadBytes, err := json.Marshal(event.Payload)
			if err != nil {
				continue
			}

			var payload events.MessageDeliveredPayload

			err = json.Unmarshal(payloadBytes, &payload)
			if err != nil {
				continue
			}

			err = h.messages.MarkMessageDelivered(ctx, payload.MessageID, userID)
			if err != nil {
				log.Printf(
					"WS MESSAGE DELIVERED ERROR: user=%s message=%s err=%v",
					userID, payload.MessageID, err,
				)
				continue
			}

		case events.EventMessageRead:
			payloadBytes, err := json.Marshal(event.Payload)
			if err != nil {
				continue
			}

			var payload events.MessageReadPayload

			err = json.Unmarshal(payloadBytes, &payload)
			if err != nil {
				continue
			}

			err = h.messages.MarkMessageRead(
				ctx,
				payload.MessageID,
				userID,
			)

			if err != nil {
				log.Printf(
					"WS MESSAGE READ ERROR: user=%s message=%s err=%v",
					userID,
					payload.MessageID,
					err,
				)
				continue
			}
		}

	}
}
