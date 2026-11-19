// The payment demo is a Windows-only provisioning and offline unlock tool.
package main

import (
	"bytes"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
	"unsafe"

	"backend-notaris-go/config"
	"backend-notaris-go/controllers"
	"backend-notaris-go/database"
	"backend-notaris-go/middleware"
	"backend-notaris-go/models"
	"backend-notaris-go/services"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
	"golang.org/x/sys/windows"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var rejected = errors.New("profil, kredensial, atau sesi demo tidak valid")
var idPattern = regexp.MustCompile(`^[0-9a-f]{32}$`)

type account struct {
	Username string `json:"username"`
	ID       uint   `json:"id"`
	Name     string `json:"-"`
	Role     string `json:"role"`
	Update   int    `json:"update"`
	Create   int    `json:"create"`
}

var accounts = []account{
	{"petugas.demo", 101, "Dimas Prasetyo", "user", 1, 1},
	{"admin.demo", 102, "Rani Wulandari", "superadmin", 1, 0},
	{"pembaca.demo", 103, "Nadia Pertiwi", "user", 0, 0},
}

func lookup(name string) (account, error) {
	if name == presentationAccount.Username {
		return presentationAccount, nil
	}
	for _, a := range accounts {
		if a.Username == name {
			return a, nil
		}
	}
	return account{}, rejected
}

type access struct {
	Read    int `json:"read"`
	Create  int `json:"create"`
	Update  int `json:"update"`
	Delete  int `json:"delete"`
	Sidebar struct {
		Code   string `json:"sidebar_kode"`
		Name   string `json:"sidebar_nama"`
		Status int    `json:"status"`
	} `json:"sidebar"`
}

type verifiedSession struct {
	Profile    string    `json:"profile"`
	Username   string    `json:"username"`
	UserID     uint      `json:"userId"`
	GroupID    uint      `json:"groupId"`
	UserName   string    `json:"userName"`
	GroupName  string    `json:"groupName"`
	GroupType  string    `json:"groupType"`
	VerifiedAt time.Time `json:"verifiedAt"`
	ExpiresAt  time.Time `json:"expiresAt"`
	Sidebars   []access  `json:"sidebars"`
}

type storedSession struct {
	Session verifiedSession `json:"session"`
	Hash    []byte          `json:"passwordHash"`
}

func (s verifiedSession) valid(id string, a account, now time.Time) bool {
	return s.validFor(id, a, now, "")
}

func expenseAccess(a account) (read, write int) {
	switch a.Username {
	case "petugas.demo":
		return 1, 1
	case "pembaca.demo":
		return 1, 0
	default:
		return 0, 0
	}
}

func (s verifiedSession) validFor(id string, a account, now time.Time, scope string) bool {
	if !(s.Profile == id && s.Username == a.Username &&
		s.UserID == a.ID && s.GroupID == a.ID && s.GroupType == a.Role &&
		s.UserName != "" && s.GroupName != "" && !s.VerifiedAt.IsZero() &&
		!now.Before(s.VerifiedAt) && now.Before(s.ExpiresAt) &&
		s.ExpiresAt.Sub(s.VerifiedAt) <= 24*time.Hour) {
		return false
	}
	if scope == "presentation" {
		return presentationAccessValid(a, s.Sidebars)
	}
	if a == presentationAccount {
		return false
	}
	allowed := a.Username == "pembaca.demo"
	expenseRead, expenseWrite := expenseAccess(a)
	create, update := a.Create, a.Update
	if scope != "" {
		create, update = 0, 0
	}
	if scope == "materai-usage" && a.Username == "admin.demo" {
		create, update = 1, 1
	}
	want := 1
	if scope != "" {
		want++
	}
	if len(s.Sidebars) != want {
		return false
	}
	found := map[string]bool{}
	for _, p := range s.Sidebars {
		if found[p.Sidebar.Code] || p.Sidebar.Status != 1 {
			return false
		}
		found[p.Sidebar.Code] = true
		switch p.Sidebar.Code {
		case "transaksi":
			if p.Read != 1 || p.Create != create || p.Update != update || (scope != "" && p.Delete != 0) {
				return false
			}
		case "monitoring":
			if scope != "monitoring" || (p.Read == 1) != allowed || p.Read < 0 || p.Read > 1 ||
				p.Sidebar.Name != "Monitoring" || p.Create != 0 || p.Update != 0 || p.Delete != 0 {
				return false
			}
		case "pengeluaran":
			if scope != "pengeluaran" || p.Sidebar.Name != "Pengeluaran" ||
				p.Read != expenseRead || p.Create != expenseWrite || p.Update != expenseWrite || p.Delete != expenseWrite {
				return false
			}
		case "laporan_materai":
			read, create := materaiAccess(a)
			if scope == "materai-usage" {
				create = 0
			}
			if (scope != "materai" && scope != "materai-usage") || p.Sidebar.Name != "Materai" || p.Read != read ||
				p.Create != create || p.Update != 0 || p.Delete != 0 {
				return false
			}
		default:
			return false
		}
	}
	if scope == "materai" || scope == "materai-usage" {
		return found["transaksi"] && found["laporan_materai"]
	}
	return found["transaksi"] && (scope == "" || found[scope])
}

func materaiAccess(a account) (int, int) {
	switch a.Username {
	case "admin.demo":
		return 1, 1
	case "pembaca.demo":
		return 1, 0
	default:
		return 0, 0
	}
}

func profileID(public ed25519.PublicKey) string {
	hash := sha256.Sum256(public)
	return hex.EncodeToString(hash[:16])
}

func profileRoot(id string) (string, error) {
	if !idPattern.MatchString(id) {
		return "", rejected
	}
	temp, err := filepath.EvalSymlinks(os.TempDir())
	if err != nil {
		return "", rejected
	}
	return filepath.Join(temp, "notaris-payment-"+id), nil
}

func readOwnedFile(root, name string) ([]byte, error) {
	file, err := openOwnedFile(root, name)
	if err != nil {
		return nil, err
	}
	defer file.Close()
	info, err := file.Stat()
	if err != nil || info.Size() > 65536 {
		return nil, rejected
	}
	return io.ReadAll(io.LimitReader(file, 65537))
}

func openOwnedFile(root, name string) (*os.File, error) {
	path := filepath.Join(root, name)
	resolved, err := filepath.EvalSymlinks(path)
	if err != nil || !strings.EqualFold(path, resolved) {
		return nil, rejected
	}
	file, err := os.Open(path)
	if err != nil {
		return nil, rejected
	}
	var info windows.ByHandleFileInformation
	if windows.GetFileInformationByHandle(windows.Handle(file.Fd()), &info) != nil ||
		info.NumberOfLinks != 1 ||
		info.FileAttributes&(windows.FILE_ATTRIBUTE_DIRECTORY|windows.FILE_ATTRIBUTE_REPARSE_POINT) != 0 {
		file.Close()
		return nil, rejected
	}
	return file, nil
}

func dataBlob(b []byte) windows.DataBlob {
	return windows.DataBlob{Size: uint32(len(b)), Data: unsafe.SliceData(b)}
}

func dpapi(input, context []byte, protect bool) ([]byte, error) {
	source, entropy := dataBlob(input), dataBlob(context)
	var result windows.DataBlob
	var err error
	if protect {
		err = windows.CryptProtectData(&source, nil, &entropy, 0, nil, windows.CRYPTPROTECT_UI_FORBIDDEN, &result)
	} else {
		err = windows.CryptUnprotectData(&source, nil, &entropy, 0, nil, windows.CRYPTPROTECT_UI_FORBIDDEN, &result)
	}
	if err != nil {
		return nil, rejected
	}
	defer windows.LocalFree(windows.Handle(uintptr(unsafe.Pointer(result.Data))))
	raw := unsafe.Slice(result.Data, result.Size)
	defer clear(raw)
	return bytes.Clone(raw), nil
}

func seal(root, id, name string, value any, private ed25519.PrivateKey) error {
	plaintext, err := json.Marshal(value)
	if err != nil {
		return err
	}
	defer clear(plaintext)
	context := []byte("notaris-payment-demo/v1/" + id + "/" + name)
	ciphertext, err := dpapi(plaintext, context, true)
	if err != nil {
		return err
	}
	message := append(bytes.Clone(context), ciphertext...)
	return writeNew(filepath.Join(root, name+".bin"), append(ed25519.Sign(private, message), ciphertext...))
}

func unseal(root, id, name string, result any) error {
	owner, err := readOwnedFile(root, "owner")
	if err != nil || string(owner) != id {
		return rejected
	}
	public, err := readOwnedFile(root, "public.key")
	if err != nil || len(public) != ed25519.PublicKeySize || profileID(public) != id {
		return rejected
	}
	packed, err := readOwnedFile(root, name+".bin")
	if err != nil || len(packed) <= ed25519.SignatureSize {
		return rejected
	}
	context := []byte("notaris-payment-demo/v1/" + id + "/" + name)
	ciphertext := packed[ed25519.SignatureSize:]
	if !ed25519.Verify(public, append(bytes.Clone(context), ciphertext...), packed[:ed25519.SignatureSize]) {
		return rejected
	}
	cleartext, err := dpapi(ciphertext, context, false)
	if err != nil {
		return rejected
	}
	defer clear(cleartext)
	if json.Unmarshal(cleartext, result) != nil {
		return rejected
	}
	return nil
}

func writeNew(path string, value []byte) error {
	file, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		return err
	}
	defer file.Close()
	_, err = file.Write(value)
	return err
}

