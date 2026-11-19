package controllers

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strconv"
	"strings"

	"backend-notaris-go/config"
	"backend-notaris-go/database"
	"backend-notaris-go/dto/request"
	"backend-notaris-go/models"
	"backend-notaris-go/services"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
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
	page, size := 1, 10
	for key, target := range map[string]*int{"page": &page, "page_size": &size} {
		if raw, ok := c.GetQuery(key); ok {
			n, e := strconv.Atoi(raw)
			if e != nil || n < 1 || n > 1000000 {
				a.reject(c, "invalid_pagination")
				return
			}
			*target = n
		}
	}
	if size > 50 {
		a.reject(c, "invalid_pagination")
		return
	}
	search := strings.TrimSpace(c.Query("search"))
	if len(search) > 100 {
		a.reject(c, "invalid_search")
		return
	}
	query := a.service.DB.Table("users u").Joins("JOIN groups g ON g.id=u.group_id")
	if search != "" {
		query = query.Where("strpos(lower(u.nama),lower(?))>0 OR strpos(lower(u.username),lower(?))>0 OR strpos(lower(u.email),lower(?))>0", search, search, search)
	}
	if raw, ok := c.GetQuery("group_id"); ok {
		id, e := strconv.ParseUint(raw, 10, 32)
		if e != nil || id == 0 {
			a.reject(c, "invalid_group_filter")
			return
		}
		query = query.Where("u.group_id=?", id)
	}
	if raw, ok := c.GetQuery("status"); ok {
		if raw != "0" && raw != "1" {
			a.reject(c, "invalid_status_filter")
			return
		}
		query = query.Where("u.status=?", raw)
	}
	// One SQL statement binds total and the current page to the same snapshot.
	// An empty page still retains its accurate total; no unbounded account read.
	var rows []adminUserProjection
	var result struct {
		Total int64
		Items json.RawMessage
	}
	filtered := query.Select(userProjectionColumns)
	if err := a.service.DB.Raw("WITH filtered AS (?), page AS (SELECT * FROM filtered ORDER BY id LIMIT ? OFFSET ?) SELECT (SELECT count(*) FROM filtered) AS total,coalesce((SELECT json_agg(page ORDER BY id) FROM page),'[]'::json) AS items", filtered, size, (page-1)*size).Scan(&result).Error; err != nil {
		adminResponse(c, err)
		return
	}
	if err := json.Unmarshal(result.Items, &rows); err != nil {
		adminResponse(c, err)
		return
	}
	var groups []adminGroupProjection
	if err := a.service.DB.Table("groups").Select("id,group_nama,group_jenis,status").Order("id").Limit(500).Find(&groups).Error; err != nil {
		adminResponse(c, err)
		return
	}
	adminOK(c, 200, gin.H{"items": rows, "total": result.Total, "page": page, "page_size": size, "groups": groups})
}

type adminUserProjection struct {
	ID          uint    `json:"id"`
	GroupID     uint    `json:"group_id"`
	GroupNama   string  `json:"group_nama"`
	GroupJenis  string  `json:"group_jenis"`
	GroupStatus int16   `json:"group_status"`
	Nama        string  `json:"nama"`
	Username    string  `json:"username"`
	Email       string  `json:"email"`
	NoTelp      *string `json:"no_telp"`
	Alamat      *string `json:"alamat"`
	Status      int16   `json:"status"`
	Revision    int64   `json:"revision"`
}
type adminGroupProjection struct {
	ID         uint   `json:"id"`
	GroupNama  string `json:"group_nama"`
	GroupJenis string `json:"group_jenis"`
	Status     int16  `json:"status"`
}

const userProjectionColumns = "u.id,u.group_id,u.nama,u.username,u.email,u.no_telp,u.alamat,u.status,u.revision,g.group_nama,g.group_jenis,g.status AS group_status"

func (a *AdministrationController) User(c *gin.Context) {
	id, ok := a.id(c)
	if !ok {
		return
	}
	a.userRecord(c, id, 200)
}
func (a *AdministrationController) userRecord(c *gin.Context, id uint, status int) {
	var user adminUserProjection
	err := a.service.DB.Table("users u").Select(userProjectionColumns).Joins("JOIN groups g ON g.id=u.group_id").Where("u.id=?", id).Take(&user).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		adminResponse(c, &services.AdminError{Status: 404, Code: "user_unavailable"})
		return
	}
	if err != nil {
		adminResponse(c, err)
		return
	}
	adminOK(c, status, user)
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
	a.userRecord(c, user.ID, 201)
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
	a.userRecord(c, user.ID, 200)
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
