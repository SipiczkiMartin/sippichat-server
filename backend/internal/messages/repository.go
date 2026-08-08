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
) ([]Message, error) {
	rows, err := r.queries.ListMessages(
		ctx,
		db.ListMessagesParams{
			ConversationID: conversationID,
			Limit:          limit,
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
