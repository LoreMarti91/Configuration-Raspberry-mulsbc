#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# mulinex_deploy_all.sh
# Script di deployment automatico completo - Mulinex Time Sync + Bag Cleanup
#
# Uso: sudo bash mulinex_deploy_all.sh
#
# Cosa fa:
#   1. Verifica dipendenze (chrony, systemctl, ecc)
#   2. Copia mulinex_timesync.sh in /usr/local/bin/
#   3. Copia mulinex_bagclean.sh in /usr/local/bin/ (uso MANUALE)
#   4. Configura /etc/chrony/chrony.conf come client NTP
#   5. Installa servizio systemd mulinex-timesync
#   6. Riavvia servizi
#   7. Mostra status finale
#
# NOTA: Niente cron automatico per bagclean - esecuzione manuale quando serve
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

# Verifica che un file esista
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

# Check root
if [ "$EUID" -ne 0 ]; then
    log_error "Questo script deve essere eseguito con sudo"
    exit 1
fi
log_success "In esecuzione come root"

# Check file necessari
log_info "Verifica file sorgente..."
check_file "$SCRIPT_DIR/$TIMESYNC_SCRIPT"
log_success "  ✓ $TIMESYNC_SCRIPT trovato"

check_file "$SCRIPT_DIR/$BAGCLEAN_SCRIPT"
log_success "  ✓ $BAGCLEAN_SCRIPT trovato"

check_file "$SCRIPT_DIR/$CHRONY_CONFIG"
log_success "  ✓ $CHRONY_CONFIG trovato"

check_file "$SCRIPT_DIR/$SYSTEMD_SERVICE"
log_success "  ✓ $SYSTEMD_SERVICE trovato"

# Check dipendenze
log_info "Verifica dipendenze..."
MISSING_DEPS=""
for cmd in chronyc chrony systemctl ip ping nmap-ncat; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING_DEPS="$MISSING_DEPS $cmd"
    fi
done

if [ -n "$MISSING_DEPS" ]; then
    log_warn "Dipendenze mancanti:$MISSING_DEPS"
    log_info "Installazione dipendenze..."
    apt-get update -qq
    apt-get install -y chrony systemd iputils-ping netcat-openbsd 2>&1 | grep -E "^(Setting up|done)" || true
    log_success "Dipendenze installate"
else
    log_success "Tutte le dipendenze presenti"
fi

# ──────────────────────────────────────────────────────────────────────────────
# INSTALLAZIONE MULINEX TIMESYNC
# ──────────────────────────────────────────────────────────────────────────────

log_section "INSTALLAZIONE MULINEX TIME SYNC"

log_info "Copia $TIMESYNC_SCRIPT in $INSTALL_DIR/"
cp "$SCRIPT_DIR/$TIMESYNC_SCRIPT" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/$TIMESYNC_SCRIPT"
log_success "  ✓ $TIMESYNC_SCRIPT installato e reso eseguibile"

log_info "Configura /etc/chrony/chrony.conf come client NTP..."
if [ -f "$CHRONY_DIR/chrony.conf" ]; then
    cp "$CHRONY_DIR/chrony.conf" "$CHRONY_DIR/chrony.conf.backup.$(date +%Y%m%d_%H%M%S)"
    log_warn "  ! Backup di chrony.conf creato"
fi
cp "$SCRIPT_DIR/$CHRONY_CONFIG" "$CHRONY_DIR/chrony.conf"
log_success "  ✓ chrony.conf configurato come client"

log_info "Installa servizio systemd..."
cp "$SCRIPT_DIR/$SYSTEMD_SERVICE" "$SYSTEMD_DIR/"
chmod 644 "$SYSTEMD_DIR/$SYSTEMD_SERVICE"
systemctl daemon-reload
log_success "  ✓ Servizio systemd installato"

log_info "Abilita e avvia servizio mulinex-timesync..."
systemctl enable mulinex-timesync.service
systemctl restart mulinex-timesync.service
log_success "  ✓ Servizio abilitato e avviato"

# ──────────────────────────────────────────────────────────────────────────────
# INSTALLAZIONE MULINEX BAGCLEAN
# ──────────────────────────────────────────────────────────────────────────────

log_section "INSTALLAZIONE MULINEX BAG CLEANUP"

