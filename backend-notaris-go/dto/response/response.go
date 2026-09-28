package response

import "github.com/gin-gonic/gin"

type APIResponse struct {
	Success bool        `json:"success"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
	Errors  interface{} `json:"errors,omitempty"`
}

func Success(c *gin.Context, message string, data interface{}) {
	c.JSON(200, APIResponse{
		Success: true,
		Message: message,
		Data:    data,
	})
}

func Error(c *gin.Context, status int, message string, errors interface{}) {
	c.JSON(status, APIResponse{
		Success: false,
		Message: message,
		Errors:  errors,
	})
}
