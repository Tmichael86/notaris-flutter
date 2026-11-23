package controllers

import (
	"encoding/json"
	"errors"
	"strconv"
	"strings"

	"backend-notaris-go/services"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type managedGroup struct {
	ID            uint   `json:"id"`
	GroupNama     string `json:"group_nama"`
	GroupJenis    string `json:"group_jenis"`
	Status        int16  `json:"status"`
	Revision      int64  `json:"revision"`
	ActiveMembers int64  `json:"active_members"`
	TotalMembers  int64  `json:"total_members"`
	Membership    string `json:"membership"`
}

const managedGroupColumns = `g.id,g.group_nama,g.group_jenis,g.status,g.revision,
 (SELECT count(*) FROM users m WHERE m.group_id=g.id AND m.status=1) AS active_members,
 (SELECT count(*) FROM users m WHERE m.group_id=g.id) AS total_members,
 (SELECT ` + services.GroupMembershipSQL + ` FROM users m WHERE m.group_id=g.id) AS membership`

func (a *AdministrationController) Groups(c *gin.Context) {
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
	query := a.service.DB.Table("groups g")
	if search != "" {
		query = query.Where("strpos(lower(g.group_nama),lower(?))>0", search)
	}
	if kind, ok := c.GetQuery("group_jenis"); ok {
		if kind != "user" && kind != "superadmin" {
			a.reject(c, "invalid_group_filter")
			return
		}
		query = query.Where("g.group_jenis=?", kind)
	}
	// Active is the default; all statuses must be explicitly requested.
	status := c.DefaultQuery("status", "1")
	if status != "all" {
		if status != "0" && status != "1" {
			a.reject(c, "invalid_status_filter")
			return
		}
		query = query.Where("g.status=?", status)
	}
	var result struct {
		Total int64
		Items json.RawMessage
	}
	filtered := query.Select(managedGroupColumns)
	if e := a.service.DB.Raw("WITH filtered AS (?), page AS (SELECT * FROM filtered ORDER BY id LIMIT ? OFFSET ?) SELECT (SELECT count(*) FROM filtered) AS total,coalesce((SELECT json_agg(page ORDER BY id) FROM page),'[]'::json) AS items", filtered, size, (page-1)*size).Scan(&result).Error; e != nil {
		adminResponse(c, e)
		return
	}
	rows := []managedGroup{}
	if e := json.Unmarshal(result.Items, &rows); e != nil {
		adminResponse(c, e)
		return
	}
	adminOK(c, 200, gin.H{"items": rows, "total": result.Total, "page": page, "page_size": size})
}
func (a *AdministrationController) GroupDetail(c *gin.Context) {
	id, ok := a.id(c)
	if !ok {
		return
	}
	var row managedGroup
	e := a.service.DB.Table("groups g").Select(managedGroupColumns).Where("g.id=?", id).Take(&row).Error
	if errors.Is(e, gorm.ErrRecordNotFound) {
		e = &services.AdminError{Status: 404, Code: "group_unavailable"}
	}
	if e != nil {
		adminResponse(c, e)
		return
	}
	adminOK(c, 200, row)
}
