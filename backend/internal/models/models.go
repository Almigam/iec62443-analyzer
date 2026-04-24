package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// User model for FR1 (Identification and Authentication Control)
type User struct {
	ID           string    `gorm:"primaryKey" json:"id"`
	Username     string    `gorm:"uniqueIndex;not null" json:"username"`
	Email        string    `gorm:"uniqueIndex;not null" json:"email"`
	PasswordHash string    `gorm:"not null" json:"-"`
	RoleID       string    `gorm:"not null" json:"role_id"`
	Role         *Role     `json:"role,omitempty"`
	Enabled      bool      `gorm:"default:true" json:"enabled"`
	LastLogin    *time.Time `json:"last_login"`
	FailedAttempts int     `gorm:"default:0" json:"failed_attempts"`
	LockedUntil  *time.Time `json:"locked_until"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

func (u *User) BeforeCreate(tx *gorm.DB) error {
	if u.ID == "" {
		u.ID = uuid.New().String()
	}
	return nil
}

// Role model for FR2 (Use Control)
type Role struct {
	ID          string    `gorm:"primaryKey" json:"id"`
	Name        string    `gorm:"uniqueIndex;not null" json:"name"`
	Description string    `json:"description"`
	Permissions []string  `gorm:"serializer:json" json:"permissions"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

func (r *Role) BeforeCreate(tx *gorm.DB) error {
	if r.ID == "" {
		r.ID = uuid.New().String()
	}
	return nil
}

// ScanResult model for storing analyzer results
type ScanResult struct {
	ID          string    `gorm:"primaryKey" json:"id"`
	Timestamp   time.Time `gorm:"index" json:"timestamp"`
	FRID        string    `gorm:"index" json:"fr_id"`
	SRID        string    `json:"sr_id"`
	Description string    `json:"description"`
	Status      string    `json:"status"` // PASS, FAIL, WARNING
	Details     string    `gorm:"type:text" json:"details"`
	SLLevel     int       `json:"sl_level"`
	CreatedAt   time.Time `json:"created_at"`
}

func (s *ScanResult) BeforeCreate(tx *gorm.DB) error {
	if s.ID == "" {
		s.ID = uuid.New().String()
	}
	if s.Timestamp.IsZero() {
		s.Timestamp = time.Now()
	}
	return nil
}

// SecurityLog model for FR6 (Timely Response to Events)
type SecurityLog struct {
	ID        string    `gorm:"primaryKey" json:"id"`
	Timestamp time.Time `gorm:"index" json:"timestamp"`
	EventType string    `json:"event_type"` // LOGIN_FAILED, ACCESS_DENIED, INTEGRITY_CHECK, etc
	UserID    string    `json:"user_id"`
	IPAddress string    `json:"ip_address"`
	Message   string    `gorm:"type:text" json:"message"`
	Severity  string    `json:"severity"` // INFO, WARN, CRITICAL
	CreatedAt time.Time `json:"created_at"`
}

func (sl *SecurityLog) BeforeCreate(tx *gorm.DB) error {
	if sl.ID == "" {
		sl.ID = uuid.New().String()
	}
	if sl.Timestamp.IsZero() {
		sl.Timestamp = time.Now()
	}
	return nil
}

// SystemConfig model for storing system configuration
type SystemConfig struct {
	ID    string `gorm:"primaryKey" json:"id"`
	Key   string `gorm:"uniqueIndex;not null" json:"key"`
	Value string `gorm:"type:text" json:"value"`
	Type  string `json:"type"` // string, int, bool, json
}

func (sc *SystemConfig) BeforeCreate(tx *gorm.DB) error {
	if sc.ID == "" {
		sc.ID = uuid.New().String()
	}
	return nil
}
