package websocket

import (
	"encoding/json"
	"fmt"
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
	secret   string
}

func NewHandler(
	hub *Hub,
	typing *typing.Service,
	messages *messages.Service,
	secret string,
) *Handler {
	return &Handler{
		hub:      hub,
		typing:   typing,
		messages: messages,
		secret:   secret,
	}
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	userID, err := userIDFromWebSocket(r, h.secret)

	if err != nil || userID == uuid.Nil {
		http.Error(
			w,
			"unauthorized",
			http.StatusUnauthorized,
		)
		return
	}

	conn, err := websocket.Accept(w, r, &websocket.AcceptOptions{
		OriginPatterns: []string{
			"localhost:*",
		},
	})
	if err != nil {
		log.Printf("WS ACCEPT ERROR: %v", err)
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
				log.Printf("WS MESSAGE SEND: payload marshall error: %v", err)
				continue
			}

			var payload events.SendMessagePayload

			err = json.Unmarshal(payloadBytes, &payload)
			if err != nil {
				log.Printf("WS MESSAGE SEND: payload unmarshall error: %v", err)
				continue
			}

			attachments := make([]messages.AttachmentInput, 0, len(payload.Attachments))

			for index, attachment := range payload.Attachments {
				var metadata []byte

				if attachment.Metadata != nil {
					metadata, err = json.Marshal(attachment.Metadata)
					if err != nil {
						log.Printf(
							"WS MESSAGE SEND: attachment metadata marshal error: %v",
							err,
						)
						continue
					}
				}

				attachments = append(
					attachments,
					messages.AttachmentInput{
						Type:        attachment.Type,
						ExternalURL: attachment.ExternalURL,
						Filename:    attachment.Filename,
						MimeType:    attachment.MimeType,
						Size:        attachment.Size,
						StorageKey:  attachment.StorageKey,
						Metadata:    metadata,
						SortOrder:   index,
					},
				)
			}

			_, err = h.messages.SendMessage(
				ctx,
				messages.SendMessageInput{
					ConversationID: payload.ConversationID,
					SenderID:       userID,
					Content:        payload.Content,
					Attachments:    attachments,
				},
			)

			if err != nil {
				log.Printf(
					"WS MESSAGE SEND ERROR: user=%s conversation=%s error=%v",
					userID,
					payload.ConversationID,
					err,
				)
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

func userIDFromWebSocket(
	r *http.Request,
	secret string,
) (uuid.UUID, error) {
	token := r.URL.Query().Get("token")

	if token == "" {
		return uuid.Nil, fmt.Errorf(
			"missing websocket token",
		)
	}

	return auth.ParseAccessToken(
		token,
		secret,
	)
}
