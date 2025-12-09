#!/bin/bash
# scripts/lib/disk-detection.sh
# Funciones para detectar y seleccionar el disco de instalación

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Variable global para el disco seleccionado
SELECTED_DISK=""
EFI_PART=""
ROOT_PART=""

# Detectar disco principal automáticamente
detect_primary_disk() {
    log "INFO" "Buscando discos disponibles..."
    
    # Obtener lista de discos: nombre, tamaño, tipo, modelo
    # Ignoramos loops y roms
    local disks=$(lsblk -d -n -o NAME,SIZE,TYPE,MODEL,TRAN | grep -E 'disk|nvme')
    
    if [ -z "$disks" ]; then
        die "No se encontraron discos físicos."
    fi
    
    # Intentar identificar NVMe primero (común en equipos modernos)
    local nvme_disk=$(echo "$disks" | grep "nvme" | head -n 1 | awk '{print $1}')
    
    # Si no hay NVMe, buscar sdX (SATA/SCSI/USB)
    local sd_disk=$(echo "$disks" | grep "^sd" | head -n 1 | awk '{print $1}')
    
    # Si no hay sd, buscar vdX (Virtual VirtIO)
    local vd_disk=$(echo "$disks" | grep "^vd" | head -n 1 | awk '{print $1}')
    
    # Prioridad: NVMe > SATA > VirtIO
    if [ -n "$nvme_disk" ]; then
        SELECTED_DISK="/dev/$nvme_disk"
        log "INFO" "Disco NVMe detectado como candidato principal: $SELECTED_DISK"
    elif [ -n "$sd_disk" ]; then
        SELECTED_DISK="/dev/$sd_disk"
        log "INFO" "Disco SATA/USB detectado como candidato principal: $SELECTED_DISK"
    elif [ -n "$vd_disk" ]; then
        SELECTED_DISK="/dev/$vd_disk"
        log "INFO" "Disco Virtual detectado como candidato principal: $SELECTED_DISK"
    else
        # Fallback: tomar el primero de la lista
        local first_disk=$(echo "$disks" | head -n 1 | awk '{print $1}')
        SELECTED_DISK="/dev/$first_disk"
        log "WARN" "No se pudo determinar tipo de disco preferido. Seleccionando el primero: $SELECTED_DISK"
    fi
}

# Listar discos de forma amigable y confirmar selección
select_and_confirm_disk() {
    detect_primary_disk
    
    echo -e "\n${BLUE}=== Selección de Disco ===${NC}"
    echo "Discos detectados:"
    lsblk -d -o NAME,SIZE,MODEL,TRAN,TYPE -e 7,11
    
    echo -e "\nEl script ha seleccionado automáticamente: ${YELLOW}${SELECTED_DISK}${NC}"
    
    if ! confirm "¿Es este el disco correcto para la instalación? (Se BORRARÁN TODOS LOS DATOS)" "Y"; then
        echo -e "\nPor favor ingresa el nombre del dispositivo manualmente (ej: /dev/sdb):"
        read -r manual_disk
        
        if [ ! -b "$manual_disk" ]; then
            die "El dispositivo $manual_disk no existe o no es un dispositivo de bloque válido."
        fi
        SELECTED_DISK="$manual_disk"
    fi
    
    # Última advertencia
    echo -e "\n${RED}¡PELIGRO!${NC}"
    echo -e "Estás a punto de formatear completamente: ${RED}${SELECTED_DISK}${NC}"
    echo "Todos los datos en este disco se perderán irremediablemente."
    
    if ! confirm "¿Estás absolutamente seguro de continuar?" "N"; then
        die "Instalación abortada por el usuario."
    fi
    
    # Definir nombres de particiones esperados
    # NVMe usa p1, p2... SD usa 1, 2...
    if [[ "$SELECTED_DISK" == *"nvme"* ]] || [[ "$SELECTED_DISK" == *"mmcblk"* ]]; then
        EFI_PART="${SELECTED_DISK}p1"
        ROOT_PART="${SELECTED_DISK}p2"
    else
        EFI_PART="${SELECTED_DISK}1"
        ROOT_PART="${SELECTED_DISK}2"
    fi
    
    log "INFO" "Disco seleccionado: $SELECTED_DISK"
    log "INFO" "Partición EFI destino: $EFI_PART"
    log "INFO" "Partición Root destino: $ROOT_PART"
}
