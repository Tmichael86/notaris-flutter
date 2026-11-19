package services

import (
	"errors"
	"time"

	"backend-notaris-go/config"
	"backend-notaris-go/models"
	"backend-notaris-go/repositories"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

var ErrInvalidCredentials = errors.New("invalid credentials")

type AuthService struct {
	repository *repositories.UserRepository
	config     config.Config
}

type Claims struct {
	UID     uint   `json:"uid"`
	GID     uint   `json:"gid"`
	Version *int64 `json:"sv,omitempty"`
	jwt.RegisteredClaims
}

func NewAuthService(cfg config.Config) *AuthService {
	return &AuthService{
		repository: repositories.NewUserRepository(),
		config:     cfg,
	}
}

func (s *AuthService) Login(username, password string) (*models.User, string, error) {
	user, err := s.repository.FindActiveByLogin(username)
	if err != nil {
		return nil, "", ErrInvalidCredentials
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(password)); err != nil {
		return nil, "", ErrInvalidCredentials
	}

	expiration := time.Now().Add(time.Duration(s.config.JWTExpireMinutes) * time.Minute)
	claims := Claims{
		UID: user.ID,
		GID: user.GroupID,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   "user",
			ExpiresAt: jwt.NewNumericDate(expiration),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "backend-notaris-go",
		},
	}
	if s.config.UsersSecurityEnabled {
		if user.SecurityVersion < 1 {
			return nil, "", ErrInvalidCredentials
		}
		version := user.SecurityVersion
		claims.Version = &version
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString([]byte(s.config.JWTSecret))
	if err != nil {
		return nil, "", err
	}

	return user, tokenString, nil
}
