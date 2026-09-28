package middleware

import (
    "net/http"
    "strings"

    "backend-notaris-go/config"
    "backend-notaris-go/services"

    "github.com/gin-gonic/gin"
    "github.com/golang-jwt/jwt/v5"
)

func JWTAuth(cfg config.Config) gin.HandlerFunc {
    return func(ctx *gin.Context) {
        header := ctx.GetHeader("Authorization")
        parts := strings.Fields(header)
        if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
            ctx.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"success": false, "message": "Token autentikasi tidak ditemukan"})
            return
        }

        claims := &services.Claims{}
        token, err := jwt.ParseWithClaims(parts[1], claims, func(token *jwt.Token) (any, error) {
            return []byte(cfg.JWTSecret), nil
        }, jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}), jwt.WithIssuer("backend-notaris-go"))

        if err != nil || !token.Valid {
            ctx.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"success": false, "message": "Token autentikasi tidak valid atau kedaluwarsa"})
            return
        }

        ctx.Set("user_id", claims.UID)
        ctx.Set("group_id", claims.GID)
        ctx.Next()
    }
}
