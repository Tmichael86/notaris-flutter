package controllers

import (
	"errors"
	"net/http"
	"regexp"
	"strconv"
	"strings"

	"backend-notaris-go/dto/response"
	"backend-notaris-go/models"
	"backend-notaris-go/repositories"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type PemohonController struct {
	repository *repositories.PemohonRepository
}

func NewPemohonController() *PemohonController {
	return &PemohonController{repository: repositories.NewPemohonRepository()}
}

type pemohonRequest struct {
	Nama         string  `json:"nama"`
	Alamat       *string `json:"alamat"`
	JenisKelamin *int    `json:"jenis_kelamin"`
	JenisKelaminNama *string `json:"jenis_kelamin_nama"`
	NoTelp       *string `json:"no_telp"`
	NIK          *string `json:"nik"`
}

var (
	pemohonNIKPattern   = regexp.MustCompile(`^[0-9]{16}$`)
	pemohonPhonePattern = regexp.MustCompile(`^[0-9+(). -]+$`)
	pemohonUUIDPattern  = regexp.MustCompile(`(?i)^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)
)

func (c *PemohonController) GetAll(ctx *gin.Context) {
	page, err := queryInt(ctx, "page", 1)
	if err != nil || page < 1 {
		response.Error(ctx, http.StatusBadRequest, "Parameter page harus bilangan bulat positif", nil)
		return
	}

	pageSize, err := queryInt(ctx, "page_size", 50)
	if err != nil || pageSize < 1 {
		response.Error(ctx, http.StatusBadRequest, "Parameter page_size harus bilangan bulat positif", nil)
		return
	}
	if pageSize > 100 {
		pageSize = 100
	}

	items, total, err := c.repository.FindActive(ctx.Request.Context(), page, pageSize)
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data pemohon", nil)
		return
	}

	response.Success(ctx, "Data pemohon berhasil diambil", gin.H{
		"items": items,
		"pagination": gin.H{
			"page":      page,
			"page_size": pageSize,
			"total":     total,
			"has_more":  int64(page)*int64(pageSize) < total,
		},
	})
}

func (c *PemohonController) GetByID(ctx *gin.Context) {
	id, ok := parsePositiveID(ctx)
	if !ok {
		response.Error(ctx, http.StatusBadRequest, "ID pemohon tidak valid", nil)
		return
	}

	item, err := c.repository.FindActiveByID(ctx.Request.Context(), id)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Pemohon tidak ditemukan", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data pemohon", nil)
		return
	}
	response.Success(ctx, "Data pemohon berhasil diambil", item)
}

func (c *PemohonController) Create(ctx *gin.Context) {
	input, ok := bindAndValidatePemohon(ctx)
	if !ok {
		return
	}
	if input.JenisKelamin != nil {
		exists, err := c.repository.JenisKelaminExists(ctx.Request.Context(), *input.JenisKelamin)
		if err != nil {
			response.Error(ctx, http.StatusInternalServerError, "Gagal memvalidasi jenis kelamin", nil)
			return
		}
		if !exists {
			response.Error(ctx, http.StatusUnprocessableEntity, "Validasi data gagal", gin.H{"jenis_kelamin": "Jenis kelamin tidak ditemukan"})
			return
		}
	}

	userID, ok := getAuthenticatedUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "User tidak terautentikasi", nil)
		return
	}

	item := toPemohonModel(input)
	created, err := c.repository.Create(ctx.Request.Context(), item, userID)
	if errors.Is(err, repositories.ErrDuplicatePemohonNIK) {
		response.Error(ctx, http.StatusConflict, "NIK pemohon sudah digunakan", gin.H{"nik": "NIK harus unik di antara data aktif"})
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal membuat data pemohon", nil)
		return
	}
	ctx.JSON(http.StatusCreated, response.APIResponse{Success: true, Message: "Data pemohon berhasil dibuat", Data: created})
}

func (c *PemohonController) Update(ctx *gin.Context) {
	id, ok := parsePositiveID(ctx)
	if !ok {
		response.Error(ctx, http.StatusBadRequest, "ID pemohon tidak valid", nil)
		return
	}
	input, ok := bindAndValidatePemohon(ctx)
	if !ok {
		return
	}
	if input.JenisKelamin != nil {
		exists, err := c.repository.JenisKelaminExists(ctx.Request.Context(), *input.JenisKelamin)
		if err != nil {
			response.Error(ctx, http.StatusInternalServerError, "Gagal memvalidasi jenis kelamin", nil)
			return
		}
		if !exists {
			response.Error(ctx, http.StatusUnprocessableEntity, "Validasi data gagal", gin.H{"jenis_kelamin": "Jenis kelamin tidak ditemukan"})
			return
		}
	}

	userID, ok := getAuthenticatedUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "User tidak terautentikasi", nil)
		return
	}

	updated, err := c.repository.Update(ctx.Request.Context(), id, toPemohonModel(input), userID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Pemohon tidak ditemukan", nil)
		return
	}
	if errors.Is(err, repositories.ErrDuplicatePemohonNIK) {
		response.Error(ctx, http.StatusConflict, "NIK pemohon sudah digunakan", gin.H{"nik": "NIK harus unik di antara data aktif"})
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal memperbarui data pemohon", nil)
		return
	}
	response.Success(ctx, "Data pemohon berhasil diperbarui", updated)
}

func (c *PemohonController) Delete(ctx *gin.Context) {
	id, ok := parsePositiveID(ctx)
	if !ok {
		response.Error(ctx, http.StatusBadRequest, "ID pemohon tidak valid", nil)
		return
	}
	userID, ok := getAuthenticatedUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "User tidak terautentikasi", nil)
		return
	}

	if err := c.repository.Deactivate(ctx.Request.Context(), id, userID); errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Pemohon tidak ditemukan", nil)
		return
	} else if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal menonaktifkan data pemohon", nil)
		return
	}
	response.Success(ctx, "Data pemohon berhasil dinonaktifkan", nil)
}

func (c *PemohonController) SyncUpsert(ctx *gin.Context) {
	uuid := strings.TrimSpace(ctx.Param("uuid"))
	if !pemohonUUIDPattern.MatchString(uuid) {
		response.Error(ctx, http.StatusBadRequest, "UUID pemohon tidak valid", nil)
		return
	}

	input, ok := bindAndValidatePemohon(ctx)
	if !ok {
		return
	}

	if input.JenisKelaminNama != nil && strings.TrimSpace(*input.JenisKelaminNama) != "" {
		genderID, err := c.repository.FindJenisKelaminIDByName(ctx.Request.Context(), *input.JenisKelaminNama)
		if errors.Is(err, gorm.ErrRecordNotFound) {
			response.Error(ctx, http.StatusUnprocessableEntity, "Validasi data gagal", gin.H{"jenis_kelamin_nama": "Jenis kelamin tidak ditemukan"})
			return
		}
		if err != nil {
			response.Error(ctx, http.StatusInternalServerError, "Gagal memvalidasi jenis kelamin", nil)
			return
		}
		input.JenisKelamin = &genderID
	}
	if input.JenisKelamin != nil {
		exists, err := c.repository.JenisKelaminExists(
			ctx.Request.Context(),
			*input.JenisKelamin,
		)
		if err != nil {
			response.Error(
				ctx,
				http.StatusInternalServerError,
				"Gagal memvalidasi jenis kelamin",
				nil,
			)
			return
		}
		if !exists {
			response.Error(
				ctx,
				http.StatusUnprocessableEntity,
				"Validasi data gagal",
				gin.H{"jenis_kelamin": "Jenis kelamin tidak ditemukan"},
			)
			return
		}
	}

	userID, ok := getAuthenticatedUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "User tidak terautentikasi", nil)
		return
	}

	item, err := c.repository.UpsertByUUID(
		ctx.Request.Context(),
		uuid,
		toPemohonModel(input),
		userID,
	)
	if errors.Is(err, repositories.ErrDuplicatePemohonNIK) {
		response.Error(
			ctx,
			http.StatusConflict,
			"NIK pemohon sudah digunakan",
			gin.H{"nik": "NIK harus unik di antara data aktif"},
		)
		return
	}
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(
			ctx,
			http.StatusNotFound,
			"Pemohon tidak ditemukan atau sudah dinonaktifkan",
			nil,
		)
		return
	}
	if err != nil {
		response.Error(
			ctx,
			http.StatusInternalServerError,
			"Gagal menyinkronkan data pemohon",
			nil,
		)
		return
	}

	response.Success(ctx, "Data pemohon berhasil disinkronkan", item)
}

func (c *PemohonController) SyncDeactivate(ctx *gin.Context) {
	uuid := strings.TrimSpace(ctx.Param("uuid"))
	if !pemohonUUIDPattern.MatchString(uuid) {
		response.Error(ctx, http.StatusBadRequest, "UUID pemohon tidak valid", nil)
		return
	}

	userID, ok := getAuthenticatedUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "User tidak terautentikasi", nil)
		return
	}

	err := c.repository.DeactivateByUUID(
		ctx.Request.Context(),
		uuid,
		userID,
	)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Pemohon tidak ditemukan", nil)
		return
	}
	if err != nil {
		response.Error(
			ctx,
			http.StatusInternalServerError,
			"Gagal menonaktifkan data pemohon melalui sinkronisasi",
			nil,
		)
		return
	}

	response.Success(ctx, "Data pemohon berhasil dinonaktifkan", nil)
}

func bindAndValidatePemohon(ctx *gin.Context) (*pemohonRequest, bool) {
	var input pemohonRequest
	if err := ctx.ShouldBindJSON(&input); err != nil {
		response.Error(ctx, http.StatusBadRequest, "JSON request tidak valid", nil)
		return nil, false
	}

	input.Nama = strings.TrimSpace(input.Nama)
	validation := gin.H{}
	if input.Nama == "" {
		validation["nama"] = "Nama wajib diisi"
	}
	if input.NIK != nil {
		nik := strings.TrimSpace(*input.NIK)
		if nik == "" {
			input.NIK = nil
		} else if !pemohonNIKPattern.MatchString(nik) {
			validation["nik"] = "NIK harus terdiri dari 16 digit angka"
		} else {
			input.NIK = &nik
		}
	}
	if input.NoTelp != nil {
		phone := strings.TrimSpace(*input.NoTelp)
		if phone == "" {
			input.NoTelp = nil
		} else {
			digits := regexp.MustCompile(`[0-9]`).FindAllString(phone, -1)
			if !pemohonPhonePattern.MatchString(phone) || len(digits) < 8 || len(digits) > 15 {
				validation["no_telp"] = "Nomor telepon harus berisi 8 sampai 15 digit dan hanya menggunakan angka atau karakter + ( ) . -"
			} else {
				input.NoTelp = &phone
			}
		}
	}
	if input.Alamat != nil {
		value := strings.TrimSpace(*input.Alamat)
		if value == "" {
			input.Alamat = nil
		} else {
			input.Alamat = &value
		}
	}
	if input.JenisKelamin != nil && *input.JenisKelamin < 1 {
		validation["jenis_kelamin"] = "Jenis kelamin harus berupa ID positif"
	}
	if len(validation) > 0 {
		response.Error(ctx, http.StatusUnprocessableEntity, "Validasi data gagal", validation)
		return nil, false
	}
	return &input, true
}

func toPemohonModel(input *pemohonRequest) *models.Pemohon {
	return &models.Pemohon{
		Nama:         input.Nama,
		Alamat:       input.Alamat,
		JenisKelamin: input.JenisKelamin,
		NoTelp:       input.NoTelp,
		NIK:          input.NIK,
	}
}

func parsePemohonID(ctx *gin.Context) (uint64, bool) {
	return parsePositiveID(ctx)
}

func parsePemohonIDString(raw string) (uint64, bool) {
	id, err := strconv.ParseUint(raw, 10, 64)
	return id, err == nil && id > 0
}
