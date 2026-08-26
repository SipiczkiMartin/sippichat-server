package storage

import (
	"context"
	"io"
)

type Object struct {
	Reader      io.ReadCloser
	Size        int64
	ContentType string
}

type Storage interface {
	Upload(
		ctx context.Context,
		key string,
		reader io.Reader,
		size int64,
		contentType string,
	) error

	Get(
		ctx context.Context,
		key string,
	) (Object, error)

	Delete(
		ctx context.Context,
		key string,
	) error

	URL(key string) string
}
