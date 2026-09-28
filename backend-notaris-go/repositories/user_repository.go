package repositories

import (
	"backend-notaris-go/database"
	"backend-notaris-go/models"

	"gorm.io/gorm"
)

type UserRepository struct {
	db *gorm.DB
}

func NewUserRepository() *UserRepository {
	return &UserRepository{db: database.DB}
}

func (r *UserRepository) FindAll() ([]models.User, error) {
	var users []models.User
	err := r.db.Table("users").
		Select("users.*, groups.group_nama AS group_nama").
		Joins("LEFT JOIN groups ON groups.id = users.group_id").
		Where("users.status = ?", 1).
		Order("users.id ASC").Find(&users).Error
	return users, err
}

func (r *UserRepository) FindByID(id uint) (*models.User, error) {
	var user models.User
	err := r.db.Table("users").
		Select("users.*, groups.group_nama AS group_nama").
		Joins("LEFT JOIN groups ON groups.id = users.group_id").
		First(&user, id).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *UserRepository) FindActiveByLogin(login string) (*models.User, error) {
	var user models.User
	err := r.db.Table("users").
		Select("users.*, groups.group_nama AS group_nama").
		Joins("LEFT JOIN groups ON groups.id = users.group_id").
		Where("users.status = ?", 1).
		Where("users.username = ? OR users.email = ?", login, login).
		First(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *UserRepository) Create(user *models.User) error { return r.db.Create(user).Error }
func (r *UserRepository) Update(user *models.User) error { return r.db.Save(user).Error }
func (r *UserRepository) Deactivate(user *models.User) error {
	return r.db.Model(user).Update("status", 0).Error
}
