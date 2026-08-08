# Registro de cambios

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/); versionado [SemVer](https://semver.org/lang/es/).

## [1.0.0] — 2026-08-08

Primera versión completa: instalación verificada de principio a fin, jugada y confirmada.

### Añadido
- `instalar.sh`: instalación portable en un comando, con conversión automática de imágenes BIN/CUE de redump y verificación por tamaño y hash de los parches descargados.
- `scripts/instalar-widescreen.sh`: **widescreen 16:9 real**, instalado en paralelo sin tocar la instalación 4:3.
- `scripts/jugar.sh`: lanzador único. Arranca en 16:9 si el widescreen está instalado; `--43` fuerza el modo original. Incluye un vigilante que remata el proceso cuando el juego se cuelga al salir.
- Acceso directo de escritorio con acción **"Abrir en 4:3"**.
- README con enlaces de descarga verificados, tabla de las nueve combinaciones de renderizador y driver que **no** funcionan, y solución de problemas.

### Corregido
- El vigilante mataba el juego a los ~30 segundos: los vídeos de intro arrancan en negro y disparaban su condición. Ahora no se arma hasta haber visto un fotograma con contenido.
- El vigilante daba por hecho `DISPLAY=:0` y no comprobaba sus dependencias, fallando en silencio y dejando el proceso colgado.

### Verificado
- **No existe doblaje latino**: los 16 archivos de voz en español del disco americano y del europeo son idénticos byte a byte.
- El 16:9 no procede del renderizador sino del ejecutable: 9 bytes de diferencia, tres de ellos un multiplicador del ángulo de visión.
- Rendimiento en Intel Iris Xe: GPU al 10-15% en carrera, con 16:9 activo.

### Descartado tras medirlo
- `dx7`, `dx8`, driver Wayland de Wine, `EmulateModeset` y D7VK 2.0: ninguno resuelve el escalado.
- nGlide 2.10 genérico: más lento que el `glide3x.dll` del Modern Patch incluso a la resolución mínima, pese a ser lo que hace el instalador oficial de Lutris.
