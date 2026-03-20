"""
FR2 - Control de Uso (UC)
Evalúa SR 2.1 al SR 2.12 según IEC 62443-3-3
"""
import subprocess
import os
import re

def check_sr_2_1_authorization() -> dict:
    """SR 2.1 - Aplicación de la autorización"""
    results = []
    status = "PASS"

    # Comprobar configuración de sudo
    sudoers_path = "/etc/sudoers"
    if os.path.exists(sudoers_path):
        try:
            output = subprocess.check_output(
                ["grep", "-v", "^#", sudoers_path],
                stderr=subprocess.DEVNULL
            ).decode().strip()
            if "ALL=(ALL) NOPASSWD: ALL" in output:
                status = "FAIL"
                results.append("Existe regla sudo sin contraseña (NOPASSWD:ALL)")
            else:
                results.append("No se detectaron reglas sudo sin contraseña peligrosas")
        except Exception as e:
            results.append(f"No se pudo leer sudoers (requiere root): {str(e)}")
            status = "WARNING"
    else:
        status = "FAIL"
        results.append("No existe /etc/sudoers")

    # Comprobar permisos de ficheros críticos
    critical_files = ["/etc/passwd", "/etc/shadow", "/etc/sudoers"]
    for f in critical_files:
        if os.path.exists(f):
            mode = oct(os.stat(f).st_mode)[-3:]
            if f == "/etc/shadow" and mode != "000":
                results.append(f"Permisos de {f}: {mode} (recomendado 000)")
                status = "WARNING"
            elif f == "/etc/passwd" and mode not in ["644", "444"]:
                results.append(f"Permisos de {f}: {mode} (recomendado 644)")
                status = "WARNING"
            else:
                results.append(f"Permisos de {f}: {mode} OK")

    return {
        "sr_id": "SR2.1",
        "fr_id": "FR2",
        "description": "Aplicación de la autorización",
        "status": status,
        "details": " | ".join(results),
        "sl_level": 1
    }


def check_sr_2_5_session_lock() -> dict:
    """SR 2.5 - Bloqueo de sesión"""
    results = []
    status = "PASS"

    # Comprobar TMOUT para cierre automático de sesión bash
    bash_profile_files = ["/etc/profile", "/etc/bash.bashrc", "/etc/environment"]
    tmout_found = False
    for path in bash_profile_files:
        if os.path.exists(path):
            with open(path, "r") as f:
                content = f.read()
            if "TMOUT" in content:
                tmout_found = True
                match = re.search(r"TMOUT=(\d+)", content)
                if match:
                    seconds = int(match.group(1))
                    if seconds > 900:
                        status = "WARNING"
                        results.append(f"TMOUT={seconds}s en {path} (recomendado <= 900s)")
                    else:
                        results.append(f"TMOUT={seconds}s en {path} OK")

    if not tmout_found:
        status = "FAIL"
        results.append("No se encontró TMOUT configurado en ningún perfil del sistema")

    return {
        "sr_id": "SR2.5",
        "fr_id": "FR2",
        "description": "Bloqueo de sesión por inactividad",
        "status": status,
        "details": " | ".join(results),
        "sl_level": 1
    }


def check_sr_2_8_audit_events() -> dict:
    """SR 2.8 - Eventos auditables"""
    results = []
    status = "PASS"

    # Comprobar si auditd está activo
    try:
        output = subprocess.check_output(
            ["systemctl", "is-active", "auditd"],
            stderr=subprocess.DEVNULL
        ).decode().strip()
        if output == "active":
            results.append("auditd está activo")
        else:
            status = "FAIL"
            results.append(f"auditd no está activo (estado: {output})")
    except Exception as e:
        status = "FAIL"
        results.append(f"No se pudo verificar auditd: {str(e)}")

    # Comprobar si existe configuración de auditoría
    audit_rules = "/etc/audit/audit.rules"
    if os.path.exists(audit_rules):
        with open(audit_rules, "r") as f:
            content = f.read()
        if "-a always,exit" in content or "-w" in content:
            results.append("Reglas de auditoría configuradas")
        else:
            status = "WARNING"
            results.append("No se encontraron reglas de auditoría en audit.rules")
    else:
        status = "WARNING"
        results.append("No existe /etc/audit/audit.rules")

    return {
        "sr_id": "SR2.8",
        "fr_id": "FR2",
        "description": "Eventos auditables",
        "status": status,
        "details": " | ".join(results),
        "sl_level": 1
    }


def check_sr_2_11_timestamps() -> dict:
    """SR 2.11 - Marcas de tiempo"""
    results = []
    status = "PASS"

    # Comprobar sincronización NTP
    ntp_services = ["systemd-timesyncd", "ntp", "chrony", "chronyd"]
    ntp_active = False
    for service in ntp_services:
        try:
            output = subprocess.check_output(
                ["systemctl", "is-active", service],
                stderr=subprocess.DEVNULL
            ).decode().strip()
            if output == "active":
                results.append(f"Sincronización de tiempo activa: {service}")
                ntp_active = True
                break
        except Exception:
            continue

    if not ntp_active:
        status = "FAIL"
        results.append("No se detectó ningún servicio NTP activo (timesyncd, ntp, chrony)")

    # Comprobar zona horaria configurada
    try:
        tz = subprocess.check_output(
            ["timedatectl", "show", "--property=Timezone", "--value"],
            stderr=subprocess.DEVNULL
        ).decode().strip()
        results.append(f"Zona horaria: {tz}")
    except Exception:
        results.append("No se pudo verificar la zona horaria")

    return {
        "sr_id": "SR2.11",
        "fr_id": "FR2",
        "description": "Marcas de tiempo y sincronización NTP",
        "status": status,
        "details": " | ".join(results),
        "sl_level": 2
    }


def run_all_fr2_checks() -> list:
    return [
        check_sr_2_1_authorization(),
        check_sr_2_5_session_lock(),
        check_sr_2_8_audit_events(),
        check_sr_2_11_timestamps(),
    ]