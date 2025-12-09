# Guía de Recuperación y Snapshots

## ¿Cómo funciona el sistema de recuperación?

Tu sistema Debian está configurado para tomar "fotos" (snapshots) del estado del sistema operativo automáticamente:
- **Antes y después** de instalar cualquier paquete con `apt`.
- **Periódicamente** (cada hora, día, semana...).
- **Manualmente** cuando tú lo decidas.

Gracias a `grub-btrfs`, estos snapshots aparecen automáticamente en el menú de arranque de GRUB.

---

## Escenario 1: El sistema no arranca o está inestable

Si instalaste algo que rompió el sistema (pantalla negra, errores al inicio), sigue estos pasos:

1. **Reinicia** el ordenador.
2. En el menú de GRUB, selecciona **"Debian GNU/Linux snapshots"**.
3. Verás una lista de snapshots ordenados por fecha y descripción (ej: "Pre-instalar nvidia-driver").
4. Selecciona uno que sepas que funcionaba y pulsa Enter.
5. El sistema arrancará en modo "Solo lectura" usando ese snapshot.

### Una vez dentro del sistema (Snapshot Read-Only):

El sistema parecerá normal, pero es una versión "congelada" y en solo lectura. Verifica que todo funciona (WiFi, gráficos, etc.).

Si todo está bien y quieres **volver permanentemente** a este estado:

```bash
sudo snaper rollback
```

El sistema te pedirá reiniciar. Al reiniciar, **tu sistema habrá vuelto al pasado**, pero tus documentos en `/home` estarán intactos (porque `/home` es un subvolumen separado).

---

## Escenario 2: Recuperar un archivo borrado por error

Si borraste un archivo de configuración importante en `/etc` (que es parte del sistema), puedes recuperarlo sin revertir todo el sistema.

1. Lista los snapshots disponibles:
   ```bash
   sudo snapper list
   ```

2. Busca el número del snapshot donde el archivo aún existía (digamos, el número 50).

3. Compara el cambio (opcional):
   ```bash
   sudo snapper diff 50..0 /etc/fichero_importante
   # (0 es el sistema actual)
   ```

4. Restaura solo ese archivo:
   ```bash
   sudo snapper undochange 50..0 /etc/fichero_importante
   ```

---

## Mantenimiento de Snapshots

Para ver cuánto espacio ocupan los snapshots:
```bash
sudo btrfs filesystem du -s /.snapshots
```

Para borrar snapshots antiguos manualmente:
```bash
sudo snapper delete 45
# O borrar un rango
sudo snapper delete 45-50
```

Tu configuración borrará automáticamente los snapshots antiguos según las reglas definidas en `/etc/snapper/configs/root`.
