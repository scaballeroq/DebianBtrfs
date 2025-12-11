Step 1: Boot into the Live Environment
sudo su
lsblk -p
export DISK="/dev/nvme0n1"
export DISK1="/dev/nvme0n1p1"
export DISK2="/dev/nvme0n1p2"

Step 2: Wipe Disk and Create GPT Partitions
apt update && apt install gdisk -y
# Wipe the disk and create a fresh GPT layout
sgdisk -Z $DISK
sgdisk -og $DISK

# Create EFI system partition (1 GiB)
sgdisk -n 1::+1G -t 1:ef00 -c 1:'ESP' $DISK

# Create root partition (rest of the disk)
sgdisk -n 2:: -t 2:8300 -c 2:'LINUX' $DISK

# Format the EFI partition with FAT32 filesystem
mkfs.fat -F32 -n EFI ${DISK1}

# Format the main partition with Btrfs filesystem
mkfs.btrfs -f -L DEBIAN ${DISK2}

# Verify the filesystem formats
lsblk -po name,size,fstype,fsver,label,uuid $DISK

Step 3: Create Essential Btrfs Subvolumes
# Mount the Btrfs root
mount -v ${DISK2} /mnt

# Create essential subvolumes
btrfs subvolume create /mnt/@           # Root filesystem
btrfs subvolume create /mnt/@home       # User home data
btrfs subvolume create /mnt/@opt        # Optional software
btrfs subvolume create /mnt/@cache      # Cache data
btrfs subvolume create /mnt/@gdm3       # Display manager data (GNOME)
btrfs subvolume create /mnt/@libvirt    # Virtual machines
btrfs subvolume create /mnt/@log        # Log files
btrfs subvolume create /mnt/@spool      # Spool data
btrfs subvolume create /mnt/@tmp        # Temporary files
btrfs subvolume create /mnt/@swap       # Swap file location

# Unmount when done
umount -v /mnt

Step 4: Mount the Subvolumes for Installation
# Define mount options for optimal Btrfs performance
BTRFS_OPTS="defaults,noatime,space_cache=v2,compress=zstd:1"

# Mount the root subvolume
mount -vo $BTRFS_OPTS,subvol=@ ${DISK2} /mnt

# Create directories for other subvolumes
mkdir -vp /mnt/{home,opt,boot/efi,var/{cache,lib/{gdm3,libvirt},log,spool,tmp,swap}}

# Mount the remaining subvolumes
mount -vo $BTRFS_OPTS,subvol=@home ${DISK2} /mnt/home
mount -vo $BTRFS_OPTS,subvol=@opt ${DISK2} /mnt/opt
mount -vo $BTRFS_OPTS,subvol=@cache ${DISK2} /mnt/var/cache
mount -vo $BTRFS_OPTS,subvol=@gdm3 ${DISK2} /mnt/var/lib/gdm3
mount -vo $BTRFS_OPTS,subvol=@libvirt ${DISK2} /mnt/var/lib/libvirt
mount -vo $BTRFS_OPTS,subvol=@log ${DISK2} /mnt/var/log
mount -vo $BTRFS_OPTS,subvol=@spool ${DISK2} /mnt/var/spool
mount -vo $BTRFS_OPTS,subvol=@tmp ${DISK2} /mnt/var/tmp

# Mount swap subvolume without compression or CoW for reliability
mount -vo defaults,noatime,subvol=@swap ${DISK2} /mnt/var/swap

# Mount the EFI partition
mount -v ${DISK1} /mnt/boot/efi

# Verify the mounts
lsblk -po name,size,fstype,uuid,mountpoints $DISK

Step 5: Install the Debian 13 Base System with debootstrap
# Install debootstrap if not already installed
apt install -y debootstrap

# Install base Debian 13 (Trixie) system into /mnt
debootstrap --arch=amd64 trixie /mnt http://deb.debian.org/debian

# Mount necessary filesystems for chroot environment
for dir in dev proc sys run; do
    mount -v --rbind "/${dir}" "/mnt/${dir}"
    mount -v --make-rslave "/mnt/${dir}"
done

# Mount EFI variables (for UEFI systems)
mount -v -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars

Step 6: Configure fstab
# Get UUIDs for Btrfs and EFI partitions
BTRFS_UUID=$(blkid -s UUID -o value ${DISK2}) ; echo $BTRFS_UUID
EFI_UUID=$(blkid -s UUID -o value ${DISK1}) ; echo $EFI_UUID

