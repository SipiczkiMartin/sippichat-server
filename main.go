package main

import (
	"fmt"
)

// var cacheMutex sync.RWMutex

func main() {
	fmt.Print("Hello world")
	// mux := http.NewServeMux()
	// mux.HandleFunc("POST /users", createUser)
	// mux.HandleFunc("GET /users/{username}", getUser)

	// fmt.Println("Server is listening to 8080")
	// http.ListenAndServe(":8080", mux)
}

// func getUser(w http.ResponseWriter, r *http.Request) {
// 	username := r.PathValue("username")

// 	cacheMutex.Lock()
// 	user, ok := userCache[username]
// 	cacheMutex.Unlock()

// 	if !ok {
// 		http.Error(w, "User not found", http.StatusNotFound)
// 		return
// 	}

// 	w.Header().Set("Content-Type", "application/json")

// 	j, err := json.Marshal(user)
// 	if err != nil {
// 		http.Error(w, err.Error(), http.StatusInternalServerError)
// 		return
// 	}

// 	w.WriteHeader(http.StatusOK)
// 	w.Write(j)
// }

// func createUser(w http.ResponseWriter, r *http.Request) {
// 	var user dtos.User
// 	err := json.NewDecoder(r.Body).Decode(&user)

// 	if err != nil {
// 		http.Error(w, err.Error(), http.StatusBadRequest)
// 		return
// 	}

// 	if user.Username == "" {
// 		http.Error(w, "Name is required", http.StatusBadRequest)
// 		return
// 	}

// 	cacheMutex.Lock()
// 	userCache[user.Username] = user
// 	cacheMutex.Unlock()

// 	w.WriteHeader(http.StatusNoContent)
// }
