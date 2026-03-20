import { useState } from "react"
import Dashboard from "./components/Dashboard"
import ScanResults from "./components/ScanResults"
import Header from "./components/Header"

export default function App() {
  const [results, setResults] = useState(null)
  const [loading, setLoading] = useState(false)
  const [activeTab, setActiveTab] = useState("dashboard")

  const runScan = async (fr = "all") => {
    setLoading(true)
    try {
      const res = await fetch(`http://localhost:8000/api/scan/${fr}`)
      const data = await res.json()
      setResults(data)
      setActiveTab("results")
    } catch (err) {
      alert("Error conectando con el backend: " + err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="app">
      <Header />
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