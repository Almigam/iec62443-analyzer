import { useState } from "react"
import { AnalyzerAPI } from "./api/client"
import Dashboard from "./components/Dashboard"
import ScanResults from "./components/ScanResults"
import Header from "./components/Header"

const API_BASE = import.meta.env.VITE_API_URL || "http://localhost:8080"

export default function App() {
  const [results, setResults] = useState(null)
  const [loading, setLoading] = useState(false)
  const [activeTab, setActiveTab] = useState("dashboard")
  const [authToken, setAuthToken] = useState(localStorage.getItem("auth_token"))

  const normalizeResponse = (data) => {
    if (!data) return null

    // Soporte para backend antiguo y nuevo formato de ScanAll
    if (Array.isArray(data.scans)) {
      const flatResults = data.scans.flatMap((scan) => scan.results || [])
      const totalChecks = data.scans.reduce((sum, scan) => sum + (scan.total || (scan.results || []).length), 0)
      const passed = data.scans.reduce((sum, scan) => sum + (scan.passed || countStatus(scan.results || [], "PASS")), 0)
      const failed = data.scans.reduce((sum, scan) => sum + (scan.failed || countStatus(scan.results || [], "FAIL")), 0)
      const warnings = data.scans.reduce((sum, scan) => sum + (scan.warnings || countStatus(scan.results || [], "WARNING")), 0)
      return {
        fr: data.fr || "ALL",
        description: data.description || "Full system scan",
        total_checks: totalChecks,
        passed,
        failed,
        warnings,
        results: flatResults,
      }
    }

    if (Array.isArray(data.results)) {
      return data
    }

    return null
  }

  const countStatus = (results, status) => {
    return results.reduce((count, item) => {
      return count + (item.status === status ? 1 : 0)
    }, 0)
  }

  const runScan = async (fr = "all") => {
    setLoading(true)
    try {
      const headers = {
        "Content-Type": "application/json",
      }
      if (authToken) {
        headers["Authorization"] = `Bearer ${authToken}`
      }
      const res = await fetch(`${API_BASE}/api/scan/${fr}`, { headers })
      if (!res.ok) {
        if (res.status === 401) {
          setAuthToken(null)
          localStorage.removeItem("auth_token")
          alert("Sesión expirada. Por favor, inicie sesión nuevamente.")
          return
        }
        throw new Error(`HTTP ${res.status}: ${res.statusText}`)
      }
      const data = await res.json()
      const normalized = normalizeResponse(data)
      if (!normalized) {
        throw new Error("Respuesta inesperada del backend")
      }
      setResults(normalized)
      setActiveTab("results")
    } catch (err) {
      alert("Error conectando con el backend: " + err.message)
    } finally {
      setLoading(false)
    }
  }

  const handleLogout = () => {
    setAuthToken(null)
    localStorage.removeItem("auth_token")
  }

  return (
    <div className="app">
      <Header onLogout={handleLogout} isAuthenticated={!!authToken} />
      <nav className="nav-tabs">
        <button
          className={activeTab === "dashboard" ? "active" : ""}
          onClick={() => setActiveTab("dashboard")}
        >
          Dashboard
        </button>
        <button
          className={activeTab === "results" ? "active" : ""}
          onClick={() => setActiveTab("results")}
          disabled={!results}
        >
          Resultados
        </button>
      </nav>

      <main className="main-content">
        {activeTab === "dashboard" && (
          <Dashboard results={results} onScan={runScan} loading={loading} />
        )}
        {activeTab === "results" && results && (
          <ScanResults results={results} />
        )}
      </main>
    </div>
  )
}