func demoScope(root, id string) (string, error) {
	scope := ""
	for _, candidate := range []string{"monitoring", "pengeluaran", "presentation", "materai", "materai-usage"} {
		name := candidate + "-owner"
		if _, err := os.Lstat(filepath.Join(root, name)); !os.IsNotExist(err) {
			marker, readErr := readOwnedFile(root, name)
			if scope != "" || readErr != nil || string(marker) != id {
				return "", rejected
			}
			scope = candidate
		}
	}
	return scope, nil
}

func activeSession(root, id string, a account, now time.Time) (storedSession, error) {
	scope, err := demoScope(root, id)
	var stored storedSession
	if err != nil || unseal(root, id, a.Username, &stored) != nil || !stored.Session.validFor(id, a, now, scope) {
		return storedSession{}, rejected
	}
	return stored, nil
}

func unlock(root, id string, a account, password string, now time.Time) (verifiedSession, error) {
	stored, err := activeSession(root, id, a, now)
	if err != nil || bcrypt.CompareHashAndPassword(stored.Hash, []byte(password)) != nil {
		return verifiedSession{}, rejected
	}
	return stored.Session, nil
}

func verifyAccount(server *httptest.Server, cfg config.Config, id string, a account, password, scope string) (verifiedSession, error) {
	payload, _ := json.Marshal(map[string]string{"username": a.Username, "password": password})
	defer clear(payload)
	resp, err := server.Client().Post(server.URL+"/api/v1/auth/login", "application/json", bytes.NewReader(payload))
	if err != nil {
		return verifiedSession{}, rejected
	}
	var login struct {
		Data struct {
			Token string `json:"token"`
		} `json:"data"`
	}
	err = json.NewDecoder(resp.Body).Decode(&login)
	resp.Body.Close()
	if err != nil || resp.StatusCode != http.StatusOK {
		return verifiedSession{}, rejected
	}
	claims := services.Claims{}
	token, err := jwt.ParseWithClaims(login.Data.Token, &claims, func(_ *jwt.Token) (any, error) {
		return []byte(cfg.JWTSecret), nil
	}, jwt.WithValidMethods([]string{"HS256"}), jwt.WithIssuer("backend-notaris-go"), jwt.WithExpirationRequired())
	if err != nil || !token.Valid || claims.UID != a.ID || claims.GID != a.ID {
		return verifiedSession{}, rejected
	}
	req, _ := http.NewRequest(http.MethodGet, server.URL+"/api/v1/auth/me/sidebar-access", nil)
	req.Header.Set("Authorization", "Bearer "+login.Data.Token)
	resp, err = server.Client().Do(req)
	if err != nil {
		return verifiedSession{}, rejected
	}
	defer resp.Body.Close()
	var info struct {
		Data struct {
			User struct {
				ID       uint   `json:"id"`
				GroupID  uint   `json:"group_id"`
				Username string `json:"username"`
				Name     string `json:"nama"`
				Group    string `json:"group_nama"`
			} `json:"user"`
			Role     string    `json:"group_jenis"`
			Verified time.Time `json:"permissions_checked_at"`
			Sidebars []access  `json:"sidebars"`
		} `json:"data"`
	}
	if json.NewDecoder(resp.Body).Decode(&info) != nil || resp.StatusCode != http.StatusOK {
		return verifiedSession{}, rejected
	}
	d := info.Data
	s := verifiedSession{id, d.User.Username, d.User.ID, d.User.GroupID, d.User.Name, d.User.Group,
		d.Role, d.Verified, claims.ExpiresAt.Time, d.Sidebars}
	if !s.validFor(id, a, time.Now(), scope) {
		return verifiedSession{}, rejected
	}
	return s, nil
}

