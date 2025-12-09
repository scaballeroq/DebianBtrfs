#!/bin/bash
# scripts/post-install.sh
# Script de configuración Post-Instalación para Snapper y GRUB-Btrfs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
source "$SCRIPT_DIR/lib/utils.sh"

init_log
check_root

log "INFO" "=== INICIANDO CONFIGURACIÓN POST-INSTALACIÓN ==="

# 1. Instalar paquetes necesarios
log "INFO" "Instalando Snapper y herramientas..."
apt-get update
apt-get install -y snapper grub-btrfs inotify-tools

# 2. Configurar Snapper para la raíz
log "INFO" "Configurando Snapper para / ..."
# Snapper intenta configurar /, pero a veces falla si ya existe .snapshots
if [ -d "/.snapshots" ]; then
    rm -rf /.snapshots
fi

snapper -c root create-config /

# 3. Corregir estructura de subvolúmenes para snapshots
# Snapper create-config crea .snapshots como un subvolumen dentro de @.
# Queremos que sea un subvolumen separado @snapshots montado en /.snapshots
# para facilitar rollbacks (excluir snapshots de snapshots).

log "INFO" "Reorganizando subvolumen .snapshots..."

# Identificar partición raíz
ROOT_DEV=$(findmnt / -n -o SOURCE)
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_DEV")

if [ -z "$ROOT_DEV" ]; then
    die "No se pudo identificar el dispositivo raíz."
fi

# Eliminar el subvolumen .snapshots que creó snapper (si es subvolumen)
if btrfs subvolume list / | grep ".snapshots"; then
    btrfs subvolume delete /.snapshots
else
    rm -rf /.snapshots
fi
mkdir /.snapshots

# Montar el toplevel (ID 5) temporalmente para crear @snapshots
mkdir -p /mnt/toplevel
mount -o subvolid=5 "$ROOT_DEV" /mnt/toplevel

# Crear @snapshots si no existe
if [ ! -d "/mnt/toplevel/@snapshots" ]; then
    btrfs subvolume create /mnt/toplevel/@snapshots
fi

# Añadir a fstab
if ! grep -q "@snapshots" /etc/fstab; then
    log "INFO" "Añadiendo @snapshots a /etc/fstab..."
    echo "UUID=$ROOT_UUID  /.snapshots  btrfs  defaults,noatime,space_cache=v2,compress=zstd:1,subvol=@snapshots  0  0" >> /etc/fstab
fi

# Montar
mount -a

# Desmontar toplevel
umount /mnt/toplevel
rmdir /mnt/toplevel

# 4. Configurar permisos
chmod 750 /.snapshots

# 5. Aplicar configuración personalizada de Snapper
log "INFO" "Aplicando configuración de retención de Snapper..."
SNAPPER_CONF="/etc/snapper/configs/root"

# Leer configuración desde nuestro archivo y aplicar sed
source "$CONFIG_DIR/snapper.conf"

# Aplicar variables con sed
sed -i "s/^TIMELINE_MIN_AGE=.*/TIMELINE_MIN_AGE=\"$TIMELINE_MIN_AGE\"/" "$SNAPPER_CONF"
sed -i "s/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY=\"$TIMELINE_LIMIT_HOURLY\"/" "$SNAPPER_CONF"
sed -i "s/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY=\"$TIMELINE_LIMIT_DAILY\"/" "$SNAPPER_CONF"
sed -i "s/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY=\"$TIMELINE_LIMIT_WEEKLY\"/" "$SNAPPER_CONF"
sed -i "s/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY=\"$TIMELINE_LIMIT_MONTHLY\"/" "$SNAPPER_CONF"
sed -i "s/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY=\"$TIMELINE_LIMIT_YEARLY\"/" "$SNAPPER_CONF"
sed -i "s/^TIMELINE_CREATE=.*/TIMELINE_CREATE=\"$TIMELINE_CREATE\"/" "$SNAPPER_CONF"
sed -i "s/^TIMELINE_CLEANUP=.*/TIMELINE_CLEANUP=\"$TIMELINE_CLEANUP\"/" "$SNAPPER_CONF"
sed -i "s/^SPACE_LIMIT=.*/SPACE_LIMIT=\"$SPACE_LIMIT\"/" "$SNAPPER_CONF"
sed -i "s/^EMPTY_PRE_POST_CLEANUP=.*/EMPTY_PRE_POST_CLEANUP=\"$EMPTY_PRE_POST_CLEANUP\"/" "$SNAPPER_CONF"
sed -i "s/^EMPTY_PRE_POST_MIN_AGE=.*/EMPTY_PRE_POST_MIN_AGE=\"$EMPTY_PRE_POST_MIN_AGE\"/" "$SNAPPER_CONF"

# 6. Configurar GRUB-Btrfs
log "INFO" "Habilitando servicio grub-btrfsd para actualización automática..."
systemctl enable --now grub-btrfsd

# Crear primer snapshot manual
log "INFO" "Creando snapshot inicial..."
snapper -c root create --description "Configuración post-instalación finalizada"

# Actualizar grub
update-grub

log "INFO" "Configuración post-instalación completada."
echo -e "${GREEN}El sistema está totalmente configurado con Snapper y arranque desde snapshots.${NC}"
