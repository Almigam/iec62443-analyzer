const STATUS_CONFIG = {
  PASS:    { icon: "✅", className: "status-pass",    label: "PASS"    },
  FAIL:    { icon: "❌", className: "status-fail",    label: "FAIL"    },
  WARNING: { icon: "⚠️", className: "status-warning", label: "WARNING" },
}

export default function ScanResults({ results }) {
  return (
    <div className="scan-results">
      <div className="results-header">
        <h2>{results.fr}</h2>
        <p>{results.total_checks} checks ejecutados</p>
      </div>

      <div className="results-table-wrapper">
        <table className="results-table">
          <thead>
            <tr>
              <th>SR ID</th>
              <th>FR</th>
              <th>Descripción</th>
              <th>Estado</th>
              <th>SL</th>
              <th>Detalles</th>
            </tr>
          </thead>
          <tbody>
            {results.results.map((r, i) => {
              const cfg = STATUS_CONFIG[r.status]
              return (
                <tr key={i} className={`row-${r.status.toLowerCase()}`}>
                  <td><code>{r.sr_id}</code></td>
                  <td><span className="fr-badge">{r.fr_id}</span></td>
                  <td>{r.description}</td>
                  <td>
                    <span className={`status-badge ${cfg.className}`}>
                      {cfg.icon} {cfg.label}
                    </span>
                  </td>
                  <td><span className="sl-badge">SL{r.sl_level}</span></td>
                  <td className="details-cell">
                    {r.details.split(" | ").map((d, j) => (
                      <div key={j} className="detail-item">{d}</div>
                    ))}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
    </div>
  )
}