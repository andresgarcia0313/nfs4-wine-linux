#!/usr/bin/env bash
#
# Widescreen 16:9 para NFS IV: High Stakes, sobre una instalación ya funcionando.
#
#   ./instalar-widescreen.sh [directorio-del-juego]
#
# Se instala EN PARALELO: añade un nfs4ws.exe y no toca ni el nfs4.exe ni el
# renderizador de la instalación 4:3, que sigue disponible con "jugar.sh --43".
# Desinstalar = borrar los archivos que crea (ver el final del script).
#
set -uo pipefail

D="${1:-/opt/games/Need For Speed IV High Stakes}"
S="${TMPDIR:-/var/tmp}/nfs4-widescreen"
PAGINA="https://www.nfsaddons.com/downloads/nfshs/tools/8133/nfshs-collisiontoggleexe-for-need-for-speed-4-modern-patch.html"
SHA_PAQUETE=2cf118c339081135ff323cc4b2f4bde94825952bc019786892aed5b924a2f4d1
SHA_SHIM=690a387ccc5a3c62ce8aa1813f9ece7ddc812859bd4bec4f9777d4b0d857af50

rojo(){ printf '\033[1;31m%s\033[0m\n' "$*"; }
verde(){ printf '\033[1;32m%s\033[0m\n' "$*"; }
azul(){ printf '\033[1;34m==> %s\033[0m\n' "$*"; }
aviso(){ printf '\033[1;33m%s\033[0m\n' "$*"; }
morir(){ rojo "ERROR: $*"; exit 1; }

[ -f "$D/nfs4.exe" ] || morir "no encuentro nfs4.exe en '$D'. ¿Ejecutaste antes instalar.sh?"
[ -f "$D/drivers/nglide/glide3x.dll" ] || morir "falta drivers/nglide: este widescreen necesita nGlide"

azul "1/6  Respaldo"
cp -a "$D/nfs4.ini" "$D/nfs4.ini.bak-ws" 2>/dev/null
[ -f "$D/savedata/config.dat" ] && cp -a "$D/savedata/config.dat" "$D/savedata/config.dat.bak-ws"
verde "    hecho"

azul "2/6  Descargando el paquete de Ravage"
# nfsaddons protege la descarga con un token de un solo uso que hay que sacar de la página.
mkdir -p "$S"; cd "$S" || exit 1
TOK=$(curl -sS -c cj -b cj -A "Mozilla/5.0" "$PAGINA" | grep -o '/dl/file/8133/[a-f0-9]\{32\}/' | head -1)
[ -n "$TOK" ] || morir "no pude obtener el enlace de descarga; ¿cambió la página?"
curl -sL -c cj -b cj -A "Mozilla/5.0" -e "$PAGINA" -o ravage.7z "https://www.nfsaddons.com$TOK" \
  || morir "falló la descarga"
echo "$SHA_PAQUETE  ravage.7z" | sha256sum -c - >/dev/null 2>&1 \
  || morir "el paquete descargado no coincide con el hash esperado"
verde "    verificado ($(stat -c%s ravage.7z) bytes)"

azul "3/6  Extrayendo"
7z x -y -o"$S/pkg" ravage.7z >/dev/null || morir "no pude extraer el paquete"
W="$S/pkg/Widescreen_Resolution_16_9"
echo "$SHA_SHIM  $W/drivers/ws_dgvoodoo_dx9/d3da.dll" | sha256sum -c - >/dev/null 2>&1 \
  || morir "el componente de corrección de aspecto no es el esperado"
verde "    componente de widescreen verificado (fix de Felix Krull)"

azul "4/6  Instalando el ejecutable 16:9 junto al tuyo"
cp -f "$W/nfs4.exe" "$D/nfs4ws.exe"
verde "    nfs4ws.exe (tu nfs4.exe no se toca)"

azul "5/6  Encadenando el corrector de aspecto con tu nGlide"
# El corrector se hace pasar por renderizador: el juego lo carga, él arregla la proporción
# y delega en el renderizador Glide real, que busca en .\Drivers\ (un nivel por encima).
mkdir -p "$D/drivers/voodoo2a-ws"
cp -f "$W/drivers/ws_dgvoodoo_dx9/d3da.dll" "$D/drivers/voodoo2a-ws/voodoo2a.dll"
printf '[THRASH]\r\nFile=voodoo2a.dll\r\nType=voodoo\r\nFogSupport=1\r\n[ENV]\r\nNGLIDE_RESOLUTION=1\r\nNGLIDE_ASPECT=0\r\nNGLIDE_REFRESH=0\r\nNGLIDE_VSYNC=1\r\nNGLIDE_GAMMA=5\r\nNGLIDE_SPLASH=0\r\n' > "$D/drivers/voodoo2a-ws/thrash.ini"
cp -f "$D/drivers/nglide/voodoo2a.dll" "$D/drivers/voodoo2a.dll"
cp -f "$D/drivers/nglide/glide3x.dll"  "$D/drivers/glide3x.dll"
cp -f "$D/drivers/nglide/glide3x.dll"  "$D/glide3x.dll"
ln -sfn drivers "$D/Drivers" 2>/dev/null   # el corrector busca .\Drivers\ y ext4 distingue mayúsculas
# El aspecto se fuerza a 16:9 en vez de deducirlo del escritorio, que bajo Wine no es fiable.
printf '[settings]\r\ntargetAspectRatioWidth=16\r\ntargetAspectRatioHeight=9\r\ndriver_voodoo2=voodoo2\r\n' > "$D/nfshs-widescreen.ini"
verde "    hecho"

azul "6/6  Configuración y lanzador propios"
# El Modern Patch busca primero <nombre-del-exe>.ini: así ambos modos conviven sin pisarse.
sed 's/^ThrashDriver=.*/ThrashDriver=voodoo2a-ws\r/' "$D/nfs4.ini" > "$D/nfs4ws.ini"
verde "    nfs4ws.ini listo"
# jugar.sh detecta nfs4ws.exe y arranca en 16:9 sin más; --43 fuerza el modo original.
grep -q 'nfs4ws.exe' "$D/jugar.sh" || aviso "    tu jugar.sh es antiguo: actualízalo desde scripts/jugar.sh"

echo
verde "Widescreen instalado."
echo
echo "  16:9   \"$D/jugar.sh\"          (a partir de ahora, por defecto)"
echo "  4:3    \"$D/jugar.sh\" --43     (sigue disponible, intacto)"
echo
aviso "  Dentro del juego: Wide Screen = Off, View Angle = Wide, Cámara 1 = High."
aviso "  NO toques la resolución ni el Z-Buffer: rompen la partida y corrompen config.dat."
echo
echo "  Desinstalar:"
echo "    rm -f '$D'/{nfs4ws.exe,nfs4ws.ini,nfshs-widescreen.ini,glide3x.dll,Drivers}"
echo "    rm -f '$D'/drivers/{voodoo2a.dll,glide3x.dll}"
echo "    rm -rf '$D/drivers/voodoo2a-ws'"