func provision(dbName, dataDir, scope string) (string, error) {
	password := os.Getenv("PGPASSWORD")
	if !regexp.MustCompile(`^payment_demo_[0-9a-f]{16}$`).MatchString(dbName) ||
		!regexp.MustCompile(`^[0-9a-f]{64}$`).MatchString(password) {
		return "", rejected
	}
	dsn := "postgres://postgres:" + password + "@127.0.0.1:55674/" + dbName + "?sslmode=disable"
	db, err := gorm.Open(postgres.Open(dsn),
		&gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
	if err != nil {
		return "", rejected
	}
	pool, err := db.DB()
	if err != nil {
		return "", rejected
	}
	defer pool.Close()
	var name, host, marker, dir string
	var port int
	err = pool.QueryRow(`SELECT current_database(), host(inet_server_addr()), inet_server_port(),
		coalesce(shobj_description(oid,'pg_database'),''), current_setting('data_directory')
		FROM pg_database WHERE datname=current_database()`).Scan(&name, &host, &port, &marker, &dir)
	if err != nil || name != dbName || host != "127.0.0.1" || port != 55674 ||
		marker != "NOTARIS PAYMENT DISPOSABLE "+dbName ||
		!strings.EqualFold(filepath.Clean(dir), filepath.Clean(dataDir)) {
		return "", rejected
	}
	if err = db.AutoMigrate(&models.Group{}, &models.User{}, &models.Sidebar{}, &models.SidebarAccess{}); err != nil {
		return "", err
	}
	passwords, hashes := map[string]string{}, map[string][]byte{}
	selected := accounts
	if scope == "presentation" {
		selected = []account{presentationAccount}
	}
	err = db.Transaction(func(tx *gorm.DB) error {
		if scope != "presentation" {
			if e := tx.Exec("INSERT INTO sidebar(id,sidebar_nama,sidebar_kode,sidebar_route,status) VALUES(1,'Transaksi','transaksi','/transaksi',1)").Error; e != nil {
				return e
			}
			if scope == "monitoring" {
				if e := tx.Exec("INSERT INTO sidebar(id,sidebar_nama,sidebar_kode,sidebar_route,status) VALUES(2,'Monitoring','monitoring','/monitoring',1)").Error; e != nil {
					return e
				}
			}
			if scope == "pengeluaran" {
				if e := tx.Exec("INSERT INTO sidebar(id,sidebar_nama,sidebar_kode,sidebar_route,status) VALUES(2,'Pengeluaran','pengeluaran','/pengeluaran',1)").Error; e != nil {
					return e
				}
			}
			if scope == "materai" || scope == "materai-usage" {
				if e := tx.Exec("INSERT INTO sidebar(id,sidebar_nama,sidebar_kode,sidebar_route,status) VALUES(2,'Materai','laporan_materai','/laporan/materai',1)").Error; e != nil {
					return e
				}
			}
		}
		for _, a := range selected {
			password := base64.RawURLEncoding.EncodeToString(randomBytes(24))
			hash, e := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
			if e != nil {
				return e
			}
			passwords[a.Username], hashes[a.Username] = password, hash
			if e = tx.Exec("INSERT INTO groups(id,group_nama,group_jenis,status) VALUES(?,?,?,1)", a.ID, a.Name, a.Role).Error; e != nil {
				return e
			}
			if e = tx.Exec("INSERT INTO users(id,group_id,username,nama,password,status) VALUES(?,?,?,?,?,1)", a.ID, a.ID, a.Username, a.Name, string(hash)).Error; e != nil {
				return e
			}
			if scope == "presentation" {
				continue
			}
			create, update := a.Create, a.Update
			if scope != "" {
				create, update = 0, 0
			}
			if scope == "materai-usage" && a.Username == "admin.demo" {
				create, update = 1, 1
			}
			if e = tx.Exec(`INSERT INTO sidebar_akses(group_id,sidebar_id,"read","create","update","delete") VALUES(?,1,1,?,?,0)`, a.ID, create, update).Error; e != nil {
				return e
			}
			if scope == "monitoring" && a.Username == "pembaca.demo" {
				if e = tx.Exec(`INSERT INTO sidebar_akses(group_id,sidebar_id,"read","create","update","delete") VALUES(?,2,1,0,0,0)`, a.ID).Error; e != nil {
					return e
				}
			}
			if scope == "pengeluaran" {
				read, write := expenseAccess(a)
				if e = tx.Exec(`INSERT INTO sidebar_akses(group_id,sidebar_id,"read","create","update","delete") VALUES(?,2,?,?,?,?)`, a.ID, read, write, write, write).Error; e != nil {
					return e
				}
			}
			if scope == "materai" || scope == "materai-usage" {
				read, create := materaiAccess(a)
				if scope == "materai-usage" {
					create = 0
				}
				if e = tx.Exec(`INSERT INTO sidebar_akses(group_id,sidebar_id,"read","create","update","delete") VALUES(?,2,?,?,0,0)`, a.ID, read, create).Error; e != nil {
					return e
				}
			}
		}
		if scope == "presentation" {
			return seedPresentationMenus(tx)
		}
		return nil
	})
	if err != nil {
		return "", err
	}
	database.DB = db
	cfg := config.Config{JWTSecret: hex.EncodeToString(randomBytes(32)), JWTExpireMinutes: 1440}
	gin.SetMode(gin.ReleaseMode)
	router := gin.New()
	router.POST("/api/v1/auth/login", controllers.NewAuthController(services.NewAuthService(cfg)).Login)
	router.GET("/api/v1/auth/me/sidebar-access", middleware.JWTAuth(cfg), controllers.NewMeController().SidebarAccess)
	server := httptest.NewServer(router)
	defer server.Close()
	public, private, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return "", err
	}
	defer clear(private)
	id := profileID(public)
	sessions := make(map[string]verifiedSession)
	for _, a := range selected {
		s, e := verifyAccount(server, cfg, id, a, passwords[a.Username], scope)
		if e != nil {
			return "", e
		}
		sessions[a.Username] = s
	}
	wrongAccount, wrongPassword := selected[0], "invalid-demo-credential"
	if len(selected) > 1 {
		wrongAccount, wrongPassword = selected[1], passwords[selected[0].Username]
	}
	if _, err = verifyAccount(server, cfg, id, wrongAccount, wrongPassword, scope); err == nil {
		return "", rejected
	}
	root, err := profileRoot(id)
	if err != nil {
		return "", err
	}
	if err = os.Mkdir(root, 0700); err != nil {
		return "", err
	}
	if err = writeNew(filepath.Join(root, "owner"), []byte(id)); err != nil {
		return "", err
	}
	if scope != "" {
		if err = writeNew(filepath.Join(root, scope+"-owner"), []byte(id)); err != nil {
			return "", err
		}
	}
	if err = writeNew(filepath.Join(root, "public.key"), public); err != nil {
		return "", err
	}
	for _, a := range selected {
		if err = seal(root, id, a.Username, storedSession{sessions[a.Username], hashes[a.Username]}, private); err != nil {
			return "", err
		}
		if err = seal(root, id, "handoff-"+a.Username, passwords[a.Username], private); err != nil {
			return "", err
		}
		if _, err = unlock(root, id, a, passwords[a.Username], time.Now()); err != nil {
			return "", err
		}
	}
	return id, nil
}

