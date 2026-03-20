"""
FR7 - Disponibilidad de Recursos (RA)
Evalúa SR 7.1 al SR 7.8 según IEC 62443-3-3
"""
import subprocess
import os
import psutil


def check_sr_7_1_dos_protection() -> dict:
    """SR 7.1 - Protección contra denegación de servicio"""
    results = []
    status = "PASS"

    # Comprobar límites del sistema (ulimits)
    try:
        output = subprocess.check_output(
            ["ulimit", "-a"],
            shell=True,
            stderr=subprocess.DEVNULL
        ).decode()
        results.append("Límites del sistema (ulimit) verificados")
        if "unlimited" in output.lower():
            status = "WARNING"
            results.append("Algunos límites del sistema son 'unlimited' (revisar)")
    except Exception as e:
        results.append(f"No se pudieron verificar ulimits: {str(e)}")

    # Comprobar uso actual de CPU y memoria
    cpu_percent = psutil.cpu_percent(interval=1)
    mem = psutil.virtual_memory()
    results.append(f"CPU actual: {cpu_percent}%")
    results.append(f"RAM: {mem.percent}% usada ({mem.used // 1024 // 1024}MB / {mem.total // 1024 // 1024}MB)")

    if cpu_percent > 90:
        status = "WARNING"
        results.append("CPU al límite (>90%)")
    if mem.percent > 90:
        status = "WARNING"
        results.append("RAM al límite (>90%)")

    return {
        "sr_id": "SR7.1",
        "fr_id": "FR7",
        "description": "Protección contra denegación de servicio",
        "status": status,
        "details": " | ".join(results),
        "sl_level": 1
    }


def check_sr_7_3_backup() -> dict:
    """SR 7.3 - Copia de seguridad del sistema de control"""
    results = []
    status = "PASS"

    # Comprobar herramientas de backup instaladas
    backup_tools = ["rsync", "tar", "duplicati", "borgbackup", "restic"]
    found = []
    for tool in backup_tools:
        try:
            subprocess.check_output(["which", tool], stderr=subprocess.DEVNULL)
            found.append(tool)
        except Exception:
            continue

    if found:
        results.append(f"Herramientas de backup detectadas: {', '.join(found)}")
    else:
        status = "WARNING"
        results.append("No se detectaron herramientas de backup (rsync, tar, restic...)")

    # Comprobar si hay tareas cron de backup
    cron_dirs = ["/etc/cron.daily", "/etc/cron.weekly", "/var/spool/cron"]
    backup_cron_found = False
    for cron_dir in cron_dirs:
        if os.path.exists(cron_dir):
            try:
                files = os.listdir(cron_dir)
                backup_files = [f for f in files if any(kw in f.lower() for kw in ["backup", "rsync", "dump"])]
                if backup_files:
                    results.append(f"Tareas cron de backup en {cron_dir}: {', '.join(backup_files)}")
                    backup_cron_found = True
            except Exception:
                pass

    if not backup_cron_found:
        status = "WARNING"
        results.append("No se detectaron tareas cron de backup automático")

    return {
        "sr_id": "SR7.3",
        "fr_id": "FR7",
        "description": "Copia de seguridad del sistema",
        "status": status,
        "details": " | ".join(results),
        "sl_level": 1
    }


def check_sr_7_4_recovery() -> dict:
    """SR 7.4 - Recuperación y reconstitución del sistema de control"""
    results = []
    status = "PASS"

    # Comprobar si systemd puede reiniciar servicios automáticamente
    try:
        output = subprocess.check_output(
            ["systemctl", "list-units", "--type=service", "--state=failed"],
            stderr=subprocess.DEVNULL
        ).decode()
        failed = [l for l in output.splitlines() if "failed" in l.lower() and ".service" in l]
        if failed:
            status = "WARNING"
            results.append(f"Servicios en estado fallido: {len(failed)}")
            for f in failed[:3]:
                results.append(f"  → {f.strip()}")
        else:
            results.append("No hay servicios en estado fallido")
    except Exception as e:
        results.append(f"No se pudo verificar servicios fallidos: {str(e)}")

    # Comprobar uptime del sistema
    try:
        uptime = subprocess.check_output(["uptime", "-p"], stderr=subprocess.DEVNULL).decode().strip()
        results.append(f"Uptime del sistema: {uptime}")
    except Exception:
        results.append("No se pudo verificar uptime")

    return {
        "sr_id": "SR7.4",
        "fr_id": "FR7",
        "description": "Recuperación y reconstitución del sistema",
        "status": status,
        "details": " | ".join(results),
        "sl_level": 1
    }


def check_sr_7_6_network_config() -> dict:
    """SR 7.6 - Ajustes de configuración de red y seguridad"""
    results = []
    status = "PASS"

    # Comprobar parámetros del kernel relacionados con red
    kernel_params = {
        "/proc/sys/net/ipv4/tcp_syncookies": ("1", "SYN cookies anti-DoS"),
        "/proc/sys/net/ipv4/conf/all/accept_redirects": ("0", "Redireccionamiento ICMP"),
        "/proc/sys/net/ipv4/conf/all/send_redirects": ("0", "Envío de redirects ICMP"),
        "/proc/sys/net/ipv4/icmp_echo_ignore_broadcasts": ("1", "Ping broadcast ignorado"),
    }

    for param_path, (expected, description) in kernel_params.items():
        if os.path.exists(param_path):
            with open(param_path, "r") as f:
                val = f.read().strip()
            if val == expected:
                results.append(f"OK: {description} = {val}")
            else:
                status = "WARNING"
                results.append(f"REVISAR: {description} = {val} (recomendado {expected})")

    return {
        "sr_id": "SR7.6",
        "fr_id": "FR7",
        "description": "Ajustes de configuración de red y seguridad",
        "status": status,
        "details": " | ".join(results),
        "sl_level": 1
    }


def check_sr_7_7_minimal_functionality() -> dict:
    """SR 7.7 - Funcionalidad mínima"""
    results = []
    status = "PASS"

    # Comprobar servicios activos innecesarios
    unnecessary = ["bluetooth", "avahi-daemon", "cups", "ModemManager"]
    for service in unnecessary:
        try:
            output = subprocess.check_output(
                ["systemctl", "is-active", service],
                stderr=subprocess.DEVNULL
            ).decode().strip()
            if output == "active":
                status = "WARNING"
                results.append(f"Servicio innecesario activo: {service}")
        except Exception:
            pass

    if status == "PASS":
        results.append("No se detectaron servicios innecesarios activos")

    # Comprobar paquetes instalados (cantidad como indicador)
    try:
        output = subprocess.check_output(
            ["dpkg", "--list"],
            stderr=subprocess.DEVNULL
        ).decode()
        pkg_count = len([l for l in output.splitlines() if l.startswith("ii")])
        results.append(f"Paquetes instalados: {pkg_count}")
        if pkg_count > 500:
            status = "WARNING"
            results.append("Muchos paquetes instalados — revisar si todos son necesarios")
    except Exception as e:
        results.append(f"No se pudo contar paquetes: {str(e)}")

    return {
        "sr_id": "SR7.7",
        "fr_id": "FR7",
        "description": "Funcionalidad mínima instalada",
        "status": status,
        "details": " | ".join(results),
        "sl_level": 1
    }


def run_all_fr7_checks() -> list:
    return [
        check_sr_7_1_dos_protection(),
        check_sr_7_3_backup(),
        check_sr_7_4_recovery(),
        check_sr_7_6_network_config(),
        check_sr_7_7_minimal_functionality(),
    ]