package messages

import (
	"context"

	db "github.com/SipiczkiMartin/chat-app/internal/database/sqlc"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	pool    *pgxpool.Pool
	queries *db.Queries
}

func NewRepository(pool *pgxpool.Pool) *Repository {
	return &Repository{
		pool:    pool,
		queries: db.New(pool),
	}
}

func (r *Repository) CreateMessage(
	ctx context.Context,
	conversationID pgtype.UUID,
	senderID pgtype.UUID,
	content string,
) (db.Message, error) {
	return r.queries.CreateMessage(
		ctx,
		db.CreateMessageParams{
			ConversationID: conversationID,
			SenderID:       senderID,
			Content:        content,
		},
	)
}

func (r *Repository) IsConversationMember(
	ctx context.Context,
	conversationID pgtype.UUID,
	userID pgtype.UUID,
) (bool, error) {
	return r.queries.IsConversationMember(
		ctx,
		db.IsConversationMemberParams{
			ConversationID: conversationID,
			UserID:         userID,
		},
	)
}

func (r *Repository) ListMessages(
	ctx context.Context,
	conversationID pgtype.UUID,
	limit int32,
	beforeCreatedAt pgtype.Timestamptz,
	beforeID pgtype.UUID,
) ([]Message, error) {
	rows, err := r.queries.ListMessages(
		ctx,
		db.ListMessagesParams{
			ConversationID:  conversationID,
			Limit:           limit,
			BeforeCreatedAt: beforeCreatedAt,
			BeforeID:        beforeID,
		},
	)

	if err != nil {
		return nil, err
	}

	messages := make([]Message, 0, len(rows))

	for _, row := range rows {
		message := Message{
			ID:             uuid.UUID(row.ID.Bytes),
			ConversationID: uuid.UUID(row.ConversationID.Bytes),
			Content:        row.Content,
			CreatedAt:      row.CreatedAt.Time,

			Sender: Sender{
				ID:          uuid.UUID(row.SenderID.Bytes),
				Username:    row.Username,
				DisplayName: row.DisplayName,
			},
		}

		if row.AvatarUrl.Valid {
			avatar := row.AvatarUrl.String
			message.Sender.AvatarURL = &avatar
		}

		messageID := pgtype.UUID{
			Bytes: message.ID,
			Valid: true,
		}

		attachments, err := r.ListAttachmentsByMessageID(
			ctx,
			messageID,
		)

		if err != nil {
			return nil, err
		}

		message.Attachments = attachments

		messages = append(messages, message)
	}

	return messages, nil
}

func (r *Repository) GetMessageByID(
	ctx context.Context,
	messageID pgtype.UUID,
) (db.GetMessageByIDRow, error) {
	return r.queries.GetMessageByID(ctx, messageID)
}

func (r *Repository) MarkMessageDelivered(ctx context.Context, messageId pgtype.UUID, userId pgtype.UUID) error {
	return r.queries.MarkMessageDelivered(ctx, db.MarkMessageDeliveredParams{
		MessageID: messageId,
		UserID:    userId,
	})
}

func (r *Repository) MarkMessageRead(ctx context.Context, messageId pgtype.UUID, userId pgtype.UUID) error {
	return r.queries.MarkMessageRead(ctx, db.MarkMessageReadParams{
		MessageID: messageId,
		UserID:    userId,
	})
}

func (r *Repository) CreateAttachment(
	ctx context.Context,
	messageID pgtype.UUID,
	attachment AttachmentInput,
) (db.Attachment, error) {
	params := db.CreateAttachmentParams{
		MessageID: messageID,
		Type:      attachment.Type,

		Filename: pgtype.Text{
			Valid: attachment.Filename != nil,
		},

		MimeType: pgtype.Text{
			Valid: attachment.MimeType != nil,
		},

		Size: pgtype.Int8{
			Valid: attachment.Size != nil,
		},

		StorageKey: pgtype.Text{
			Valid: attachment.StorageKey != nil,
		},

		ExternalUrl: pgtype.Text{
			Valid: attachment.ExternalURL != nil,
		},

		Metadata:  attachment.Metadata,
		SortOrder: int32(attachment.SortOrder),
	}

	if attachment.Filename != nil {
		params.Filename.String = *attachment.Filename
	}

	if attachment.MimeType != nil {
		params.MimeType.String = *attachment.MimeType
	}

	if attachment.Size != nil {
		params.Size.Int64 = *attachment.Size
	}

	if attachment.StorageKey != nil {
		params.StorageKey.String = *attachment.StorageKey
	}

	if attachment.ExternalURL != nil {
		params.ExternalUrl.String = *attachment.ExternalURL
	}

	return r.queries.CreateAttachment(ctx, params)
}

func (r *Repository) ListAttachmentsByMessageID(
	ctx context.Context,
	messageID pgtype.UUID,
) ([]Attachment, error) {
	rows, err := r.queries.ListAttachmentsByMessageID(
		ctx,
		messageID,
	)

	if err != nil {
		return nil, err
	}

	attachments := make([]Attachment, 0, len(rows))

	for _, row := range rows {
		attachment := Attachment{
			ID:        uuid.UUID(row.ID.Bytes),
			MessageID: uuid.UUID(row.MessageID.Bytes),
			Type:      row.Type,
			Metadata:  row.Metadata,
			SortOrder: int(row.SortOrder),
		}

		if row.Filename.Valid {
			value := row.Filename.String
			attachment.Filename = &value
		}

		if row.MimeType.Valid {
			value := row.MimeType.String
			attachment.MimeType = &value
		}

		if row.Size.Valid {
			value := row.Size.Int64
			attachment.Size = &value
		}

		if row.StorageKey.Valid {
			value := row.StorageKey.String
			attachment.StorageKey = &value
		}

		if row.ExternalUrl.Valid {
			attachment.ExternalURL = row.ExternalUrl.String
		}

		attachments = append(attachments, attachment)
	}

	return attachments, nil
}
