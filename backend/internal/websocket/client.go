package websocket

import (
	"context"
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

	return wsjson.Write(
		context.Background(),
		c.Conn,
		data,
	)
}

func (c *WSClient) Close() error {
	return c.Conn.Close(
		websocket.StatusNormalClosure,
		"closed",
	)
}
