# 📡 Mulinex Time Sync System - Guida Implementazione

## 🎯 Obiettivo
Sistema **completo di sincronizzazione oraria** per Raspberry Pi (Rasp) che al boot:
1. ✋ **Chiede conferma SSH** ("Sei pronto?")
2. 🌐 **Controlla internet** → sincronizza da NTP pubblici
3. 🖥️ **Altrimenti fallback** → scansiona e sincronizza da PC (ethernet/WiFi)
4. ⏰ **Mantiene il tempo** → anche senza connessione internet

---

## 📂 File di progetto

| File | Destinazione | Ruolo |
|------|-------------|-------|
| `mulinex_deploy_all.sh` | Rasp | **NUOVO** - Script deployment automatico completo |
| `mulinex_timesync.sh` | `/usr/local/bin/` | Script principale - sincronizzazione oraria |
| `mulinex_bagclean.sh` | `/usr/local/bin/` | **NUOVO** - Pulizia automatica bag ROS2 |
| `chronyc_rasp_CONFIG.conf` | `/etc/chrony/chrony.conf` | Config Rasp come client NTP |
| `chronyc pc` | PC: `/etc/chrony/chrony.conf` | Config PC come server NTP |
| `mulinex-timesync.service` | `/etc/systemd/system/` | Servizio systemd per avvio automatico |
| `install_mulinex_timesync.sh` | Rasp | (Legacy) Script di installazione per timesync solo |
| `bashrc.sh` | Rasp: `~/.bashrc` | (Opzionale) Fallback per login manuale |

---

## � INSTALLAZIONE RAPIDA (CONSIGLIATO)

### **Metodo 1: Deploy Automatico Completo** ⭐ **NUOVO - SCONSIGLIATO**

Se hai una Rasp **nuova con chrony già installato**, usa lo script di deploy automatico che fa tutto:

```bash
# SSH sulla Rasp (via network 100.100.100.X)
ssh mulsbc@100.100.100.X

# Se cloni per la prima volta
git clone https://github.com/mulsbc/Configuration-Raspberry-mulsbc.git
cd Configuration-Raspberry-mulsbc

# Esegui lo script (farà tutto automaticamente)
sudo bash setup.sh
```

Lo script farà automaticamente:
- ✅ Copia `mulinex_timesync.sh` in `/usr/local/bin/`
- ✅ Copia `mulinex_bagclean.sh` in `/usr/local/bin/`
- ✅ Configura `/etc/chrony/chrony.conf` come client
- ✅ Installa il servizio systemd `mulinex-timesync`
- ✅ Configura pulizia automatica bag con cron
- ✅ Riavvia i servizi
- ✅ Mostra lo stato di tutto

---

## 🔧 INSTALLAZIONE MANUALE PER RASP

### **Fase 1: Setup iniziale Rasp**

```bash
# Accedi via SSH alla Rasp
ssh mulsbc@192.168.2.1

# Vai in directory di lavoro
mkdir -p ~/mulinex_setup
cd ~/mulinex_setup

# Copia i file (da PC)
# scp mulinex_timesync.sh mulsbc@192.168.2.1:~/mulinex_setup/
# scp install_mulinex_timesync.sh mulsbc@192.168.2.1:~/mulinex_setup/
```

### **Fase 2a: Installa Time Sync (su Rasp con sudo)**

```bash
cd ~/mulinex_setup
chmod +x install_mulinex_timesync.sh
sudo bash install_mulinex_timesync.sh
```

L'installer farà automaticamente:
- ✅ Copia `mulinex_timesync.sh` in `/usr/local/bin/`
- ✅ Configura `/etc/chrony/chrony.conf` come client
- ✅ Crea servizio systemd
- ✅ Abilita avvio automatico
- ✅ Riavvia chrony

### **Fase 2b: Installa Bag Cleanup (su Rasp con sudo)** ⭐ **NUOVO**

```bash
# Copia lo script
sudo cp mulinex_bagclean.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/mulinex_bagclean.sh

# Crea log directory
sudo mkdir -p /var/log
sudo touch /var/log/mulinex_bagclean.log
sudo chmod 666 /var/log/mulinex_bagclean.log

# Opzionale: Aggiungi cron job per esecuzione automatica (ogni giorno alle 2 AM)
echo "0 2 * * * /usr/local/bin/mulinex_bagclean.sh" | sudo crontab -
```

