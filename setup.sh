#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# setup.sh - Mulinex Time Sync - Setup Completo
#
# Uso: sudo bash setup.sh
#
# Questo script configura completamente una Raspberry Pi con:
# ✅ Sincronizzazione oraria automatica (boot + SSH login)
# ✅ Pulizia automatica ROS2 bag
# ✅ Esecuzione senza password (sudoers)
# ✅ Log completi di ogni operazione
# ══════════════════════════════════════════════════════════════════════════════

set -e

# ──────────────────────────────────────────────────────────────────────────────
# CONFIGURAZIONE
# ──────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESYNC_SCRIPT="mulinex_timesync.sh"
BAGCLEAN_SCRIPT="mulinex_bagclean.sh"
CHRONY_CONFIG="chronyc_rasp_CONFIG.conf"
SYSTEMD_SERVICE="mulinex-timesync.service"
BASHRC_MULINEX="bashrc_mulinex.sh"
SUDOERS_MULINEX="sudoers_mulinex"

INSTALL_DIR="/usr/local/bin"
CHRONY_DIR="/etc/chrony"
SYSTEMD_DIR="/etc/systemd/system"
LOG_DIR="/var/log"

BAGCLEAN_LOG="$LOG_DIR/mulinex_bagclean.log"
TIMESYNC_LOG="$LOG_DIR/mulinex_timesync.log"

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ──────────────────────────────────────────────────────────────────────────────
# FUNZIONI UTILITY
# ──────────────────────────────────────────────────────────────────────────────

log_info() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${RESET} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${RESET} $1"
}

log_error() {
    echo -e "${RED}[✗]${RESET} $1"
}

log_section() {
    echo ""
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${RESET}"
    echo -e "${CYAN}${BOLD}  $1${RESET}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${RESET}"
    echo ""
}

