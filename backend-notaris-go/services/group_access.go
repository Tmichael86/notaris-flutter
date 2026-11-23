package services

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"

	"backend-notaris-go/models"
	"gorm.io/gorm"
)

// The editor consumes one MVCC snapshot, including definitions it cannot edit.
// /auth/me/sidebar-access retains its existing operational response contract.
type AccessGroup struct {
	ID            uint   `json:"id"`
	Name          string `json:"group_nama"`
	Kind          string `json:"group_jenis"`
	Status        int16  `json:"status"`
	Revision      int64  `json:"revision"`
	ActiveMembers int64  `json:"active_members"`
}
type AccessDefinition struct {
	ID     uint   `json:"id"`
	Parent *uint  `json:"sidebar_parent_id"`
	Name   string `json:"sidebar_nama"`
	Code   string `json:"sidebar_kode"`
	Route  string `json:"sidebar_route"`
	Icon   string `json:"sidebar_icon"`
	Index  int32  `json:"sidebar_index"`
	Status int16  `json:"status"`
}
type AccessEntry struct {
	Sidebar  AccessDefinition `json:"sidebar"`
	Read     int16            `json:"read"`
	Create   int16            `json:"create"`
	Update   int16            `json:"update"`
	Delete   int16            `json:"delete"`
	Editable bool             `json:"editable"`
	Reason   string           `json:"reason"`
}
type GroupAccessSnapshot struct {
	Group   AccessGroup   `json:"group"`
	Catalog string        `json:"catalog_fingerprint"`
	Entries []AccessEntry `json:"entries"`
}

func accessCatalog(tx *gorm.DB) ([]AccessEntry, string, error) {
	var defs []AccessDefinition
	if e := tx.Table("sidebar").Select("id,sidebar_parent_id AS parent,sidebar_nama AS name,sidebar_kode AS code,sidebar_route AS route,sidebar_icon AS icon,sidebar_index AS index,status").Order("id").Limit(1001).Find(&defs).Error; e != nil {
		return nil, "", e
	}
	if len(defs) > 1000 {
		return nil, "", adminError(422, "catalog_too_large")
	}
	byID := map[uint]AccessDefinition{}
	codes := map[string]bool{}
	for _, d := range defs {
		if d.ID == 0 || d.Code == "" || codes[d.Code] || (d.Status != 0 && d.Status != 1) {
			return nil, "", adminError(422, "invalid_catalog")
		}
		byID[d.ID] = d
		codes[d.Code] = true
	}
	b, e := json.Marshal(defs)
	if e != nil {
		return nil, "", e
	}
	h := sha256.Sum256(b)
	entries := make([]AccessEntry, 0, len(defs))
	for _, d := range defs {
		reason := ""
		seen := map[uint]bool{}
		cur := d
		for {
			if seen[cur.ID] {
				reason = "Hierarki siklik; hanya baca"
				break
			}
			seen[cur.ID] = true
			if cur.Status != 1 {
				reason = "Sidebar atau parent nonaktif; hanya baca"
				break
			}
			if cur.Parent == nil || *cur.Parent == 0 {
				break
			}
			parent, ok := byID[*cur.Parent]
			if !ok {
				reason = "Parent tidak tersedia; hanya baca"
				break
			}
			cur = parent
		}
		entries = append(entries, AccessEntry{Sidebar: d, Editable: reason == "", Reason: reason})
	}
	return entries, hex.EncodeToString(h[:]), nil
}

func accessSnapshot(tx *gorm.DB, id uint) (GroupAccessSnapshot, error) {
	var out GroupAccessSnapshot
	var g models.Group
	if e := tx.First(&g, id).Error; e != nil {
		return out, adminError(404, "group_unavailable")
	}
	out.Group = AccessGroup{ID: g.ID, Name: g.GroupNama, Kind: g.GroupJenis, Status: g.Status, Revision: g.Revision}
	if e := tx.Model(&models.User{}).Where("group_id=? AND status=1", id).Count(&out.Group.ActiveMembers).Error; e != nil {
		return out, e
	}
	var e error
	out.Entries, out.Catalog, e = accessCatalog(tx)
	if e != nil {
		return out, e
	}
	index := map[uint]int{}
	for i, row := range out.Entries {
		index[row.Sidebar.ID] = i
	}
	var grants []models.SidebarAccess
	if e = tx.Where("group_id=?", id).Order("sidebar_id").Find(&grants).Error; e != nil {
		return out, e
	}
	seen := map[uint]bool{}
	for _, p := range grants {
		i, ok := index[p.SidebarID]
		if !ok || seen[p.SidebarID] || p.Read < 0 || p.Read > 1 || p.Create < 0 || p.Create > 1 || p.Update < 0 || p.Update > 1 || p.Delete < 0 || p.Delete > 1 {
			return out, adminError(422, "invalid_grant_snapshot")
		}
		seen[p.SidebarID] = true
		r := &out.Entries[i]
		r.Read = p.Read
		r.Create = p.Create
		r.Update = p.Update
		r.Delete = p.Delete
	}
	return out, nil
}

func (a Administration) GroupAccess(ctx context.Context, actor AdminActor, id uint) (GroupAccessSnapshot, error) {
	var out GroupAccessSnapshot
	if !a.Enabled {
		return out, adminError(503, "admin_security_not_enabled")
	}
	e := a.DB.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if e := a.authorize(tx, actor, "groups", "read"); e != nil {
			return e
		}
		var e error
		out, e = accessSnapshot(tx, id)
		return e
	}, &sql.TxOptions{Isolation: sql.LevelRepeatableRead, ReadOnly: true})
	return out, adminSafeRead(e)
}