---

## 🖥️ SETUP SU PC UBUNTU

### **Step 1: Configura PC come server NTP**

Copia `chronyc pc` in:
```bash
sudo cp chronyc\ pc /etc/chrony/chrony.conf
sudo systemctl restart chrony
```

**Cosa fa:**
- PC ascolta da subnet `100.100.100.0/24` (ethernet)
- PC ascolta da subnet `192.168.2.0/24` (WiFi AP)
- PC sincronizza con NTP pubblici
- Rasp si sincronizzerà con il PC come server

### **Verifica su PC:**

```bash
# Controlla che chrony sia in ascolto
sudo chronyc clients

# Dovrebbe mostrare clienti connessi (anche se ancora vuoti)
```

---

## 🚀 UTILIZZO

### **Al Boot della Rasp:**

```
Mulinex Time Sync Bootstrap
═══════════════════════════

Sei pronto a inizializzare la sincronizzazione? (yes/no): █
```

**Se rispondi "yes":**
1. ✅ Controlla internet
2. ✅ Cerca PC su ethernet (100.100.100.X)
3. ✅ Cerca PC su WiFi AP (192.168.2.X)
4. ✅ Sincronizza l'orologio

**Se rispondi "no":**
- ⏸️ Richiede di nuovo la domanda (riprovi)

### **Esecuzione manuale:**

```bash
# Su Rasp
/usr/local/bin/mulinex_timesync.sh

# Oppure via systemd
sudo systemctl start mulinex-timesync
```

---

## 📊 MONITORAGGIO

### **Log dello script:**

```bash
# In tempo reale
tail -f /var/log/mulinex_timesync.log

# Ultimi 50 eventi
tail -50 /var/log/mulinex_timesync.log
```

### **Status chrony (Rasp):**

```bash
chronyc status          # Stato generale
chronyc sources -v      # Sorgenti NTP dettagliate
chronyc tracking        # Parametri di tracking
```

### **Log systemd (Rasp):**

```bash
# Ultimi avvii
journalctl -u mulinex-timesync -n 20

# In tempo reale
journalctl -u mulinex-timesync -f
```

### **Verifica da PC:**

```bash
# Controlla se Rasp si è connessa come client
chronyc clients

# Dovrebbe mostrare qualcosa come:
# 192.168.2.X / 100.100.100.X     0     0     0     0  ...
```

---

## 🧹 MULINEX BAG CLEANUP

### **Cos'è?** ⭐ **NUOVO**

`mulinex_bagclean.sh` monitora e pulisce automaticamente i ROS2 bag files quando lo spazio disco supera soglie critiche.

**Caratteristiche:**
- 📊 Monitora spazio disco automaticamente
- 🚨 Allarme quando occupazione > 70%
- 🗑️ Elimina bag files vecchi per liberare spazio
- 📝 Log completo in `/var/log/mulinex_bagclean.log`
- ⏰ Eseguibile manualmente o via cron automatico

### **Logica di pulizia:**

```
1️⃣ Check spazio disco (root partition)
   │
   ├─ Occupazione < 60% → OK, vai a step 2
   ├─ Occupazione 60-70% → ⚠️ Warning, vai a step 2
   └─ Occupazione > 70% → 🚨 ALLARME!
      │
      └─→ Propone eliminazione bag > 2 settimane
          finché occupazione non scende sotto 60%
   
2️⃣ Cerca bag > 30 giorni
   │
   └─→ Chiede conferma eliminazione
       (anche se occupazione OK)
```

### **Utilizzo manuale:**

```bash
# Test (non elimina, solo simula)
sudo /usr/local/bin/mulinex_bagclean.sh

# Output tipico:
# [OK] Spazio disco: 50% occupato
# [INFO] Cerco bag antichi...
# [FOUND] /root/bags/2025-01-15_14-32-10 (72 giorni)
#   → Eliminarla? (y/n): y
```

### **Automatizzazione con cron:** ⭐ **CONSIGLIATO**

Pulizia automatica ogni giorno alle 2 AM:

```bash
# Già configurato da mulinex_deploy_all.sh
# Ma se fatto manualmente:
sudo crontab -e

# Aggiungi questa riga:
0 2 * * * /usr/local/bin/mulinex_bagclean.sh
```

### **Personalizzazione:**

