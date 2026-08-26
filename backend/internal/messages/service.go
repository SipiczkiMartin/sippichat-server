package messages

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"time"

	"github.com/SipiczkiMartin/chat-app/internal/conversations"
	"github.com/SipiczkiMartin/chat-app/internal/events"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

type Broadcaster interface {
	SendToUser(userID uuid.UUID, event any)
}

type Service struct {
	repo             *Repository
	conversationRepo *conversations.Repository
	hub              Broadcaster
}

func NewService(repo *Repository, conversationRepo *conversations.Repository, hub Broadcaster) *Service {
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
	Attachments    []AttachmentInput
}

type ListMessagesInput struct {
	ConversationID  uuid.UUID
	Limit           int32
	BeforeCreatedAt *time.Time
	BeforeID        *uuid.UUID
}

func (s *Service) SendMessage(
	ctx context.Context,
	input SendMessageInput,
) (Message, error) {

	log.Printf(
		"SEND MESSAGE: conversation=%s sender=%s content=%q",
		input.ConversationID,
		input.SenderID,
		input.Content,
	)

	if input.Content == "" && len(input.Attachments) == 0 {
		return Message{}, errors.New("message must contain text or an attachment")
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
		log.Printf("SEND MESSAGE: membership check error: %v", err)
		return Message{}, err
	}

	log.Printf("SEND MESSAGE: isMember=%v", isMember)

	if !isMember {
		log.Printf("SEND MESSAGE ERROR: user is not member")
		return Message{}, errors.New("user is not a conversation member!")
	}

	message, err := s.repo.CreateMessage(
		ctx,
		conversationID,
		senderID,
		input.Content,
	)

	if err != nil {
		log.Printf("SEND MESSAGE: CreateMessage ERROR: %v", err)
		return Message{}, err
	}

	for _, attachment := range input.Attachments {
		_, err := s.repo.CreateAttachment(
			ctx,
			pgtype.UUID{
				Bytes: message.ID.Bytes,
				Valid: true,
			},
			attachment,
		)

		if err != nil {
			log.Printf(
				"SEND MESSAGE: CreateAttachment ERROR: %v",
				err,
			)
			return Message{}, err
		}
	}

	messageDetails, err := s.repo.GetMessageByID(
		ctx,
		message.ID,
	)

	if err != nil {
		return Message{}, err
	}
	log.Printf("SEND MESSAGE: created message=%v", message.ID)

	attachments, err := s.repo.ListAttachmentsByMessageID(
		ctx,
		message.ID,
	)

	if err != nil {
		log.Printf(
			"SEND MESSAGE: ListAttachmentsByMessageID ERROR: %v",
			err,
		)
		return Message{}, err
	}

	newMessage := Message{
		ID:             uuid.UUID(messageDetails.ID.Bytes),
		ConversationID: uuid.UUID(messageDetails.ConversationID.Bytes),
		Content:        messageDetails.Content,
		CreatedAt:      messageDetails.CreatedAt.Time,
		Attachments:    attachments,

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
		log.Printf("SEND MESSAGE: GetMessageByID ERROR: %v", err)
		return Message{}, err
	}

	log.Printf("SEND MESSAGE: loaded message=%v", messageDetails.ID)

	eventAttachments := make(
		[]events.MessageCreatedAttachment,
		0,
		len(newMessage.Attachments),
	)

	for _, attachment := range newMessage.Attachments {
		var metadata map[string]any

		if len(attachment.Metadata) > 0 {
			if err := json.Unmarshal(attachment.Metadata, &metadata); err != nil {
				log.Printf(
					"SEND MESSAGE: invalid attachment metadata: %v",
					err,
				)
				return Message{}, err
			}
		}

		eventAttachments = append(
			eventAttachments,
			events.MessageCreatedAttachment{
				ID:          attachment.ID,
				Type:        attachment.Type,
				Filename:    attachment.Filename,
				MimeType:    attachment.MimeType,
				Size:        attachment.Size,
				StorageKey:  attachment.StorageKey,
				ExternalURL: attachment.ExternalURL,
				Metadata:    metadata,
				SortOrder:   attachment.SortOrder,
			},
		)
	}

	event := events.Event{
		Type: events.EventMessageCreated,
		Payload: events.MessageCreatedPayload{
			ID:             newMessage.ID,
			ConversationID: newMessage.ConversationID,
			Content:        newMessage.Content,
			CreatedAt:      newMessage.CreatedAt,
			Sender: events.MessageCreatedSender{
				ID:          newMessage.Sender.ID,
				Username:    newMessage.Sender.Username,
				DisplayName: newMessage.Sender.DisplayName,
				AvatarURL:   newMessage.Sender.AvatarURL,
			},
			Attachments: eventAttachments,
		},
	}

	log.Printf(
		"SEND MESSAGE: broadcasting message=%s to %d members",
		newMessage.ID,
		len(members),
	)

	for _, memberID := range members {

		if !memberID.Valid {
			log.Printf("SEND MESSAGE: skipping invalid member ID")
			continue
		}

		log.Printf(
			"SEND MESSAGE: SendToUser user=%s",
			memberID.Bytes,
		)

		s.hub.SendToUser(
			memberID.Bytes,
			event,
		)
	}

	return newMessage, nil
}

