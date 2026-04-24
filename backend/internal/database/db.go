package database

import (
	"os"
	"path/filepath"

	"github.com/almigam/iec62443-analyzer/internal/models"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func Init(dbPath string) (*gorm.DB, error) {
	// Ensure directory exists
	dir := filepath.Dir(dbPath)
	if err := os.MkdirAll(dir, 0700); err != nil {
		return nil, err
	}

	db, err := gorm.Open(sqlite.Open(dbPath), &gorm.Config{})
	if err != nil {
		return nil, err
	}

	// Auto migrate models
	if err := db.AutoMigrate(
		&models.User{},
		&models.Role{},
		&models.ScanResult{},
		&models.SecurityLog{},
		&models.SystemConfig{},
	); err != nil {
		return nil, err
	}

	return db, nil
}
