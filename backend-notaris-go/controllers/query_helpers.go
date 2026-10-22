package controllers

import (
	"strconv"

	"github.com/gin-gonic/gin"
)

// queryInt reads an optional integer query parameter and applies its default
// when the parameter is not provided. Invalid values are returned as errors.
func queryInt(ctx *gin.Context, key string, defaultValue int) (int, error) {
	raw, exists := ctx.GetQuery(key)
	if !exists {
		return defaultValue, nil
	}

	value, err := strconv.Atoi(raw)
	if err != nil {
		return 0, err
	}
	return value, nil
}