func (s *Service) ListMessages(
	ctx context.Context,
	input ListMessagesInput,
) ([]Message, error) {
	conversationID := pgtype.UUID{
		Bytes: input.ConversationID,
		Valid: true,
	}

	beforeCreatedAt := pgtype.Timestamptz{
		Valid: false,
	}

	beforeID := pgtype.UUID{
		Valid: false,
	}

	if input.BeforeCreatedAt != nil {
		beforeCreatedAt = pgtype.Timestamptz{
			Time:  *input.BeforeCreatedAt,
			Valid: true,
		}
	}

	if input.BeforeID != nil {
		beforeID = pgtype.UUID{
			Bytes: *input.BeforeID,
			Valid: true,
		}
	}

	return s.repo.ListMessages(
		ctx,
		conversationID,
		input.Limit,
		beforeCreatedAt,
		beforeID,
	)
}

func (s *Service) MarkMessageDelivered(
	ctx context.Context,
	messageId uuid.UUID,
	userId uuid.UUID,
) error {
	messageIDPG := pgtype.UUID{
		Bytes: messageId,
		Valid: true,
	}

	userIDPG := pgtype.UUID{
		Bytes: userId,
		Valid: true,
	}

	message, err := s.repo.GetMessageByID(ctx, messageIDPG)
	if err != nil {
		return err
	}

	isMember, err := s.repo.IsConversationMember(ctx, message.ConversationID, userIDPG)
	if err != nil {
		return err
	}

	if !isMember {
		return errors.New("user is not a conversation member!")
	}

	err = s.repo.MarkMessageDelivered(ctx, messageIDPG, userIDPG)
	if err != nil {
		return err
	}

	s.hub.SendToUser(
		uuid.UUID(message.SenderID.Bytes),
		events.Event{
			Type: events.EventMessageDelivered,
			Payload: events.MessageDeliveredPayload{
				MessageID: messageId,
			},
		},
	)
	return nil
}

func (s *Service) MarkMessageRead(
	ctx context.Context,
	messageID uuid.UUID,
	userID uuid.UUID,
) error {
	messageIDPG := pgtype.UUID{
		Bytes: messageID,
		Valid: true,
	}

	userIDPG := pgtype.UUID{
		Bytes: userID,
		Valid: true,
	}

	message, err := s.repo.GetMessageByID(ctx, messageIDPG)
	if err != nil {
		return err
	}

	isMember, err := s.repo.IsConversationMember(
		ctx,
		message.ConversationID,
		userIDPG,
	)
	if err != nil {
		return err
	}

	if !isMember {
		return errors.New("user is not a conversation member")
	}

	err = s.repo.MarkMessageRead(
		ctx,
		messageIDPG,
		userIDPG,
	)
	if err != nil {
		return err
	}

	s.hub.SendToUser(
		uuid.UUID(message.SenderID.Bytes),
		events.Event{
			Type: events.EventMessageRead,
			Payload: events.MessageReadPayload{
				MessageID: messageID,
			},
		},
	)

	return nil
}
