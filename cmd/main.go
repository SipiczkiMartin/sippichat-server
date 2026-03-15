package main

import (
	"fmt"
	"log"

	"github.com/go-sql-driver/mysql"
	"github.com/jinzhu/gorm"
	"github.com/sipichat/web-service/cmd/api"
	"github.com/sipichat/web-service/config"
	"github.com/sipichat/web-service/db"
)

func main() {
	conn, err := db.NewMySQLConnection(mysql.Config{
		User:                 config.Envs.DBUser,
		Passwd:               config.Envs.DBPassword,
		Addr:                 config.Envs.DBAddress,
		DBName:               config.Envs.DBName,
		Net:                  "tcp",
		AllowNativePasswords: true,
		ParseTime:            true,
	})

	if err != nil {
		log.Fatal(err)
	}

	initStorage(conn)

	server := api.NewAPIServer(":8080", conn)
	if err := server.Run(); err != nil {
		log.Fatal(err)
	}
}

func initStorage(db *gorm.DB) {
	err := db.DB().Ping()
	if err != nil {
		log.Fatal(err)
	}

	fmt.Println("DB: Connected successfully")
}

// var cacheMutex sync.RWMutex

// shit method for nothing...
// func articlesHandler(w http.ResponseWriter, r *http.Request) {
// 	fmt.Fprintf(w, "Welcome to the protected articles route!")
// }

// // Another Protected Route
// func deleteArticleHandler(w http.ResponseWriter, r *http.Request) {
// 	fmt.Fprintf(w, "Article deleted successfully!")
// }

// // here need to validate user from the DB and get all permissions or rules
// func validateUser(username, password string) (int64, []string, error) {
// 	if username == "Martin" && password == "pass" {
// 		return 1, []string{"admin", "user"}, nil
// 	}
// 	return 0, nil, fmt.Errorf("Invalid credentials")
// }

// func main() {
// 	mux := http.NewServeMux()
// 	mux.HandleFunc("/login", login)
// 	// mux.HandleFunc("POST /users", createUser)
// 	// mux.HandleFunc("GET /users/{username}", getUser)

// 	//this is how to authenticate using the jwt token itself coming from user after login... btw no jwt no action...
// 	mux.Handle("/articles", JWTAuthMiddleware(PermissionMiddleware("admin", http.HandlerFunc(articlesHandler))))
// 	mux.Handle("/articles/delete", JWTAuthMiddleware(PermissionMiddleware("article.delete", http.HandlerFunc(deleteArticleHandler))))

// 	fmt.Println("Server is listening to 8080")
// 	http.ListenAndServe(":8080", mux)
// }

// func login(w http.ResponseWriter, r *http.Request) {
// 	var loginRequest struct {
// 		Username string `json:"username"`
// 		Password string `json:"password"`
// 	}

// 	decoder := json.NewDecoder(r.Body)
// 	err := decoder.Decode(&loginRequest)
// 	if err != nil {
// 		http.Error(w, "Invalid request", http.StatusBadRequest)
// 	}

// 	//maybe pass the struct as pointer...
// 	userId, permissions, err := validateUser(loginRequest.Username, loginRequest.Password)
// 	if err != nil {
// 		http.Error(w, "Invalid credentials", http.StatusUnauthorized)
// 	}

// 	log.Printf("%d", userId)

// 	token, err := auth.GenerateJWT(userId, permissions)
// 	if err != nil {
// 		http.Error(w, "Error generating token", http.StatusInternalServerError)
// 	}

// 	w.Header().Set("Content-Type", "application/json")
// 	json.NewEncoder(w).Encode(map[string]string{"token": token})
// }

// func JWTAuthMiddleware(next http.Handler) http.Handler {
// 	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
// 		// Extract token from the Authorization header
// 		authHeader := r.Header.Get("Authorization")
// 		if authHeader == "" {
// 			http.Error(w, "Authorization token required", http.StatusUnauthorized)
// 			return
// 		}

// 		// Extract token from "Bearer <token>"
// 		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
// 		if tokenString == authHeader {
// 			http.Error(w, "Authorization format must be Bearer <token>", http.StatusUnauthorized)
// 			return
// 		}

// 		// Parse JWT token
// 		claims, err := auth.ParseJWT(tokenString)
// 		log.Printf("claims: %v", claims)
// 		if err != nil {
// 			http.Error(w, "Invalid token", http.StatusUnauthorized)
// 			return
// 		}

// 		// Add user info to the request context
// 		r = r.WithContext(context.WithValue(r.Context(), "user_id", claims.UserId))
// 		r = r.WithContext(context.WithValue(r.Context(), "permissions", claims.Permissions))

// 		next.ServeHTTP(w, r)
// 	})
// }

// func PermissionMiddleware(requiredPermission string, next http.Handler) http.Handler {
// 	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
// 		permissions, ok := r.Context().Value("permissions").([]string)
// 		if !ok {
// 			http.Error(w, "Error extracting permissions", http.StatusUnauthorized)
// 			return
// 		}

// 		// Check if the required permission is present
// 		hasPermission := false
// 		for _, perm := range permissions {
// 			if perm == requiredPermission {
// 				hasPermission = true
// 				break
// 			}
// 		}

// 		if !hasPermission {
// 			http.Error(w, "Forbidden", http.StatusForbidden)
// 			returnAPIServer
// 		}

// 		next.ServeHTTP(w, r)
// 	})
// }

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
