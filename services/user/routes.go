package user

import (
	"fmt"
	"log"
	"net/http"

	"github.com/go-playground/validator/v10"
	"github.com/gorilla/mux"
	"github.com/sipichat/web-service/config"
	"github.com/sipichat/web-service/dtos"
	"github.com/sipichat/web-service/services/auth"
	"github.com/sipichat/web-service/utils"
)

type Handler struct {
	store dtos.UserStore
}

func NewHandler(store dtos.UserStore) *Handler {
	return &Handler{store: store}
}

func (h *Handler) RegisterRoutes(router *mux.Router) {
	router.HandleFunc("/login", h.handleLogin).Methods("POST")
	router.HandleFunc("/register", h.handleRegister).Methods("POST")
}

func (h *Handler) handleLogin(w http.ResponseWriter, r *http.Request) {
	var payload dtos.LoginUsertDTO
	if err := utils.ParseJson(r, &payload); err != nil {
		utils.WriteError(w, http.StatusBadRequest, err)
	}

	if err := utils.Validate.Struct(payload); err != nil {
		errors := err.(validator.ValidationErrors)
		utils.WriteError(w, http.StatusBadRequest, fmt.Errorf("invalid payload &y", errors))
		return
	}

	u, err := h.store.GetUserByUsername(payload.Username)
	if err != nil {
		utils.WriteError(w, http.StatusBadRequest, fmt.Errorf("not found, invalid username or password"))
		return
	}

	if !auth.ComparePasswords(u.Password, []byte(payload.Password)) {
		utils.WriteError(w, http.StatusBadRequest, fmt.Errorf("not found, invalid username or password"))
		return
	}

	secret := []byte(config.Envs.JWTSecret)
	token, err := auth.CreateJWT(secret, u.ID)
	log.Println("dd:" + token)

	if err != nil {
		utils.WriteError(w, http.StatusInternalServerError, err)
	}

	utils.WriteJson(w, http.StatusOK, map[string]string{"token": token}) //for jwt auth token

}

func (h *Handler) handleRegister(w http.ResponseWriter, r *http.Request) {
	var payload dtos.RegisterUserDTO
	if err := utils.ParseJson(r, &payload); err != nil {
		utils.WriteError(w, http.StatusBadRequest, err)
	}

	if err := utils.Validate.Struct(payload); err != nil {
		errors := err.(validator.ValidationErrors)
		utils.WriteError(w, http.StatusBadRequest, fmt.Errorf("invalid payload &y", errors))
		return
	}

	// user exists check
	_, err := h.store.GetUserByUsername(payload.Username)
	if err == nil {
		utils.WriteError(w, http.StatusBadRequest, fmt.Errorf("user with username %s already exists!", payload.Username))
		return
	} else if err != nil && err.Error() != "user not found" {
		utils.WriteError(w, http.StatusInternalServerError, err)
		return
	}

	hashedPass, err := auth.HashPasswords(payload.Password)

	if err != nil {
		utils.WriteError(w, http.StatusInternalServerError, err)
		return
	}

	err = h.store.CreateUser(dtos.User{
		Username: payload.Username,
		Password: hashedPass,
	})

	if err != nil {
		utils.WriteError(w, http.StatusInternalServerError, err)
	}

	utils.WriteJson(w, http.StatusCreated, nil)

}
