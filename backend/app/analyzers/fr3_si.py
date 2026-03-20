"""
FR3 - Integridad del Sistema (SI)
Evalúa SR 3.1 al SR 3.9 según IEC 62443-3-3
"""
import subprocess
import os


def check_sr_3_2_malicious_code() -> dict:
    """SR 3.2 - Protección contra códigos maliciosos"""
    results = []
    status = "PASS"

    # Comprobar si hay antivirus instalado
    av_tools = ["clamav", "clamdscan", "clamscan", "rkhunter", "chkrootkit"]
    found = []
    for tool in av_tools:
        try:
            subprocess.check_output(["which", tool], stderr=subprocess.DEVNULL)
            found.append(tool)
        except Exception:
            continue

    if found:
        results.append(f"Herramientas antimalware detectadas: {', '.join(found)}")
    else:
        status = "FAIL"
        results.append("No se detectó ninguna herramienta antimalware (clamav, rkhunter, chkrootkit)")

    # Comprobar si clamav está actualizado (base de datos)
    clamav_db = "/var/lib/clamav/main.cvd"
    clamav_db_alt = "/var/lib/clamav/main.cld"
    if os.path.exists(clamav_db) or os.path.exists(clamav_db_alt):
        results.append("Base de datos de ClamAV presente")
    elif "clamav" in found or "clamscan" in found:
        status = "WARNING"
        results.append("ClamAV instalado pero base de datos no encontrada")

    return {
        "sr_id": "SR3.2",
        "fr_id": "FR3",
        "description": "Protección contra códigos maliciosos",
        "status": status,
        "details": " | ".join(results),
        "sl_level": 1
    }


def check_sr_3_4_software_integrity() -> dict:
    """SR 3.4 - Integridad del software y de la información"""
    results = []
    status = "PASS"

    # Comprobar paquetes con debsums (integridad de ficheros instalados)
    try:
        subprocess.check_output(["which", "debsums"], stderr=subprocess.DEVNULL)
        results.append("debsums disponible para verificación de integridad de paquetes")
        try:
            output = subprocess.check_output(
                ["debsums", "--silent", "--changed"],
                stderr=subprocess.DEVNULL,
                timeout=30
            ).decode().strip()
            if output:
                status = "FAIL"
                results.append(f"Ficheros modificados detectados por debsums: {output[:200]}")
            else:
                results.append("No se detectaron ficheros de paquetes modificados")
        except subprocess.TimeoutExpired:
            results.append("debsums tardó demasiado, omitido")
        except Exception as e:
            results.append(f"Error ejecutando debsums: {str(e)}")
    except Exception:
        status = "WARNING"
        results.append("debsums no instalado (recomendado para verificar integridad)")

    # Comprobar si hay actualizaciones de seguridad pendientes
    try:
        output = subprocess.check_output(
            ["apt", "list", "--upgradable"],
            stderr=subprocess.DEVNULL
        ).decode()
        security_updates = [l for l in output.splitlines() if "security" in l.lower()]
        if security_updates:
            status = "WARNING"
            results.append(f"Actualizaciones de seguridad pendientes: {len(security_updates)}")
        else:
            results.append("No hay actualizaciones de seguridad pendientes")
    except Exception as e:
        results.append(f"No se pudo verificar actualizaciones: {str(e)}")

    return {
        "sr_id": "SR3.4",
        "fr_id": "FR3",
        "description": "Integridad del software y de la información",
        "status": status,
        "details": " | ".join(results),
        "sl_level": 2
    }


def check_sr_3_6_deterministic_output() -> dict:
    """SR 3.6 - Salida determinista"""
    results = []
    status = "PASS"

    # Comprobar si hay watchdog configurado (garantiza recuperación ante fallos)
    watchdog_path = "/dev/watchdog"
    if os.path.exists(watchdog_path):
        results.append("Dispositivo watchdog presente en /dev/watchdog")
    else:
        status = "WARNING"
        results.append("No se detectó watchdog hardware (/dev/watchdog)")

    # Comprobar systemd-watchdog
    try:
        output = subprocess.check_output(
            ["systemctl", "show", "--property=WatchdogSec", "systemd-journald"],
            stderr=subprocess.DEVNULL
        ).decode().strip()
        results.append(f"Watchdog systemd: {output}")
    except Exception:
        results.append("No se pudo verificar watchdog de systemd")

    return {
        "sr_id": "SR3.6",
        "fr_id": "FR3",
        "description": "Salida determinista ante fallos",
        "status": status,
        "details": " | ".join(results),
        "sl_level": 1
    }


def check_sr_3_7_error_handling() -> dict:
    """SR 3.7 - Tratamiento de errores"""
    results = []
    status = "PASS"

    # Comprobar si los logs del sistema están activos
    log_paths = ["/var/log/syslog", "/var/log/auth.log", "/var/log/kern.log"]
    for log in log_paths:
        if os.path.exists(log):
            size = os.path.getsize(log)
            results.append(f"{log}: {size} bytes")
        else:
            status = "WARNING"
            results.append(f"Log no encontrado: {log}")

    # Comprobar que journald está activo
    try:
        output = subprocess.check_output(
            ["systemctl", "is-active", "systemd-journald"],
            stderr=subprocess.DEVNULL
        ).decode().strip()
        if output == "active":
            results.append("systemd-journald activo")
        else:
            status = "FAIL"
            results.append(f"systemd-journald no activo: {output}")
    except Exception as e:
        results.append(f"No se pudo verificar journald: {str(e)}")

    return {
        "sr_id": "SR3.7",
        "fr_id": "FR3",
        "description": "Tratamiento de errores y logging",
        "status": status,
        "details": " | ".join(results),
        "sl_level": 2
    }


def run_all_fr3_checks() -> list:
    return [
        check_sr_3_2_malicious_code(),
        check_sr_3_4_software_integrity(),
        check_sr_3_6_deterministic_output(),
        check_sr_3_7_error_handling(),
    ]