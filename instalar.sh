#!/bin/bash
# ============================================================================
# instalar.sh - poe a configuracao da M-BIND numa maquina nova
# ============================================================================
# Antes de correr:
#   1. Raspberry Pi OS Lite (64 bit), utilizador "blocks".
#   2. Pelo KIAUH: Klipper, Moonraker, Mainsail, KlipperScreen e Crowsnest.
#   3. Firmware do Klipper gravado na Octopus Pro e nas duas H36, e as tres
#      placas ligadas por USB ao Pi.
#
# Uso:
#   git clone https://github.com/lrmartins97/m-bind-config.git ~/m-bind-config
#   bash ~/m-bind-config/instalar.sh
#
# O que faz:
#   1. confirma que o que vem do KIAUH esta instalado;
#   2. encontra os numeros de serie das tres placas (pede para desligar o USB
#      da cabeca T1 por uns segundos, para distinguir o T0 do T1);
#   3. guarda a pasta config que o KIAUH criou (config_antes_<data>) e poe
#      esta no lugar dela;
#   4. cria o printer.cfg desta maquina a partir do printer.cfg.exemplo;
#   5. instala o que falta: moonraker-timelapse, Sonar, NozzleSight e
#      print-from-usb-klipper (cada instalador faz as suas perguntas);
#   6. reinicia o Klipper e o Moonraker e diz o que falta calibrar.
# Nao mexe numa pasta config que ja seja este repositorio.
# ============================================================================
set -euo pipefail

PRINTER_DATA="${PRINTER_DATA:-${HOME}/printer_data}"
CONFIG="${PRINTER_DATA}/config"
SERIAL_DIR="${SERIAL_DIR:-/dev/serial/by-id}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NOZZLESIGHT_URL="https://github.com/lrmartins97/NozzleSight.git"
USB_URL="https://github.com/lrafa97/print-from-usb-klipper.git"
TIMELAPSE_URL="https://github.com/mainsail-crew/moonraker-timelapse.git"
SONAR_URL="https://github.com/mainsail-crew/sonar.git"

titulo() { printf '\n\033[1;35m== %s\033[0m\n' "$*"; }
info()   { printf '   %s\n' "$*"; }
erro()   { printf '\n\033[1;31mERRO: %s\033[0m\n' "$*" >&2; exit 1; }

# --- 1. Verificacoes ---------------------------------------------------------
titulo "A verificar a maquina"
[ "$(id -u)" -ne 0 ] || erro "Nao corras como root (sem sudo). O script pede a password quando for preciso."
falta=""
for d in klipper moonraker mainsail mainsail-config crowsnest KlipperScreen; do
    [ -d "${HOME}/${d}" ] || falta="${falta} ${d}"
done
[ -d "${PRINTER_DATA}" ] || falta="${falta} printer_data"
[ -z "${falta}" ] || erro "Falta instalar pelo KIAUH:${falta}"
info "Klipper, Moonraker, Mainsail, KlipperScreen e Crowsnest: instalados."

if [ -d "${CONFIG}/.git" ]; then
    info "A pasta config ja e' o repositorio da M-BIND: nada a fazer."
    info "Para atualizar:  cd ${CONFIG} && git pull"
    exit 0
fi
[ -f "${REPO_DIR}/mbind.cfg" ] && [ -f "${REPO_DIR}/printer.cfg.exemplo" ] \
    || erro "Este script tem de estar dentro do repositorio m-bind-config."

# --- 2. Numeros de serie das placas ------------------------------------------
titulo "A procurar as placas"
listar() { ls "${SERIAL_DIR}" 2>/dev/null | grep -i "$1" || true; }
octopus="$(listar stm32h723)"
cabecas="$(listar stm32g431)"
n_oct=$(printf '%s' "${octopus}" | grep -c . || true)
n_cab=$(printf '%s' "${cabecas}" | grep -c . || true)
[ "${n_oct}" -eq 1 ] || erro "Esperava 1 Octopus (stm32h723) em ${SERIAL_DIR}, encontrei ${n_oct}. Confirma o USB e o firmware."
[ "${n_cab}" -eq 2 ] || erro "Esperava 2 cabecas (stm32g431) em ${SERIAL_DIR}, encontrei ${n_cab}. Confirma o USB e o firmware."
info "Octopus: ${octopus}"

