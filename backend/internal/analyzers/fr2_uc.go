package analyzers

import (
	"github.com/almigam/iec62443-analyzer/internal/models"
	"gorm.io/gorm"
)

// FR2 - Use Control
func RunFR2Checks(db *gorm.DB) []map[string]interface{} {
	var results []map[string]interface{}

	results = append(results, checkSR21RoleBasedAccess(db))
	results = append(results, checkSR22AdminAccounts(db))
	results = append(results, checkSR23UnauthorizedAccess(db))
	results = append(results, checkSR24PrivilegeManagement(db))

	return results
}

func checkSR21RoleBasedAccess(db *gorm.DB) map[string]interface{} {
	var roles []models.Role
	db.Find(&roles)

	status := "PASS"
	details := "Role-based access control (RBAC) configured"
	var roleNames []string

	for _, role := range roles {
		roleNames = append(roleNames, role.Name)
	}

	if len(roles) == 0 {
		status = "FAIL"
		details = "No roles defined in the system"
	} else {
		details += " | Roles: " + joinStrings(roleNames)
	}

	return map[string]interface{}{
		"sr_id":        "SR2.1",
		"fr_id":        "FR2",
		"description":  "Role-based access control (RBAC)",
		"status":       status,
		"details":      details,
		"sl_level":     1,
	}
}

func checkSR22AdminAccounts(db *gorm.DB) map[string]interface{} {
	var adminRole models.Role
	result := db.Where("name = ?", "Admin").First(&adminRole)

	status := "PASS"
	details := "Admin accounts properly managed"

	if result.RowsAffected == 0 {
		status = "FAIL"
		details = "No Admin role found - system administration impossible"
	} else {
		var adminUsers []models.User
		db.Where("role_id = ?", adminRole.ID).Find(&adminUsers)

		if len(adminUsers) == 0 {
			status = "FAIL"
			details = "No users with Admin role"
		} else if len(adminUsers) > 3 {
			status = "WARNING"
			details = "Too many Admin accounts (" + string(rune(len(adminUsers))) + ")"
		} else {
			details = "Admin role has " + string(rune(len(adminUsers))) + " assigned users"
		}
	}

	return map[string]interface{}{
		"sr_id":        "SR2.2",
		"fr_id":        "FR2",
		"description":  "Administrator account management",
		"status":       status,
		"details":      details,
		"sl_level":     2,
	}
}

func checkSR23UnauthorizedAccess(db *gorm.DB) map[string]interface{} {
	var deniedLogs []models.SecurityLog
	db.Where("event_type = ?", "ACCESS_DENIED").Find(&deniedLogs)

	status := "PASS"
	details := "Unauthorized access attempts detected: " + string(rune(len(deniedLogs)))

	if len(deniedLogs) > 10 {
		status = "WARNING"
		details = "High number of unauthorized access attempts - possible attack"
	}

	return map[string]interface{}{
		"sr_id":        "SR2.3",
		"fr_id":        "FR2",
		"description":  "Unauthorized access control",
		"status":       status,
		"details":      details,
		"sl_level":     1,
	}
}

func checkSR24PrivilegeManagement(db *gorm.DB) map[string]interface{} {
	var roles []models.Role
	db.Find(&roles)

	status := "PASS"
	details := "Privilege levels properly assigned"
	excessivePrivileges := 0

	for _, role := range roles {
		// Count permissions - if a non-admin role has >10 permissions, flag it
		if role.Name != "Admin" && len(role.Permissions) > 10 {
			excessivePrivileges++
		}
	}

	if excessivePrivileges > 0 {
		status = "WARNING"
		details = "Some non-admin roles have excessive permissions"
	}

	return map[string]interface{}{
		"sr_id":        "SR2.4",
		"fr_id":        "FR2",
		"description":  "Privilege management and least privilege",
		"status":       status,
		"details":      details,
		"sl_level":     2,
	}
}

func joinStrings(strs []string) string {
	result := ""
	for i, s := range strs {
		if i > 0 {
			result += ", "
		}
		result += s
	}
	return result
}
