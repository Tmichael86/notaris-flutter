package response

import "backend-notaris-go/models"

type SidebarTree struct {
	Sidebar models.Sidebar   `json:"sidebar"`
	Childs  []models.Sidebar `json:"childs,omitempty"`
}
