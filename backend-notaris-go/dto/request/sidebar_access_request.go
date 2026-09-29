package request

type SidebarAccessItem struct {
	SidebarID uint  `json:"sidebar_id" binding:"required"`
	Read      int16 `json:"read" binding:"oneof=0 1"`
	Create    int16 `json:"create" binding:"oneof=0 1"`
	Update    int16 `json:"update" binding:"oneof=0 1"`
	Delete    int16 `json:"delete" binding:"oneof=0 1"`
}

type UpdateSidebarAccessRequest struct {
	Access []SidebarAccessItem `json:"access" binding:"required"`
}
