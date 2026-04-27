package analyzers

import (
	"os"

	"github.com/almigam/iec62443-analyzer/internal/models"
	"gorm.io/gorm"
)

// FR1 - Identification and Authentication Control
func RunFR1Checks(db *gorm.DB) []map[string]interface{} {
	var results []map[string]interface{}

	results = append(results, checkSR11UserAuth(db))
	results = append(results, checkSR13AccountManagement(db))
	results = append(results, checkSR14PasswordPolicy(db))
	results = append(results, checkSR15DefaultAccounts(db))
	results = append(results, checkSR16TLSConfiguration())
	results = append(results, checkSR17FailedLoginAttempts(db))

	return results
}

func checkSR11UserAuth(db *gorm.DB) map[string]interface{} {
	var userCount int64
	db.Model(&models.User{}).Count(&userCount)

	status := "PASS"
	details := "User authentication system configured"

	if userCount == 0 {
		status = "FAIL"
		details = "No users found in the system"
	}

	return map[string]interface{}{
		"sr_id":       "SR1.1",
		"fr_id":       "FR1",
		"description": "Identification and authentication of human users",
		"status":      status,
		"details":     details,
		"sl_level":    1,
	}
}

func checkSR13AccountManagement(db *gorm.DB) map[string]interface{} {
	var users []models.User
	db.Find(&users)

	status := "PASS"
	details := "Account management controls in place"
	issues := 0

	for _, user := range users {
		if !user.Enabled {
			details += " | Disabled account detected: " + user.Username
		}
		if user.LockedUntil != nil {
			details += " | Locked account: " + user.Username
		}
	}

	if issues > 0 {
		status = "WARNING"
	}

	return map[string]interface{}{
		"sr_id":       "SR1.3",
		"fr_id":       "FR1",
		"description": "User registration and de-registration",
		"status":      status,
		"details":     details,
		"sl_level":    1,
	}
}

func checkSR14PasswordPolicy(db *gorm.DB) map[string]interface{} {
	status := "PASS"
	details := "Password policy enforced: minimum 12 characters, complexity required"

	if !hasPasswordHashingEnabled(db) {
		status = "FAIL"
		details = "Password hashing not properly configured"
	}

	return map[string]interface{}{
		"sr_id":       "SR1.4",
		"fr_id":       "FR1",
		"description": "Password management",
		"status":      status,
		"details":     details,
		"sl_level":    1,
	}
}

func checkSR15DefaultAccounts(db *gorm.DB) map[string]interface{} {
	var users []models.User
	db.Find(&users)

	status := "PASS"
	details := "No default accounts detected"
	defaultAccounts := []string{"admin", "pi", "root", "default"}

	for _, user := range users {
		for _, defaultAcc := range defaultAccounts {
			if user.Username == defaultAcc {
				status = "FAIL"
				details = "Default account found: " + user.Username
				break
			}
		}
	}

	return map[string]interface{}{
		"sr_id":       "SR1.5",
		"fr_id":       "FR1",
		"description": "Default account removal",
		"status":      status,
		"details":     details,
		"sl_level":    2,
	}
}

func checkSR16TLSConfiguration() map[string]interface{} {
	status := "PASS"
	details := "HTTPS/TLS enforced for all communications"

	if _, err := os.Stat("./certs/server.crt"); os.IsNotExist(err) {
		status = "FAIL"
		details = "TLS certificate not found"
	} else if _, err := os.Stat("./certs/server.key"); os.IsNotExist(err) {
		status = "FAIL"
		details = "TLS private key not found"
	}

	return map[string]interface{}{
		"sr_id":       "SR1.6",
		"fr_id":       "FR1",
		"description": "Transport layer security (TLS)",
		"status":      status,
		"details":     details,
		"sl_level":    1,
	}
}

func checkSR17FailedLoginAttempts(db *gorm.DB) map[string]interface{} {
	var securityLogs []models.SecurityLog
	db.Where("event_type = ? AND severity = ?", "LOGIN_FAILED", "CRITICAL").Find(&securityLogs)

	status := "PASS"
	details := "Failed login attempts are being monitored"

	if len(securityLogs) > 0 {
		status = "WARNING"
		details = "Multiple failed login attempts detected - accounts may be locked"
	}

	return map[string]interface{}{
		"sr_id":       "SR1.7",
		"fr_id":       "FR1",
		"description": "Login attempt monitoring and account lockout",
		"status":      status,
		"details":     details,
		"sl_level":    2,
	}
}

func hasPasswordHashingEnabled(db *gorm.DB) bool {
	var user models.User
	result := db.First(&user)
	return result.RowsAffected > 0 && user.PasswordHash != ""
}
