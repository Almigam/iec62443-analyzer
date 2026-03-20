from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from app.database import init_db, get_db, ScanResult
from app.analyzers.fr1_iac import run_all_fr1_checks
from app.analyzers.fr2_uc import run_all_fr2_checks
from app.analyzers.fr3_si import run_all_fr3_checks
from app.analyzers.fr4_dc import run_all_fr4_checks
from app.analyzers.fr5_rdf import run_all_fr5_checks
from app.analyzers.fr6_tre import run_all_fr6_checks
from app.analyzers.fr7_ra import run_all_fr7_checks

app = FastAPI(
    title="IEC 62443-3-3 Analyzer",
    description="Analizador de cumplimiento para sistemas de control industrial",
    version="0.2.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
def startup():
    init_db()

@app.get("/")
def root():
    return {"message": "IEC 62443-3-3 Analyzer API", "status": "running"}

def save_results(db, results):
    for r in results:
        db.add(ScanResult(**r))
    db.commit()

def build_summary(fr_name: str, results: list) -> dict:
    return {
        "fr": fr_name,
        "total_checks": len(results),
        "passed": sum(1 for r in results if r["status"] == "PASS"),
        "failed": sum(1 for r in results if r["status"] == "FAIL"),
        "warnings": sum(1 for r in results if r["status"] == "WARNING"),
        "results": results
    }

@app.get("/api/scan/fr1")
def scan_fr1(db: Session = Depends(get_db)):
    results = run_all_fr1_checks()
    save_results(db, results)
    return build_summary("FR1 - Control de Identificación y Autenticación (IAC)", results)

@app.get("/api/scan/fr2")
def scan_fr2(db: Session = Depends(get_db)):
    results = run_all_fr2_checks()
    save_results(db, results)
    return build_summary("FR2 - Control de Uso (UC)", results)

@app.get("/api/scan/fr3")
def scan_fr3(db: Session = Depends(get_db)):
    results = run_all_fr3_checks()
    save_results(db, results)
    return build_summary("FR3 - Integridad del Sistema (SI)", results)

@app.get("/api/scan/fr4")
def scan_fr4(db: Session = Depends(get_db)):
    results = run_all_fr4_checks()
    save_results(db, results)
    return build_summary("FR4 - Confidencialidad de los Datos (DC)", results)

@app.get("/api/scan/fr5")
def scan_fr5(db: Session = Depends(get_db)):
    results = run_all_fr5_checks()
    save_results(db, results)
    return build_summary("FR5 - Flujo de Datos Restringido (RDF)", results)

@app.get("/api/scan/fr6")
def scan_fr6(db: Session = Depends(get_db)):
    results = run_all_fr6_checks()
    save_results(db, results)
    return build_summary("FR6 - Respuesta Oportuna a los Incidentes (TRE)", results)

@app.get("/api/scan/fr7")
def scan_fr7(db: Session = Depends(get_db)):
    results = run_all_fr7_checks()
    save_results(db, results)
    return build_summary("FR7 - Disponibilidad de Recursos (RA)", results)

@app.get("/api/scan/all")
def scan_all(db: Session = Depends(get_db)):
    all_results = (
        run_all_fr1_checks() +
        run_all_fr2_checks() +
        run_all_fr3_checks() +
        run_all_fr4_checks() +
        run_all_fr5_checks() +
        run_all_fr6_checks() +
        run_all_fr7_checks()
    )
    save_results(db, all_results)
    return build_summary("Análisis Completo IEC 62443-3-3", all_results)

@app.get("/api/history")
def get_history(db: Session = Depends(get_db)):
    results = db.query(ScanResult).order_by(ScanResult.timestamp.desc()).limit(50).all()
    return results