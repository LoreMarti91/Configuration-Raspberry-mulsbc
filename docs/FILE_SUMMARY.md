# 📋 File Summary - Mulinex Time Sync System

## **Panoramica Completa dei File**

---

## **🔵 File ORIGINALI (già presenti)**

### **1. `mulinex_timesync.sh` ✨ MODIFICATO**
**Destinazione:** `/usr/local/bin/mulinex_timesync.sh` (Rasp)

**Cosa fa:**
- ✋ **Prompt interattivo:** Chiede "Sei pronto?" → ripete se "no"
- 🌐 **Check internet:** Ping a `pool.ntp.org` 
- 🔍 **Scansiona subnet ethernet:** `100.100.100.0/24` (fino a 254 host)
- 📡 **Scansiona subnet WiFi AP:** `192.168.2.0/24` (se wlan0 è AP)
- 📝 **Log completo:** Scritto in `/var/log/mulinex_timesync.log`
- ⏰ **Sincronia dynamica:** Configura `/etc/chrony/sources.d/mulinex_pc.sources`

**Modifica aggiunta:**
```bash
prompt_ready() {
    # Chiede conferma in loop fino a "yes"
    read -p "Sei pronto a inizializzare la sincronizzazione? (yes/no): " answer
    # Ripete se risposte diverse
}
```

---

### **2. `chronyc pc` (PC Ubuntu)**
**Destinazione:** `/etc/chrony/chrony.conf` (su PC)

**Cosa fa:**
- 📡 **Server NTP:** Sincronizza da internet (`ntp.ubuntu.com`, `ubuntu.pool.ntp.org`)
- 🚪 **Accetta client da:** 
  - `100.100.100.0/24` (ethernet)
  - `192.168.2.0/24` (WiFi AP)
- 🔐 **Secure:** Usa `allow` per whitelist (non ingresso da sconosciuti)

**Riga chiave:**
```bash
allow 100.100.100.0/24
allow 192.168.2.0/24
```

---

### **3. `chronyc_rasp` (Rasp - come client)**
**Destinazione:** `/etc/chrony/chrony.conf` (su Rasp)

**Stato:** Aggiornato nel progetto (vedi file)

**Cosa fa:**
- 🤐 **NTP pubblici DISABILITATI** (solo se internet disponibile via script)
- 📂 **Legge dinamicamente:** Da `/etc/chrony/sources.d/` (scritto da `mulinex_timesync.sh`)
- ⏱️ **Step veloce:** `makestep 1 3` (forza aggiustamento al boot)

---

### **4. `bashrc.sh` (PC locale - bashrc)**
**Destinazione:** Opzionale - per fallback login manuale

**Cosa fa:**
- 🔄 **Hook al login:** Esegue `mulinex_timesync.sh` al primo login SSH
- 🚩 **Flag:** Usa `/tmp/mulinex_timesync_done` per non ripetere

**Riga chiave:**
```bash
sudo /usr/local/bin/mulinex_timesync.sh
```

---

## **🟢 File NUOVI (da usare)**

### **5. `mulinex_deploy_all.sh` 🚀 ⭐ CONSIGLIATO**
**Destinazione:** Rasp - eseguire una sola volta con `sudo`

**Cosa fa (deployment completo automatico):**
1. ✅ Verifica dipendenze (installa se mancano)
2. ✅ Copia `mulinex_timesync.sh` → `/usr/local/bin/`
3. ✅ Copia `mulinex_bagclean.sh` → `/usr/local/bin/`
4. ✅ Configura `/etc/chrony/chrony.conf` come client
5. ✅ Installa servizio systemd `mulinex-timesync`
6. ✅ Abilita avvio automatico
7. ✅ Configura cron job per pulizia bag (ogni giorno 2 AM)
8. ✅ Mostra status finale di tutti i servizi

**Comando:**
```bash
sudo bash mulinex_deploy_all.sh
```

**Vantaggio:** Tutto in uno! Non devi fare nulla di manuale.

---

### **6. `install_mulinex_timesync.sh` ⚙️ (Legacy)**
**Destinazione:** Rasp - eseguire una sola volta con `sudo`

