# Guía de Personalización Avanzada

Este instalador es modular y permite personalizar casi cualquier aspecto editando los archivos en `scripts/config/`.

## 1. Modificar paquetes a instalar
Edita `scripts/config/packages.conf`.

- Para añadir un entorno de escritorio diferente (ej: KDE Plasma):
  ```bash
  DESKTOP_PACKAGES=(
      "task-kde-desktop"
      "plasma-nm"
  )
  ```
- Para añadir tus herramientas favoritas:
  Agrega paquetes al array `SYSTEM_TOOLS`.

## 2. Cambiar esquema de particionado o subvolúmenes
Edita `scripts/config/subvolumes.conf`.

Si prefieres no tener un subvolumen separado para `/opt`, simplemente comenta o borra esa línea.
Si quieres compresión más agresiva, cambia `compress=zstd:1` por `compress=zstd:3` (más CPU, menos espacio).

## 3. Configurar Swap
Por defecto, el script calcula el swap automáticamente o usa un valor fijo si se especifica.
Para cambiar el tamaño del swap, edita `scripts/install.sh` y busca la línea:

```bash
dd if=/dev/zero of=/var/swap/swapfile ...
```

Cambia `count=35840` (35GB) por el valor en MB que desees.

## 4. Personalizar retención de Snapshots
Edita `scripts/config/snapper.conf`.

Si tienes poco disco duro, reduce los límites:

```bash
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="3"
```

## 5. Añadir Hooks personalizados
El instalador copia todo el contenido del repositorio a `/root/debian-install`.
Puedes añadir scripts propios en `scripts/hooks/` (tendrías que crear la lógica para ejecutarlos) o simplemente modificar `scripts/install.sh` para llamar a tus propios scripts al final de la instalación.
