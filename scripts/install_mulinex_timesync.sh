#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# install_mulinex_timesync.sh
# Script di installazione per Raspberry Pi - Mulinex Time Sync System
#
# Esegui con: sudo bash install_mulinex_timesync.sh
# ══════════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_NAME="mulinex_timesync.sh"
INSTALL_DIR="/usr/local/bin"
SYSTEMD_SERVICE="mulinex-timesync.service"
SYSTEMD_DIR="/etc/systemd/system"
LOG_DIR="/var/log"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# ──────────────────────────────────────────────────────────────────────────────
# Controlla se in esecuzione come root
# ──────────────────────────────────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
   log_error "Questo script deve essere eseguito con sudo"
   exit 1
fi

log_info "╔════════════════════════════════════════════════════════════════╗"
log_info "║  Mulinex Time Sync - Installazione su Raspberry Pi            ║"
log_info "╚════════════════════════════════════════════════════════════════╝"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Step 1: Verifica dipendenze
# ──────────────────────────────────────────────────────────────────────────────
log_info "Step 1: Verifica dipendenze..."

MISSING_DEPS=""
for cmd in chronyc chrony ping ip systemctl; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING_DEPS="$MISSING_DEPS $cmd"
    fi
done

if [ -n "$MISSING_DEPS" ]; then
    log_error "Mancano i seguenti comandi:$MISSING_DEPS"
    log_info "Installa con: sudo apt-get install chrony iputils-ping"
    exit 1
fi

log_success "Tutte le dipendenze sono disponibili"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Step 2: Copia script principale
# ──────────────────────────────────────────────────────────────────────────────
log_info "Step 2: Installa script principale..."

if [ ! -f "$SCRIPT_NAME" ]; then
    log_error "File $SCRIPT_NAME non trovato nella directory corrente"
    exit 1
fi

cp "$SCRIPT_NAME" "$INSTALL_DIR/$SCRIPT_NAME"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
log_success "Script installato in $INSTALL_DIR/$SCRIPT_NAME"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Step 3: Configura chrony per Rasp
# ──────────────────────────────────────────────────────────────────────────────
log_info "Step 3: Configura chrony per client (Rasp)..."

CHRONY_CONF="/etc/chrony/chrony.conf"
CHRONY_BACKUP="/etc/chrony/chrony.conf.backup.$(date +%Y%m%d_%H%M%S)"

# Backup configurazione originale
if [ -f "$CHRONY_CONF" ]; then
    cp "$CHRONY_CONF" "$CHRONY_BACKUP"
    log_info "Backup della configurazione originale: $CHRONY_BACKUP"
fi

# Crea nuova configurazione per client Rasp
cat > "$CHRONY_CONF" << 'CHRONY_CLIENT'
# Raspberry Pi Mulinex - /etc/chrony/chrony.conf
# Sincronizzazione da Internet o da PC locale via mulinex_timesync.sh

confdir /etc/chrony/conf.d

# NTP pubblici DISABILITATI - Attivati solo se internet OK
#pool ntp.ubuntu.com        iburst maxsources 4
#pool 0.ubuntu.pool.ntp.org iburst maxsources 1
#pool 1.ubuntu.pool.ntp.org iburst maxsources 1
#pool 2.ubuntu.pool.ntp.org iburst maxsources 2

# Sorgenti dinamiche (mulinex_timesync.sh scrive qui il server locale)
sourcedir /etc/chrony/sources.d

# Configurazione sistema
keyfile /etc/chrony/chrony.keys
driftfile /var/lib/chrony/chrony.drift
ntsdumpdir /var/lib/chrony
logdir /var/log/chrony
log tracking measurements statistics

# Parametri di sincronizzazione
maxupdateskew 100.0
rtcsync
makestep 1 3
leapsectz right/UTC
CHRONY_CLIENT

log_success "Configurazione chrony salvata in $CHRONY_CONF"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Step 4: Crea directory necessarie
# ──────────────────────────────────────────────────────────────────────────────
log_info "Step 4: Crea directory e file di log..."

mkdir -p /etc/chrony/sources.d
chmod 755 /etc/chrony/sources.d
touch "$LOG_DIR/mulinex_timesync.log"
chmod 644 "$LOG_DIR/mulinex_timesync.log"

log_success "Directory create e log inizializzati"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Step 5: Crea servizio systemd per boot automatico
# ──────────────────────────────────────────────────────────────────────────────
log_info "Step 5: Configura avvio automatico tramite systemd..."

cat > "$SYSTEMD_DIR/$SYSTEMD_SERVICE" << 'SYSTEMD_UNIT'
[Unit]
Description=Mulinex Time Synchronization Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/mulinex_timesync.sh
StandardInput=tty
StandardOutput=journal
StandardError=journal
SyslogIdentifier=mulinex-timesync

[Install]
WantedBy=multi-user.target
SYSTEMD_UNIT

chmod 644 "$SYSTEMD_DIR/$SYSTEMD_SERVICE"

# Reload systemd daemon
systemctl daemon-reload

log_success "Servizio systemd creato: $SYSTEMD_DIR/$SYSTEMD_SERVICE"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Step 6: Abilita servizio all'avvio
# ──────────────────────────────────────────────────────────────────────────────
log_info "Step 6: Abilita servizio al boot..."

if systemctl enable "$SYSTEMD_SERVICE"; then
    log_success "Servizio abilitato all'avvio"
else
    log_warn "Errore nell'abilitazione del servizio"
fi
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Step 7: Restart chrony con nuova config
# ──────────────────────────────────────────────────────────────────────────────
log_info "Step 7: Riavvia chronyd con nuova configurazione..."

systemctl restart chrony 2>/dev/null || systemctl restart chronyd 2>/dev/null
sleep 2

if systemctl is-active --quiet chrony 2>/dev/null || systemctl is-active --quiet chronyd 2>/dev/null; then
    log_success "chronyd è in esecuzione"
else
    log_warn "Possibile errore con chronyd, verifica con: systemctl status chrony"
fi
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Riepilogo installazione
# ──────────────────────────────────────────────────────────────────────────────
log_info "╔════════════════════════════════════════════════════════════════╗"
log_info "║  Installazione completata!                                    ║"
log_info "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "📋 File installati:"
echo "  • Script: $INSTALL_DIR/$SCRIPT_NAME"
echo "  • Config: $CHRONY_CONF"
echo "  • Servizio: $SYSTEMD_DIR/$SYSTEMD_SERVICE"
echo "  • Log: $LOG_DIR/mulinex_timesync.log"
echo ""

echo "🔧 Comandi utili:"
echo "  • Esegui manualmente: $INSTALL_DIR/$SCRIPT_NAME"
echo "  • Stato servizio: systemctl status $SYSTEMD_SERVICE"
echo "  • Log tempo reale: journalctl -u $SYSTEMD_SERVICE -f"
echo "  • Log script: tail -f $LOG_DIR/mulinex_timesync.log"
echo "  • Stato chrony: chronyc status"
echo "  • Sorgenti NTP: chronyc sources -v"
echo ""

echo "🚀 Al prossimo boot, lo script verrà eseguito automaticamente"
echo "   Ti verrà richiesta conferma in SSH prima di sincronizzare"
echo ""

log_success "Setup completato con successo!"
