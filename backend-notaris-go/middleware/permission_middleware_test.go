package middleware

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"backend-notaris-go/models"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/require"
)

type fakePermissionChecker struct {
	access *models.SidebarAccess
	err    error
}

func (f fakePermissionChecker) FindByGroupAndSidebarCode(groupID uint, sidebarCode string) (*models.SidebarAccess, error) {
	return f.access, f.err
}

func runPermissionMiddleware(
	checker PermissionChecker,
	action PermissionAction,
	groupID any,
) *httptest.ResponseRecorder {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	router.Use(func(ctx *gin.Context) {
		if groupID != nil {
			ctx.Set("group_id", groupID)
		}
		ctx.Next()
	})
	router.GET("/test", RequirePermission(checker, "transaksi", action), func(ctx *gin.Context) {
		ctx.JSON(http.StatusOK, gin.H{"success": true})
	})

	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	recorder := httptest.NewRecorder()
	router.ServeHTTP(recorder, req)

	return recorder
}

func TestRequirePermissionAllowsConfiguredAction(t *testing.T) {
	recorder := runPermissionMiddleware(
		fakePermissionChecker{
			access: &models.SidebarAccess{Read: 1, Create: 1, Update: 0, Delete: 0},
		},
		PermissionCreate,
		uint(1),
	)

	require.Equal(t, http.StatusOK, recorder.Code)
}

func TestRequirePermissionRejectsMissingAction(t *testing.T) {
	recorder := runPermissionMiddleware(
		fakePermissionChecker{
			access: &models.SidebarAccess{Read: 1, Create: 0, Update: 0, Delete: 0},
		},
		PermissionCreate,
		uint(1),
	)

	require.Equal(t, http.StatusForbidden, recorder.Code)
}

func TestRequirePermissionRejectsUnknownSidebar(t *testing.T) {
	recorder := runPermissionMiddleware(
		fakePermissionChecker{err: errors.New("record not found")},
		PermissionRead,
		uint(1),
	)

	require.Equal(t, http.StatusForbidden, recorder.Code)
}

func TestRequirePermissionRejectsMissingGroupContext(t *testing.T) {
	recorder := runPermissionMiddleware(
		fakePermissionChecker{
			access: &models.SidebarAccess{Read: 1},
		},
		PermissionRead,
		nil,
	)

	require.Equal(t, http.StatusUnauthorized, recorder.Code)
}

func TestRequirePermissionRejectsInvalidGroupContext(t *testing.T) {
	recorder := runPermissionMiddleware(
		fakePermissionChecker{
			access: &models.SidebarAccess{Read: 1},
		},
		PermissionRead,
		"1",
	)

	require.Equal(t, http.StatusUnauthorized, recorder.Code)
}

func TestRequirePermissionReturnsServerErrorOnRepositoryFailure(t *testing.T) {
	recorder := runPermissionMiddleware(
		fakePermissionChecker{err: errors.New("database unavailable")},
		PermissionRead,
		uint(1),
	)

	require.Equal(t, http.StatusInternalServerError, recorder.Code)
}
