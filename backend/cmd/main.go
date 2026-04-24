package main

import (
	"crypto/tls"
	"fmt"
	"log"
	"net/http"
	"os"
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
		c.Writer.Header().Set("Access-Control-Allow-Origin", cfg.AllowedOrigins)
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

	// Setup HTTPS
	tlsConfig := &tls.Config{
		MinVersion:               tls.VersionTLS12,
		CurvePreferences:         []tls.CurveID{tls.CurveP521, tls.CurveP384, tls.CurveP256},
		PreferServerCipherSuites: true,
		CipherSuites: []uint16{
			tls.TLS_AES_256_GCM_SHA384,
			tls.TLS_CHACHA20_POLY1305_SHA256,
			tls.TLS_AES_128_GCM_SHA256,
		},
	}

	server := &http.Server{
		Addr:      fmt.Sprintf(":%d", cfg.Port),
		Handler:   router,
		TLSConfig: tlsConfig,
		// Timeouts for resilience (FR7)
		ReadTimeout:      15 * time.Second,
		WriteTimeout:     15 * time.Second,
		IdleTimeout:      60 * time.Second,
		MaxHeaderBytes:   1 << 20,
	}

	log.Printf("Starting IEC 62443-3-3 Analyzer on port %d (HTTPS)\n", cfg.Port)
	log.Printf("Environment: %s\n", cfg.Environment)

	if err := server.ListenAndServeTLS(cfg.TLSCert, cfg.TLSKey); err != nil {
		log.Fatalf("Server error: %v", err)
	}
}