log_info "Copia $BAGCLEAN_SCRIPT in $INSTALL_DIR/"
cp "$SCRIPT_DIR/$BAGCLEAN_SCRIPT" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/$BAGCLEAN_SCRIPT"
log_success "  ✓ $BAGCLEAN_SCRIPT installato e reso eseguibile"

log_info "Crea log directory per bag cleanup..."
mkdir -p "$LOG_DIR"
touch "$BAGCLEAN_LOG"
chmod 666 "$BAGCLEAN_LOG"
log_success "  ✓ Log file creato: $BAGCLEAN_LOG"

log_info "Bagclean installato - sarà usato MANUALMENTE quando necessario"
log_info "  Esecuzione manuale: sudo /usr/local/bin/mulinex_bagclean.sh"
log_success "  ✓ Niente cron automatico (controllo manuale)"

# ──────────────────────────────────────────────────────────────────────────────
# CONFIGURAZIONE BASHRC E SUDOERS
# ──────────────────────────────────────────────────────────────────────────────

log_section "CONFIGURAZIONE BASHRC E SUDOERS"

# Backup bashrc esistente
BASHRC_PATH="/home/$SUDO_USER/.bashrc"
if [ -f "$BASHRC_PATH" ]; then
    cp "$BASHRC_PATH" "$BASHRC_PATH.backup.$(date +%Y%m%d_%H%M%S)"
    log_warn "  ! Backup di .bashrc creato"
fi

# Copia il bashrc.sh in ~/.bashrc
log_info "Configura ~/.bashrc per esecuzione automatica al login SSH..."
# Rimuovi le vecchie sezioni Mulinex (se presenti)
sed -i '/# ── Mulinex:/d' "$BASHRC_PATH" 2>/dev/null || true
sed -i '/_TIMESYNC_STAMP/,/^$/d' "$BASHRC_PATH" 2>/dev/null || true
sed -i '/_BAGCLEAN_STAMP/,/^$/d' "$BASHRC_PATH" 2>/dev/null || true

# Aggiungi le nuove sezioni al termine del file
cat >> "$BASHRC_PATH" << 'BASHRC_MULINEX'

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

BASHRC_MULINEX

chown $SUDO_USER:$SUDO_USER "$BASHRC_PATH"
log_success "  ✓ ~/.bashrc configurato"

# Configura sudoers per permettere esecuzione senza password
log_info "Configura sudoers per esecuzione senza password..."
SUDOERS_FILE="/etc/sudoers.d/mulinex"

# Crea il file sudoers
cat > "$SUDOERS_FILE" << SUDOERS_MULINEX
# Mulinex: permessi per esecuzione senza password
$SUDO_USER ALL=(ALL) NOPASSWD: /usr/local/bin/mulinex_timesync.sh
$SUDO_USER ALL=(ALL) NOPASSWD: /usr/local/bin/mulinex_bagclean.sh
SUDOERS_MULINEX

chmod 440 "$SUDOERS_FILE"
log_success "  ✓ Sudoers configurato (esecuzione senza password)"

log_section "VERIFICA INSTALLAZIONE"

log_info "Status dei servizi:"
echo ""

# Check chrony
if systemctl is-active --quiet chrony; then
    echo -e "${GREEN}  ✓ Chrony${RESET}        - ATTIVO"
else
    echo -e "${RED}  ✗ Chrony${RESET}        - INATTIVO (errore!)"
fi

# Check mulinex-timesync
if systemctl is-active --quiet mulinex-timesync; then
    echo -e "${GREEN}  ✓ Mulinex Time Sync${RESET} - ATTIVO"
else
    echo -e "${RED}  ✗ Mulinex Time Sync${RESET} - INATTIVO (errore!)"
fi

