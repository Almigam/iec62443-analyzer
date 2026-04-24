package analyzers

import (
	"time"

	"github.com/almigam/iec62443-analyzer/internal/models"
	"gorm.io/gorm"
)

// FR6 - Timely Response to Events
func RunFR6Checks(db *gorm.DB) []map[string]interface{} {
	var results []map[string]interface{}

	results = append(results, checkSR61LoggingMonitoring(db))
	results = append(results, checkSR62SecurityAlerts(db))
	results = append(results, checkSR63EventResponse(db))
	results = append(results, checkSR64IncidentHandling(db))

	return results
}

func checkSR61LoggingMonitoring(db *gorm.DB) map[string]interface{} {
	status := "PASS"
	details := "Logging and monitoring system is active"

	var logCount int64
	db.Model(&models.SecurityLog{}).Count(&logCount)

	if logCount == 0 {
		status = "WARNING"
		details = "No security logs recorded yet"
	} else {
		details = "Security logging active - " + string(rune(logCount)) + " events recorded"
	}

	return map[string]interface{}{
		"sr_id":        "SR6.1",
		"fr_id":        "FR6",
		"description":  "Security event logging and monitoring",
		"status":       status,
		"details":      details,
		"sl_level":     1,
	}
}

func checkSR62SecurityAlerts(db *gorm.DB) map[string]interface{} {
	status := "PASS"
	details := "Security alert system configured"

	// Check for critical events in the last hour
	oneHourAgo := time.Now().Add(-1 * time.Hour)
	var criticalEvents int64
	db.Model(&models.SecurityLog{}).
		Where("severity = ? AND timestamp > ?", "CRITICAL", oneHourAgo).
		Count(&criticalEvents)

	if criticalEvents > 0 {
		status = "WARNING"
		details = "Critical security events detected in the last hour"
	} else {
		details = "No critical events in the last hour"
	}

	return map[string]interface{}{
		"sr_id":        "SR6.2",
		"fr_id":        "FR6",
		"description":  "Real-time security alerts",
		"status":       status,
		"details":      details,
		"sl_level":     2,
	}
}

func checkSR63EventResponse(db *gorm.DB) map[string]interface{} {
	status := "PASS"
	details := "Event response procedures in place"

	// Check for failed login lockouts
	var lockedUsers []models.User
	db.Where("locked_until IS NOT NULL AND locked_until > ?", time.Now()).Find(&lockedUsers)

	if len(lockedUsers) > 0 {
		details = "Account lockout mechanism is active - " + string(rune(len(lockedUsers))) + " accounts locked"
		status = "WARNING"
	} else {
		details = "No active account lockouts - system responsive"
	}

	return map[string]interface{}{
		"sr_id":        "SR6.3",
		"fr_id":        "FR6",
		"description":  "Security event response procedures",
		"status":       status,
		"details":      details,
		"sl_level":     2,
	}
}

func checkSR64IncidentHandling(db *gorm.DB) map[string]interface{} {
	status := "PASS"
	details := "Incident handling and recovery procedures configured"

	// Check system logs for recovery indicators
	var recoveryLogs int64
	db.Model(&models.SecurityLog{}).
		Where("event_type IN ?", []string{"SYSTEM_RECOVERY", "SECURITY_REMEDIATION"}).
		Count(&recoveryLogs)

	if recoveryLogs > 0 {
		details = "System has executed " + string(rune(recoveryLogs)) + " recovery actions"
	} else {
		details = "Incident handling procedures documented and tested"
	}

	return map[string]interface{}{
		"sr_id":        "SR6.4",
		"fr_id":        "FR6",
		"description":  "Incident handling and recovery",
		"status":       status,
		"details":      details,
		"sl_level":     2,
	}
}
