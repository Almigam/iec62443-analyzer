"""
FR5 - Flujo de Datos Restringido (RDF)
Evalúa SR 5.1 al SR 5.4 según IEC 62443-3-3
"""
import subprocess
import os


def check_sr_5_1_network_segmentation() -> dict:
    """SR 5.1 - Segmentación de red"""
    results = []
    status = "PASS"

    # Comprobar interfaces de red activas
    try:
        output = subprocess.check_output(
            ["ip", "link", "show"],
            stderr=subprocess.DEVNULL
        ).decode()
        interfaces = [l.split(":")[1].strip() for l in output.splitlines() if ": " in l and "lo" not in l]
        results.append(f"Interfaces de red activas: {', '.join(interfaces)}")
    except Exception as e:
        results.append(f"No se pudieron listar interfaces: {str(e)}")

    # Comprobar si IP forwarding está deshabilitado
    ipv4_forward = "/proc/sys/net/ipv4/ip_forward"
    if os.path.exists(ipv4_forward):
        with open(ipv4_forward, "r") as f:
            val = f.read().strip()
        if val == "1":
            status = "WARNING"
            results.append("IP forwarding habilitado (val=1) — revisar si es necesario")
        else:
            results.append("IP forwarding deshabilitado (val=0) OK")

    return {
        "sr_id": "SR5.1",
        "fr_id": "FR5",
        "description": "Segmentación de red",
        "status": status,
        "details": " | ".join(results),
        "sl_level": 1
    }


def check_sr_5_2_zone_boundary() -> dict:
    """SR 5.2 - Protección de los límites de la zona (Firewall)"""
    results = []
    status = "PASS"

    # Comprobar iptables / nftables / ufw
    firewall_found = False

    # UFW
    try:
        output = subprocess.check_output(
            ["ufw", "status"],
            stderr=subprocess.DEVNULL
        ).decode()
        if "active" in output.lower():
            results.append("UFW activo")
            firewall_found = True
        else:
            results.append("UFW instalado pero inactivo")
    except Exception:
        pass

    # iptables
    try:
        output = subprocess.check_output(
            ["iptables", "-L", "-n"],
            stderr=subprocess.DEVNULL
        ).decode()
        rules = [l for l in output.splitlines() if l.startswith("ACCEPT") or l.startswith("DROP") or l.startswith("REJECT")]
        if rules:
            results.append(f"iptables: {len(rules)} reglas activas")
            firewall_found = True
        else:
            results.append("iptables: sin reglas activas (política por defecto)")
    except Exception:
        pass

    # nftables
    try:
        output = subprocess.check_output(
            ["nft", "list", "ruleset"],
            stderr=subprocess.DEVNULL
        ).decode().strip()
        if output:
            results.append("nftables: reglas configuradas")
            firewall_found = True
    except Exception:
        pass

    if not firewall_found:
        status = "FAIL"
        results.append("No se detectó ningún firewall activo (ufw, iptables, nftables)")

    # Comprobar puertos abiertos
    try:
        output = subprocess.check_output(
            ["ss", "-tlnp"],
            stderr=subprocess.DEVNULL
        ).decode()
        open_ports = [l for l in output.splitlines() if "LISTEN" in l]
        results.append(f"Puertos en escucha: {len(open_ports)}")
        for port_line in open_ports[:5]:  # Mostrar máximo 5
            results.append(f"  → {port_line.strip()}")
    except Exception as e:
        results.append(f"No se pudieron listar puertos: {str(e)}")

    return {
        "sr_id": "SR5.2",
        "fr_id": "FR5",
        "description": "Protección de límites de zona (Firewall)",
        "status": status,
        "details": " | ".join(results),
        "sl_level": 1
    }


def check_sr_5_3_general_purpose_comms() -> dict:
    """SR 5.3 - Restricciones de comunicación de propósito general"""
    results = []
    status = "PASS"

    # Comprobar servicios innecesarios activos
    unnecessary_services = ["telnet", "ftp", "rsh", "rlogin", "vsftpd", "xinetd"]
    for service in unnecessary_services:
        try:
            output = subprocess.check_output(
                ["systemctl", "is-active", service],
                stderr=subprocess.DEVNULL
            ).decode().strip()
            if output == "active":
                status = "FAIL"
                results.append(f"Servicio inseguro activo: {service}")
        except Exception:
            pass

    if status == "PASS":
        results.append("No se detectaron servicios de comunicación inseguros activos (telnet, ftp, rsh...)")

    # Comprobar si el servidor de correo está activo innecesariamente
    mail_services = ["postfix", "sendmail", "exim4"]
    for service in mail_services:
        try:
            output = subprocess.check_output(
                ["systemctl", "is-active", service],
                stderr=subprocess.DEVNULL
            ).decode().strip()
            if output == "active":
                status = "WARNING"
                results.append(f"Servidor de correo activo: {service} (revisar si es necesario)")
        except Exception:
            pass

    return {
        "sr_id": "SR5.3",
        "fr_id": "FR5",
        "description": "Restricción de comunicaciones de propósito general",
        "status": status,
        "details": " | ".join(results),
        "sl_level": 1
    }


def run_all_fr5_checks() -> list:
    return [
        check_sr_5_1_network_segmentation(),
        check_sr_5_2_zone_boundary(),
        check_sr_5_3_general_purpose_comms(),
    ]