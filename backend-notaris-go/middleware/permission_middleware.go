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

// RequirePermission resolves the user's current group from the database on
// every protected request. JWT group claims can be stale after an admin moves
// a user to another group, so they are not authoritative for current access.
// Workflow-specific permissions must still be enforced separately.
func RequirePermission(accessRepository *repositories.SidebarAccessRepository, sidebarCode, permission string) gin.HandlerFunc {
	return func(ctx *gin.Context) {
		value, exists := ctx.Get("user_id")
		userID, ok := value.(uint)
		if !exists || !ok || userID == 0 {
			ctx.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"message": "Identitas pengguna tidak valid",
			})
			return
		}

		user, err := repositories.NewUserRepository().FindByID(userID)
		if err != nil || user.Status != 1 {
			ctx.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"message": "Pengguna tidak ditemukan atau tidak aktif",
			})
			return
		}

		group, err := repositories.NewGroupRepository().FindByID(user.GroupID)
		if err != nil || group.Status != 1 {
			ctx.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"success": false,
				"message": "Grup pengguna tidak ditemukan atau tidak aktif",
			})
			return
		}

		access, err := accessRepository.FindByGroupAndSidebarCode(user.GroupID, sidebarCode)
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