check_file() {
    local file="$1"
    if [ ! -f "$file" ]; then
        log_error "File non trovato: $file"
        exit 1
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# CONTROLLI PRELIMINARI
# ──────────────────────────────────────────────────────────────────────────────

log_section "CONTROLLI PRELIMINARI"

if [ "$EUID" -ne 0 ]; then
    log_error "Questo script deve essere eseguito con sudo"
    exit 1
fi
log_success "In esecuzione come root"

log_info "Verifica file sorgente..."
check_file "$SCRIPT_DIR/scripts/$TIMESYNC_SCRIPT"
log_success "  ✓ $TIMESYNC_SCRIPT trovato"

check_file "$SCRIPT_DIR/scripts/$BAGCLEAN_SCRIPT"
log_success "  ✓ $BAGCLEAN_SCRIPT trovato"

check_file "$SCRIPT_DIR/config/$CHRONY_CONFIG"
log_success "  ✓ $CHRONY_CONFIG trovato"

check_file "$SCRIPT_DIR/system/$SYSTEMD_SERVICE"
log_success "  ✓ $SYSTEMD_SERVICE trovato"

log_info "Verifica dipendenze..."
MISSING_DEPS=""
for cmd in chronyc chrony systemctl ip ping; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING_DEPS="$MISSING_DEPS $cmd"
    fi
done

if [ -n "$MISSING_DEPS" ]; then
    log_warn "Dipendenze mancanti:$MISSING_DEPS"
    log_info "Installazione dipendenze..."
    apt-get update -qq
    apt-get install -y chrony systemd iputils-ping 2>&1 | grep -E "^(Setting up|done)" || true
    log_success "Dipendenze installate"
else
    log_success "Tutte le dipendenze presenti"
fi

# ──────────────────────────────────────────────────────────────────────────────
# INSTALLAZIONE MULINEX TIMESYNC
# ──────────────────────────────────────────────────────────────────────────────

log_section "INSTALLAZIONE MULINEX TIME SYNC"

log_info "Copia $TIMESYNC_SCRIPT in $INSTALL_DIR/"
cp "$SCRIPT_DIR/scripts/$TIMESYNC_SCRIPT" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/$TIMESYNC_SCRIPT"
log_success "  ✓ $TIMESYNC_SCRIPT installato"

log_info "Configura /etc/chrony/chrony.conf come client NTP..."
if [ -f "$CHRONY_DIR/chrony.conf" ]; then
    cp "$CHRONY_DIR/chrony.conf" "$CHRONY_DIR/chrony.conf.backup.$(date +%Y%m%d_%H%M%S)"
    log_warn "  ! Backup di chrony.conf creato"
fi
cp "$SCRIPT_DIR/config/$CHRONY_CONFIG" "$CHRONY_DIR/chrony.conf"
log_success "  ✓ chrony.conf configurato"

log_info "Installa servizio systemd..."
cp "$SCRIPT_DIR/system/$SYSTEMD_SERVICE" "$SYSTEMD_DIR/"
chmod 644 "$SYSTEMD_DIR/$SYSTEMD_SERVICE"
systemctl daemon-reload
log_success "  ✓ Servizio installato"

log_info "Abilita e avvia servizio..."
systemctl enable mulinex-timesync.service
systemctl restart mulinex-timesync.service
log_success "  ✓ Servizio abilitato e avviato"

# ──────────────────────────────────────────────────────────────────────────────
# INSTALLAZIONE MULINEX BAGCLEAN
# ──────────────────────────────────────────────────────────────────────────────

log_section "INSTALLAZIONE MULINEX BAG CLEANUP"

log_info "Copia $BAGCLEAN_SCRIPT in $INSTALL_DIR/"
cp "$SCRIPT_DIR/scripts/$BAGCLEAN_SCRIPT" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/$BAGCLEAN_SCRIPT"
log_success "  ✓ $BAGCLEAN_SCRIPT installato"

log_info "Crea log file..."
mkdir -p "$LOG_DIR"
touch "$BAGCLEAN_LOG"
chmod 666 "$BAGCLEAN_LOG"
log_success "  ✓ Log file creato: $BAGCLEAN_LOG"

# ──────────────────────────────────────────────────────────────────────────────
# CONFIGURAZIONE BASHRC E SUDOERS
# ──────────────────────────────────────────────────────────────────────────────

log_section "CONFIGURAZIONE BASHRC E SUDOERS"

BASHRC_PATH="/home/$SUDO_USER/.bashrc"
if [ -f "$BASHRC_PATH" ]; then
    cp "$BASHRC_PATH" "$BASHRC_PATH.backup.$(date +%Y%m%d_%H%M%S)"
    log_warn "  ! Backup di .bashrc creato"
fi

log_info "Configura ~/.bashrc per esecuzione automatica..."
sed -i '/# ── Mulinex:/d' "$BASHRC_PATH" 2>/dev/null || true
sed -i '/_TIMESYNC_STAMP/,/^$/d' "$BASHRC_PATH" 2>/dev/null || true
sed -i '/_BAGCLEAN_STAMP/,/^$/d' "$BASHRC_PATH" 2>/dev/null || true

cat >> "$BASHRC_PATH" << 'BASHRC_CONFIG'

# ── Mulinex: sincronizzazione orario all'avvio shell ──────────────────────────
_TIMESYNC_STAMP="/tmp/mulinex_timesync_done"
if [ ! -f "$_TIMESYNC_STAMP" ]; then
    if [ -x /usr/local/bin/mulinex_timesync.sh ]; then
        echo "[Mulinex] Sincronizzazione orario in corso..."
        sudo /usr/local/bin/mulinex_timesync.sh
        touch "$_TIMESYNC_STAMP"
        echo "[Mulinex] Ora attuale: $(date)"
    fi
fi
unset _TIMESYNC_STAMP

# ── Mulinex: gestione bag ROS2 dopo sincronizzazione ──────────────────────────
_BAGCLEAN_STAMP="/tmp/mulinex_bagclean_done"
if [ ! -f "$_BAGCLEAN_STAMP" ]; then
    if [ -x /usr/local/bin/mulinex_bagclean.sh ]; then
        echo "[Mulinex] Verifica spazio disco e pulizia bag in corso..."
        sudo /usr/local/bin/mulinex_bagclean.sh
        touch "$_BAGCLEAN_STAMP"
    fi
fi
unset _BAGCLEAN_STAMP

BASHRC_CONFIG

chown $SUDO_USER:$SUDO_USER "$BASHRC_PATH"
log_success "  ✓ ~/.bashrc configurato"

log_info "Configura sudoers per esecuzione senza password..."
cat > "/etc/sudoers.d/mulinex" << SUDOERS_CONFIG
# Mulinex: permessi esecuzione senza password
$SUDO_USER ALL=(ALL) NOPASSWD: /usr/local/bin/mulinex_timesync.sh
$SUDO_USER ALL=(ALL) NOPASSWD: /usr/local/bin/mulinex_bagclean.sh
SUDOERS_CONFIG

chmod 440 "/etc/sudoers.d/mulinex"
log_success "  ✓ Sudoers configurato"

# ──────────────────────────────────────────────────────────────────────────────
# VERIFICA INSTALLAZIONE
# ──────────────────────────────────────────────────────────────────────────────

log_section "VERIFICA INSTALLAZIONE"

log_info "Status servizi:"
echo ""

if systemctl is-active --quiet chrony; then
    echo -e "${GREEN}  ✓${RESET} Chrony - ATTIVO"
else
    echo -e "${RED}  ✗${RESET} Chrony - INATTIVO"
fi

if systemctl is-active --quiet mulinex-timesync; then
    echo -e "${GREEN}  ✓${RESET} Mulinex Time Sync - ATTIVO"
else
    echo -e "${RED}  ✗${RESET} Mulinex Time Sync - INATTIVO"
fi

echo ""
log_info "File installati:"
[ -x "$INSTALL_DIR/$TIMESYNC_SCRIPT" ] && echo -e "${GREEN}  ✓${RESET} $INSTALL_DIR/$TIMESYNC_SCRIPT" || echo -e "${RED}  ✗${RESET} $INSTALL_DIR/$TIMESYNC_SCRIPT"
[ -x "$INSTALL_DIR/$BAGCLEAN_SCRIPT" ] && echo -e "${GREEN}  ✓${RESET} $INSTALL_DIR/$BAGCLEAN_SCRIPT" || echo -e "${RED}  ✗${RESET} $INSTALL_DIR/$BAGCLEAN_SCRIPT"
[ -f "$CHRONY_DIR/chrony.conf" ] && echo -e "${GREEN}  ✓${RESET} $CHRONY_DIR/chrony.conf" || echo -e "${RED}  ✗${RESET} $CHRONY_DIR/chrony.conf"

echo ""
log_info "Bash & Sudoers:"
grep -q "mulinex_timesync.sh" "/home/$SUDO_USER/.bashrc" 2>/dev/null && echo -e "${GREEN}  ✓${RESET} ~/.bashrc configurato" || echo -e "${RED}  ✗${RESET} ~/.bashrc non configurato"
[ -f "/etc/sudoers.d/mulinex" ] && echo -e "${GREEN}  ✓${RESET} /etc/sudoers.d/mulinex" || echo -e "${RED}  ✗${RESET} /etc/sudoers.d/mulinex"

# ──────────────────────────────────────────────────────────────────────────────
# INFORMAZIONI FINALI
# ──────────────────────────────────────────────────────────────────────────────

log_section "PROSSIMI STEP"

echo -e "${BOLD}1. Verifica sincronizzazione NTP:${RESET}"
echo "   $ chronyc status"
echo "   $ chronyc sources -v"
echo ""

echo -e "${BOLD}2. Test primo login SSH:${RESET}"
echo "   $ exit"
echo "   $ ssh mulsbc@<ip_rasp>"
echo "   → Vedrai messaggi [Mulinex] per timesync e bagclean"
echo ""

echo -e "${BOLD}3. Reboot per testare avvio automatico:${RESET}"
echo "   $ sudo reboot"
echo ""

log_section "✅ SETUP COMPLETATO!"
echo -e "${GREEN}${BOLD}Flusso di esecuzione:${RESET}"
echo ""
echo -e "${BOLD}• Boot:${RESET} mulinex-timesync.service (sincronizzazione automatica)"
echo -e "${BOLD}• SSH Login:${RESET} ~/.bashrc esegue timesync → bagclean (automatico)"
echo -e "${BOLD}• Manuale:${RESET} sudo /usr/local/bin/mulinex_timesync.sh"
echo ""
echo -e "${YELLOW}Documentazione: vedi docs/GUIDA_DEFINITIVA.md${RESET}"
echo ""
