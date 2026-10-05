package request

type CreateGroupRequest struct {
	GroupNama  string `json:"group_nama" binding:"required"`
	GroupJenis string `json:"group_jenis" binding:"required,oneof=superadmin user"`
}

type UpdateGroupRequest struct {
	GroupNama  string `json:"group_nama" binding:"required"`
	GroupJenis string `json:"group_jenis" binding:"required,oneof=superadmin user"`
}
