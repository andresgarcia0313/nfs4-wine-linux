#!/usr/bin/env bash
#
# Need For Speed IV: High Stakes / Road Challenge (1999) en Linux con Wine
# Instalación portable: no ejecuta el instalador del CD (16 bits, no arranca en 64 bits).
#
#   ./instalar.sh /ruta/a/NFS4.iso [directorio-destino]
#
# Acepta también la imagen BIN/CUE de redump: pásale el .bin y la convierte con bchunk.
#
set -uo pipefail

IMAGEN="${1:-}"
DEST="${2:-/opt/games/Need For Speed IV High Stakes}"
TMP="${TMPDIR:-/var/tmp}/nfs4-instalacion"
PARCHE_URL="https://veg.by/files/nfs4/nfs4_modern_patch.7z"
PARCHE_BYTES=1377052
SILENT_URL="https://github.com/CookiePLMonster/SilentPatchNFS90s/releases/download/BUILD-1/SilentPatchNFS90s.zip"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

rojo(){ printf '\033[1;31m%s\033[0m\n' "$*"; }
verde(){ printf '\033[1;32m%s\033[0m\n' "$*"; }
azul(){ printf '\033[1;34m==> %s\033[0m\n' "$*"; }
aviso(){ printf '\033[1;33m%s\033[0m\n' "$*"; }
morir(){ rojo "ERROR: $*"; exit 1; }

[ -n "$IMAGEN" ] || morir "uso: $0 /ruta/a/NFS4.iso [directorio-destino]"
[ -f "$IMAGEN" ] || morir "no encuentro la imagen: $IMAGEN"

