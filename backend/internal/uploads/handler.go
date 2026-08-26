package uploads

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"

	"github.com/SipiczkiMartin/chat-app/internal/auth"
	"github.com/google/uuid"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{
		service: service,
	}
}

func (h *Handler) Upload(
	w http.ResponseWriter,
	r *http.Request,
) {
	userID := auth.UserIDFromContext(
		r.Context(),
	)

	if userID == uuid.Nil {
		http.Error(
			w,
			"unauthorized",
			http.StatusUnauthorized,
		)
		return
	}

	err := r.ParseMultipartForm(
		30 << 20, // 30 MB
	)

	if err != nil {
		http.Error(
			w,
			"invalid multipart form",
			http.StatusBadRequest,
		)
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		http.Error(
			w,
			"file is required",
			http.StatusBadRequest,
		)
		return
	}

	defer file.Close()

	result, err := h.service.Upload(
		r.Context(),
		header.Filename,
		header.Header.Get("Content-Type"),
		header.Size,
		file,
	)

	if err != nil {
		http.Error(
			w,
			err.Error(),
			http.StatusBadRequest,
		)
		return
	}

	response := struct {
		StorageKey string `json:"storage_key"`
		URL        string `json:"url"`
		Filename   string `json:"filename"`
		MimeType   string `json:"mime_type"`
		Size       int64  `json:"size"`
		Type       string `json:"type"`
	}{
		StorageKey: result.StorageKey,
		URL:        result.URL,
		Filename:   result.Filename,
		MimeType:   result.MimeType,
		Size:       result.Size,
		Type:       result.Type,
	}

	w.Header().Set(
		"Content-Type",
		"application/json",
	)

	w.WriteHeader(http.StatusCreated)

	if err := json.NewEncoder(w).Encode(response); err != nil {
		return
	}
}

func (h *Handler) Download(
	w http.ResponseWriter,
	r *http.Request,
) {

	userID := auth.UserIDFromContext(
		r.Context(),
	)

	if userID == uuid.Nil {
		http.Error(
			w,
			"unauthorized",
			http.StatusUnauthorized,
		)
		return
	}

	filename := r.PathValue("filename")

	if filename == "" {
		http.Error(
			w,
			"filename is required",
			http.StatusBadRequest,
		)
		return
	}

	key := "attachments/" + filename

	if key == "" {
		http.Error(
			w,
			"storage key is required",
			http.StatusBadRequest,
		)
		return
	}

	object, err := h.service.Get(
		r.Context(),
		key,
	)

	if err != nil {
		log.Printf(
			"DOWNLOAD ERROR: user=%s key=%q err=%v",
			userID,
			key,
			err,
		)

		http.Error(
			w,
			"file not found",
			http.StatusNotFound,
		)
		return
	}

	defer object.Reader.Close()

	w.Header().Set(
		"Content-Type",
		object.ContentType,
	)

	w.Header().Set(
		"Content-Length",
		fmt.Sprintf("%d", object.Size),
	)

	w.Header().Set(
		"Content-Disposition",
		"inline",
	)

	w.WriteHeader(http.StatusOK)

	if _, err := io.Copy(w, object.Reader); err != nil {
		return
	}
}
