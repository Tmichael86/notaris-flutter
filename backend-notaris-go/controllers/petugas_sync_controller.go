package controllers

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/mail"
	"regexp"
	"strconv"
	"time"

	"backend-notaris-go/database"
	"backend-notaris-go/dto/response"
	"backend-notaris-go/middleware"
	"backend-notaris-go/models"
	"backend-notaris-go/repositories"
	"backend-notaris-go/synccontract"
	"github.com/gin-gonic/gin"
)

var petugasSyncUUID = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

// Route middleware requires read permission before exposing canonical records.
// Each push additionally checks the operation-specific existing permission.
func PetugasSyncPush(ctx *gin.Context) {
	var m synccontract.PetugasMutation
	decoder := json.NewDecoder(http.MaxBytesReader(ctx.Writer, ctx.Request.Body, 1<<20))
	decoder.DisallowUnknownFields()
	if decoder.Decode(&m) != nil || decoder.Decode(new(any)) != io.EOF || !petugasSyncUUID.MatchString(m.MutationID) || !petugasSyncUUID.MatchString(m.PetugasUUID) || m.PetugasUUID != ctx.Param("uuid") || m.Validate() != nil {
		response.Error(ctx, 400, "Mutation tidak valid", gin.H{"code": "invalid_mutation"})
		return
	}
	permission := middleware.PermissionUpdate
	if m.Operation == synccontract.PetugasDelete {
		permission = middleware.PermissionDelete
	} else if m.ExpectedRowVersion == nil {
		permission = middleware.PermissionCreate
	}
	middleware.RequirePermission(repositories.NewSidebarAccessRepository(), "petugas", permission)(ctx)
	if ctx.IsAborted() {
		return
	}
	if p := m.Payload; p != nil {
		email, err := mail.ParseAddress(p.Email)
		if err != nil || email.Address != p.Email {
			response.Error(ctx, 422, "Email tidak valid", gin.H{"code": "invalid_payload"})
			return
		}
		if p.TanggalLahir != nil {
			if _, err := time.Parse("2006-01-02", *p.TanggalLahir); err != nil {
				response.Error(ctx, 422, "Tanggal tidak valid", gin.H{"code": "invalid_payload"})
				return
			}
		}
	}
	actor, ok := getAuthenticatedUserID(ctx)
	if !ok {
		response.Error(ctx, 401, "Identitas tidak valid", nil)
		return
	}
	ack, err := repositories.NewPetugasSyncRepository(database.DB).Apply(ctx.Request.Context(), m, actor)
	var conflict *repositories.PetugasVersionConflict
	switch {
	case errors.As(err, &conflict):
		response.Error(ctx, 409, "Versi Petugas berbeda", gin.H{"code": "version_conflict", "current": publicPetugas(conflict.Current)})
		return
	case errors.Is(err, repositories.ErrMutationReuse):
		response.Error(ctx, 409, "Mutation sudah digunakan", gin.H{"code": "mutation_reuse"})
		return
	case errors.Is(err, repositories.ErrPetugasReference):
		response.Error(ctx, 422, "Referensi server tidak ditemukan", gin.H{"code": "invalid_reference"})
		return
	case errors.Is(err, repositories.ErrPetugasConstraint):
		response.Error(ctx, 409, "Data melanggar constraint", gin.H{"code": "constraint_conflict"})
		return
	case errors.Is(err, synccontract.ErrInvalidMutation):
		response.Error(ctx, 400, "Mutation tidak valid", gin.H{"code": "invalid_mutation"})
		return
	case err != nil:
		response.Error(ctx, 500, "Gagal menyimpan mutation", gin.H{"code": "sync_failed"})
		return
	}
	// Resolve the exact acknowledged version from immutable outbox history, not
	// today's latest row. Receipts can be replayed after subsequent updates.
	var snapshot string
	err = database.DB.WithContext(ctx.Request.Context()).Raw("SELECT payload::text FROM petugas_sync_outbox WHERE petugas_uuid = ?::uuid AND row_version = ? ORDER BY id LIMIT 1", ack.PetugasUUID, ack.RowVersion).Row().Scan(&snapshot)
	var row models.Petugas
	if err != nil || json.Unmarshal([]byte(snapshot), &row) != nil {
		response.Error(ctx, 500, "Gagal membaca acknowledgment", gin.H{"code": "sync_failed"})
		return
	}
	response.Success(ctx, "Mutation tersimpan", gin.H{"acknowledgement": ack, "record": publicPetugas(&row)})
}

// Deliberately omit actor audit fields and any unrelated user/account data.
func publicPetugas(row *models.Petugas) any {
	if row == nil {
		return nil
	}
	return gin.H{"id": row.ID, "uuid": row.UUID, "row_version": row.RowVersion, "status": row.Status, "deleted_at": row.DeletedAt, "nama": row.Nama, "nik": row.NIK, "alamat": row.Alamat, "tempat_lahir": row.TempatLahir, "tanggal_lahir": row.TanggalLahir, "jenis_kelamin_id": row.JenisKelamin, "no_telp": row.NoTelp, "email": row.Email, "user_id": row.UserID}
}

func PetugasSyncPull(ctx *gin.Context) {
	cursor, e1 := strconv.ParseInt(ctx.DefaultQuery("cursor", "0"), 10, 64)
	limit, e2 := strconv.Atoi(ctx.DefaultQuery("limit", "100"))
	if e1 != nil || e2 != nil {
		response.Error(ctx, 400, "Cursor atau limit tidak valid", gin.H{"code": "invalid_cursor"})
		return
	}
	page, err := repositories.NewPetugasPublicationRepository(database.DB).Pull(ctx.Request.Context(), synccontract.PetugasPullRequest{Cursor: cursor, Limit: limit})
	if errors.Is(err, repositories.ErrPetugasCursorExpired) {
		response.Error(ctx, 410, "Cursor kedaluwarsa; full resync diperlukan", gin.H{"code": "cursor_expired"})
		return
	}
	if errors.Is(err, repositories.ErrPetugasPull) {
		response.Error(ctx, 400, "Cursor atau limit tidak valid", gin.H{"code": "invalid_cursor"})
		return
	}
	if err != nil {
		response.Error(ctx, 500, "Gagal mengambil perubahan", gin.H{"code": "sync_failed"})
		return
	}
	response.Success(ctx, "Perubahan Petugas", page)
}