func randomBytes(n int) []byte {
	data := make([]byte, n)
	if _, err := rand.Read(data); err != nil {
		panic("random generator unavailable")
	}
	return data
}

func run(args []string) error {
	if len(args) > 0 && strings.HasPrefix(args[0], "promo-") {
		return runPromotional(args)
	}
	if len(args) == 3 && (args[0] == "provision" || args[0] == "provision-monitoring" || args[0] == "provision-pengeluaran" || args[0] == "provision-presentation" || args[0] == "provision-materai" || args[0] == "provision-materai-usage") {
		scope := strings.TrimPrefix(args[0], "provision")
		id, err := provision(args[1], args[2], strings.TrimPrefix(scope, "-"))
		if err == nil {
			fmt.Println(id)
		}
		return err
	}
	if len(args) < 2 || len(args) > 3 {
		return rejected
	}
	id := args[1]
	root, err := profileRoot(id)
	if err != nil {
		return rejected
	}
	if (args[0] == "verify" || args[0] == "verify-db") && len(args) == 2 {
		if args[0] == "verify-db" {
			file, err := openOwnedFile(root, "offline.sqlite")
			if err != nil {
				return err
			}
			file.Close()
		}
		scope, err := demoScope(root, id)
		if err != nil {
			return err
		}
		selected := accounts
		if scope == "presentation" {
			selected = []account{presentationAccount}
		}
		var output []map[string]any
		for _, a := range selected {
			stored, e := activeSession(root, id, a, time.Now())
			if e != nil {
				return e
			}
			s := stored.Session
			info := map[string]any{"username": s.Username, "id": s.UserID, "role": s.GroupType,
				"expiresAt": s.ExpiresAt}
			if scope == "presentation" {
				info["groupId"], info["sidebars"] = s.GroupID, s.Sidebars
				info["verifiedAt"], info["userName"], info["groupName"] = s.VerifiedAt, s.UserName, s.GroupName
			}
			for _, p := range s.Sidebars {
				switch p.Sidebar.Code {
				case "monitoring":
					info["monitoring"] = p.Read
				case "pengeluaran":
					info["pengeluaran"] = []int{p.Read, p.Create, p.Update, p.Delete}
				case "laporan_materai":
					info["materai"] = []int{p.Read, p.Create, p.Update, p.Delete}
				case "transaksi":
					info["read"], info["create"], info["update"] = p.Read, p.Create, p.Update
				}
			}
			output = append(output, info)
		}
		return json.NewEncoder(os.Stdout).Encode(output)
	}
	if len(args) != 3 {
		return rejected
	}
	a, err := lookup(args[2])
	if err != nil {
		return err
	}
	switch args[0] {
	case "unlock":
		var password string
		if json.NewDecoder(io.LimitReader(os.Stdin, 1024)).Decode(&password) != nil {
			return rejected
		}
		session, err := unlock(root, id, a, password, time.Now())
		if err != nil {
			return err
		}
		return json.NewEncoder(os.Stdout).Encode(session)
	case "credential":
		if _, err = activeSession(root, id, a, time.Now()); err != nil {
			return err
		}
		var password string
		if err = unseal(root, id, "handoff-"+a.Username, &password); err != nil {
			return err
		}
		content, _ := windows.UTF16PtrFromString(a.Username + "\n" + password)
		title, _ := windows.UTF16PtrFromString("Kredensial pembayaran demo")
		windows.NewLazySystemDLL("user32.dll").NewProc("MessageBoxW").Call(
			0, uintptr(unsafe.Pointer(content)), uintptr(unsafe.Pointer(title)), 0x10000)
		return nil
	default:
		return rejected
	}
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		// Database/HTTP errors may carry credential material. Keep output generic.
		fmt.Fprintln(os.Stderr, "Operasi autentikasi demo ditolak.")
		os.Exit(1)
	}
}
