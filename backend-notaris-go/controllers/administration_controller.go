package controllers

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strconv"

	"backend-notaris-go/config"
	"backend-notaris-go/database"
	"backend-notaris-go/dto/request"
	"backend-notaris-go/models"
	"backend-notaris-go/services"
	"github.com/gin-gonic/gin"
)

// AdministrationController is the only registered administrative write path.
// The old unversioned service writers are disabled, including grant replacement.
type AdministrationController struct{ service services.Administration }

func NewAdministrationController(cfg config.Config) *AdministrationController {
	return &AdministrationController{services.Administration{DB: database.DB, Enabled: cfg.UsersSecurityEnabled}}
}
func adminActor(c *gin.Context) services.AdminActor {
	id, _ := getAuthenticatedUserID(c)
	version, _ := c.Get("security_version")
	sv, _ := version.(int64)
	requestID, _ := c.Get("admin_request_id")
	rid, _ := requestID.(string)
	return services.AdminActor{ID: id, Version: sv, RequestID: rid}
}
func adminResponse(c *gin.Context, err error) {
	problem := &services.AdminError{Status: 500, Code: "admin_operation_failed"}
	var known *services.AdminError
	if errors.As(err, &known) {
		problem = known
	}
	c.AbortWithStatusJSON(problem.Status, gin.H{"success": false, "code": problem.Code,
		"message": "Operasi administrasi ditolak atau tidak dapat diselesaikan.", "request_id": adminActor(c).RequestID})
}
func (a *AdministrationController) Guard(menu, action string) gin.HandlerFunc {
	return func(c *gin.Context) {
		rid := services.AdminRequestID()
		c.Set("admin_request_id", rid)
		c.Header("X-Request-ID", rid)
		if err := a.service.Check(c.Request.Context(), adminActor(c), menu, action); err != nil {
			adminResponse(c, err)
			return
		}
		c.Next()
	}
}
func (a *AdministrationController) reject(c *gin.Context, code string) {
	adminResponse(c, a.service.Reject(adminActor(c), "input", "invalid_input", &services.AdminError{Status: 400, Code: code}))
}
func (a *AdministrationController) decode(c *gin.Context, value any) bool {
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, 32768)
	decoder := json.NewDecoder(c.Request.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(value); err != nil {
		a.reject(c, "invalid_input")
		return false
	}
	if err := decoder.Decode(new(any)); err != io.EOF {
		a.reject(c, "invalid_input")
		return false
	}
	return true
}
func (a *AdministrationController) id(c *gin.Context) (uint, bool) {
	n, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil || n == 0 {
		a.reject(c, "invalid_target")
		return 0, false
	}
	return uint(n), true
}
func adminOK(c *gin.Context, status int, value any) {
	c.JSON(status, gin.H{"success": true, "data": value, "request_id": adminActor(c).RequestID})
}
func (a *AdministrationController) Users(c *gin.Context) {
	var users []models.User
	if err := a.service.DB.Order("id").Find(&users).Error; err != nil {
		adminResponse(c, err)
		return
	}
	adminOK(c, 200, users)
}
func (a *AdministrationController) Assignable(c *gin.Context) {
	var groups []models.Group
	if err := a.service.DB.Where("status=1 AND group_jenis='user'").Order("id").Find(&groups).Error; err != nil {
		adminResponse(c, err)
		return
	}
	adminOK(c, 200, groups)
}

type adminUserInput struct {
	GroupID          uint    `json:"group_id"`
	Username         string  `json:"username"`
	Email            string  `json:"email"`
	Nama             string  `json:"nama"`
	NoTelp           *string `json:"no_telp"`
	Alamat           *string `json:"alamat"`
	ExpectedRevision int64   `json:"expected_revision"`
}

