package services

import (
	"time"

	"backend-notaris-go/database"
	"backend-notaris-go/dto/request"
	"backend-notaris-go/models"

	"gorm.io/gorm/clause"
)

type SyncService interface {
	PushSync(req request.SyncPushRequest) (time.Time, error)
	PullSync() ([]models.Pemohon, []models.Transaksi, error)
}

type syncService struct{}

func NewSyncService() SyncService {
	return &syncService{}
}

func (s *syncService) PushSync(req request.SyncPushRequest) (time.Time, error) {
	now := time.Now()

	// 1. Upsert Pemohons
	if len(req.Pemohons) > 0 {
		var pemohons []models.Pemohon
		for _, item := range req.Pemohons {
			pemohons = append(pemohons, models.Pemohon{
				UUID:         item.UUID,
				Nama:         item.Nama,
				NIK:          item.NIK,
				Alamat:       item.Alamat,
				IsDirty:      false,
				LastSyncedAt: &now,
				UpdatedAt:    now,
			})
		}

		// ON CONFLICT (uuid) DO UPDATE
		err := database.DB.Clauses(clause.OnConflict{
			Columns:   []clause.Column{{Name: "uuid"}},
			DoUpdates: clause.AssignmentColumns([]string{"nama", "nik", "alamat", "is_dirty", "last_synced_at", "updated_at"}),
		}).Create(&pemohons).Error

		if err != nil {
			return now, err
		}
	}

	// 2. Upsert Transaksis
	if len(req.Transaksis) > 0 {
		var transaksis []models.Transaksi
		for _, item := range req.Transaksis {
			transaksis = append(transaksis, models.Transaksi{
				UUID:         item.UUID,
				NoAkta:       item.NoAkta,
				Total:        item.Total,
				PemohonUUID:  item.PemohonUUID,
				IsDirty:      false,
				LastSyncedAt: &now,
				UpdatedAt:    now,
			})
		}

		// ON CONFLICT (uuid) DO UPDATE
		err := database.DB.Clauses(clause.OnConflict{
			Columns:   []clause.Column{{Name: "uuid"}},
			DoUpdates: clause.AssignmentColumns([]string{"no_akta", "total", "pemohon_uuid", "is_dirty", "last_synced_at", "updated_at"}),
		}).Create(&transaksis).Error

		if err != nil {
			return now, err
		}
	}

	return now, nil
}

func (s *syncService) PullSync() ([]models.Pemohon, []models.Transaksi, error) {
	var pemohons []models.Pemohon
	var transaksis []models.Transaksi

	if err := database.DB.Find(&pemohons).Error; err != nil {
		return nil, nil, err
	}

	if err := database.DB.Find(&transaksis).Error; err != nil {
		return nil, nil, err
	}

	return pemohons, transaksis, nil
}