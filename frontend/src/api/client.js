// API Configuration
export const API_CONFIG = {
  baseURL: import.meta.env.VITE_API_URL || 'http://localhost:8080',
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  }
}

// API Service
export class ApiService {
  static async request(endpoint, options = {}) {
    const url = `${API_CONFIG.baseURL}${endpoint}`
    const authToken = localStorage.getItem('auth_token')
    
    const headers = {
      ...API_CONFIG.headers,
      ...options.headers,
    }

    if (authToken) {
      headers['Authorization'] = `Bearer ${authToken}`
    }

    const config = {
      ...options,
      headers,
    }

    try {
      const response = await fetch(url, config)

      if (response.status === 401) {
        // Token expired
        localStorage.removeItem('auth_token')
        window.location.href = '/login'
      }

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }

      return await response.json()
    } catch (error) {
      console.error('API request failed:', error)
      throw error
    }
  }

  static get(endpoint) {
    return this.request(endpoint, { method: 'GET' })
  }

  static post(endpoint, data) {
    return this.request(endpoint, {
      method: 'POST',
      body: JSON.stringify(data),
    })
  }

  static put(endpoint, data) {
    return this.request(endpoint, {
      method: 'PUT',
      body: JSON.stringify(data),
    })
  }

  static delete(endpoint) {
    return this.request(endpoint, { method: 'DELETE' })
  }
}

// Analyzer API endpoints
export const AnalyzerAPI = {
  health: () => ApiService.get('/healthz'),
  scanFR: (frNumber) => ApiService.get(`/api/scan/fr${frNumber}`),
  scanAll: () => ApiService.get('/api/scan/all'),
  getResults: () => ApiService.get('/api/results'),
}
