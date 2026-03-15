package dtos

import (
	"fmt"
)

type Message struct {
	Sender   string `json:"sender"`
	Receiver string `json:"receiver"`
	Body     string `json:"body"`
}

func (m Message) String() string {
	return fmt.Sprintf("Message:{Sender: %s, Receiver: %s, Body: %s}", m.Sender, m.Receiver, m.Body)
}
