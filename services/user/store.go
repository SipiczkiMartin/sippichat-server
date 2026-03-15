package user

import (
	"database/sql"
	"fmt"
	"log"

	"github.com/jinzhu/gorm"
	"github.com/sipichat/web-service/dtos"
)

type Store struct {
	db *gorm.DB
}

func NewStore(db *gorm.DB) *Store {
	return &Store{db: db}
}

func (s *Store) GetUserByUsername(username string) (*dtos.User, error) {
	log.Default().Output(1, username)
	rows, err := s.db.DB().Query("Select * from users where username = ?", username)
	if err != nil {
		return nil, err
	}

	u := new(dtos.User)
	for rows.Next() {
		u, err = scanRowToUser(rows)
		fmt.Printf("%s", "r: "+u.Username)
		if err != nil {
			return nil, err
		}
	}

	if u.ID == 0 {
		return nil, fmt.Errorf("user not found")
	}

	return u, nil
}

func scanRowToUser(rows *sql.Rows) (*dtos.User, error) {
	user := new(dtos.User)

	err := rows.Scan(
		&user.ID,
		&user.Username,
		&user.Password,
		&user.CreatedAt,
	)

	if err != nil {
		return nil, err
	}

	return user, nil
}

func (s *Store) GetUserByID(id int) (*dtos.User, error) {
	rows, err := s.db.DB().Query("Select * from users where id = ?", id)
	if err != nil {
		return nil, err
	}

	u := new(dtos.User)
	for rows.Next() {
		u, err = scanRowToUser(rows)
		if err != nil {
			return nil, err
		}
	}

	if u.ID == 0 {
		return nil, fmt.Errorf("user not found")
	}

	return u, nil
}

func (s *Store) CreateUser(user dtos.User) error {
	_, err := s.db.DB().Exec("insert into users (username,password) values (?,?)", user.Username, user.Password)
	if err != nil {
		return err
	}

	return nil
}
