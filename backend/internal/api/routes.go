package api

import (
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func RegisterRoutes(router *gin.Engine, db *gorm.DB) {
	// Health check
	router.GET("/api/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "healthy"})
	})

	// Analyzer routes
	router.GET("/api/scan/fr1", ScanFR1(db))
	router.GET("/api/scan/fr2", ScanFR2(db))
	router.GET("/api/scan/fr3", ScanFR3(db))
	router.GET("/api/scan/fr4", ScanFR4(db))
	router.GET("/api/scan/fr5", ScanFR5(db))
	router.GET("/api/scan/fr6", ScanFR6(db))
	router.GET("/api/scan/fr7", ScanFR7(db))
	router.GET("/api/scan/all", ScanAll(db))

	// Results endpoint
	router.GET("/api/results", GetScanResults(db))
}
