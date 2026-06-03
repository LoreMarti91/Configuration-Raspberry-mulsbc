#!/bin/bash
# =============================================================
# mulinex_timesync.sh — Mulinex time sync
#
# Logica:
#   1. Ha internet? → usa NTP pubblici (rimuove sorgente PC)
#   2. No internet → legge ARP table per trovare IP del PC
#      a. Prima cerca su ethernet (subnet di eth0, es. 100.100.100.0/24)
#      b. Se non trovato, cerca su rete AP (subnet di wlan0, es. 192.168.X.0/24)
#         → Rileva automaticamente il terzo ottetto da wlan0 (adatto a qualsiasi AP)
#   3. Trovato PC → scrive sources.d, ricarica chrony, makestep
#   4. Nessuna fonte → log warning
# =============================================================

LOG_FILE="/var/log/mulinex_timesync.log"
CHRONY_SOURCE_FILE="/etc/chrony/sources.d/mulinex_pc.sources"
ETH_IFACE="eth0"
WLAN_IFACE="wlan0"
NET_TIMEOUT=3

# Codici colore ANSI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Colora il messaggio per il terminale in base al contenuto
_colorize() {
    local msg="$1"
    case "$msg" in
        *"✓"*|*"OK"*)         echo -e "${GREEN}${msg}${RESET}" ;;
        *"✗"*|*"fallito"*|*"FAILED"*) echo -e "${RED}${msg}${RESET}" ;;
        *"⚠"*|*"warning"*|*"Warning"*) echo -e "${YELLOW}${msg}${RESET}" ;;
        *"Step"*|*"==="*)     echo -e "${CYAN}${BOLD}${msg}${RESET}" ;;
        *)                     echo -e "${msg}" ;;
    esac
}

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" >> "$LOG_FILE"   # file: senza colori
    _colorize "$msg"             # terminale: con colori
}

# Scrive SOLO sul file — usata dentro command substitution $() per non inquinare stdout
logf() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# ── Ricava l'IP della rasp su una interfaccia ──
get_own_ip() {
    local iface="$1"
    ip -4 addr show "$iface" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1
}

# ── Ricava i primi 3 ottetti da un IP (es. 100.100.100.2 → 100.100.100) ──
get_prefix() {
    echo "$1" | cut -d. -f1-3
}

# ── Cerca il PC nella ARP table su una certa subnet ──
# Restituisce il primo IP trovato nella ARP table che appartiene alla subnet
find_pc_via_arp() {
    local prefix="$1"   # es. "100.100.100"
    local iface="$2"
    local label="$3"

    logf "  Cerco PC via ARP su ${prefix}.0/24 (${label})..."

    # Legge la ARP table: filtra solo stati validi, esclude FAILED
    local found
    found=$(ip neigh show dev "$iface" 2>/dev/null \
        | awk -v prefix="$prefix" '
            /REACHABLE|STALE|DELAY|PROBE/ {
                if ($1 ~ "^" prefix "\\.") print $1
            }
        ' | head -1)

    if [ -n "$found" ]; then
        logf "  ✓ PC trovato via ARP su ${label}: $found"
        echo "$found"   # SOLO l'IP su stdout
        return 0
    fi

    logf "  ✗ Nessun host in ARP table su ${label}"
    return 1
}

# ── Scrive il file sources.d e sincronizza via chrony ──
apply_ntp_server() {
    local server_ip="$1"
    local label="$2"

    log "Configuro chrony → server $server_ip ($label)"

    # Scrive SOLO l'IP, niente variabili con log dentro
    printf '# Generato da mulinex_timesync.sh\nserver %s iburst prefer\n' \
        "$server_ip" | sudo tee "$CHRONY_SOURCE_FILE" > /dev/null

    # Ricarica le sorgenti
    if chronyc reload sources 2>/dev/null; then
        log "  chrony: reload sources OK"
    else
        log "  chrony: reload fallito, provo restart..."
        systemctl restart chrony 2>/dev/null
        sleep 3
    fi

    # Aspetta max 15s che chrony contatti il server
    local i=0
    while [ $i -lt 15 ]; do
        sleep 1
        i=$((i+1))
        if chronyc sources 2>/dev/null | grep -qE '^\^[\*\+]'; then
            break
        fi
    done

    # Forza step immediato
    if chronyc makestep 2>/dev/null; then
        log "✓ Sync OK da $label ($server_ip) — ora: $(date)"
        return 0
    fi

    log "✗ makestep fallito per $label ($server_ip)"
    return 1
}

# ── Richiesta conferma interattiva ──
prompt_ready() {
    while true; do
        echo ""
        echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}${BOLD}║     Mulinex — Sincronizzazione orario      ║${RESET}"
        echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════╝${RESET}"
        echo ""
        read -rp "  Sincronizzare l'orario? (yes/no): " answer
        case "$answer" in
            yes|YES|Yes|y|Y)
                return 0 ;;
            no|NO|No|n|N)
                log "Sincronizzazione saltata dall'utente."
                exit 0 ;;
            *)
                echo -e "${YELLOW}  Digita 'yes' oppure 'no'.${RESET}" ;;
        esac
    done
}

