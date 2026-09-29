package response

import "backend-notaris-go/models"

type SidebarAccessResponse struct {
SidebarID uint `json:"sidebar_id"`
Sidebar models.Sidebar `json:"sidebar"`
Read int16 `json:"read"`
Create int16 `json:"create"`
Update int16 `json:"update"`
Delete int16 `json:"delete"`
}
