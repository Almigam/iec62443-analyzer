import { PieChart, Pie, Cell, Tooltip, Legend, ResponsiveContainer } from "recharts"

const FR_LIST = [
  { id: "fr1", label: "FR1 - Identificación y Autenticación" },
  { id: "fr2", label: "FR2 - Control de Uso" },
  { id: "fr3", label: "FR3 - Integridad del Sistema" },
  { id: "fr4", label: "FR4 - Confidencialidad de Datos" },
  { id: "fr5", label: "FR5 - Flujo de Datos Restringido" },
  { id: "fr6", label: "FR6 - Respuesta a Incidentes" },
  { id: "fr7", label: "FR7 - Disponibilidad de Recursos" },
]

const COLORS = {
  PASS: "#22c55e",
  FAIL: "#ef4444",
  WARNING: "#f59e0b",
}

export default function Dashboard({ results, onScan, loading }) {
  const chartData = results
    ? [
        { name: "PASS", value: results.passed },
        { name: "FAIL", value: results.failed },
        { name: "WARNING", value: results.warnings },
      ]
    : []

  const score = results
    ? Math.round((results.passed / results.total_checks) * 100)
    : null

  return (
    <div className="dashboard">

      {/* Botones de escaneo */}
      <div className="scan-section">
        <h2>Ejecutar Análisis</h2>
        <div className="scan-buttons">
          <button
            className="btn btn-primary btn-large"
            onClick={() => onScan("all")}
            disabled={loading}
          >
            {loading ? "⏳ Analizando..." : "🔍 Análisis Completo"}
          </button>
          <div className="fr-buttons">
            {FR_LIST.map((fr) => (
              <button
                key={fr.id}
                className="btn btn-secondary"
                onClick={() => onScan(fr.id)}
                disabled={loading}
              >
                {fr.label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Resultados resumen */}
      {results && (
        <>
          <div className="stats-grid">
            <div className="stat-card stat-total">
              <span className="stat-number">{results.total_checks}</span>
              <span className="stat-label">Total Checks</span>
            </div>
            <div className="stat-card stat-pass">
              <span className="stat-number">{results.passed}</span>
              <span className="stat-label">✅ PASS</span>
            </div>
            <div className="stat-card stat-fail">
              <span className="stat-number">{results.failed}</span>
              <span className="stat-label">❌ FAIL</span>
            </div>
            <div className="stat-card stat-warning">
              <span className="stat-number">{results.warnings}</span>
              <span className="stat-label">⚠️ WARNING</span>
            </div>
            <div className={`stat-card stat-score ${score >= 70 ? "score-good" : score >= 40 ? "score-medium" : "score-bad"}`}>
              <span className="stat-number">{score}%</span>
              <span className="stat-label">Puntuación</span>
            </div>
          </div>

          {/* Gráfico */}
          <div className="chart-section">
            <h2>Distribución de Resultados</h2>
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={chartData}
                  cx="50%"
                  cy="50%"
                  outerRadius={100}
                  dataKey="value"
                  label={({ name, value }) => `${name}: ${value}`}
                >
                  {chartData.map((entry) => (
                    <Cell key={entry.name} fill={COLORS[entry.name]} />
                  ))}
                </Pie>
                <Tooltip />
                <Legend />
              </PieChart>
            </ResponsiveContainer>
          </div>

          {/* Resumen por FR */}
          <div className="fr-summary">
            <h2>Resumen por Requisito Fundamental</h2>
            <div className="fr-grid">
              {groupByFR(results.results).map(({ fr_id, items }) => {
                const pass = items.filter(i => i.status === "PASS").length
                const fail = items.filter(i => i.status === "FAIL").length
                const warn = items.filter(i => i.status === "WARNING").length
                const frScore = Math.round((pass / items.length) * 100)
                return (
                  <div key={fr_id} className="fr-card">
                    <div className="fr-card-header">
                      <strong>{fr_id}</strong>
                      <span className={`fr-score ${frScore >= 70 ? "score-good" : frScore >= 40 ? "score-medium" : "score-bad"}`}>
                        {frScore}%
                      </span>
                    </div>
                    <div className="fr-card-bars">
                      <span className="pass-count">✅ {pass}</span>
                      <span className="fail-count">❌ {fail}</span>
                      <span className="warn-count">⚠️ {warn}</span>
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        </>
      )}

      {!results && !loading && (
        <div className="empty-state">
          <p>🔍 Pulsa "Análisis Completo" para empezar el escaneo del sistema</p>
        </div>
      )}
    </div>
  )
}

function groupByFR(results) {
  const groups = {}
  for (const r of results) {
    if (!groups[r.fr_id]) groups[r.fr_id] = []
    groups[r.fr_id].push(r)
  }
  return Object.entries(groups).map(([fr_id, items]) => ({ fr_id, items }))
}