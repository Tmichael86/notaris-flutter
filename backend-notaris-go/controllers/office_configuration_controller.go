package controllers

import (
	"backend-notaris-go/config"
	"backend-notaris-go/services"
	"errors"
	"github.com/gin-gonic/gin"
)

// RequireOfficeSecurity refuses this new endpoint when P0 enforcement is OFF.
// JWTAuth supplies security_version only after checking the current DB identity.
func RequireOfficeSecurity(cfg config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		if !cfg.UsersSecurityEnabled {
			c.AbortWithStatusJSON(503, gin.H{"success": false, "code": "security_unavailable", "message": "Keamanan konfigurasi belum tersedia."})
			return
		}
		c.Next()
	}
}
func OfficeConfigurationRead(c *gin.Context) {
	c.Header("Cache-Control", "no-store")
	v, ok := c.Get("security_version")
	version, valid := v.(int64)
	if !ok || !valid || version < 1 {
		c.AbortWithStatusJSON(401, gin.H{"success": false, "code": "session_invalid"})
		return
	}
	data, e := services.ReadOfficeConfiguration(c.Request.Context())
	if e != nil {
		status, code, message := 503, "configuration_unavailable", "Konfigurasi belum dapat dimuat."
		switch {
		case errors.Is(e, services.ErrOfficeMissing):
			status, code, message = 404, "configuration_missing", "Konfigurasi belum tersedia."
		case errors.Is(e, services.ErrOfficeAmbiguous):
			status, code, message = 409, "configuration_ambiguous", "Konfigurasi ambigu. Hubungi administrator."
		case errors.Is(e, services.ErrOfficeInvalid):
			status, code, message = 422, "configuration_invalid", "Data konfigurasi tidak valid."
		}
		c.JSON(status, gin.H{"success": false, "code": code, "message": message})
		return
	}
	c.JSON(200, gin.H{"success": true, "data": data})
}
