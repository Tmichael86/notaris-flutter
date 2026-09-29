package middleware

import (
	"errors"
	"net/http"

	"backend-notaris-go/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type PermissionAction string

const (
	PermissionRead   PermissionAction = "read"
	PermissionCreate PermissionAction = "create"
	PermissionUpdate PermissionAction = "update"
	PermissionDelete PermissionAction = "delete"
)

type PermissionChecker interface {
	FindByGroupAndSidebarCode(groupID uint, sidebarCode string) (*models.SidebarAccess, error)
}

func RequirePermission(checker PermissionChecker, sidebarCode string, action PermissionAction) gin.HandlerFunc {
	return func(ctx *gin.Context) {
		groupIDValue, exists := ctx.Get("group_id")
		if !exists {
			ctx.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"message": "Informasi group pengguna tidak ditemukan",
			})
			return
		}

		groupID, ok := groupIDValue.(uint)
		if !ok || groupID == 0 {
			ctx.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"message": "Informasi group pengguna tidak valid",
			})
			return
		}

		access, err := checker.FindByGroupAndSidebarCode(groupID, sidebarCode)
		if err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				ctx.AbortWithStatusJSON(http.StatusForbidden, gin.H{
					"success": false,
					"message": "Anda tidak memiliki izin untuk mengakses resource ini",
				})
				return
			}

			ctx.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{
				"success": false,
				"message": "Gagal memeriksa hak akses",
			})
			return
		}

		if !hasPermission(access, action) {
			ctx.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"success": false,
				"message": "Anda tidak memiliki izin untuk mengakses resource ini",
			})
			return
		}

		ctx.Next()
	}
}

func hasPermission(access *models.SidebarAccess, action PermissionAction) bool {
	if access == nil {
		return false
	}

	switch action {
	case PermissionRead:
		return access.Read == 1
	case PermissionCreate:
		return access.Create == 1
	case PermissionUpdate:
		return access.Update == 1
	case PermissionDelete:
		return access.Delete == 1
	default:
		return false
	}
}
