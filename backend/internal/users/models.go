package users

import "github.com/google/uuid"

type UserSearchResult struct {
	ID          uuid.UUID
	Username    string
	DisplayName string
	AvatarUrl   *string
}