**Cosa fa (solo time sync, senza bag cleanup):**
1. ✅ Copia `mulinex_timesync.sh` → `/usr/local/bin/`
2. ✅ Copia config → `/etc/chrony/chrony.conf`
3. ✅ Crea directory `/etc/chrony/sources.d/`
4. ✅ Crea servizio systemd → `/etc/systemd/system/mulinex-timesync.service`
5. ✅ Abilita avvio automatico → `systemctl enable`
6. ✅ Riavvia chrony
7. ✅ Mostra checklist di verifica

**Comando:**
```bash
sudo bash install_mulinex_timesync.sh
```

**Nota:** Usa `mulinex_deploy_all.sh` invece se possibile (più completo).

---

### **7. `mulinex_bagclean.sh` 🧹 ⭐ NUOVO**
**Destinazione:** `/usr/local/bin/mulinex_bagclean.sh` (Rasp)

**Cosa fa (pulizia automatica ROS2 bag):**
1. 📊 Monitora spazio disco root
2. 🚨 Allarme se occupazione > 70%
3. 🗑️ Propone eliminazione bag > 2 settimane
4. ⏰ Continua finché occupazione < 60%
5. 📝 Log completo in `/var/log/mulinex_bagclean.log`
6. 📂 Trova automaticamente cartelle bag (case-insensitive)

**Cartelle supportate:**
```
bag/, bags/, bag_files/, rosbag/, rosbags/, ros_bags/, ros2bags/
```

**Utilizzo manuale:**
```bash
sudo /usr/local/bin/mulinex_bagclean.sh
```

**Automatico (via cron - ogni giorno 2 AM):**
```bash
echo "0 2 * * * /usr/local/bin/mulinex_bagclean.sh" | sudo crontab -
```

**Soglie personalizzabili (nel file):**
```bash
ALARM_THRESHOLD=70      # % disco → allarme
TARGET_THRESHOLD=60     # % disco → obiettivo
OLD_WEEKS=2             # settimane → "vecchio"
OLD_MONTH=30            # giorni → "molto vecchio"
```

---

### **8. `chronyc_rasp_CONFIG.conf` 📖**
**Destinazione:** Solo reference - already copied by installer

**Cosa è:** Copia della configurazione che il installer applica

---

### **9. `mulinex-timesync.service` ⚡**
**Destinazione:** `/etc/systemd/system/mulinex-timesync.service`

**Cosa è:** File di servizio systemd per avvio automatico

**Installato da:** `mulinex_deploy_all.sh` o `install_mulinex_timesync.sh`

---

### **10. `GUIDA_IMPLEMENTAZIONE.md` 📚 ⭐ AGGIORNATA**
**Destinazione:** Leggere per capire il sistema

**Contenuti (aggiornati):**
- 🚀 Metodo 1: Deploy Automatico (CONSIGLIATO)
- 🔧 Metodo 2: Installazione Manuale
- 📊 Diagramma flusso completo
- 🧹 Guida completa mulinex_bagclean.sh
- 📊 Comandi di monitoraggio
- 🐛 Troubleshooting
- ✅ Checklist finale (entrambi metodi)

---

### **11. `README.md` 🚀**
**Destinazione:** Quick start veloce

**Contenuti:**
- ⚡ 3 step per setup (15 min totali)
- 🎮 Test immediato senza reboot
- 📊 Comandi essenziali
- ✅ Cosa aspettarsi al primo boot

---

## **🔴 File DA IGNORARE / DEPRECATI**

Nessuno! Tutti i file sono utilizzati.

---

## **📊 Mappa di Installazione (Deploy Automatico)**

```
PC Ubuntu
    │
    ├─ chronyc pc
    │  (copia in /etc/chrony/chrony.conf su PC)
    │
    └─ mulinex_deploy_all.sh
       (copia su Rasp, esegui con sudo)
           │
           ▼
Rasp
    ├─ /usr/local/bin/mulinex_timesync.sh ✓
    ├─ /usr/local/bin/mulinex_bagclean.sh ✓
    ├─ /etc/chrony/chrony.conf ✓
    ├─ /etc/systemd/system/mulinex-timesync.service ✓
    ├─ /var/log/mulinex_timesync.log
    ├─ /var/log/mulinex_bagclean.log
    └─ cron: mulinex_bagclean.sh ogni 2 AM ✓
```

