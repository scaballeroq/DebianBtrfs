# Instalador Automático de Debian 13 (Trixie) con Btrfs y Snapper

> 🇬🇧 **[Read in English](README.en.md)**

Script automatizado para realizar una instalación limpia y óptima de Debian 13 utilizando el sistema de archivos Btrfs, con soporte completo para snapshots automáticos (Snapper) y arranque desde snapshots (GRUB-Btrfs).

## Características

- 🚀 **Automatización Completa**: Detecta hardware, particiona e instala el sistema base.
- 💾 **Btrfs Optimizado**: Estructura de subvolúmenes estilo SUSE/Ubuntu para fácil rollback.
- 📸 **Snapshots Automáticos**: Configuración de Snapper lista para usar.
- ↩️ **Boot from Snapshots**: Integración con GRUB para arrancar estados anteriores del sistema.
- 🔌 **Drivers Incluidos**: Instala automáticamente firmwares privativos (WiFi, GPU, Bluetooth).
- 🧠 **Detección Inteligente**: Detecta discos NVMe/SATA/VirtIO automáticamente.
- 💤 **Hibernación**: Configura swap con soporte para hibernación out-of-the-box.

## Requisitos Previos

1. **Un Live USB de Debian 13** (o cualquier distro live reciente basada en Debian/Ubuntu).
2. **Conexión a Internet** (cableada o WiFi configurada en el entorno Live).
3. **¡Respaldo de datos!** El script borrará TODO el disco seleccionado.

## Instrucciones de Uso

### Paso 1: Arrancar Live USB
Arranca tu equipo con el USB de instalación y abre una terminal. Conviértete en root:

```bash
sudo su
```

### Paso 2: Descargar/Clonar este repositorio
Si tienes git instalado:
```bash
git clone <URL_DE_ESTE_REPO> debian-install
cd debian-install
```

### Paso 3: Ejecutar el Instalador
Da permisos de ejecución y lanza el script principal:

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

El script te preguntará confirmación antes de borrar el disco.

### Paso 4: Post-Instalación
Una vez terminada la instalación, reinicia el sistema y entra en tu nuevo Debian.
Abre una terminal y ejecuta el script de post-instalación (que habrá sido copiado a `/root`):

```bash
sudo su
/root/debian-install/scripts/post-install.sh
```

Esto configurará Snapper y GRUB-Btrfs.

## Estructura de Subvolúmenes

El sistema crea la siguiente estructura de subvolúmenes para separar datos del sistema y datos de usuario, facilitando los rollbacks sin perder archivos personales:

| Subvolumen | Punto de Montaje | Descripción |
|------------|------------------|-------------|
| `@` | `/` | Raíz del sistema (se hacen snapshots de esto) |
| `@home` | `/home` | Datos de usuario (EXCLUIDO de snapshots) |
| `@snapshots` | `/.snapshots` | Almacenamiento de snapshots |
| `@opt` | `/opt` | Software de terceros |
| `@var_log` | `/var/log` | Logs del sistema (para no perder logs al revertir) |
| `@swap` | `/var/swap` | Swap file (NoCoW, sin compresión) |

## Personalización

Puedes editar los archivos en `scripts/config/` antes de instalar:
- `packages.conf`: Lista de paquetes a instalar.
- `subvolumes.conf`: Estructura de subvolúmenes.
- `snapper.conf`: Política de retención de snapshots.

## Licencia
MIT License - Usa este software bajo tu propio riesgo.