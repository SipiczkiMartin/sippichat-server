package messages

import (
	"context"
	"errors"

	"github.com/SipiczkiMartin/chat-app/internal/conversations"
	"github.com/SipiczkiMartin/chat-app/internal/events"
	"github.com/SipiczkiMartin/chat-app/internal/websocket"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

type Service struct {
	repo             *Repository
	conversationRepo *conversations.Repository
	hub              *websocket.Hub
}

func NewService(repo *Repository, conversationRepo *conversations.Repository, hub *websocket.Hub) *Service {
	return &Service{
		repo:             repo,
		conversationRepo: conversationRepo,
		hub:              hub,
	}
}

type SendMessageInput struct {
	ConversationID uuid.UUID
	SenderID       uuid.UUID
	Content        string
}

func (s *Service) SendMessage(
	ctx context.Context,
	input SendMessageInput,
) (Message, error) {
	if input.Content == "" {
		return Message{}, errors.New("no message content!")
	}

	conversationID := pgtype.UUID{
		Bytes: input.ConversationID,
		Valid: true,
	}

	senderID := pgtype.UUID{
		Bytes: input.SenderID,
		Valid: true,
	}

	isMember, err := s.repo.IsConversationMember(
		ctx,
		conversationID,
		senderID,
	)

	if err != nil {
		return Message{}, err
	}

	if !isMember {
		return Message{}, errors.New("user is not a conversation member!")
	}

	message, err := s.repo.CreateMessage(
		ctx,
		conversationID,
		senderID,
		input.Content,
	)

	if err != nil {
		return Message{}, err
	}

	messageDetails, err := s.repo.GetMessageByID(
		ctx,
		message.ID,
	)

	if err != nil {
		return Message{}, err
	}

	newMessage := Message{
		ID:             uuid.UUID(messageDetails.ID.Bytes),
		ConversationID: uuid.UUID(messageDetails.ConversationID.Bytes),
		Content:        messageDetails.Content,
		CreatedAt:      messageDetails.CreatedAt.Time,

		Sender: Sender{
			ID:          uuid.UUID(messageDetails.SenderID.Bytes),
			Username:    messageDetails.Username,
			DisplayName: messageDetails.DisplayName,
		},
	}

	if messageDetails.AvatarUrl.Valid {
		avatar := messageDetails.AvatarUrl.String
		newMessage.Sender.AvatarURL = &avatar
	}

	members, err := s.conversationRepo.ListConversationMembers(
		ctx,
		conversationID,
	)

	if err != nil {
		return Message{}, err
	}

	event := events.Event{
		Type:    events.EventMessageCreated,
		Payload: newMessage,
	}

	for _, memberID := range members {

		if !memberID.Valid {
			continue
		}

		s.hub.SendToUser(
			memberID.Bytes,
			event,
		)
	}

	return newMessage, nil
}

func (s *Service) ListMessages(
	ctx context.Context,
	conversationID uuid.UUID,
	limit int32,
) ([]Message, error) {
	id := pgtype.UUID{
		Bytes: conversationID,
		Valid: true,
	}

	return s.repo.ListMessages(
		ctx,
		id,
		limit,
	)
}
