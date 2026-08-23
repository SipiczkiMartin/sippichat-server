package websocket

import (
	"context"
	"log"
	"sync"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	"github.com/google/uuid"
)

const (
	heartbeatInterval = 30 * time.Second
	heartbeatTimeout  = 10 * time.Second
)

type WSClient struct {
	UserID uuid.UUID
	Conn   *websocket.Conn

	mu sync.Mutex

	heartbeatCancel context.CancelFunc
}

func (c *WSClient) Send(data any) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	log.Printf(
		"WS SEND: user=%s data=%+v",
		c.UserID,
		data,
	)

	err := wsjson.Write(
		context.Background(),
		c.Conn,
		data,
	)

	if err != nil {
		log.Printf(
			"WS SEND ERROR: user=%s error=%v",
			c.UserID,
			err,
		)

		return err
	}

	log.Printf(
		"WS SEND SUCCESS: user=%s",
		c.UserID,
	)

	return nil
}

func (c *WSClient) StartHeartbeat() {
	ctx, cancel := context.WithCancel(context.Background())

	c.mu.Lock()
	c.heartbeatCancel = cancel
	c.mu.Unlock()

	go func() {
		ticker := time.NewTicker(heartbeatInterval)
		defer ticker.Stop()

		for {
			select {
			case <-ticker.C:
				pingCtx, pingCancel := context.WithTimeout(
					ctx,
					heartbeatTimeout,
				)

				err := c.Conn.Ping(pingCtx)

				pingCancel()

				if err != nil {
					log.Printf(
						"WS HEARTBEAT FAILED: user=%s error=%v",
						c.UserID,
						err,
					)

					_ = c.closeWithReason(
						websocket.StatusGoingAway,
						"heartbeat timeout",
					)

					return
				}

				// log.Printf(
				// 	"WS HEARTBEAT OK: user=%s",
				// 	c.UserID,
				// )

			case <-ctx.Done():
				return
			}
		}
	}()
}

func (c *WSClient) StopHeartbeat() {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.heartbeatCancel != nil {
		c.heartbeatCancel()
		c.heartbeatCancel = nil
	}
}

func (c *WSClient) closeWithReason(
	code websocket.StatusCode,
	reason string,
) error {
	c.StopHeartbeat()
	return c.Conn.Close(code, reason)
}

func (c *WSClient) Close() error {
	return c.closeWithReason(
		websocket.StatusNormalClosure,
		"closed",
	)
}
