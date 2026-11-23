package repositories

import (
	"backend-notaris-go/database"
	"backend-notaris-go/dto/response"
	"backend-notaris-go/models"
	"context"
	"encoding/json"

	"gorm.io/gorm"
)

type SidebarRepository struct{ db *gorm.DB }

// Count and page share one PostgreSQL snapshot, including out-of-range pages.
// Literal strpos deliberately does not interpret LIKE wildcard characters.
func (r *SidebarRepository) Catalog(ctx context.Context, page, size int, search, status string) (response.SidebarCatalogPage, error) {
	var row struct {
		Total int64
		Items string
	}
	err := r.db.WithContext(ctx).Raw(`WITH filtered AS MATERIALIZED (
 SELECT s.id,s.sidebar_nama,s.sidebar_kode,s.sidebar_route,s.sidebar_icon,s.sidebar_index,s.status,s.sidebar_parent_id,s.created_at,
 p.sidebar_nama AS parent_name,p.status AS parent_status,(p.id IS NOT NULL) AS parent_exists
 FROM sidebar s LEFT JOIN sidebar p ON p.id=s.sidebar_parent_id
 WHERE (?='all' OR (?='active' AND s.status=1) OR (?='inactive' AND s.status=0))
 AND (?='' OR strpos(lower(concat_ws(' ',s.sidebar_nama,s.sidebar_kode,s.sidebar_route,s.sidebar_icon,p.sidebar_nama,s.id::text,s.sidebar_parent_id::text)),lower(?))>0)
), paged AS (SELECT * FROM filtered ORDER BY sidebar_index ASC NULLS LAST,id ASC LIMIT ? OFFSET ?)
SELECT (SELECT count(*) FROM filtered) AS total,coalesce((SELECT json_agg(paged ORDER BY sidebar_index ASC NULLS LAST,id ASC) FROM paged),'[]'::json)::text AS items`, status, status, status, search, search, size, (page-1)*size).Scan(&row).Error
	out := response.SidebarCatalogPage{Page: page, PageSize: size, Total: row.Total, TotalPages: (row.Total + int64(size) - 1) / int64(size), Items: []response.SidebarCatalogRow{}}
	if out.TotalPages == 0 {
		out.TotalPages = 1
	}
	if err != nil {
		return out, err
	}
	err = json.Unmarshal([]byte(row.Items), &out.Items)
	return out, err
}

func NewSidebarRepository() *SidebarRepository {
	return &SidebarRepository{db: database.DB}
}

func (r *SidebarRepository) FindAllActive() ([]models.Sidebar, error) {
	var sidebars []models.Sidebar
	err := r.db.Where("status = ?", 1).
		Order("sidebar_parent_id ASC").
		Order("sidebar_index ASC").
		Order("id ASC").
		Find(&sidebars).Error
	return sidebars, err
}

func (r *SidebarRepository) FindByID(id uint) (*models.Sidebar, error) {
	var sidebar models.Sidebar
	err := r.db.First(&sidebar, id).Error
	if err != nil {
		return nil, err
	}
	return &sidebar, nil
}
