package devfixture_test

import (
	"backend-notaris-go/config"
	"backend-notaris-go/controllers"
	"backend-notaris-go/database"
	"backend-notaris-go/middleware"
	"backend-notaris-go/repositories"
	"backend-notaris-go/services"
	"bytes"
	"encoding/json"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"net/http/httptest"
	"os"
	"regexp"
	"testing"
)

func TestSyntheticHTTP(t *testing.T) {
	dsn := os.Getenv("NOTARIS_FIXTURE_HTTP_DSN")
	if dsn == "" {
		t.Skip("isolated synthetic fixture DSN unset")
	}
	parsed, err := pgx.ParseConfig(dsn)
	if err != nil || parsed.Port == 5432 || (parsed.Host != "127.0.0.1" && parsed.Host != "localhost") || !regexp.MustCompile(`^notaris_fixture_test_[a-f0-9]+$`).MatchString(parsed.Database) {
		t.Fatal("unsafe test target")
	}
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatal("test connection failed")
	}
	pool, _ := db.DB()
	defer pool.Close()
	old := database.DB
	database.DB = db
	defer func() { database.DB = old }()
	cfg := config.Config{JWTSecret: "fixture-only-test-secret-not-a-production-secret", JWTExpireMinutes: 30}
	r := gin.New()
	r.POST("/login", controllers.NewAuthController(services.NewAuthService(cfg)).Login)
	r.GET("/me", middleware.JWTAuth(cfg), controllers.NewMeController().SidebarAccess)
	r.GET("/categories", middleware.JWTAuth(cfg), middleware.RequirePermission(repositories.NewSidebarAccessRepository(), "kategori_pekerjaan", middleware.PermissionRead), controllers.NewSimpleMasterController("pekerjaan_kategori", "fixture").GetAll)
	call := func(path, token string, body []byte) *httptest.ResponseRecorder {
		method := "GET"
		if body != nil {
			method = "POST"
		}
		req := httptest.NewRequest(method, path, bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		if token != "" {
			req.Header.Set("Authorization", "Bearer "+token)
		}
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		return w
	}
	input, _ := json.Marshal(map[string]string{"username": "fixture.operator", "password": os.Getenv("NOTARIS_DEV_FIXTURE_PASSWORD")})
	login := call("/login", "", input)
	if login.Code != 200 {
		t.Fatalf("fixture normal login failed status=%d", login.Code)
	}
	var envelope struct {
		Data struct {
			Token string `json:"token"`
		} `json:"data"`
	}
	if json.Unmarshal(login.Body.Bytes(), &envelope) != nil || envelope.Data.Token == "" {
		t.Fatal("missing fresh login JWT")
	}
	for _, path := range []string{"/me", "/categories"} {
		if w := call(path, envelope.Data.Token, nil); w.Code != 200 {
			t.Fatalf("normal permission flow %s status %d", path, w.Code)
		}
	}
	if w := call("/categories", "", nil); w.Code != 401 {
		t.Fatal("anonymous request allowed")
	}
}
