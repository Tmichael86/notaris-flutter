package routes

import (
	"backend-notaris-go/config"
	"backend-notaris-go/middleware"
	"backend-notaris-go/repositories"
	"encoding/json"
	"errors"
	"io"
	"net/http"

	"github.com/gin-gonic/gin"
)

// RegisterAttributeWorkflow is called only by the owned disposable demo.
func RegisterAttributeWorkflow(router *gin.Engine, cfg config.Config, repo repositories.AttributeWorkflow) {
	r := router.Group("/api/v1/attribute-workflow", middleware.JWTAuth(cfg),
		middleware.RequirePermission(repositories.NewSidebarAccessRepository(), "transaksi", middleware.PermissionRead))
	r.GET("/processes/:uuid", func(c *gin.Context) {
		value, e := repo.View(c.Request.Context(), c.Param("uuid"), attributeActor(c))
		attributeResponse(c, value, e)
	})
	r.POST("/processes/:uuid", func(c *gin.Context) {
		var command repositories.AttributeCommand
		decoder := json.NewDecoder(http.MaxBytesReader(c.Writer, c.Request.Body, 16<<10))
		decoder.DisallowUnknownFields()
		if decoder.Decode(&command) != nil || decoder.Decode(new(any)) != io.EOF {
			attributeResponse(c, nil, repositories.ErrAttributeInvalid)
			return
		}
		revision, e := repo.Execute(c.Request.Context(), c.Param("uuid"), attributeActor(c), command)
		attributeResponse(c, gin.H{"revision": revision}, e)
	})
	r.GET("/inbox", func(c *gin.Context) {
		value, e := repo.Inbox(c.Request.Context(), attributeActor(c))
		attributeResponse(c, value, e)
	})
	r.POST("/inbox/:event/read", func(c *gin.Context) {
		attributeResponse(c, gin.H{"read": true}, repo.MarkRead(c.Request.Context(), attributeActor(c), c.Param("event")))
	})
}

func attributeActor(c *gin.Context) int64 {
	actor, _ := c.MustGet("user_id").(uint)
	return int64(actor)
}

func attributeResponse(c *gin.Context, data any, err error) {
	switch {
	case errors.Is(err, repositories.ErrAttributeForbidden):
		c.JSON(403, gin.H{"code": "workflow_forbidden"})
	case errors.Is(err, repositories.ErrAttributeConflict):
		c.JSON(409, gin.H{"code": "workflow_conflict"})
	case errors.Is(err, repositories.ErrAttributeInvalid):
		c.JSON(422, gin.H{"code": "workflow_invalid"})
	case err != nil:
		c.JSON(500, gin.H{"code": "workflow_failed"})
	default:
		c.JSON(200, gin.H{"data": data})
	}
}
