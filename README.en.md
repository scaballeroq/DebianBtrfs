# Automated Debian 13 (Trixie) Installer with Btrfs and Snapper

> 🇪🇸 **[Leer en Español](README.md)**

Automated script to perform a clean and optimal installation of Debian 13 using the Btrfs file system, with full support for automatic snapshots (Snapper) and booting from snapshots (GRUB-Btrfs).

## Features

- 🚀 **Full Automation**: Detects hardware, partitions, and installs the base system.
- 💾 **Optimized Btrfs**: SUSE/Ubuntu style subvolume structure for easy rollbacks.
- 📸 **Automatic Snapshots**: Snapper configuration ready to use.
- ↩️ **Boot from Snapshots**: GRUB integration to boot previous system states.
- 🔌 **Drivers Included**: Automatically installs proprietary firmware (WiFi, GPU, Bluetooth).
- 🧠 **Smart Detection**: Automatically detects NVMe/SATA/VirtIO disks.
- 💤 **Hibernation**: Configures swap with out-of-the-box hibernation support.

## Prerequisites

1.  **A Debian 13 Live USB** (or any recent Debian/Ubuntu generic live distro).
2.  **Internet Connection** (wired or WiFi configured in the Live environment).
3.  **Data Backup!** The script will ERASE the entire selected disk.

## Usage Instructions

### Step 1: Boot Live USB
Boot your computer with the installation USB and open a terminal. Become root:

```bash
sudo su
```

### Step 2: Download/Clone this repository
If you have git installed:
```bash
git clone <URL_OF_THIS_REPO> debian-install
cd debian-install
```

### Step 3: Run the Installer
Grant execution permissions and launch the main script:

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

The script will ask for confirmation before wiping the disk.

### Step 4: Post-Installation
Once the installation is finished, reboot the system and log in to your new Debian.
Open a terminal and run the post-installation script (which will have been copied to `/root`):

```bash
sudo su
/root/debian-install/scripts/post-install.sh
```

This will configure Snapper and GRUB-Btrfs.

## Subvolume Structure

The system creates the following subvolume structure to separate system data from user data, facilitating rollbacks without losing personal files:

| Subvolume | Mount Point | Description |
|------------|------------------|-------------|
| `@` | `/` | System root (snapshots are taken of this) |
| `@home` | `/home` | User data (EXCLUDED from snapshots) |
| `@snapshots` | `/.snapshots` | Snapshot storage |
| `@opt` | `/opt` | Third-party software |
| `@var_log` | `/var/log` | System logs (to avoid losing logs when rolling back) |
| `@swap` | `/var/swap` | Swap file (NoCow, no compression) |

## Customization

You can edit the files in `scripts/config/` before installing:
- `packages.conf`: List of packages to install.
- `subvolumes.conf`: Subvolume structure.
- `snapper.conf`: Snapshot retention policy.

## License
MIT License - Use this software at your own risk.
