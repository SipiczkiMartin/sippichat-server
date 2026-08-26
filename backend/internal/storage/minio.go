package storage

import (
	"context"
	"fmt"
	"io"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

type MinIOStorage struct {
	client    *minio.Client
	bucket    string
	publicURL string
}

func NewMinIOStorage(
	endpoint string,
	accessKey string,
	secretKey string,
	bucket string,
	useSSL bool,
	publicURL string,
) (*MinIOStorage, error) {
	client, err := minio.New(
		endpoint,
		&minio.Options{
			Creds: credentials.NewStaticV4(
				accessKey,
				secretKey,
				"",
			),
			Secure: useSSL,
		},
	)

	if err != nil {
		return nil, fmt.Errorf(
			"create minio client: %w",
			err,
		)
	}

	return &MinIOStorage{
		client:    client,
		bucket:    bucket,
		publicURL: publicURL,
	}, nil
}

func (s *MinIOStorage) EnsureBucket(
	ctx context.Context,
) error {
	exists, err := s.client.BucketExists(
		ctx,
		s.bucket,
	)

	if err != nil {
		return fmt.Errorf(
			"check storage bucket: %w",
			err,
		)
	}

	if exists {
		return nil
	}

	err = s.client.MakeBucket(
		ctx,
		s.bucket,
		minio.MakeBucketOptions{},
	)

	if err != nil {
		return fmt.Errorf(
			"create storage bucket: %w",
			err,
		)
	}

	return nil
}

func (s *MinIOStorage) Upload(
	ctx context.Context,
	key string,
	reader io.Reader,
	size int64,
	contentType string,
) error {
	_, err := s.client.PutObject(
		ctx,
		s.bucket,
		key,
		reader,
		size,
		minio.PutObjectOptions{
			ContentType: contentType,
		},
	)

	if err != nil {
		return fmt.Errorf(
			"upload object: %w",
			err,
		)
	}

	return nil
}

func (s *MinIOStorage) Get(
	ctx context.Context,
	key string,
) (Object, error) {
	info, err := s.client.StatObject(
		ctx,
		s.bucket,
		key,
		minio.StatObjectOptions{},
	)

	if err != nil {
		return Object{}, fmt.Errorf(
			"stat object: %w",
			err,
		)
	}

	reader, err := s.client.GetObject(
		ctx,
		s.bucket,
		key,
		minio.GetObjectOptions{},
	)

	if err != nil {
		return Object{}, fmt.Errorf(
			"get object: %w",
			err,
		)
	}

	contentType := info.ContentType

	if contentType == "" {
		contentType = "application/octet-stream"
	}

	return Object{
		Reader:      reader,
		Size:        info.Size,
		ContentType: contentType,
	}, nil
}

func (s *MinIOStorage) Delete(
	ctx context.Context,
	key string,
) error {
	err := s.client.RemoveObject(
		ctx,
		s.bucket,
		key,
		minio.RemoveObjectOptions{},
	)

	if err != nil {
		return fmt.Errorf(
			"delete object: %w",
			err,
		)
	}

	return nil
}

func (s *MinIOStorage) URL(key string) string {
	return fmt.Sprintf(
		"%s/%s/%s",
		s.publicURL,
		s.bucket,
		key,
	)
}