# Check file installati
echo ""
log_info "File installati:"
[ -x "$INSTALL_DIR/$TIMESYNC_SCRIPT" ] && echo -e "${GREEN}  ✓${RESET} $INSTALL_DIR/$TIMESYNC_SCRIPT" || echo -e "${RED}  ✗${RESET} $INSTALL_DIR/$TIMESYNC_SCRIPT"
[ -x "$INSTALL_DIR/$BAGCLEAN_SCRIPT" ] && echo -e "${GREEN}  ✓${RESET} $INSTALL_DIR/$BAGCLEAN_SCRIPT" || echo -e "${RED}  ✗${RESET} $INSTALL_DIR/$BAGCLEAN_SCRIPT"
[ -f "$CHRONY_DIR/chrony.conf" ] && echo -e "${GREEN}  ✓${RESET} $CHRONY_DIR/chrony.conf" || echo -e "${RED}  ✗${RESET} $CHRONY_DIR/chrony.conf"
[ -f "$SYSTEMD_DIR/$SYSTEMD_SERVICE" ] && echo -e "${GREEN}  ✓${RESET} $SYSTEMD_DIR/$SYSTEMD_SERVICE" || echo -e "${RED}  ✗${RESET} $SYSTEMD_DIR/$SYSTEMD_SERVICE"

# Log files
echo ""
log_info "Log files disponibili:"
[ -f "$TIMESYNC_LOG" ] && echo -e "${GREEN}  ✓${RESET} $TIMESYNC_LOG" || echo -e "${YELLOW}  ?${RESET} $TIMESYNC_LOG (verrà creato al boot)"
[ -f "$BAGCLEAN_LOG" ] && echo -e "${GREEN}  ✓${RESET} $BAGCLEAN_LOG" || echo -e "${YELLOW}  ?${RESET} $BAGCLEAN_LOG (verrà creato al primo login SSH)"

# Bash configuration
echo ""
log_info "Bash configuration:"
if grep -q "mulinex_timesync.sh" "/home/$SUDO_USER/.bashrc" 2>/dev/null; then
    echo -e "${GREEN}  ✓${RESET} ~/.bashrc - mulinex_timesync.sh"
else
    echo -e "${RED}  ✗${RESET} ~/.bashrc - mulinex_timesync.sh non trovato"
fi

if grep -q "mulinex_bagclean.sh" "/home/$SUDO_USER/.bashrc" 2>/dev/null; then
    echo -e "${GREEN}  ✓${RESET} ~/.bashrc - mulinex_bagclean.sh"
else
    echo -e "${RED}  ✗${RESET} ~/.bashrc - mulinex_bagclean.sh non trovato"
fi

# Sudoers
echo ""
log_info "Sudoers configuration:"
if [ -f "/etc/sudoers.d/mulinex" ]; then
    echo -e "${GREEN}  ✓${RESET} /etc/sudoers.d/mulinex (esecuzione senza password)"
else
    echo -e "${RED}  ✗${RESET} /etc/sudoers.d/mulinex non trovato"
fi

# ──────────────────────────────────────────────────────────────────────────────
# INFORMAZIONI FINALI
# ──────────────────────────────────────────────────────────────────────────────

log_section "PROSSIMI STEP"

echo -e "${BOLD}1. Verifica sincronia NTP:${RESET}"
echo "   $ sudo chronyc tracking"
echo "   $ sudo chronyc sources"
echo ""

echo -e "${BOLD}2. Test primo login SSH (esecuzione automatica):${RESET}"
echo "   $ ssh mulsbc@<ip_rasp>"
echo "   → Vedrai mulinex_timesync.sh in esecuzione"
echo "   → Poi mulinex_bagclean.sh (verifica spazio disco)"
echo ""

echo -e "${BOLD}3. Reboot per testare avvio automatico (systemd):${RESET}"
echo "   $ sudo reboot"
echo ""

log_section "✅ DEPLOYMENT COMPLETATO!"
echo -e "${GREEN}${BOLD}Flusso di esecuzione:${RESET}"
echo ""
echo -e "${BOLD}1. Al boot della Rasp (systemd):${RESET}"
echo -e "   ${GREEN}→${RESET} mulinex-timesync.service avvia mulinex_timesync.sh"
echo ""
echo -e "${BOLD}2. Al login SSH (bashrc - esecuzione automatica):${RESET}"
echo -e "   ${GREEN}→${RESET} mulinex_timesync.sh (sincronizzazione oraria)"
echo -e "   ${GREEN}→${RESET} mulinex_bagclean.sh (verifica disco e pulizia bag)"
echo ""
echo -e "${YELLOW}Esecuzione senza password:${RESET} Abilitata via sudoers"
echo ""