---

## **📊 Mappa Installazione (Manuale)**

```
┌─ PC UBUNTU ──────────────────┐
│                               │
│  /etc/chrony/chrony.conf      │  ← chronyc pc
│  (Server NTP)                 │
│                               │
│  Ascolta da:                  │
│  • 100.100.100.0/24           │
│  • 192.168.2.0/24             │
└─────────────────────────────┬─┘
                              │
                   (ethernet o WiFi)
                              │
┌─────────────────────────────▼─┐
│ RASPBERRY PI (CLIENT)         │
│                               │
│ 1. install_mulinex_timesync   │
│    └─ Copia tutti i file      │
│                               │
│ 2. /usr/local/bin/            │
│    mulinex_timesync.sh        │
│    └─ Script sincronizzazione │
│                               │
│ 3. /etc/chrony/               │
│    chrony.conf (client)       │
│    sources.d/                 │
│    └─ File generati           │
│                               │
│ 4. /etc/systemd/system/       │
│    mulinex-timesync.service   │
│    └─ Boot automatico         │
│                               │
│ 5. /var/log/                  │
│    mulinex_timesync.log       │
│    └─ Log di esecuzione       │
└───────────────────────────────┘
```

---

## **🎯 Flusso Esecuzione**

```
RASP BOOT
   │
   ├─ systemd avvia mulinex-timesync.service
   │
   ├─ mulinex_timesync.sh esegue
   │
   ├─ [PROMPT] "Sei pronto?" ◄── UTENTE RISPONDE
   │
   ├─ Step 1: Internet? (ping pool.ntp.org)
   │           ├─ YES → usa NTP pubblici
   │           └─ NO  → continua
   │
   ├─ Step 2: PC via ethernet? (scan 100.100.100.*)
   │           ├─ TROVATO → sincronizza
   │           └─ NO  → continua
   │
   ├─ Step 3: PC via WiFi AP? (scan 192.168.2.*)
   │           ├─ TROVATO → sincronizza
   │           └─ NO  → Step 4
   │
   └─ Step 4: FALLBACK
               └─ Log warning, no sync

FINE BOOT ✅
```

---

## **📝 Modifiche Fatte**

### **A `mulinex_timesync.sh`:**
```bash
# AGGIUNTO: Funzione prompt_ready()
prompt_ready() {
    while true; do
        echo "╔════════════════════════════════════════════╗"
        echo "║  Mulinex Time Sync Bootstrap               ║"
        echo "╚════════════════════════════════════════════╝"
        read -p "Sei pronto a inizializzare la sincronizzazione? (yes/no): " answer
        
        case "$answer" in
            yes|YES|Yes) return 0 ;;
            no|NO|No) sleep 2 ;;
            *) echo "⚠ Risposta non riconosciuta..." ;;
        esac
    done
}

# AGGIUNTO: Step 0 - richiesta utente
if [ -t 0 ]; then
    prompt_ready  # Terminal interattivo
else
    log "Non in sessione interattiva, procedo automaticamente..."
fi
```

### **A `/etc/chrony/chrony.conf` (Rasp):**
- Pool NTP pubblici DISABILITATI (sono ancora commentati)
- Abilitato: `sourcedir /etc/chrony/sources.d`
- Configurazione client (non server)
- Logging completo

---

## **✅ Conclusione**

| Phase | File | Action | Destinazione |
|-------|------|--------|--------------|
| 1. Setup PC | `chronyc pc` | Copy | `/etc/chrony/chrony.conf` |
| 2. Copy Files | `mulinex_timesync.sh` + `install_...sh` | SCP | Rasp `~/` |
| 3. Install Rasp | `install_mulinex_timesync.sh` | `sudo bash` | Auto-copy |
| 4. Boot Test | - | `sudo reboot` | Vedi prompt |
| 5. Documentazione | `GUIDA_IMPLEMENTAZIONE.md` | Read | Reference |

**Tutti i file sono pronti! 🎉**
