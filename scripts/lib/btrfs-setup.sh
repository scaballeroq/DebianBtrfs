#!/bin/bash
# scripts/lib/btrfs-setup.sh
# Funciones para configuración de Btrfs, subvolúmenes y fstab

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
CONFIG_DIR="$(dirname "$(dirname "${BASH_SOURCE[0]}")")/config"

# Crear subvolúmenes basados en la configuración
setup_btrfs_subvolumes() {
    local root_part="$1"
    local mount_point="/mnt"
    
    log "INFO" "Configurando subvolúmenes Btrfs en $root_part..."
    
    # Montar la raíz btrfs temporalmente para crear subvolúmenes
    mount "$root_part" "$mount_point" || die "No se pudo montar $root_part en $mount_point"
    
    # Leer archivo de configuración
    local subvol_conf="$CONFIG_DIR/subvolumes.conf"
    if [ ! -f "$subvol_conf" ]; then
        die "No se encontró el archivo de configuración de subvolúmenes: $subvol_conf"
    fi
    
    # Crear subvolúmenes leyendo el config
    # Ignoramos líneas de comentarios y vacías
    grep -v '^#' "$subvol_conf" | grep -v '^$' | while read -r line; do
        # Formato: nombre:ruta:opciones
        local subvol_name=$(echo "$line" | cut -d':' -f1)
        
        log "INFO" "Creando subvolumen: $subvol_name"
        btrfs subvolume create "$mount_point/$subvol_name" || log "WARN" "Error creando subvolumen $subvol_name (¿ya existe?)"
    done
    
    # Desmontar raíz
    umount "$mount_point"
}

# Montar subvolúmenes para la instalación
mount_partitions() {
    local root_part="$1"
    local efi_part="$2"
    local mount_point="/mnt"
    local subvol_conf="$CONFIG_DIR/subvolumes.conf"
    
    log "INFO" "Montando subvolúmenes para instalación..."
    
    # 1. Montar raíz (@) primero
    # Buscamos la línea que empieza por @: (exactamente @)
    local root_conf=$(grep '^@:' "$subvol_conf")
    local root_opts=$(echo "$root_conf" | cut -d':' -f3)
    
    mount -o "$root_opts,subvol=@" "$root_part" "$mount_point" || die "Fallo al montar raíz (@)"
    
    # 2. Iterar sobre el resto de subvolúmenes
    grep -v '^#' "$subvol_conf" | grep -v '^$' | grep -v '^@:' | while read -r line; do
        local subvol_name=$(echo "$line" | cut -d':' -f1)
        local mount_target=$(echo "$line" | cut -d':' -f2)
        local mount_opts=$(echo "$line" | cut -d':' -f3)
        
        # Crear punto de montaje si no existe (dentro de /mnt normalmente)
        # Nota: las rutas en config ya incluyen /mnt, ej: /mnt/home
        # Excepto si configuramos rutas relativas, pero asumimos absolutas al mount temporal
        
        if [ ! -d "$mount_target" ]; then
            mkdir -p "$mount_target"
        fi
        
        log "INFO" "Montando $subvol_name en $mount_target"
        mount -o "$mount_opts,subvol=$subvol_name" "$root_part" "$mount_target" || die "Fallo al montar $subvol_name"
    done
    
    # 3. Montar partición EFI
    log "INFO" "Montando partición EFI en /mnt/boot/efi"
    mkdir -p "$mount_point/boot/efi"
    mount "$efi_part" "$mount_point/boot/efi" || die "Fallo al montar partición EFI"
}

# Generar fstab
generate_fstab() {
    local root_part="$1"
    local efi_part="$2"
    local fstab_path="/mnt/etc/fstab"
    local subvol_conf="$CONFIG_DIR/subvolumes.conf"
    
    log "INFO" "Generando /etc/fstab..."
    
    # Obtener UUIDs
    local btrfs_uuid=$(blkid -s UUID -o value "$root_part")
    local efi_uuid=$(blkid -s UUID -o value "$efi_part")
    
    if [ -z "$btrfs_uuid" ] || [ -z "$efi_uuid" ]; then
        die "No se pudieron obtener los UUIDs de las particiones."
    fi
    
    # Crear cabecera fstab
    echo "# /etc/fstab: static file system information." > "$fstab_path"
    echo "# Generado por script de instalación automatizada" >> "$fstab_path"
    echo "" >> "$fstab_path"
    
    # Generar entradas Btrfs desde config
    grep -v '^#' "$subvol_conf" | grep -v '^$' | while read -r line; do
        local subvol_name=$(echo "$line" | cut -d':' -f1)
        # El punto de montaje en fstab debe ser relativo al sistema instalado (sin /mnt)
        local full_mount=$(echo "$line" | cut -d':' -f2)
        local mount_opts=$(echo "$line" | cut -d':' -f3)
        
        # Convertir /mnt/home -> /home, /mnt -> /
        local fstab_mount="${full_mount#/mnt}"
        if [ -z "$fstab_mount" ]; then fstab_mount="/"; fi
        
        echo "UUID=$btrfs_uuid  $fstab_mount  btrfs  $mount_opts,subvol=$subvol_name  0  0" >> "$fstab_path"
    done
    
    # Entrada EFI
    echo "UUID=$efi_uuid  /boot/efi  vfat  defaults,noatime  0  2" >> "$fstab_path"
    
    log "INFO" "Archivo fstab generado correctamente."
}
