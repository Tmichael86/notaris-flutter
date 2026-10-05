package request

type CreateUserRequest struct {
	GroupID         uint    `json:"group_id" binding:"required"`
	Nama            string  `json:"nama" binding:"required"`
	NoTelp          *string `json:"no_telp" binding:"omitempty,numeric"`
	Email           string  `json:"email" binding:"required,email"`
	Username        string  `json:"username" binding:"required,alphanum"`
	Password        string  `json:"password" binding:"required"`
	PasswordConfirm string  `json:"password_confirm" binding:"required,eqfield=Password"`
	Alamat          *string `json:"alamat"`
	Image           *string `json:"image"`
}

type UpdateUserRequest struct {
	GroupID         uint    `json:"group_id" binding:"required"`
	Nama            string  `json:"nama" binding:"required"`
	NoTelp          *string `json:"no_telp" binding:"omitempty,numeric"`
	Email           string  `json:"email" binding:"required,email"`
	Username        string  `json:"username" binding:"required,alphanum"`
	Password        string  `json:"password"`
	PasswordConfirm string  `json:"password_confirm" binding:"omitempty,eqfield=Password"`
	Alamat          *string `json:"alamat"`
	Image           *string `json:"image"`
}
