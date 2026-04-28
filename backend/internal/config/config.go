package config

import (
	"os"
	"strconv"
)

type Config struct {
	Environment    string
	Port           int
	DBPath         string
	TLSCert        string
	TLSKey         string
	AllowedOrigins string
	JWTSecret      string
	LogDir         string
}

func LoadConfig() *Config {
	return &Config{
		Environment:    getEnv("ENV", "development"),
		Port:           getEnvInt("PORT", 8080),
		DBPath:         getEnv("DB_PATH", "./data/iec62443.db"),
		TLSCert:        getEnv("TLS_CERT", "./certs/server.crt"),
		TLSKey:         getEnv("TLS_KEY", "./certs/server.key"),
		AllowedOrigins: getEnv("ALLOWED_ORIGINS", "http://localhost"),
		JWTSecret:      getEnv("JWT_SECRET", "your-secret-key-change-in-production"),
		LogDir:         getEnv("LOG_DIR", "./logs"),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intVal, err := strconv.Atoi(value); err == nil {
			return intVal
		}
	}
	return defaultValue
}
