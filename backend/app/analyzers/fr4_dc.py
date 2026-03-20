"""
FR4 - Confidencialidad de los Datos (DC)
Evalúa SR 4.1 al SR 4.3 según IEC 62443-3-3
"""
import subprocess
import os
import re


def check_sr_4_1_confidentiality() -> dict:
    """SR 4.1 - Confidencialidad de la información"""
    results = []
    status = "PASS"

    # Comprobar configuración SSH (protocolo cifrado principal)
    ssh_config = "/etc/ssh/sshd_config"
    if os.path.exists(ssh_config):
        with open(ssh_config, "r") as f:
            content = f.read()

        # Verificar que no se permite root login
        if re.search(r"^PermitRootLogin\s+yes", content, re.MULTILINE):
            status = "FAIL"
            results.append("SSH permite login como root (PermitRootLogin yes)")
        else:
            results.append("SSH: PermitRootLogin no está en 'yes'")

        # Verificar autenticación por contraseña
        if re.search(r"^PasswordAuthentication\s+no", content, re.MULTILINE):
            results.append("SSH: PasswordAuthentication deshabilitada (solo clave pública)")
        else:
            status = "WARNING"
            results.append("SSH: PasswordAuthentication habilitada (recomendado usar solo clave pública)")

        # Verificar protocolo SSH
        if "Protocol 1" in content:
            status = "FAIL"
            results.append("SSH: Protocolo 1 detectado (inseguro, usar solo protocolo 2)")
        else:
            results.append("SSH: Protocolo 1 no detectado")
    else:
        status = "WARNING"
        results.append("No existe /etc/ssh/sshd_config (SSH no instalado o no configurado)")

    return {
        "sr_id": "SR4.1",
        "fr_id": "FR4",
        "description": "Confidencialidad de la información en tránsito",
        "status": status,
        "details": " | ".join(results),
        "sl_level": 1
    }


def check_sr_4_2_information_persistence() -> dict:
    """SR 4.2 - Persistencia de la información"""
    results = []
    status = "PASS"

    # Comprobar si /tmp se limpia al reiniciar
    try:
        output = subprocess.check_output(
            ["systemctl", "is-enabled", "systemd-tmpfiles-clean"],
            stderr=subprocess.DEVNULL
        ).decode().strip()
        results.append(f"systemd-tmpfiles-clean: {output}")
    except Exception:
        status = "WARNING"
        results.append("No se pudo verificar limpieza automática de /tmp")

    # Comprobar si hay ficheros world-writable en lugares sensibles
    try:
        output = subprocess.check_output(
            ["find", "/etc", "-perm", "-002", "-type", "f"],
            stderr=subprocess.DEVNULL,
            timeout=15
        ).decode().strip()
        if output:
            status = "FAIL"
            results.append(f"Ficheros escribibles por todos en /etc: {output[:300]}")
        else:
            results.append("No hay ficheros world-writable en /etc")
    except subprocess.TimeoutExpired:
        results.append("Búsqueda de world-writable en /etc tardó demasiado")
    except Exception as e:
        results.append(f"Error buscando world-writable: {str(e)}")

    return {
        "sr_id": "SR4.2",
        "fr_id": "FR4",
        "description": "Persistencia y borrado seguro de información",
        "status": status,
        "details": " | ".join(results),
        "sl_level": 2
    }


def check_sr_4_3_cryptography() -> dict:
    """SR 4.3 - Uso de criptografía"""
    results = []
    status = "PASS"

    # Comprobar algoritmos SSH permitidos
    ssh_config = "/etc/ssh/sshd_config"
    if os.path.exists(ssh_config):
        with open(ssh_config, "r") as f:
            content = f.read()
        if "Ciphers" in content:
            results.append("Ciphers SSH configurados explícitamente")
            if "arcfour" in content.lower() or "des" in content.lower():
                status = "FAIL"
                results.append("Algoritmos de cifrado débiles detectados en SSH (arcfour/DES)")
        else:
            status = "WARNING"
            results.append("SSH usa ciphers por defecto (recomendado especificarlos explícitamente)")

    # Comprobar si OpenSSL está instalado y versión
    try:
        output = subprocess.check_output(
            ["openssl", "version"],
            stderr=subprocess.DEVNULL
        ).decode().strip()
        results.append(f"OpenSSL: {output}")
    except Exception:
        status = "WARNING"
        results.append("OpenSSL no encontrado")

    return {
        "sr_id": "SR4.3",
        "fr_id": "FR4",
        "description": "Uso de criptografía",
        "status": status,
        "details": " | ".join(results),
        "sl_level": 1
    }


def run_all_fr4_checks() -> list:
    import re
    return [
        check_sr_4_1_confidentiality(),
        check_sr_4_2_information_persistence(),
        check_sr_4_3_cryptography(),
    ]