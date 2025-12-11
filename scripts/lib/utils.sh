#!/bin/bash
# scripts/lib/utils.sh
# Utilidades comunes para el script de instalación automática

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Archivo de log
LOG_FILE="/var/log/debian-install.log"

# Inicializar log
init_log() {
    touch "$LOG_FILE"
    log "INFO" "Iniciando proceso de instalación..."
}

# Función de logging
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Escribir en archivo
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Escribir en pantalla con colores
    case "$level" in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        *)
            echo "[$level] $message"
            ;;
    esac
}

# Manejo de errores fatales
die() {
    log "ERROR" "$1"
    cleanup
    exit 1
}

# Verificar permisos de root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        die "Este script debe ejecutarse como root (usar sudo su)"
    fi
}

# Verificar entorno UEFI
check_uefi() {
    if [ -d "/sys/firmware/efi" ]; then
        log "INFO" "Sistema UEFI detectado."
    else
        die "Este script está diseñado solo para sistemas UEFI. No se detectó /sys/firmware/efi."
    fi
}

# Solicitar confirmación del usuario
confirm() {
    local message="$1"
    local default="${2:-N}" # Default to No if not specified
    
    if [ "$default" = "Y" ]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi
    
    echo -e "${YELLOW}$message $prompt${NC}"
    read -r response
    
    if [ -z "$response" ]; then
        response="$default"
    fi
    
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0 
            ;;
        *)
            return 1 
            ;;
    esac
}

# Limpieza general (placeholder, expandir según necesidad)
cleanup() {
    # Solo desmontar si hay algo montado en /mnt que parezca nuestro
    if mountpoint -q /mnt; then
        log "WARN" "Desmontando /mnt para limpieza..."
        umount -R /mnt || true
    fi
}

# Verificar conexión a internet
check_internet() {
    log "INFO" "Verificando conexión a internet..."
    if ping -c 1 deb.debian.org >/dev/null 2>&1; then
        log "INFO" "Conexión a internet verificada."
    else
        die "No hay conexión a internet. Por favor verifica tu red."
    fi
}

# Instalar dependencias necesarias para el script
install_script_dependencies() {
    local pkgs=("gdisk" "btrfs-progs" "dosfstools" "debootstrap" "arch-install-scripts") # arch-install-scripts para genfstab si decidimos usarlo, o util-linux
    
    # Verificar si apt está disponible (estamos en Debian/Ubuntu live)
    if command -v apt >/dev/null; then
        log "INFO" "Instalando dependencias del script..."
        apt update -y || log "WARN" "apt update falló, intentando continuar..."
        apt install -y gdisk btrfs-progs dosfstools debootstrap || die "No se pudieron instalar las dependencias."
    else
        die "Gestor de paquetes apt no encontrado. Asegúrate de correr esto en un Live CD basado en Debian."
    fi
}
