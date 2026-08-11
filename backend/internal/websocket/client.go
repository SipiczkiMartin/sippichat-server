package websocket

import (
	"context"
	"log"
	"sync"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	"github.com/google/uuid"
)

type WSClient struct {
	UserID uuid.UUID
	Conn   *websocket.Conn

	mu sync.Mutex
}

func (c *WSClient) Send(data any) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	log.Printf("WS SEND: user=%s data=%+v", c.UserID, data)

	err := wsjson.Write(
		context.Background(),
		c.Conn,
		data,
	)

	if err != nil {
		log.Printf("WS SEND ERROR: user=%s error=%v", c.UserID, err)
		return err
	}

	log.Printf("WS SEND SUCCESS: user=%s", c.UserID)

	return nil
}

func (c *WSClient) Close() error {
	return c.Conn.Close(
		websocket.StatusNormalClosure,
		"closed",
	)
}
