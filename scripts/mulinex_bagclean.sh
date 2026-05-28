### sudo nano /usr/local/bin/mulinex_bagclean.sh
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      /usr/local/bin/mulinex_bagclean.sh                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   
#!/bin/bash
# =============================================================
# mulinex_bagclean.sh — Mulinex ROS2 bag cleanup
#
# Logica:
#   1. Trova tutte le cartelle bag sotto ~/
#   2. Controlla spazio disco — allarme se >75% occupato
#   3. Se >75%: propone eliminazione bag >2 settimane
#      finché non scende sotto 60% occupato
#   4. Sempre: cerca bag >1 mese e chiede se eliminarle
# =============================================================

# Se lanciato con sudo, HOME diventa /root — usiamo SUDO_USER per trovare
# la home dell'utente reale
if [ -n "$SUDO_USER" ]; then
    BAGS_ROOT=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    BAGS_ROOT="$HOME"
fi
ALARM_THRESHOLD=70      # % occupato → allarme
TARGET_THRESHOLD=60     # % occupato → obiettivo dopo pulizia
OLD_WEEKS=2             # settimane → bag "vecchie" (pulizia spazio)
OLD_MONTH=30            # giorni → bag "molto vecchie" (pulizia sempre)

# Nomi cartelle bag da cercare (case insensitive)
BAG_DIR_PATTERN="bag|bags|bag_files|rosbag|rosbags|ros_bags|ros2bags"

# Codici colore
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

LOG_FILE="/var/log/mulinex_bagclean.log"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" >> "$LOG_FILE"
}

print_color() {
    local color="$1"
    local msg="$2"
    echo -e "${color}${msg}${RESET}"
}

# ── Trova tutte le cartelle bag sotto HOME ──
find_bag_dirs() {
    find "$BAGS_ROOT" -maxdepth 4 -type d 2>/dev/null \
        | grep -iE "/($BAG_DIR_PATTERN)$" \
        | sort
}

# ── Spazio disco della partizione root ──
get_disk_usage_pct() {
    df / | awk 'NR==2 {gsub("%","",$5); print $5}'
}

get_disk_info() {
    df -h / | awk 'NR==2 {printf "%s totale, %s usato, %s libero (%s%%)", $2, $3, $4, $5}'
}

# ── Lista bag in una cartella ordinate per data (dalla più vecchia) ──
list_bags_sorted() {
    local dir="$1"
    # Le cartelle bag hanno nome timestamp YYYY-MM-DD_HH-MM-SS
    find "$dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort
}

# ── Età in giorni di una cartella (basata sul nome timestamp o mtime) ──
bag_age_days() {
    local bag_path="$1"
    local bag_name
    bag_name=$(basename "$bag_path")

    # Prova a estrarre data dal nome (formato YYYY-MM-DD_*)
    if echo "$bag_name" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}'; then
        local bag_date
        bag_date=$(echo "$bag_name" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}')
        local bag_ts now_ts
        bag_ts=$(date -d "$bag_date" +%s 2>/dev/null)
        now_ts=$(date +%s)
        if [ -n "$bag_ts" ]; then
            echo $(( (now_ts - bag_ts) / 86400 ))
            return
        fi
    fi

    # Fallback: usa mtime della cartella
    local mtime
    mtime=$(stat -c %Y "$bag_path" 2>/dev/null)
    local now_ts
    now_ts=$(date +%s)
    echo $(( (now_ts - mtime) / 86400 ))
}

# ── Dimensione leggibile di una cartella ──
bag_size() {
    du -sh "$1" 2>/dev/null | cut -f1
}

# ── Elimina una lista di bag con conferma ──
delete_bags() {
    local -a bags=("$@")
    local deleted=0
    for bag in "${bags[@]}"; do
        local size
        size=$(bag_size "$bag")
        rm -rf "$bag"
        if [ $? -eq 0 ]; then
            print_color "$GREEN" "    ✓ Eliminata: $(basename $bag) ($size)"
            log "Eliminata bag: $bag ($size)"
            deleted=$((deleted + 1))
        else
            print_color "$RED" "    ✗ Errore eliminando: $(basename $bag)"
            log "ERRORE eliminando: $bag"
        fi
    done
    return $deleted
}

