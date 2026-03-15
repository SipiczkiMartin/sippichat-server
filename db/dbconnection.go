package db

import (
	"log"

	"github.com/go-sql-driver/mysql"
	"github.com/jinzhu/gorm"
	_ "github.com/jinzhu/gorm/dialects/mysql"
)

func NewMySQLConnection(cfg mysql.Config) (*gorm.DB, error) {

	dsn := cfg.FormatDSN()
	conn, err := gorm.Open("mysql", dsn)
	if err != nil {
		log.Fatal(err)
	}

	return conn, nil
}
