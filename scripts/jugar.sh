#!/usr/bin/env bash
# Need For Speed IV: High Stakes (Road Challenge)
# Wine 11 + Modern Patch de VEG v0.1.0 + SilentPatchNFS90s BUILD-1
#
# El juego NO cierra limpio bajo Wine: al pulsar "Salir" deja de dibujar (pantalla negra)
# pero el proceso sigue vivo quemando un núcleo. Mismo bug que en NFS III. El vigilante
# de abajo lo remata solo. Alt+F4 sí cierra limpiamente.

DIR="$(dirname "$(readlink -f "$0")")"
export WINEPREFIX="$DIR/prefix"
export WINEARCH=win64
export WINEDEBUG=-all
# mscoree,mshtml= : sin Wine Mono/Gecko (el juego no usa .NET y su instalador cuelga el arranque)
# dinput=n,b      : IMPRESCINDIBLE. dinput.dll es Ultimate ASI Loader; sin este override
#                   SilentPatchNFS90s NO carga y SingleProcAffinity cae en la implementación
#                   de VEG, que ata todo el proceso a un solo núcleo en vez de solo los
#                   hilos problemáticos. Además arregla el polling del mando bajo Wine.
export WINEDLLOVERRIDES="mscoree,mshtml=;dinput=n,b"

cd "$DIR" || exit 1         # obligatorio: el juego busca sus datos en el directorio de trabajo
wineserver -k 2>/dev/null   # idempotente: el juego admite una sola instancia

# --- Vigilante de salida colgada -------------------------------------------------
# Muestrea el color medio de la ventana cada 2 s. Si permanece en negro absoluto
# durante ~8 s seguidos, el juego ya no está dibujando: se pulsó "Salir".
vigilante() {
  # Sin herramientas de captura no hay vigilancia posible: mejor decirlo que fallar en silencio.
  command -v xdotool >/dev/null && command -v import >/dev/null || {
    echo "vigilante desactivado: faltan xdotool o imagemagick" >&2; return; }
  export DISPLAY="${DISPLAY:-:0}"              # XWayland no siempre es :0

  local negras=0 ciegas=0 wid="" medio=""
  sleep 25                                     # margen para el arranque
  while pgrep -x 'nfs4.exe' >/dev/null 2>&1; do
    wid=$(xdotool search --name "Need For Speed" 2>/dev/null | head -1)
    medio=""
    [ -n "$wid" ] && medio=$(import -window "$wid" -resize 1x1 -depth 8 txt:- 2>/dev/null \
                             | awk 'NR==2{print $3}')
    case "$medio" in
      "(0,0,0)"|"#000000"|"(0,0,0,255)"|"srgb(0,0,0)") negras=$((negras+1)); ciegas=0 ;;
      "")                                              ciegas=$((ciegas+1)) ;;
      *)                                               negras=0; ciegas=0 ;;
    esac
    # 4 muestras negras = 8 s sin dibujar. 150 capturas fallidas seguidas (5 min) = el
    # vigilante está ciego; se retira en vez de quedarse girando para siempre.
    if [ "$negras" -ge 4 ]; then
      pkill -x 'nfs4.exe' 2>/dev/null
      sleep 2
      pgrep -x 'nfs4.exe' >/dev/null && pkill -9 -x 'nfs4.exe' 2>/dev/null
      wineserver -k 2>/dev/null
      return
    fi
    [ "$ciegas" -ge 150 ] && { echo "vigilante ciego: no consigo capturar la ventana" >&2; return; }
    sleep 2
  done
}
vigilante &
VIGIA=$!

wine nfs4.exe "$@"          # sin exec: hay que volver aquí para limpiar

# --- Limpieza ---------------------------------------------------------------------
kill "$VIGIA" 2>/dev/null
sleep 1
pgrep -x 'nfs4.exe' >/dev/null && { pkill -x 'nfs4.exe'; sleep 1; }
wineserver -k 2>/dev/null
