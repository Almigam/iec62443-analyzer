package api

import (
	"net/http"
	"time"

	"github.com/almigam/iec62443-analyzer/internal/analyzers"
	"github.com/almigam/iec62443-analyzer/internal/models"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type ScanRequest struct {
	FRNumber int `json:"fr_number"` // 1-7
}

// ScanFR1 handles FR1 (Identification and Authentication Control) scan
func ScanFR1(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		results := analyzers.RunFR1Checks(db)
		saveScanResults(db, results)
		c.JSON(http.StatusOK, gin.H{
			"fr":            "FR1",
			"description":   "Identification and Authentication Control",
			"total_checks":  len(results),
			"passed":        countStatus(results, "PASS"),
			"failed":        countStatus(results, "FAIL"),
			"warnings":      countStatus(results, "WARNING"),
			"results":       results,
		})
	}
}

// ScanFR2 handles FR2 (Use Control) scan
func ScanFR2(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		results := analyzers.RunFR2Checks(db)
		saveScanResults(db, results)
		c.JSON(http.StatusOK, gin.H{
			"fr":            "FR2",
			"description":   "Use Control",
			"total_checks":  len(results),
			"passed":        countStatus(results, "PASS"),
			"failed":        countStatus(results, "FAIL"),
			"warnings":      countStatus(results, "WARNING"),
			"results":       results,
		})
	}
}

// ScanFR3 handles FR3 (System Integrity) scan
func ScanFR3(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		results := analyzers.RunFR3Checks(db)
		saveScanResults(db, results)
		c.JSON(http.StatusOK, gin.H{
			"fr":            "FR3",
			"description":   "System Integrity",
			"total_checks":  len(results),
			"passed":        countStatus(results, "PASS"),
			"failed":        countStatus(results, "FAIL"),
			"warnings":      countStatus(results, "WARNING"),
			"results":       results,
		})
	}
}

// ScanFR4 handles FR4 (Data Confidentiality) scan
func ScanFR4(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		results := analyzers.RunFR4Checks(db)
		saveScanResults(db, results)
		c.JSON(http.StatusOK, gin.H{
			"fr":            "FR4",
			"description":   "Data Confidentiality",
			"total_checks":  len(results),
			"passed":        countStatus(results, "PASS"),
			"failed":        countStatus(results, "FAIL"),
			"warnings":      countStatus(results, "WARNING"),
			"results":       results,
		})
	}
}

// ScanFR5 handles FR5 (Restricted Data Flow) scan
func ScanFR5(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		results := analyzers.RunFR5Checks(db)
		saveScanResults(db, results)
		c.JSON(http.StatusOK, gin.H{
			"fr":            "FR5",
			"description":   "Restricted Data Flow",
			"total_checks":  len(results),
			"passed":        countStatus(results, "PASS"),
			"failed":        countStatus(results, "FAIL"),
			"warnings":      countStatus(results, "WARNING"),
			"results":       results,
		})
	}
}

// ScanFR6 handles FR6 (Timely Response to Events) scan
func ScanFR6(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		results := analyzers.RunFR6Checks(db)
		saveScanResults(db, results)
		c.JSON(http.StatusOK, gin.H{
			"fr":            "FR6",
			"description":   "Timely Response to Events",
			"total_checks":  len(results),
			"passed":        countStatus(results, "PASS"),
			"failed":        countStatus(results, "FAIL"),
			"warnings":      countStatus(results, "WARNING"),
			"results":       results,
		})
	}
}

// ScanFR7 handles FR7 (Resource Availability) scan
func ScanFR7(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		results := analyzers.RunFR7Checks(db)
		saveScanResults(db, results)
		c.JSON(http.StatusOK, gin.H{
			"fr":            "FR7",
			"description":   "Resource Availability",
			"total_checks":  len(results),
			"passed":        countStatus(results, "PASS"),
			"failed":        countStatus(results, "FAIL"),
			"warnings":      countStatus(results, "WARNING"),
			"results":       results,
		})
	}
}

// ScanAll runs all FR scans
func ScanAll(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var allResults []map[string]interface{}

		for i := 1; i <= 7; i++ {
			var results []map[string]interface{}
			switch i {
			case 1:
				results = analyzers.RunFR1Checks(db)
			case 2:
				results = analyzers.RunFR2Checks(db)
			case 3:
				results = analyzers.RunFR3Checks(db)
			case 4:
				results = analyzers.RunFR4Checks(db)
			case 5:
				results = analyzers.RunFR5Checks(db)
			case 6:
				results = analyzers.RunFR6Checks(db)
			case 7:
				results = analyzers.RunFR7Checks(db)
			}
			saveScanResults(db, results)
			allResults = append(allResults, map[string]interface{}{
				"fr":       i,
				"results":  results,
				"total":    len(results),
				"passed":   countStatus(results, "PASS"),
				"failed":   countStatus(results, "FAIL"),
				"warnings": countStatus(results, "WARNING"),
			})
		}

		c.JSON(http.StatusOK, gin.H{
			"timestamp": time.Now(),
			"scans":     allResults,
		})
	}
}

// GetScanResults retrieves past scan results
func GetScanResults(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var results []models.ScanResult
		db.Order("timestamp DESC").Limit(100).Find(&results)
		c.JSON(http.StatusOK, results)
	}
}

// Helper functions
func saveScanResults(db *gorm.DB, results []map[string]interface{}) {
	for _, r := range results {
		scan := models.ScanResult{
			FRID:        r["fr_id"].(string),
			SRID:        r["sr_id"].(string),
			Description: r["description"].(string),
			Status:      r["status"].(string),
			Details:     r["details"].(string),
			SLLevel:     r["sl_level"].(int),
		}
		db.Create(&scan)
	}
}

func countStatus(results []map[string]interface{}, status string) int {
	count := 0
	for _, r := range results {
		if r["status"].(string) == status {
			count++
		}
	}
	return count
}
