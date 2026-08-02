package websocket

import (
	"log"
	"sync"

	"github.com/google/uuid"
)

type Hub struct {
	mu sync.RWMutex

	clients map[uuid.UUID]map[*WSClient]struct{}
}

func NewHub() *Hub {
	return &Hub{
		clients: make(map[uuid.UUID]map[*WSClient]struct{}),
	}
}

func (h *Hub) Register(client *WSClient) {
	h.mu.Lock()
	defer h.mu.Unlock()

	log.Println("WS Connected", client.UserID)

	if _, ok := h.clients[client.UserID]; !ok {
		h.clients[client.UserID] = make(map[*WSClient]struct{})
	}

	h.clients[client.UserID][client] = struct{}{}
}

func (h *Hub) Unregister(client *WSClient) {
	h.mu.Lock()
	defer h.mu.Unlock()

	connections, ok := h.clients[client.UserID]
	if !ok {
		return
	}

	delete(connections, client)
	if len(connections) == 0 {
		delete(h.clients, client.UserID)
	}
}

func (h *Hub) Connections(userID uuid.UUID) []*WSClient {
	h.mu.Lock()
	defer h.mu.Unlock()

	connections := h.clients[userID]
	result := make([]*WSClient, 0, len(connections))

	for c := range connections {
		result = append(result, c)
	}

	return result
}