# ── Chiede conferma yes/no ──
ask_confirm() {
    local prompt="$1"
    while true; do
        read -rp "$(echo -e "${YELLOW}  ${prompt} (yes/no): ${RESET}")" answer
        case "$answer" in
            yes|YES|Yes|y|Y) return 0 ;;
            no|NO|No|n|N)    return 1 ;;
            *) echo -e "${YELLOW}  Digita 'yes' oppure 'no'.${RESET}" ;;
        esac
    done
}

# ═══════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════

echo ""
print_color "$CYAN$BOLD" "╔════════════════════════════════════════════╗"
print_color "$CYAN$BOLD" "║     Mulinex — Gestione bag ROS2            ║"
print_color "$CYAN$BOLD" "╚════════════════════════════════════════════╝"
echo ""

log "=== Avvio mulinex_bagclean.sh ==="

# ── Step 1: Trova cartelle bag ──
print_color "$CYAN$BOLD" "[ Step 1 ] Ricerca cartelle bag..."
mapfile -t BAG_DIRS < <(find_bag_dirs)

if [ ${#BAG_DIRS[@]} -eq 0 ]; then
    print_color "$GREEN" "  ✓ Nessuna cartella bag trovata — nessuna azione necessaria."
    log "Nessuna cartella bag trovata."
    exit 0
fi

print_color "$GREEN" "  ✓ Trovate ${#BAG_DIRS[@]} cartella/e bag:"
for d in "${BAG_DIRS[@]}"; do
    local_size=$(du -sh "$d" 2>/dev/null | cut -f1)
    echo -e "    ${CYAN}→ $d${RESET} ($local_size)"
done

# ── Step 2: Controlla spazio disco ──
echo ""
print_color "$CYAN$BOLD" "[ Step 2 ] Controllo spazio disco..."
DISK_PCT=$(get_disk_usage_pct)
DISK_INFO=$(get_disk_info)

if [ "$DISK_PCT" -ge "$ALARM_THRESHOLD" ]; then
    print_color "$RED" "  ✗ Disco occupato al ${DISK_PCT}% — ATTENZIONE! (${DISK_INFO})"
    log "Disco al ${DISK_PCT}% — sopra soglia allarme ${ALARM_THRESHOLD}%"
    NEED_CLEANUP=true
else
    print_color "$GREEN" "  ✓ Disco occupato al ${DISK_PCT}% — OK (${DISK_INFO})"
    log "Disco al ${DISK_PCT}% — sotto soglia allarme"
    NEED_CLEANUP=false
fi

# ── Step 3: Pulizia per spazio (se disco >75%) ──
if [ "$NEED_CLEANUP" = true ]; then
    echo ""
    print_color "$YELLOW$BOLD" "[ Step 3 ] Pulizia bag per liberare spazio (obiettivo: <${TARGET_THRESHOLD}% occupato)..."

    # Raccoglie tutte le bag più vecchie di 2 settimane da tutte le cartelle
    declare -a CLEANUP_CANDIDATES=()
    for bag_dir in "${BAG_DIRS[@]}"; do
        while IFS= read -r bag; do
            age=$(bag_age_days "$bag")
            if [ "$age" -ge "$((OLD_WEEKS * 7))" ]; then
                CLEANUP_CANDIDATES+=("$bag")
            fi
        done < <(list_bags_sorted "$bag_dir")
    done

    if [ ${#CLEANUP_CANDIDATES[@]} -eq 0 ]; then
        print_color "$YELLOW" "  ⚠ Nessuna bag più vecchia di ${OLD_WEEKS} settimane trovata."
        print_color "$YELLOW" "    Libera spazio manualmente o aumenta la soglia."
    else
        print_color "$YELLOW" "  Bag più vecchie di ${OLD_WEEKS} settimane (dalla più vecchia):"
        for bag in "${CLEANUP_CANDIDATES[@]}"; do
            age=$(bag_age_days "$bag")
            size=$(bag_size "$bag")
            echo -e "    ${RED}→ $(basename $bag)${RESET}  ${age} giorni  ($size)  [$bag]"
        done
        echo ""

        if ask_confirm "Eliminare queste bag per liberare spazio?"; then
            for bag in "${CLEANUP_CANDIDATES[@]}"; do
                delete_bags "$bag"
                # Controlla se abbiamo raggiunto l'obiettivo
                DISK_PCT=$(get_disk_usage_pct)
                if [ "$DISK_PCT" -lt "$TARGET_THRESHOLD" ]; then
                    print_color "$GREEN" "  ✓ Spazio libero sufficiente — disco al ${DISK_PCT}%, stop pulizia."
                    break
                fi
            done
            DISK_PCT=$(get_disk_usage_pct)
            DISK_INFO=$(get_disk_info)
            if [ "$DISK_PCT" -ge "$TARGET_THRESHOLD" ]; then
                print_color "$YELLOW" "  ⚠ Disco ancora al ${DISK_PCT}% dopo pulizia (${DISK_INFO})"
                print_color "$YELLOW" "    Considera di eliminare anche bag più recenti manualmente."
            else
                print_color "$GREEN" "  ✓ Disco ora al ${DISK_PCT}% (${DISK_INFO})"
            fi
        else
            print_color "$YELLOW" "  ⚠ Pulizia saltata dall'utente."
            log "Pulizia spazio saltata dall'utente."
        fi
    fi
else
    print_color "$GREEN" "  ✓ Spazio sufficiente, nessuna pulizia necessaria."
fi

# ── Step 4: Bag vecchie >1 mese (indipendente dallo spazio) ──
echo ""
print_color "$CYAN$BOLD" "[ Step 4 ] Ricerca bag più vecchie di ${OLD_MONTH} giorni..."

declare -a OLD_BAGS=()
for bag_dir in "${BAG_DIRS[@]}"; do
    while IFS= read -r bag; do
        age=$(bag_age_days "$bag")
        if [ "$age" -ge "$OLD_MONTH" ]; then
            OLD_BAGS+=("$bag")
        fi
    done < <(list_bags_sorted "$bag_dir")
done

if [ ${#OLD_BAGS[@]} -eq 0 ]; then
    print_color "$GREEN" "  ✓ Nessuna bag più vecchia di ${OLD_MONTH} giorni."
    log "Nessuna bag >1 mese trovata."
else
    print_color "$YELLOW" "  ⚠ Trovate ${#OLD_BAGS[@]} bag più vecchie di ${OLD_MONTH} giorni:"
    for bag in "${OLD_BAGS[@]}"; do
        age=$(bag_age_days "$bag")
        size=$(bag_size "$bag")
        echo -e "    ${RED}→ $(basename $bag)${RESET}  ${age} giorni  ($size)  [$bag]"
    done
    echo ""
    log "Trovate ${#OLD_BAGS[@]} bag >1 mese."

    if ask_confirm "Eliminare tutte le bag più vecchie di ${OLD_MONTH} giorni?"; then
        delete_bags "${OLD_BAGS[@]}"
        DISK_PCT=$(get_disk_usage_pct)
        DISK_INFO=$(get_disk_info)
        print_color "$GREEN" "  ✓ Disco ora al ${DISK_PCT}% (${DISK_INFO})"
    else
        print_color "$YELLOW" "  ⚠ Eliminazione bag vecchie saltata dall'utente."
        log "Eliminazione bag >1 mese saltata dall'utente."
    fi
fi

echo ""
print_color "$CYAN$BOLD" "════════════════════════════════════════════"
print_color "$GREEN$BOLD" "  Gestione bag completata — $(date '+%Y-%m-%d %H:%M:%S')"
print_color "$CYAN$BOLD" "════════════════════════════════════════════"
echo ""
log "=== Fine mulinex_bagclean.sh ==="


































