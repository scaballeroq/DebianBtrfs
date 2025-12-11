#!/bin/bash
# scripts/install.sh
# Script Principal de Instalación de Debian 13 con Btrfs y Snapper

# ==============================================================================
# CONFIGURACIÓN E INICIALIZACIÓN
# ==============================================================================

# Obtener ruta absoluta del directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
CONFIG_DIR="$SCRIPT_DIR/config"

# Cargar librerías
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/disk-detection.sh"
source "$LIB_DIR/partitioning.sh"
source "$LIB_DIR/btrfs-setup.sh"
source "$CONFIG_DIR/packages.conf" # Cargar variables de paquetes

# Inicializar proceso
init_log
check_root
check_uefi
check_internet
install_script_dependencies

log "INFO" "=== INICIANDO INSTALACIÓN DE DEBIAN 13 (TRIXIE) ==="

# ==============================================================================
# 1. SELECCIÓN DE DISCO Y PARTICIONADO
# ==============================================================================

select_and_confirm_disk
# Variables SELECTED_DISK, EFI_PART, ROOT_PART seteadas por la función anterior

wipe_disk "$SELECTED_DISK"
create_partitions "$SELECTED_DISK" "$EFI_PART" "$ROOT_PART"
format_partitions "$EFI_PART" "$ROOT_PART"

# ==============================================================================
# 2. CONFIGURACIÓN DE BTRFS Y MONTAJE
# ==============================================================================

setup_btrfs_subvolumes "$ROOT_PART"
mount_partitions "$ROOT_PART" "$EFI_PART"

# ==============================================================================
# 3. INSTALACIÓN BASE (DEBOOTSTRAP)
# ==============================================================================

log "INFO" "Iniciando instalación base con debootstrap (Trixie)..."
debootstrap --arch=amd64 trixie /mnt http://deb.debian.org/debian || die "Fallo en debootstrap"

# ==============================================================================
# 4. CONFIGURACIÓN DEL SISTEMA
# ==============================================================================

generate_fstab "$ROOT_PART" "$EFI_PART"

log "INFO" "Configurando hostname y hosts..."
echo "debian" > /mnt/etc/hostname
cat > /mnt/etc/hosts <<EOF
127.0.0.1       localhost
127.0.1.1       debian

::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

log "INFO" "Configurando repositorios APT..."
cat > /mnt/etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian trixie main contrib non-free non-free-firmware

deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware

deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
EOF

# Preparando entorno Chroot
log "INFO" "Montando sistemas de archivos virtuales para chroot..."
for dir in dev proc sys run; do
    mount --rbind "/$dir" "/mnt/$dir"
    mount --make-rslave "/mnt/$dir"
done
# Montar efivars específicamente
if [ -d /sys/firmware/efi/efivars ]; then
    mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars
fi

# Copiar scripts necesarios al sistema destino para post-instalación
log "INFO" "Copiando scripts al sistema instalado..."
mkdir -p /mnt/root/debian-install
cp -r "$SCRIPT_DIR/.."/* /mnt/root/debian-install/

# Generar script temporal para ejecutar DENTRO del chroot
cat > /mnt/root/install_inside_chroot.sh <<EOF
#!/bin/bash
source /root/debian-install/scripts/config/packages.conf

echo "=== Configurando dentro del chroot ==="

# Configurar zona horaria (Madrid por defecto según solicitud)
ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
apt-get update
apt-get install -y locales
echo "es_ES.UTF-8 UTF-8" > /etc/locale.gen
dpkg-reconfigure --frontend=noninteractive locales
update-locale LANG=es_ES.UTF-8

# Instalar paquetes base, kernel y firmwares
echo "Instalando paquetes..."
# Usamos las funciones del config file que cargamos al principio
apt-get install -y $(get_all_packages)

# Crear usuario
echo "Creando usuario..."
useradd -m -G sudo,adm -s /bin/bash -c "Sergio Caballero" caballero
echo "caballero:caballero" | chpasswd
echo "root:root" | chpasswd
echo "⚠️  Contraseñas reseteadas a 'caballero' y 'root'. ¡CÁMBIALAS DESPUÉS!"

# Configurar GRUB (instalación básica)
echo "Instalando GRUB..."
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=debian --recheck
update-grub

# Instalar GNOME
echo "Instalando GNOME Desktop..."
apt-get install -y ${DESKTOP_PACKAGES[@]}

# Configurar SWAP y Hibernación
# Esto es complejo dentro del chroot, lo hacemos por pasos
echo "Configurando Swap e Hibernación..."

# Crear subvolumen swap ya montado en /var/swap
# Crear archivo de swap
truncate -s 0 /var/swap/swapfile
chattr +C /var/swap/swapfile # NoCOW
btrfs property set /var/swap compression none

# Calcular tamaño swap (RAM + 2GB rule of thumb para hibernación, o fijo 35GB como pidió el usuario)
# El usuario pidió 35GB para 32GB RAM.
dd if=/dev/zero of=/var/swap/swapfile bs=1M count=35840 status=progress
chmod 600 /var/swap/swapfile
mkswap -L SWAP /var/swap/swapfile
swapon /var/swap/swapfile

# Añadir a fstab si no está (aunque ya lo pusimos en btrfs-setup.sh? No, pusimos el subvolumen, no el fichero)
if ! grep -q "/var/swap/swapfile" /etc/fstab; then
    echo "/var/swap/swapfile none swap defaults 0 0" >> /etc/fstab
fi

# Configurar hibernación en GRUB e Initramfs
# Calcular offset
SWAP_OFFSET=\$(btrfs inspect-internal map-swapfile -r /var/swap/swapfile)
ROOT_UUID=\$(blkid -s UUID -o value $ROOT_PART)

# Configurar GRUB
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet resume=UUID='"$ROOT_UUID"' resume_offset='"$SWAP_OFFSET"'"/' /etc/default/grub
update-grub

# Configurar Initramfs
echo "RESUME=/var/swap/swapfile" > /etc/initramfs-tools/conf.d/resume
echo "RESUME_OFFSET=\$SWAP_OFFSET" >> /etc/initramfs-tools/conf.d/resume
update-initramfs -u -k all

EOF

# Ejecutar el script dentro del chroot
chmod +x /mnt/root/install_inside_chroot.sh
log "INFO" "Entrando a chroot para configuración final..."
chroot /mnt /root/install_inside_chroot.sh

# ==============================================================================
# FINALIZACIÓN
# ==============================================================================

log "INFO" "Instalación completada."
log "INFO" "Desmontando sistemas de archivos..."
umount -R /mnt

log "INFO" "¡Proceso terminado con éxito!"
echo -e "${GREEN}Instalación finalizada. Puedes reiniciar el sistema.${NC}"
echo -e "${YELLOW}Recuerda ejecutar el script 'post-install.sh' después del primer reinicio para configurar Snapper.${NC}"
echo -e "El script estará en: /root/debian-install/scripts/post-install.sh"
