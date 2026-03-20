"""
FR6 - Respuesta Oportuna a los Incidentes (TRE)
Evalúa SR 6.1 al SR 6.2 según IEC 62443-3-3
"""
import subprocess
import os


def check_sr_6_1_audit_log_access() -> dict:
    """SR 6.1 - Accesibilidad de los registros de auditoría"""
    results = []
    status = "PASS"

    # Comprobar que los logs de auditoría existen y son accesibles
    audit_log = "/var/log/audit/audit.log"
    if os.path.exists(audit_log):
        size = os.path.getsize(audit_log)
        results.append(f"Log de auditoría encontrado: {audit_log} ({size} bytes)")
        # Comprobar que no sea modificable por todos
        mode = oct(os.stat(audit_log).st_mode)[-3:]
        if mode in ["600", "640"]:
            results.append(f"Permisos del log de auditoría: {mode} OK")
        else:
            status = "WARNING"
            results.append(f"Permisos del log de auditoría: {mode} (recomendado 600 o 640)")
    else:
        status = "WARNING"
        results.append("No existe /var/log/audit/audit.log — auditd puede no estar configurado")

    # Comprobar logs alternativos
    syslog = "/var/log/syslog"
    if os.path.exists(syslog):
        results.append(f"Syslog disponible: {syslog}")
    else:
        status = "WARNING"
        results.append("No existe /var/log/syslog")

    return {
        "sr_id": "SR6.1",
        "fr_id": "FR6",
        "description": "Accesibilidad de los registros de auditoría",
        "status": status,
        "details": " | ".join(results),
        "sl_level": 1
    }


def check_sr_6_2_continuous_monitoring() -> dict:
    """SR 6.2 - Supervisión continua"""
    results = []
    status = "PASS"

    # Comprobar fail2ban (detección de intrusiones básica)
    try:
        output = subprocess.check_output(
            ["systemctl", "is-active", "fail2ban"],
            stderr=subprocess.DEVNULL
        ).decode().strip()
        if output == "active":
            results.append("fail2ban activo (detección de intrusiones)")
        else:
            status = "WARNING"
            results.append(f"fail2ban no activo (estado: {output})")
    except Exception:
        status = "WARNING"
        results.append("fail2ban no instalado (recomendado para supervisión)")

    # Comprobar si hay IDS instalado
    ids_tools = ["snort", "suricata", "ossec"]
    found_ids = []
    for tool in ids_tools:
        try:
            subprocess.check_output(["which", tool], stderr=subprocess.DEVNULL)
            found_ids.append(tool)
        except Exception:
            continue

    if found_ids:
        results.append(f"IDS detectado: {', '.join(found_ids)}")
    else:
        status = "WARNING"
        results.append("No se detectó IDS (snort, suricata, ossec)")

    # Comprobar journald para logs persistentes
    try:
        output = subprocess.check_output(
            ["journalctl", "--disk-usage"],
            stderr=subprocess.DEVNULL
        ).decode().strip()
        results.append(f"Uso de disco journald: {output}")
    except Exception:
        results.append("No se pudo verificar journald")

    return {
        "sr_id": "SR6.2",
        "fr_id": "FR6",
        "description": "Supervisión continua del sistema",
        "status": status,
        "details": " | ".join(results),
        "sl_level": 2
    }


def run_all_fr6_checks() -> list:
    return [
        check_sr_6_1_audit_log_access(),
        check_sr_6_2_continuous_monitoring(),
    ]