Modifica le soglie in `/usr/local/bin/mulinex_bagclean.sh`, linee 25-27:

```bash
ALARM_THRESHOLD=70      # % → trigger allarme (default 70%)
TARGET_THRESHOLD=60     # % → obiettivo dopo pulizia (default 60%)
OLD_WEEKS=2             # settimane → "vecchi" (default 2)
OLD_MONTH=30            # giorni → "molto vecchi" (default 30)
```

Esempio: Pulizia più aggressiva (soglia 50%):
```bash
ALARM_THRESHOLD=60
TARGET_THRESHOLD=50
OLD_WEEKS=1
```

### **Cartelle supportate:**

Lo script cerca automaticamente bag in queste cartelle (case-insensitive):
- `bag/`, `bags/`, `bag_files/`
- `rosbag/`, `rosbags/`
- `ros_bags/`, `ros2bags/`

```bash
# Es: tutte queste vengono trovate
~/bag/
~/ros_bags/
~/ROS2BAGS/
~/my_project/bag_files/
```

### **Log del bag cleanup:**

```bash
# Ultimo esecuzione
tail -50 /var/log/mulinex_bagclean.log

# Monitoraggio in tempo reale (durante esecuzione)
sudo /usr/local/bin/mulinex_bagclean.sh

# Grep log per errori
grep ERROR /var/log/mulinex_bagclean.log
```

### **Verifica cron job:**

```bash
# Mostra tutti i cron job di root
sudo crontab -l

# Deve contenere:
# 0 2 * * * /usr/local/bin/mulinex_bagclean.sh
```

---

## 🔄 FLUSSO DI SINCRONIZZAZIONE

```
┌─────────────────────────────┐
│   Rasp Boot / SSH Login     │
└──────────────┬──────────────┘
               │
               ▼
     ┌─────────────────────┐
     │ Prompt "Sei pronto?"│ ◄── Conferma utente (yes/no)
     └────────┬────────────┘
              │
              ▼
    ┌──────────────────────┐
    │ Internet disponibile?│
    └────┬────────┬────────┘
         │        │
      YES│        │NO
         ▼        ▼
    ┌────────┐  ┌──────────────────────────┐
    │ NTP    │  │ Scansiona subnet locale  │
    │Pubblici│  │ (100.100.100.0/24)       │
    └────────┘  └────┬──────────┬──────────┘
                    │         │
                 TROVATO   NON TROVATO
                    │         │
                    ▼         ▼
                   ┌──┐   ┌──────────────────┐
                   │PC│   │ Prova WiFi AP    │
                   │  │   │ (192.168.2.0/24) │
                   └──┘   └────┬─────┬───────┘
                              │     │
                           TROVATO NON TROVATO
                              │     │
                              ▼     ▼
                             ┌──┐  ⚠️ ERROR
                             │PC│  (Log warning)
                             │  │
                             └──┘
                              │
                              ▼
                    ✅ SYNC RIUSCITO
                    Ora system aggiornata
```

---

## ⚙️ CONFIGURAZIONE AVANZATA

### **Modifica timeout di scansione:**

In `mulinex_timesync.sh`, linee 27-28:

```bash
PING_TIMEOUT=1   # timeout ping per scansione (veloce)
NET_TIMEOUT=5    # timeout per test internet
```

Aumenta se le reti sono lente:
```bash
PING_TIMEOUT=3
NET_TIMEOUT=10
```

### **Range IP PC - AUTOMATICO:**

✅ **Non serve modificare nulla!** Il codice rileva automaticamente:
- **Ethernet:** scan della subnet dell'IP eth0 (es. 100.100.100.0/24)
- **WiFi AP:** scan della subnet dell'IP wlan0 (es. 192.168.X.0/24)
- **Gateway AP:** cerca sempre il .1 della rete WiFi (es. 192.168.X.1)

Se hai network diversi:
- 100.100.100.0/24 → auto-rilevato da eth0
- 192.168.X.0/24 → auto-rilevato da wlan0 (dove X è il terzo ottetto di wlan0)

### **Disabilita boot automatico:**

```bash
sudo systemctl disable mulinex-timesync
```

---

## 🐛 TROUBLESHOOTING

### **"Nessuna fonte di tempo disponibile"**

**Causa:** Rasp non trova PC

