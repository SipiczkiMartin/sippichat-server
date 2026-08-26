package messages

import "github.com/google/uuid"

type Attachment struct {
	ID          uuid.UUID
	MessageID   uuid.UUID
	Type        string
	Filename    *string
	MimeType    *string
	Size        *int64
	StorageKey  *string
	ExternalURL string
	Metadata    []byte
	SortOrder   int
}

type AttachmentInput struct {
	Type        string
	ExternalURL *string
	Filename    *string
	MimeType    *string
	Size        *int64
	Metadata    []byte
	SortOrder   int
	StorageKey  *string
}
