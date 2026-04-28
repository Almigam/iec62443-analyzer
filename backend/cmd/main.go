package main

import (
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/almigam/iec62443-analyzer/internal/api"
	"github.com/almigam/iec62443-analyzer/internal/config"
	"github.com/almigam/iec62443-analyzer/internal/database"
	"github.com/gin-gonic/gin"
)

func main() {
	// Load configuration
	cfg := config.LoadConfig()

	// Initialize database
	db, err := database.Init(cfg.DBPath)
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}

	// Setup Gin router
	if cfg.Environment == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.Default()

	// CORS middleware for OT network
	router.Use(func(c *gin.Context) {
		origin := c.GetHeader("Origin")
		allowedOrigin := getAllowedOrigin(origin, cfg.AllowedOrigins)
		if allowedOrigin != "" {
			c.Writer.Header().Set("Access-Control-Allow-Origin", allowedOrigin)
		}
		c.Writer.Header().Set("Vary", "Origin")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})

	// Health check endpoint
	router.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "healthy", "timestamp": time.Now()})
	})

	// API endpoints
	api.RegisterRoutes(router, db)

	// HTTP Server configuration
	server := &http.Server{
		Addr:           fmt.Sprintf(":%d", cfg.Port),
		Handler:        router,
		ReadTimeout:    15 * time.Second,
		WriteTimeout:   15 * time.Second,
		IdleTimeout:    60 * time.Second,
		MaxHeaderBytes: 1 << 20,
	}

	log.Printf("Starting IEC 62443-3-3 Analyzer on http://localhost:%d\n", cfg.Port)
	log.Printf("Environment: %s\n", cfg.Environment)
	log.Printf("Database: %s\n", cfg.DBPath)

	if err := server.ListenAndServe(); err != nil {
		log.Fatalf("Server error: %v", err)
	}
}

func getAllowedOrigin(requestOrigin, allowedOrigins string) string {
	if requestOrigin == "" {
		return ""
	}

	allowed := strings.Split(allowedOrigins, ",")
	for _, origin := range allowed {
		origin = strings.TrimSpace(origin)
		if origin == "*" || origin == requestOrigin {
			return requestOrigin
		}
	}

	return ""
}
