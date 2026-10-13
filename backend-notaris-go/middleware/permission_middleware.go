package middleware

import (
	"errors"
	"net/http"

	"backend-notaris-go/repositories"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

const (
	PermissionRead   = "read"
	PermissionCreate = "create"
	PermissionUpdate = "update"
	PermissionDelete = "delete"
)

// RequirePermission enforces the CRUD permission configured for a sidebar.
// This protects menu-backed API routes; workflow-specific permissions must
// still be enforced separately by the workflow service.
func RequirePermission(repository *repositories.SidebarAccessRepository, sidebarCode, permission string) gin.HandlerFunc {
	return func(ctx *gin.Context) {
		value, exists := ctx.Get("group_id")
		groupID, ok := value.(uint)
		if !exists || !ok || groupID == 0 {
			ctx.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"message": "Grup pengguna tidak valid",
			})
			return
		}

		access, err := repository.FindByGroupAndSidebarCode(groupID, sidebarCode)
		if errors.Is(err, gorm.ErrRecordNotFound) {
			ctx.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"success": false,
				"message": "Akses menu tidak diizinkan",
			})
			return
		}
		if err != nil {
			ctx.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{
				"success": false,
				"message": "Gagal memeriksa hak akses",
			})
			return
		}

		allowed := false
		switch permission {
		case PermissionRead:
			allowed = access.Read == 1
		case PermissionCreate:
			allowed = access.Create == 1
		case PermissionUpdate:
			allowed = access.Update == 1
		case PermissionDelete:
			allowed = access.Delete == 1
		default:
			ctx.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{
				"success": false,
				"message": "Jenis izin tidak dikenal",
			})
			return
		}

		if !allowed {
			ctx.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"success": false,
				"message": "Akses menu tidak diizinkan",
			})
			return
		}

		ctx.Next()
	}
}