# ---------------------------------------------------------------- 1. Dependencias
azul "1/7  Comprobando dependencias"
faltan=()
for c in wine 7z curl find; do command -v "$c" >/dev/null || faltan+=("$c"); done
if [ ${#faltan[@]} -gt 0 ]; then
  rojo "faltan: ${faltan[*]}"
  echo "   Debian/Ubuntu:  sudo apt install wine p7zip-full curl bchunk"
  echo "   Wine 11 estable desde el repositorio oficial: https://wiki.winehq.org/Ubuntu"
  exit 1
fi
WINEVER=$(wine --version 2>/dev/null)
verde "    wine: $WINEVER"
case "$WINEVER" in
  wine-[1-8].*) aviso "    Wine 9 o anterior: el juego es de 32 bits y puede fallar. Recomendado Wine 10.18+" ;;
esac
# El ejecutable del juego es de 32 bits: Wine debe traer los binarios PE i386 del nuevo WoW64.
if ! ls /opt/wine*/lib/wine/i386-windows/kernel32.dll /usr/lib/wine/i386-windows/kernel32.dll >/dev/null 2>&1; then
  aviso "    No encuentro los binarios de 32 bits de Wine (i386-windows)."
  aviso "    Si el juego falla con 'could not load kernel32.dll', ese es el motivo."
fi

# ---------------------------------------------------------------- 2. Imagen del CD
azul "2/7  Preparando la imagen del CD"
mkdir -p "$TMP"
ISO="$IMAGEN"
# Los dumps de redump son BIN/CUE en sectores crudos de 2352 bytes: 7z no los abre.
if [ "${IMAGEN##*.}" = "bin" ] || [ "${IMAGEN##*.}" = "BIN" ]; then
  command -v bchunk >/dev/null || morir "la imagen es BIN/CUE y falta bchunk (sudo apt install bchunk)"
  CUE="${IMAGEN%.*}.cue"
  [ -f "$CUE" ] || morir "no encuentro el .cue junto al .bin"
  azul "    convirtiendo BIN/CUE a ISO con bchunk"
  ( cd "$TMP" && bchunk "$IMAGEN" "$CUE" nfs4 >/dev/null 2>&1 ) || morir "bchunk falló"
  ISO="$TMP/nfs401.iso"
  [ -f "$ISO" ] || morir "bchunk no generó la ISO esperada"
  verde "    ISO generada"
fi

azul "     Extrayendo los datos del CD"
rm -rf "$TMP/cd"; mkdir -p "$TMP/cd" "$DEST"
7z x -y -o"$DEST" "$ISO" DATA SAVEDATA >/dev/null 2>&1 \
  || 7z x -y -o"$DEST" "$ISO" data savedata >/dev/null 2>&1 \
  || morir "la imagen no contiene DATA/SAVEDATA. ¿Es el CD de NFS IV?"
verde "    datos copiados"

# Permisos: los archivos salen del CD en solo lectura y el juego guarda dentro de su directorio
find "$DEST" -xdev -type d -exec chmod 755 {} + 2>/dev/null
find "$DEST" -xdev -type f -exec chmod 644 {} + 2>/dev/null

# ---------------------------------------------------------------- 3. Minúsculas
azul "3/7  Unificando nombres a minúsculas"
# El CD usa MAYÚSCULAS y el parche minúsculas. Sin unificar, en ext4 quedan DATA/MENUS y
# data/menus como dos árboles distintos y el juego lee solo uno de los dos.
( cd "$DEST" && find . -xdev -depth -name '*[A-Z]*' | while IFS= read -r p; do
    d=$(dirname "$p"); b=$(basename "$p"); nb=$(printf '%s' "$b" | tr 'A-Z' 'a-z')
    [ "$b" != "$nb" ] && mv -T "$p" "$d/$nb" 2>/dev/null
  done )
verde "    hecho"

# ---------------------------------------------------------------- 4. Parches
azul "4/7  Descargando y aplicando parches"
# veg.by sirve una cadena TLS incompleta: se descarga sin verificarla y se comprueba el tamaño exacto
curl -kL --retry 3 -o "$TMP/parche.7z" "$PARCHE_URL" 2>/dev/null || morir "no pude descargar el Modern Patch"
TAM=$(stat -c %s "$TMP/parche.7z")
[ "$TAM" = "$PARCHE_BYTES" ] || morir "el parche descargado mide $TAM bytes y deberían ser $PARCHE_BYTES"
verde "    Modern Patch v0.1.0 verificado ($TAM bytes)"
7z x -aoa -o"$DEST" "$TMP/parche.7z" >/dev/null || morir "no pude aplicar el Modern Patch"

if curl -L --retry 2 -o "$TMP/silent.zip" "$SILENT_URL" 2>/dev/null && [ -s "$TMP/silent.zip" ]; then
  7z x -aoa -o"$DEST" "$TMP/silent.zip" >/dev/null && verde "    SilentPatchNFS90s aplicado"
else
  aviso "    SilentPatch no disponible; se continúa sin él"
fi

# ---------------------------------------------------------------- 5. Configuración
azul "5/7  Configurando"
cp -f "$RAIZ/config/nfs4.ini" "$DEST/nfs4.ini"
mkdir -p "$DEST/drivers/nglide"
cp -f "$RAIZ/config/nglide-thrash.ini" "$DEST/drivers/nglide/thrash.ini"
verde "    nfs4.ini y nglide configurados (español, renderizador nglide)"

# ---------------------------------------------------------------- 6. Prefijo Wine
azul "6/7  Creando el prefijo de Wine (puede tardar unos minutos, no lo interrumpas)"
export WINEPREFIX="$DEST/prefix"
export WINEARCH=win64
export WINEDEBUG=-all
export WINEDLLOVERRIDES="mscoree,mshtml="   # sin esto, el instalador de Wine Mono cuelga el arranque
rm -rf "$WINEPREFIX"
wineboot -i >/dev/null 2>&1
wineserver -w
N=$(ls "$WINEPREFIX/drive_c/windows/syswow64/" 2>/dev/null | wc -l)
if [ "$N" -lt 100 ]; then
  rojo "    syswow64 tiene solo $N archivos: el prefijo quedó sin soporte de 32 bits."
  rojo "    El juego no arrancará. Borra '$WINEPREFIX' y repite sin interrumpir."
  exit 1
fi
verde "    prefijo listo ($N archivos en syswow64)"

# ---------------------------------------------------------------- 7. Lanzador
azul "7/7  Instalando lanzador y acceso directo"
cp -f "$RAIZ/scripts/jugar.sh" "$DEST/jugar.sh"
chmod +x "$DEST/jugar.sh"

APPS="$HOME/.local/share/applications"
mkdir -p "$APPS"
cat > "$APPS/nfs4.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Need For Speed IV: High Stakes
Comment=Need for Speed IV (1999) con Modern Patch sobre Wine
Exec="$DEST/jugar.sh"
Path=$DEST
Terminal=false
Categories=Game;ArcadeGame;
EOF
update-desktop-database "$APPS" 2>/dev/null

mkdir -p "$HOME/Juegos/Instalados" 2>/dev/null
ln -sfn "$DEST" "$HOME/Juegos/Instalados/Need For Speed IV High Stakes" 2>/dev/null

rm -rf "$TMP/cd"
echo
verde "Instalación terminada."
echo
echo "  Jugar:     \"$DEST/jugar.sh\""
echo "             o desde el menú de aplicaciones"
echo
aviso "  La PRIMERA vez, entra en Opciones -> Gráficos y deja Triple Buffer en No:"
aviso "  con él activado el juego revienta con 'AMF=5 screen.c(563)' y la avería queda"
aviso "  grabada en savedata/config.dat."
aviso "  Para salir usa Alt+F4. El botón \"Salir\" del menú deja el proceso colgado;"
aviso "  el lanzador lo detecta y lo cierra solo en unos 8 segundos."
