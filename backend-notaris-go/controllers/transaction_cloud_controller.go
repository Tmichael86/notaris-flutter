package controllers

import (
	"backend-notaris-go/database"
	"backend-notaris-go/repositories"
	"encoding/json"
	"errors"
	"github.com/gin-gonic/gin"
	"io"
	"net/http"
	"strconv"
)

// Shared single-office catalog, authenticated transaksi permission at the router.
// There is no worker, publication route, or global synchronization activation.
func TransactionCloudCreate(ctx *gin.Context) {
	actor, ok := getAuthenticatedUserID(ctx)
	if !ok {
		ctx.JSON(401, gin.H{"code": "invalid_actor"})
		return
	}
	var m repositories.TransactionCloudCreate
	d := json.NewDecoder(http.MaxBytesReader(ctx.Writer, ctx.Request.Body, 2<<20))
	d.DisallowUnknownFields()
	if d.Decode(&m) != nil || d.Decode(new(any)) != io.EOF {
		ctx.JSON(400, gin.H{"code": "invalid_payload"})
		return
	}
	ack, err := repositories.NewTransactionCloudRepository(database.DB).Create(ctx.Request.Context(), m, int64(actor))
	switch {
	case errors.Is(err, repositories.ErrTransactionCloudInvalid), errors.Is(err, repositories.ErrTransactionCloudReference):
		ctx.JSON(422, gin.H{"code": "invalid_reference_or_payload"})
	case errors.Is(err, repositories.ErrTransactionCloudReuse):
		ctx.JSON(409, gin.H{"code": "mutation_reuse"})
	case errors.Is(err, repositories.ErrTransactionCloudConflict):
		ctx.JSON(409, gin.H{"code": "aggregate_exists"})
	case errors.Is(err, repositories.ErrTransactionNumberExhausted):
		ctx.JSON(409, gin.H{"code": "number_exhausted"})
	case err != nil:
		ctx.JSON(500, gin.H{"code": "sync_failed"})
	default:
		ctx.JSON(200, gin.H{"acknowledgement": ack})
	}
}
func TransactionCloudPull(ctx *gin.Context) {
	cursor, e1 := strconv.ParseInt(ctx.DefaultQuery("cursor", "0"), 10, 64)
	limit, e2 := strconv.Atoi(ctx.DefaultQuery("limit", "100"))
	if e1 != nil || e2 != nil {
		ctx.JSON(400, gin.H{"code": "invalid_cursor"})
		return
	}
	page, err := repositories.NewTransactionCloudRepository(database.DB).Pull(ctx.Request.Context(), cursor, limit)
	if errors.Is(err, repositories.ErrTransactionCloudCursor) {
		ctx.JSON(400, gin.H{"code": "invalid_cursor"})
		return
	}
	if err != nil {
		ctx.JSON(500, gin.H{"code": "sync_failed"})
		return
	}
	ctx.JSON(200, page)
}