func (i adminUserInput) model(id uint) models.User {
	return models.User{ID: id, GroupID: i.GroupID, Username: i.Username, Email: i.Email, Nama: i.Nama, NoTelp: i.NoTelp, Alamat: i.Alamat}
}
func (a *AdministrationController) CreateUser(c *gin.Context) {
	var input struct {
		adminUserInput
		Password     string `json:"password"`
		Confirmation string `json:"password_confirm"`
	}
	if !a.decode(c, &input) {
		return
	}
	hash, err := services.AdminPassword(input.Password, input.Confirmation)
	if err != nil {
		adminResponse(c, a.service.Reject(adminActor(c), "user", "user_create", err))
		return
	}
	user, err := a.service.SaveUser(c.Request.Context(), adminActor(c), input.model(0), 0, hash)
	if err != nil {
		adminResponse(c, err)
		return
	}
	adminOK(c, 201, user)
}
func (a *AdministrationController) UpdateUser(c *gin.Context) {
	id, ok := a.id(c)
	if !ok {
		return
	}
	var input adminUserInput
	if !a.decode(c, &input) {
		return
	}
	user, err := a.service.SaveUser(c.Request.Context(), adminActor(c), input.model(id), input.ExpectedRevision, "")
	if err != nil {
		adminResponse(c, err)
		return
	}
	adminOK(c, 200, user)
}
func (a *AdministrationController) UserSecurity(c *gin.Context) {
	id, ok := a.id(c)
	if !ok {
		return
	}
	var rev int64
	var hash string
	if c.Request.Method == http.MethodDelete {
		var input struct {
			Revision int64 `json:"expected_revision"`
		}
		if !a.decode(c, &input) {
			return
		}
		rev = input.Revision
	} else {
		var input struct {
			Revision     int64  `json:"expected_revision"`
			Password     string `json:"password"`
			Confirmation string `json:"password_confirm"`
		}
		if !a.decode(c, &input) {
			return
		}
		rev = input.Revision
		var err error
		hash, err = services.AdminPassword(input.Password, input.Confirmation)
		if err != nil {
			adminResponse(c, a.service.Reject(adminActor(c), "user", "password_reset", err))
			return
		}
	}
	if err := a.service.UserSecurity(c.Request.Context(), adminActor(c), id, rev, hash); err != nil {
		adminResponse(c, err)
		return
	}
	adminOK(c, 200, nil)
}
func (a *AdministrationController) Group(c *gin.Context) {
	var id uint
	if c.Request.Method != http.MethodPost {
		var ok bool
		id, ok = a.id(c)
		if !ok {
			return
		}
	}
	var input struct {
		Name     string `json:"group_nama"`
		Kind     string `json:"group_jenis"`
		Revision int64  `json:"expected_revision"`
	}
	if !a.decode(c, &input) {
		return
	}
	if err := a.service.GroupChange(c.Request.Context(), adminActor(c), models.Group{ID: id, GroupNama: input.Name, GroupJenis: input.Kind}, input.Revision, c.Request.Method == http.MethodDelete); err != nil {
		adminResponse(c, err)
		return
	}
	adminOK(c, 200, nil)
}
func (a *AdministrationController) Grants(c *gin.Context) {
	id, ok := a.id(c)
	if !ok {
		return
	}
	var input struct {
		Revision int64                       `json:"expected_revision"`
		Access   []request.SidebarAccessItem `json:"access"`
	}
	if !a.decode(c, &input) {
		return
	}
	if err := a.service.Grants(c.Request.Context(), adminActor(c), id, input.Revision, input.Access); err != nil {
		adminResponse(c, err)
		return
	}
	adminOK(c, 200, nil)
}

// Deliberately not a Users listing: a single active reference, no credentials,
// personal contacts, role, group, or administrative revision metadata.
func PetugasUserReference(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil || id == 0 {
		c.JSON(400, gin.H{"success": false, "code": "invalid_reference"})
		return
	}
	var count int64
	if err := database.DB.Table("users u").Joins("JOIN groups g ON g.id=u.group_id").Where("u.id=? AND u.status=1 AND g.status=1", id).Count(&count).Error; err != nil {
		c.JSON(500, gin.H{"success": false, "code": "reference_unavailable"})
		return
	}
	if count != 1 {
		c.JSON(404, gin.H{"success": false, "code": "reference_unavailable"})
		return
	}
	c.JSON(200, gin.H{"success": true, "data": gin.H{"id": id, "status": 1}})
}
