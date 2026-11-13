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

func transactionRepository(ctx *gin.Context) *repositories.TransactionCloudRepository {
	domain := ctx.GetString("transaction_domain")
	if domain == "" {
		domain = "notaris"
	}
	return repositories.NewTransactionCloudRepositoryForDomain(database.DB, domain)
}

// Shared single-office catalog, authenticated transaksi permission at the router.
// There is no worker, publication route, or global synchronization activation.
func TransactionCloudCreate(ctx *gin.Context) {
	transactionCloudWrite(ctx, false)
}
func TransactionCloudUpdate(ctx *gin.Context) {
	transactionCloudWrite(ctx, true)
}
func transactionCloudWrite(ctx *gin.Context, update bool) {
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
	repo := transactionRepository(ctx)
	var ack *repositories.TransactionCloudAck
	var err error
	if update {
		ack, err = repo.Update(ctx.Request.Context(), m, int64(actor))
	} else {
		ack, err = repo.Create(ctx.Request.Context(), m, int64(actor))
	}
	transactionCloudResponse(ctx, ack, err)
}
func TransactionCloudDelete(ctx *gin.Context) {
	actor, ok := getAuthenticatedUserID(ctx)
	if !ok {
		ctx.JSON(401, gin.H{"code": "invalid_actor"})
		return
	}
	var m repositories.TransactionCloudDelete
	d := json.NewDecoder(http.MaxBytesReader(ctx.Writer, ctx.Request.Body, 2<<20))
	d.DisallowUnknownFields()
	if d.Decode(&m) != nil || d.Decode(new(any)) != io.EOF {
		ctx.JSON(400, gin.H{"code": "invalid_payload"})
		return
	}
	ack, err := transactionRepository(ctx).Delete(ctx.Request.Context(), m, int64(actor))
	transactionCloudResponse(ctx, ack, err)
}
func transactionCloudResponse(ctx *gin.Context, ack *repositories.TransactionCloudAck, err error) {
	switch {
	case errors.Is(err, repositories.ErrTransactionCloudInvalid), errors.Is(err, repositories.ErrTransactionCloudReference):
		ctx.JSON(422, gin.H{"code": "invalid_reference_or_payload"})
	case errors.Is(err, repositories.ErrTransactionCloudReuse):
		ctx.JSON(409, gin.H{"code": "mutation_reuse"})
	case errors.Is(err, repositories.ErrTransactionCloudConflict):
		ctx.JSON(409, gin.H{"code": "aggregate_exists"})
	case errors.Is(err, repositories.ErrTransactionCloudRevision):
		ctx.JSON(409, gin.H{"code": "revision_conflict"})
	case errors.Is(err, repositories.ErrTransactionCloudPayment):
		ctx.JSON(422, gin.H{"code": "payment_history_immutable"})
	case errors.Is(err, repositories.ErrTransactionCloudAudit):
		ctx.JSON(422, gin.H{"code": "actor_provenance_unresolved"})
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
	page, err := transactionRepository(ctx).Pull(ctx.Request.Context(), cursor, limit)
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
