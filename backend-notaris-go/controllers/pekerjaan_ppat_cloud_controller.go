package controllers

import (
	"backend-notaris-go/database"
	"backend-notaris-go/repositories"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

// The router applies JWT and the operation-specific Pekerjaan Ppat sidebar
// permission before these handlers. There is no background worker activation.
func PekerjaanPpatCloudCreate(ctx *gin.Context) {
	actor, ok := getAuthenticatedUserID(ctx)
	if !ok {
		ctx.JSON(http.StatusUnauthorized, gin.H{"code": "invalid_actor"})
		return
	}
	var request repositories.PpatCloudCreate
	decoder := json.NewDecoder(http.MaxBytesReader(ctx.Writer, ctx.Request.Body, 1<<20))
	decoder.DisallowUnknownFields()
	if decoder.Decode(&request) != nil || decoder.Decode(new(any)) != io.EOF {
		ctx.JSON(http.StatusBadRequest, gin.H{"code": "invalid_payload"})
		return
	}
	ack, err := repositories.NewPpatCloudRepository(database.DB).Create(ctx.Request.Context(), request, int64(actor))
	switch {
	case errors.Is(err, repositories.ErrPpatCloudInvalid):
		ctx.JSON(http.StatusUnprocessableEntity, gin.H{"code": "invalid_reference_or_payload"})
	case errors.Is(err, repositories.ErrPpatCloudReuse):
		ctx.JSON(http.StatusConflict, gin.H{"code": "mutation_reuse"})
	case errors.Is(err, repositories.ErrPpatCloudConflict):
		ctx.JSON(http.StatusConflict, gin.H{"code": "aggregate_exists"})
	case err != nil:
		ctx.JSON(http.StatusInternalServerError, gin.H{"code": "sync_failed"})
	default:
		ctx.JSON(http.StatusOK, gin.H{"acknowledgement": ack})
	}
}

func PekerjaanPpatCloudPull(ctx *gin.Context) {
	cursor, err1 := strconv.ParseInt(ctx.DefaultQuery("cursor", "0"), 10, 64)
	limit, err2 := strconv.Atoi(ctx.DefaultQuery("limit", "100"))
	if err1 != nil || err2 != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"code": "invalid_cursor"})
		return
	}
	page, err := repositories.NewPpatCloudRepository(database.DB).Pull(ctx.Request.Context(), cursor, limit)
	if errors.Is(err, repositories.ErrPpatCloudCursor) {
		ctx.JSON(http.StatusBadRequest, gin.H{"code": "invalid_cursor"})
		return
	}
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"code": "sync_failed"})
		return
	}
	ctx.JSON(http.StatusOK, page)
}

func PekerjaanPpatCloudUpdate(ctx *gin.Context) {
	actor, ok := getAuthenticatedUserID(ctx)
	if !ok {
		ctx.JSON(http.StatusUnauthorized, gin.H{"code": "invalid_actor"})
		return
	}
	var request repositories.PpatCloudUpdate
	decoder := json.NewDecoder(http.MaxBytesReader(ctx.Writer, ctx.Request.Body, 1<<20))
	decoder.DisallowUnknownFields()
	if decoder.Decode(&request) != nil || decoder.Decode(new(any)) != io.EOF {
		ctx.JSON(http.StatusBadRequest, gin.H{"code": "invalid_payload"})
		return
	}
	ack, err := repositories.NewPpatCloudRepository(database.DB).Update(ctx.Request.Context(), request, int64(actor))
	ppatMutationResponse(ctx, ack, err)
}

func PekerjaanPpatCloudDelete(ctx *gin.Context) {
	actor, ok := getAuthenticatedUserID(ctx)
	if !ok {
		ctx.JSON(http.StatusUnauthorized, gin.H{"code": "invalid_actor"})
		return
	}
	var request repositories.PpatCloudDelete
	decoder := json.NewDecoder(http.MaxBytesReader(ctx.Writer, ctx.Request.Body, 1<<20))
	decoder.DisallowUnknownFields()
	if decoder.Decode(&request) != nil || decoder.Decode(new(any)) != io.EOF {
		ctx.JSON(http.StatusBadRequest, gin.H{"code": "invalid_payload"})
		return
	}
	ack, err := repositories.NewPpatCloudRepository(database.DB).Delete(ctx.Request.Context(), request, int64(actor))
	ppatMutationResponse(ctx, ack, err)
}

func ppatMutationResponse(ctx *gin.Context, ack *repositories.PpatCloudAck, err error) {
	switch {
	case errors.Is(err, repositories.ErrPpatCloudInvalid):
		ctx.JSON(http.StatusUnprocessableEntity, gin.H{"code": "invalid_reference_or_payload"})
	case errors.Is(err, repositories.ErrPpatCloudReuse):
		ctx.JSON(http.StatusConflict, gin.H{"code": "mutation_reuse"})
	case errors.Is(err, repositories.ErrPpatCloudRevision):
		ctx.JSON(http.StatusConflict, gin.H{"code": "revision_conflict"})
	case err != nil:
		ctx.JSON(http.StatusInternalServerError, gin.H{"code": "sync_failed"})
	default:
		ctx.JSON(http.StatusOK, gin.H{"acknowledgement": ack})
	}
}
