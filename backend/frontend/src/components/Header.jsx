export default function Header() {
  return (
    <header className="header">
      <div className="header-content">
        <div className="header-logo">
          <span className="header-icon">🛡️</span>
          <div>
            <h1>IEC 62443-3-3 Analyzer</h1>
            <p>Analizador de cumplimiento para sistemas de control industrial</p>
          </div>
        </div>
        <div className="header-badge">
          <span>Raspberry Pi OS 64-bit</span>
        </div>
      </div>
    </header>
  )
}