# Create /etc/fstab inside the target system
cat > /mnt/etc/fstab << EOF
UUID=$BTRFS_UUID /                btrfs defaults,noatime,space_cache=v2,compress=zstd:1,subvol=@ 0 0
UUID=$BTRFS_UUID /home            btrfs defaults,noatime,space_cache=v2,compress=zstd:1,subvol=@home 0 0
UUID=$BTRFS_UUID /opt             btrfs defaults,noatime,space_cache=v2,compress=zstd:1,subvol=@opt 0 0
UUID=$BTRFS_UUID /var/cache       btrfs defaults,noatime,space_cache=v2,compress=zstd:1,subvol=@cache 0 0
UUID=$BTRFS_UUID /var/lib/gdm3    btrfs defaults,noatime,space_cache=v2,compress=zstd:1,subvol=@gdm3 0 0
UUID=$BTRFS_UUID /var/lib/libvirt btrfs defaults,noatime,space_cache=v2,compress=zstd:1,subvol=@libvirt 0 0
UUID=$BTRFS_UUID /var/log         btrfs defaults,noatime,space_cache=v2,compress=zstd:1,subvol=@log 0 0
UUID=$BTRFS_UUID /var/spool       btrfs defaults,noatime,space_cache=v2,compress=zstd:1,subvol=@spool 0 0
UUID=$BTRFS_UUID /var/tmp         btrfs defaults,noatime,space_cache=v2,compress=zstd:1,subvol=@tmp 0 0
UUID=$BTRFS_UUID /var/swap        btrfs defaults,noatime,subvol=@swap 0 0
UUID=$EFI_UUID   /boot/efi        vfat  defaults,noatime 0 2
EOF

# Verify the fstab file content
cat /mnt/etc/fstab

Step 7: Chroot into the Installed System
chroot /mnt /bin/bash

Step 8: Configure Base System Settings
# Set the system hostname
echo "debian" > /etc/hostname

# Configure /etc/hosts
cat > /etc/hosts << EOF
127.0.0.1       localhost
127.0.1.1       $(cat /etc/hostname)

::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

# Set the timezone (adjust to your region)
ln -sf /usr/share/zoneinfo/Erope/Madrid /etc/localtime

# Install and configure locales
apt install -y locales
dpkg-reconfigure locales

Step 9: Configure Repositories and Install Base Package
# Configure APT sources for Debian 13 (Trixie)
cat > /etc/apt/sources.list << EOF
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian trixie main contrib non-free non-free-firmware

deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware

deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
EOF

# Update package lists
apt update

# Install kernel, system tools, and essential utilities
apt install -y linux-image-amd64 linux-headers-amd64 \
    firmware-linux firmware-linux-nonfree \
    grub-efi-amd64 efibootmgr network-manager \
    btrfs-progs sudo vim bash-completion
    
Step 10: Create Swap with Hibernation Support
# Prepare swap file
truncate -s 0 /var/swap/swapfile
chattr +C /var/swap/swapfile                     # Disable COW
btrfs property set /var/swap compression none    # Disable compression

# My system has 32 GB RAM, so I create 35
dd if=/dev/zero of=/var/swap/swapfile bs=1M count=35840 status=progress
chmod 600 /var/swap/swapfile
mkswap -L SWAP /var/swap/swapfile

# Add swap to fstab and enable it
echo "/var/swap/swapfile none swap defaults 0 0" >> /etc/fstab
swapon /var/swap/swapfile
swapon -v

# Configure GRUB for hibernation
SWAP_OFFSET=$(btrfs inspect-internal map-swapfile -r /var/swap/swapfile)
BTRFS_UUID=$(blkid -s UUID -o value ${DISK2})
GRUB_CMD="quiet resume=UUID=$BTRFS_UUID resume_offset=$SWAP_OFFSET"
echo "GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_CMD\"" >> /etc/default/grub

# Update GRUB configuration with new kernel parameters
update-grub

# Configure initramfs for hibernation (using swap file)
cat > /etc/initramfs-tools/conf.d/resume << EOF
RESUME=/var/swap/swapfile
RESUME_OFFSET=$SWAP_OFFSET
EOF

# Update initramfs to include hibernation support  
update-initramfs -u -k all

Step 11: Create a User
# Create a new user (replace with your username and name)
useradd -m -G sudo,adm -s /bin/bash -c "Sergio Caballero" caballero

# Set the user password
passwd caballero

# Verify the user creation
id caballero

Step 12: Install and Configure GRUB Bootloader
# Install GRUB for UEFI
grub-install \
  --target=x86_64-efi \
  --efi-directory=/boot/efi \
  --bootloader-id=debian \
  --recheck

# Generate GRUB configuration
update-grub

Step 13: Exit Chroot and Reboot
exit
# Unmount all mounted directories
umount -vR /mnt

# Reboot into the installed system
reboot

Step 14: Install the Desktop Environment
sudo apt install -y task-gnome-desktop
sudo reboot
