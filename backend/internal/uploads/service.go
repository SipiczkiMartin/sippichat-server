package uploads

import (
	"context"
	"fmt"
	"io"
	"path/filepath"
	"strings"

	"github.com/SipiczkiMartin/chat-app/internal/storage"
	"github.com/google/uuid"
)

const MaxFileSize int64 = 25 * 1024 * 1024 // 25 MB

type Service struct {
	storage storage.Storage
}

func NewService(storage storage.Storage) *Service {
	return &Service{
		storage: storage,
	}
}

type UploadResult struct {
	StorageKey string
	URL        string
	Filename   string
	MimeType   string
	Size       int64
	Type       string
}

func (s *Service) Upload(
	ctx context.Context,
	filename string,
	contentType string,
	size int64,
	reader io.Reader,
) (UploadResult, error) {

	if size <= 0 {
		return UploadResult{}, fmt.Errorf(
			"invalid file size",
		)
	}

	if size > MaxFileSize {
		return UploadResult{}, fmt.Errorf(
			"file exceeds maximum size of 25 MB",
		)
	}

	contentType = strings.ToLower(
		strings.TrimSpace(contentType),
	)

	// GIFs are external attachments.
	if contentType == "image/gif" {
		return UploadResult{}, fmt.Errorf(
			"GIF uploads are not supported",
		)
	}

	attachmentType := "file"

	if strings.HasPrefix(contentType, "image/") {
		attachmentType = "image"
	}

	extension := filepath.Ext(filename)

	key := fmt.Sprintf(
		"attachments/%s%s",
		uuid.New().String(),
		extension,
	)

	err := s.storage.Upload(
		ctx,
		key,
		reader,
		size,
		contentType,
	)

	if err != nil {
		return UploadResult{}, err
	}

	return UploadResult{
		StorageKey: key,
		URL:        s.storage.URL(key),
		Filename:   filename,
		MimeType:   contentType,
		Size:       size,
		Type:       attachmentType,
	}, nil
}

func (s *Service) Get(
	ctx context.Context,
	key string,
) (storage.Object, error) {
	if strings.TrimSpace(key) == "" {
		return storage.Object{}, fmt.Errorf(
			"storage key is required",
		)
	}

	return s.storage.Get(
		ctx,
		key,
	)
}