# Espera ate haver N cabecas ligadas (no maximo 60 s)
esperar_cabecas() {
    local i
    for i in $(seq 1 60); do
        [ "$(listar stm32g431 | grep -c . || true)" -eq "$1" ] && return 0
        sleep 1
    done
    return 1
}
echo
echo "   Para saber qual e' o T0 e qual e' o T1:"
read -rp "   Desliga o cabo USB da cabeca T1 (direita) e carrega Enter... " _
esperar_cabecas 1 || erro "Continuam ligadas duas cabecas. Nada foi alterado; volta a correr o script."
t0="$(listar stm32g431)"
read -rp "   Volta a ligar o cabo da cabeca T1 e carrega Enter... " _
esperar_cabecas 2 || erro "A cabeca T1 nao voltou a aparecer. Nada foi alterado; volta a correr o script."
t1="$(listar stm32g431 | grep -vxF "${t0}")"
info "T0: ${t0}"
info "T1: ${t1}"

# --- 3. Pasta config ---------------------------------------------------------
titulo "A instalar a configuracao"
if [ "${REPO_DIR}" != "${CONFIG}" ]; then
    if [ -e "${CONFIG}" ]; then
        antes="${CONFIG}_antes_$(date +%Y%m%d_%H%M%S)"
        mv "${CONFIG}" "${antes}"
        info "Pasta config anterior guardada em ${antes}"
    fi
    mv "${REPO_DIR}" "${CONFIG}"
    info "Repositorio movido para ${CONFIG}"
fi
cd "${CONFIG}"
# O mainsail.cfg e' um atalho criado pelo KIAUH (fica fora do repositorio)
if [ ! -e mainsail.cfg ] && [ -f "${HOME}/mainsail-config/mainsail.cfg" ]; then
    ln -s "${HOME}/mainsail-config/mainsail.cfg" mainsail.cfg
fi

# --- 4. printer.cfg desta maquina --------------------------------------------
sed -e "s#@SERIAL_OCTOPUS@#${SERIAL_DIR}/${octopus}#" \
    -e "s#@SERIAL_T0@#${SERIAL_DIR}/${t0}#" \
    -e "s#@SERIAL_T1@#${SERIAL_DIR}/${t1}#" \
    printer.cfg.exemplo > printer.cfg
info "printer.cfg criado com os numeros de serie desta maquina."

# --- 5. Programas que faltam -------------------------------------------------
# Cada um so' e' instalado se a pasta dele ainda nao existir.
instalar() {  # instalar <pasta> <url> <comando de instalacao>
    local pasta="${HOME}/$1"
    if [ -d "${pasta}" ]; then
        info "$1: ja instalado."
        return 0
    fi
    titulo "A instalar $1"
    git clone "$2" "${pasta}"
    (cd "${pasta}" && eval "$3")
}
instalar moonraker-timelapse "${TIMELAPSE_URL}" "make install"
instalar sonar "${SONAR_URL}" "make config && make install"
instalar kTAMV "${NOZZLESIGHT_URL}" "bash ./install.sh"
instalar print-from-usb-klipper "${USB_URL}" "./install.sh --no-restart"

# --- 6. Reiniciar e o que falta ----------------------------------------------
titulo "A reiniciar o Klipper e o Moonraker"
sudo systemctl restart moonraker klipper

titulo "Configuracao instalada. Falta calibrar esta maquina:"
cat <<'EOF'
   1. Confirmar o T0 e o T1: aquecer so' o T0 e ver se e' a cabeca esquerda
      que aquece. Se for a direita, troca os dois serial no printer.cfg.
   2. PID das duas cabecas: PID_CALIBRATE HEATER=extruder TARGET=<temp> e
      HEATER=extruder1, depois SAVE_CONFIG.
   3. Altura do Z do T0: CALIBRAR_Z, ACCEPT e SAVE_CONFIG.
   4. Camara do bico: confirmar as camaras no crowsnest.conf (caminhos
      by-path = portas USB) e as portas em calibracao/camara.cfg.
   5. Foco da camara: CALIBRATE_IDEX_CAMERA_FOCUS.
   6. Calibracao entre ferramentas: CALIBRATE_IDEX.
EOF