# ═══════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════

log "=== Avvio sincronizzazione orario Mulinex ==="

# ── Chiede conferma solo se siamo in sessione interattiva ──
if [ -t 0 ]; then
    prompt_ready
fi

# ── Leggi IP rasp su eth0 e wlan0 ──
ETH_IP=$(get_own_ip "$ETH_IFACE")
WLAN_IP=$(get_own_ip "$WLAN_IFACE")
log "  eth0=$ETH_IP  wlan0=$WLAN_IP"

# ── Step 1: Internet? ──
log "Step 1: verifica internet..."
if ping -c 1 -W "$NET_TIMEOUT" "216.239.35.0" &>/dev/null; then
    log "  ✓ Internet disponibile, uso NTP pubblici"
    rm -f "$CHRONY_SOURCE_FILE"
    systemctl restart chrony 2>/dev/null
    sleep 5
    if chronyc makestep 2>/dev/null; then
        log "✓ Sync da internet OK — ora: $(date)"
        exit 0
    fi
    log "  Sync internet fallito, provo locale..."
fi

# ── Step 2a: Cerca PC via ARP su ethernet ──
if [ -n "$ETH_IP" ]; then
    ETH_PREFIX=$(get_prefix "$ETH_IP")
    log "Step 2a: ARP su ethernet (prefix $ETH_PREFIX)..."
    PC_IP=$(find_pc_via_arp "$ETH_PREFIX" "$ETH_IFACE" "ethernet")
    if [ -n "$PC_IP" ]; then
        if apply_ntp_server "$PC_IP" "PC-ethernet"; then
            exit 0
        fi
    fi
else
    log "Step 2a: eth0 non ha IP, skip"
fi

# ── Step 2b: Cerca PC via ARP su rete AP (wlan0) ──
# Solo se wlan0 ha un IP che finisce in .1 (= rasp è gateway AP)
if [ -n "$WLAN_IP" ]; then
    WLAN_LAST=$(echo "$WLAN_IP" | cut -d. -f4)
    if [ "$WLAN_LAST" = "1" ]; then
        WLAN_PREFIX=$(get_prefix "$WLAN_IP")
        log "Step 2b: ARP su rete AP (prefix $WLAN_PREFIX)..."
        PC_IP=$(find_pc_via_arp "$WLAN_PREFIX" "$WLAN_IFACE" "AP-WiFi")
        if [ -n "$PC_IP" ]; then
            if apply_ntp_server "$PC_IP" "PC-AP-WiFi"; then
                exit 0
            fi
        fi
    else
        log "Step 2b: wlan0 è client ($WLAN_IP), non AP — skip"
    fi
else
    log "Step 2b: wlan0 non ha IP, skip"
fi

# ── Step 3: Fallback ──
log "⚠ Nessuna fonte disponibile. Ora di sistema: $(date)"
exit 1





























