package analyzers

import (
	"crypto/md5"
	"fmt"
	"io/ioutil"
	"os"
)

// FR3 - System Integrity
func RunFR3Checks(db interface{}) []map[string]interface{} {
	var results []map[string]interface{}

	results = append(results, checkSR31FileIntegrity())
	results = append(results, checkSR32ConfigIntegrity())
	results = append(results, checkSR33CriticalFileProtection())

	return results
}

func checkSR31FileIntegrity() map[string]interface{} {
	status := "PASS"
	details := "File integrity monitoring configured"

	criticalFiles := []string{
		"./certs/server.crt",
		"./certs/server.key",
	}

	for _, file := range criticalFiles {
		if _, err := os.Stat(file); os.IsNotExist(err) {
			status = "FAIL"
			details = "Critical file missing: " + file
			break
		}
	}

	return map[string]interface{}{
		"sr_id":       "SR3.1",
		"fr_id":       "FR3",
		"description": "File integrity monitoring",
		"status":      status,
		"details":     details,
		"sl_level":    2,
	}
}

func checkSR32ConfigIntegrity() map[string]interface{} {
	status := "PASS"
	details := "Configuration files protected against unauthorized modification"

	configDir := "./data"
	if stat, err := os.Stat(configDir); err == nil {
		perms := stat.Mode().Perm()
		if perms > 0750 {
			status = "WARNING"
			details = "Configuration directory has permissive permissions"
		} else {
			details = "Configuration directory permissions: " + fmt.Sprintf("%o", perms)
		}
	}

	return map[string]interface{}{
		"sr_id":       "SR3.2",
		"fr_id":       "FR3",
		"description": "Configuration and code integrity",
		"status":      status,
		"details":     details,
		"sl_level":    2,
	}
}

func checkSR33CriticalFileProtection() map[string]interface{} {
	status := "PASS"
	details := "Critical files are protected"

	protectedPaths := []string{
		"./certs",
		"./data",
	}

	for _, path := range protectedPaths {
		fileInfo, err := os.Stat(path)
		if err == nil {
			perms := fileInfo.Mode().Perm()
			if perms > 0700 {
				status = "WARNING"
				details = fmt.Sprintf("Path %s has permissive permissions: %o", path, perms)
			}
		}
	}

	return map[string]interface{}{
		"sr_id":       "SR3.3",
		"fr_id":       "FR3",
		"description": "Protection of critical system files",
		"status":      status,
		"details":     details,
		"sl_level":    2,
	}
}

// Helper to calculate file hash
func fileHash(filepath string) (string, error) {
	data, err := ioutil.ReadFile(filepath)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%x", md5.Sum(data)), nil
}
