package response

// Informational metadata only; no grant, actor or credential fields.
type SidebarCatalogRow struct {
	ID           uint    `json:"id"`
	Name         *string `json:"sidebar_nama"`
	Code         *string `json:"sidebar_kode"`
	Route        *string `json:"sidebar_route"`
	Icon         *string `json:"sidebar_icon"`
	Index        *int32  `json:"sidebar_index"`
	Status       *int16  `json:"status"`
	ParentID     *uint   `json:"sidebar_parent_id"`
	ParentName   *string `json:"parent_name"`
	ParentStatus *int16  `json:"parent_status"`
	ParentExists bool    `json:"parent_exists"`
	CreatedAt    *string `json:"created_at"`
}
type SidebarCatalogPage struct {
	Items      []SidebarCatalogRow `json:"items"`
	Total      int64               `json:"total"`
	Page       int                 `json:"page"`
	PageSize   int                 `json:"page_size"`
	TotalPages int64               `json:"total_pages"`
}
