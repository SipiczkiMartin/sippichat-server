package dtos

import (
	"time"
)

type UserStore interface {
	GetUserByUsername(username string) (*User, error)
	GetUserByID(id int) (*User, error)
	CreateUser(User) error
}

type RegisterUserDTO struct {
	Username string `json:"username" validate:"required"`
	Password string `json:"password" validate:"required,min=3,max=30"`
}

type LoginUsertDTO struct {
	Username string `json:"username" validate:"required"`
	Password string `json:"password" validate:"required"`
}

type User struct {
	ID        int       `json:"id"`
	Username  string    `json:"username"`
	Password  string    `json:"password"`
	CreatedAt time.Time `json:"createdAt"`
}