**Soluzione:**
1. Verifica che PC sia raggiungibile sulle reti corrette:
   ```bash
   # Su ethernet (se eth0 ha IP)
   ping 100.100.100.X
   
   # Su WiFi AP (se wlan0 ha IP come gateway)
   ping 192.168.X.1    # Dove X è il terzo ottetto di wlan0
   ```

2. Verifica che chrony sia attivo su PC:
   ```bash
   sudo systemctl status chrony
   ```

3. Controlla che PC accetti connessioni:
   ```bash
   sudo chronyc clients
   ```

### **Orologio salta avanti/indietro**

**Causa:** Slew lento vs step veloce

**Soluzione:** In `/etc/chrony/chrony.conf`:
```bash
makestep 0.1 3  # Step anche per piccole deviazioni (< 100ms)
```

### **Rasp sincronizzato ma perde tempo**

**Causa:** Orologio hardware (RTC) non sincronizzato

**Soluzione:**
```bash
# Sincronizza RTC subito
sudo chronyc makestep

# Verifica drift
cat /var/lib/chrony/chrony.drift
```

---

## 📝 CHECKLIST FINALE

### **Metodo 1: Deploy Automatico** ⭐ (Consigliato)

Se usi `mulinex_deploy_all.sh`:
- [ ] Script copiato su Rasp: `mulinex_deploy_all.sh`
- [ ] Eseguito con: `sudo bash ~/mulinex_deploy_all.sh`
- [ ] Script ha installato tutto automaticamente
- [ ] Systemd status: `sudo systemctl status mulinex-timesync`
- [ ] Cron job presente: `sudo crontab -l | grep mulinex_bagclean`
- [ ] Log temporizzazione: `tail /var/log/mulinex_timesync.log`
- [ ] Log bag cleanup: `tail /var/log/mulinex_bagclean.log`

### **Metodo 2: Installazione Manuale**

**Su PC:**
- [ ] File `chronyc pc` copiato in `/etc/chrony/chrony.conf`
- [ ] `sudo systemctl restart chrony` eseguito
- [ ] `sudo chronyc status` mostra online
- [ ] `sudo chronyc clients` pronto ad accettare connessioni

**Su Rasp:**
- [ ] `install_mulinex_timesync.sh` eseguito con sudo
- [ ] `/usr/local/bin/mulinex_timesync.sh` esiste e eseguibile
- [ ] `/usr/local/bin/mulinex_bagclean.sh` esiste e eseguibile
- [ ] `/etc/chrony/chrony.conf` aggiornato
- [ ] `sudo systemctl status mulinex-timesync` abilitato
- [ ] Cron job configurato: `echo "0 2 * * * /usr/local/bin/mulinex_bagclean.sh" | sudo crontab -`
- [ ] `/etc/chrony/sources.d/` directory creata

### **Test finale (comune a entrambi i metodi):**

- [ ] Riavvia Rasp: `sudo reboot`
- [ ] SSH entra durante boot, vedi prompt "Sei pronto?"
- [ ] Rispondi "yes"
- [ ] Controlla log: `tail -20 /var/log/mulinex_timesync.log`
- [ ] `date` mostra ora corretta
- [ ] `chronyc tracking` mostra sincronizzazione OK
- [ ] Test manuale bagclean: `sudo /usr/local/bin/mulinex_bagclean.sh`

---

## 🎓 STRUTTURA FINALE

```
Rasp (Client)
├── /usr/local/bin/mulinex_timesync.sh
│   └─ Script di sincronizzazione
├── /etc/chrony/chrony.conf
│   └─ Config client (disabilita NTP pubblici)
├── /etc/chrony/sources.d/mulinex_pc.sources
│   └─ Generato dinamicamente (server locale)
├── /etc/systemd/system/mulinex-timesync.service
│   └─ Servizio per boot automatico
└── /var/log/mulinex_timesync.log
    └─ Log delle sincronizzazioni

PC Ubuntu (Server)
├── /etc/chrony/chrony.conf
│   └─ Config server (abilita NTP pubblici)
└── [Ascolta da subnet 100.100.100.0/24 e 192.168.2.0/24]
```

---

## ✅ Fatto!

Il sistema è pronto! 🚀

**Al prossimo boot della Rasp:**
1. Riceverai il prompt SSH
2. Dirai "yes"
3. Sincronizzazione automatica
4. Orologio perfettamente sincronizzato

Buon lavoro! 🎉
