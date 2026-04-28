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
      setResults(data)
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