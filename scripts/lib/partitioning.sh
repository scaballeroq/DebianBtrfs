#!/bin/bash
# scripts/lib/partitioning.sh
# Funciones para particionado y formateo

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Función para limpiar el disco
wipe_disk() {
    local disk="$1"
    
    log "INFO" "Limpiando tabla de particiones y datos antiguos en $disk..."
    
    # Desmontar cualquier cosa montada en ese disco
    for part in $(lsblk -l "$disk" -o NAME,MOUNTPOINT | grep -v NAME | awk '{print $1}'); do
        path="/dev/$part"
        if mountpoint -q "$path" || grep -qs "$path" /proc/mounts; then
            log "WARN" "Desmontando $path..."
            umount "$path" || umount -l "$path" || true
        fi
    done
    swapoff -a
    
    # Eliminar tablas de particiones y firmas
    sgdisk -Z "$disk" || die "Fallo al limpiar tabla de particiones (sgdisk -Z)"
    sgdisk -og "$disk" || die "Fallo al limpiar MBR (sgdisk -og)"
    wipefs -a "$disk"
    
    # Pequeña pausa para que el kernel actualice
    sleep 2
}

# Crear particiones GPT
create_partitions() {
    local disk="$1"
    
    log "INFO" "Creando nueva tabla de particiones GPT en $disk..."
    
    # Partición 1: EFI System Partition (1GB como solicitado)
    # Tipo ef00 (EFI System)
    sgdisk -n 1::+1G -t 1:ef00 -c 1:'ESP' "$disk" || die "Fallo al crear partición EFI"
    
    # Partición 2: Linux Root (Resto del disco)
    # Tipo 8300 (Linux filesystem)
    sgdisk -n 2:: -t 2:8300 -c 2:'LINUX' "$disk" || die "Fallo al crear partición Root"
    
    # Forzar relectura de la tabla de particiones
    partprobe "$disk"
    sleep 3
    
    # Verificar que las particiones existen
    local efi_part="$2"
    local root_part="$3"
    
    if [ ! -b "$efi_part" ] || [ ! -b "$root_part" ]; then
        die "Las particiones no se crearon correctamente o no son visibles por el kernel aún."
    fi
}

# Formatear particiones
format_partitions() {
    local efi_part="$1"
    local root_part="$2"
    
    log "INFO" "Formateando partición EFI ($efi_part) como FAT32..."
    mkfs.fat -F32 -n EFI "$efi_part" || die "Fallo al formatear partición EFI"
    
    log "INFO" "Formateando partición Root ($root_part) como Btrfs..."
    # -f para forzar si detecta fs previo
    mkfs.btrfs -f -L DEBIAN "$root_part" || die "Fallo al formatear partición Root (Btrfs)"
    
    log "INFO" "Particionado y formateo completados con éxito."
}
