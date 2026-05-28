# 📚 Guida Definitiva - Mulinex Time Sync + Bag Cleanup

## 📂 File nel Progetto

### **File Originali (NON MODIFICATI)**
✅ `mulinex_timesync.sh` — Script sincronizzazione oraria con prompt interattivo  
✅ `mulinex_bagclean.sh` — Script pulizia ROS2 bag quando disco pieno  
✅ `install_mulinex_timesync.sh` — Installazione manuale alternativa  
✅ `chronyc pc` — Config PC come server NTP  
✅ `chronyc_rasp` — Config Rasp (riferimento)  
✅ `chronyc_rasp_CONFIG.conf` — Config Rasp client (copia utilizzata)  
✅ `mulinex-timesync.service` — Servizio systemd  
✅ `bashrc.sh` — Hook bash per esecuzione automatica  
✅ `sudoers.tmp` — Permessi sudoers senza password  

### **File Nuovi (deploy automatico)**
✅ `mulinex_deploy_all.sh` — **Script di installazione completa** (quello che usi!)  
✅ `GUIDA_DEPLOY_AUTOMATICO.md` — Guida tecnica dettagliata  

---

## 🚀 Come Usare (Quick Start)

### **Step 1: Configurazione PC (una sola volta)**

```bash
# Sul PC Ubuntu, copia la config di server NTP
sudo cp /home/lorenzo/Desktop/Rasp_PD/chronyc\ pc /etc/chrony/chrony.conf

# Riavvia chrony
sudo systemctl restart chrony

# Verifica che sia ok
sudo systemctl status chrony
```

### **Step 2: Deploy su Rasp Nuova**

```bash
# Da PC, copia lo script
scp mulinex_deploy_all.sh mulsbc@192.168.2.1:~/

# SSH sulla Rasp
ssh mulsbc@192.168.2.1

# Installa tutto
sudo bash ~/mulinex_deploy_all.sh

# Attendi 2-3 minuti (installa dipendenze, configura, verifica)
```

**Fatto!** ✅

---

## 🎯 Cosa Accade Dopo l'Installazione

### **Al Boot della Rasp**

```
┌─ BOOT ──────────────────────────────────┐
│                                          │
│  systemd avvia:                         │
│  mulinex-timesync.service               │
│  └─→ mulinex_timesync.sh                │
│     (sincronizzazione oraria)           │
│                                          │
└──────────────────────────────────────────┘
```

### **Al Login SSH (primo login dopo boot)**

```
┌─ SSH Login ──────────────────────────────┐
│                                           │
│  ~/.bashrc esegue automaticamente:       │
│                                           │
│  1. mulinex_timesync.sh                  │
│     [Mulinex] Sincronizzazione orario... │
│     [Mulinex] Ora attuale: ...           │
│                                           │
│  2. mulinex_bagclean.sh                  │
│     [Mulinex] Verifica disco...          │
│     [OK] Spazio: 45% occupato            │
│                                           │
│  (Entrambi eseguiti SENZA chiedere pwd)  │
│                                           │
└───────────────────────────────────────────┘
```

**Nota:** Viene eseguito solo il primo login dopo il boot (flag `/tmp/mulinex_*_done`)

---

## ⏸️ Come Disattivare i 2 Check

### **Opzione 1: Disattivare SOLO l'esecuzione al login SSH**

Così il boot rimane automatico, ma al login non esegui nulla:

```bash
# Edita il bashrc
nano ~/.bashrc

# Commenta le 2 sezioni mulinex (aggiungi # all'inizio di ogni riga)
# # ── Mulinex: sincronizzazione orario all'avvio shell ──────────────────────────
# _TIMESYNC_STAMP="/tmp/mulinex_timesync_done"
# if [ ! -f "$_TIMESYNC_STAMP" ]; then
#     ...
# fi
# unset _TIMESYNC_STAMP
#
# # ── Mulinex: gestione bag ROS2 dopo sincronizzazione ──────────────────────────
# _BAGCLEAN_STAMP="/tmp/mulinex_bagclean_done"
# if [ ! -f "$_BAGCLEAN_STAMP" ]; then
#     ...
# fi
# unset _BAGCLEAN_STAMP

# Salva: Ctrl+X → Y → Enter
```

### **Opzione 2: Disattivare l'esecuzione al boot**

Così al login SSH non esegue nulla, e il boot rimane pulito:

```bash
# Disabilita il servizio systemd
sudo systemctl disable mulinex-timesync
sudo systemctl stop mulinex-timesync

# Verifica disabilitato
sudo systemctl status mulinex-timesync
# Dovrebbe dire: "inactive (dead)" e "disabled"
```

### **Opzione 3: Disattivare TUTTO**

```bash
# Disabilita il servizio
sudo systemctl disable mulinex-timesync
sudo systemctl stop mulinex-timesync

# Commenta le sezioni nel bashrc (come Opzione 1)
nano ~/.bashrc
```

### **Se vuoi riabilitare**

```bash
# Riabilita il servizio
sudo systemctl enable mulinex-timesync
sudo systemctl start mulinex-timesync

# O decommmenta il bashrc
nano ~/.bashrc
# Togli i # dalle sezioni mulinex
```

---

## 🔧 Esecuzione Manuale (Quando Serve)

Anche se disattivato, puoi sempre eseguire manualmente:

### **Sincronizzazione oraria**

```bash
sudo /usr/local/bin/mulinex_timesync.sh

# Output:
# ╔════════════════════════════════════════════╗
# ║  Mulinex Time Sync Bootstrap               ║
# ╚════════════════════════════════════════════╝
# 
# Sei pronto a inizializzare la sincronizzazione? (yes/no): yes
# 
# Step 1: Controlla Internet...
# ✓ Internet disponibile! Sincronizzazione da NTP pubblici
# ...
```

### **Verifica e pulizia bag**

```bash
sudo /usr/local/bin/mulinex_bagclean.sh

# Output:
# [OK] Spazio disco: 45% occupato
# [INFO] Cerco bag molto vecchi (> 30 giorni)...
# [FOUND] /home/mulsbc/bags/2024-12-01_10-30-45 (177 giorni)
#   → Eliminarla? (y/n): y
# [INFO] Bag eliminato
```

---

## 📊 Monitoraggio

### **Status sincronizzazione**

```bash
# Stato del servizio
sudo systemctl status mulinex-timesync

# Log in tempo reale
tail -f /var/log/mulinex_timesync.log

# Log systemd
journalctl -u mulinex-timesync -f

# Status chrony
chronyc status
chronyc sources -v
chronyc tracking
```

### **Verifica da PC che Rasp sia connessa**

```bash
# Su PC
sudo chronyc clients

# Dovrebbe mostrare qualcosa come:
# 100.100.100.50                  0     0     0     0
# 192.168.2.50                    0     0     0     0
```

### **Status bagclean**

```bash
# Log delle esecuzioni
tail -50 /var/log/mulinex_bagclean.log

# Verifica ultimo spazio controllato
grep "Spazio disco" /var/log/mulinex_bagclean.log | tail -1
```

---

## 🔍 Troubleshooting

### **Rasp non sincronizza**

```bash
# 1. Verifica che PC sia raggiungibile
ping 100.100.100.X   # Ethernet
ping 192.168.2.X     # WiFi AP

# 2. Verifica che chrony sia attivo su PC
sudo systemctl status chrony   # Su PC

# 3. Verifica log Rasp
tail -30 /var/log/mulinex_timesync.log

# 4. Se niente funziona, riavvia chrony su Rasp
sudo systemctl restart chrony
```

### **Bagclean non trova i bag**

I bag devono stare in cartelle riconosciute (case-insensitive):
- `bag/`, `bags/`, `bag_files/`
- `rosbag/`, `rosbags/`
- `ros_bags/`, `ros2bags/`

```bash
# Se i tuoi bag sono in /my/custom/bags_dir/
# Rinomina a una cartella riconosciuta:
mv /my/custom/bags_dir /my/custom/bag
# Ora viene trovata!
```

### **Prompt "Sei pronto?" non appare al login SSH**

```bash
# Accedi normalmente e esegui manualmente
sudo /usr/local/bin/mulinex_timesync.sh
```

### **Vuoi vedere cosa fa bashrc?**

```bash
# Visualizza le sezioni mulinex in bashrc
grep -A 10 "# ── Mulinex:" ~/.bashrc
```

---

## ✅ Checklist Completa

### **Setup Iniziale**

- [ ] PC Ubuntu: `sudo cp chronyc\ pc /etc/chrony/chrony.conf`
- [ ] PC Ubuntu: `sudo systemctl restart chrony`
- [ ] PC Ubuntu: `sudo systemctl status chrony` → active (running)

### **Deploy su Rasp**

- [ ] `scp mulinex_deploy_all.sh mulsbc@192.168.2.1:~/`
- [ ] `ssh mulsbc@192.168.2.1`
- [ ] `sudo bash ~/mulinex_deploy_all.sh`
- [ ] Script completa senza errori

### **Verifica Immediata**

- [ ] `sudo systemctl status mulinex-timesync` → active (running)
- [ ] `chronyc status` → Sync: 1 (sincronizzato) o System time ???
- [ ] `tail -20 /var/log/mulinex_timesync.log` → vedi step di sincronizzazione

### **Test SSH Login**

- [ ] Esci dalla SSH
- [ ] `ssh mulsbc@192.168.2.1`
- [ ] Vedi messaggi `[Mulinex]` per timesync e bagclean
- [ ] `date` mostra ora corretta

### **Test Boot Automatico**

- [ ] `sudo reboot`
- [ ] Aspetta che Rasp si riavvii
- [ ] `ssh mulsbc@192.168.2.1`
- [ ] Verifica sincronizzazione: `chronyc status`

### **Test Bagclean Manuale**

- [ ] `sudo /usr/local/bin/mulinex_bagclean.sh`
- [ ] Vedi output di verifica spazio disco
- [ ] Se hai bag vecchi, vedi la domanda di eliminazione

---

## 📝 Configurazione Avanzata

### **Modifica soglie bagclean**

```bash
# Edita il file
sudo nano /usr/local/bin/mulinex_bagclean.sh

# Linee 25-27, modifica:
ALARM_THRESHOLD=70      # % disco → trigger allarme (default 70%)
TARGET_THRESHOLD=60     # % disco → obiettivo (default 60%)
OLD_WEEKS=2             # settimane → "vecchio" (default 2)
OLD_MONTH=30            # giorni → "molto vecchio" (default 30)
```

**Esempio: Più aggressivo**
```bash
ALARM_THRESHOLD=60      # Allarme a 60%
TARGET_THRESHOLD=45     # Pulisci fino a 45%
OLD_WEEKS=1             # Considera "vecchio" dopo 1 settimana
```

### **Modifica timeout di scansione**

```bash
# Edita mulinex_timesync.sh
sudo nano /usr/local/bin/mulinex_timesync.sh

# Linee ~27:
NET_TIMEOUT=3   # timeout per test internet (default 3s)
```

Se la rete è lenta:
```bash
NET_TIMEOUT=10  # Aumenta a 10s
```

---

## 🎯 Scenari di Utilizzo

### **Scenario 1: Rasp con Internet Sempre**

```bash
# ✅ Sincronizza da NTP pubblici automaticamente
# Bagclean verifica disco al login SSH
# Niente intervento manuale normalmente
```

### **Scenario 2: Rasp Senza Internet (solo PC locale)**

```bash
# ✅ Al boot: mulinex_timesync.sh scansiona subnet
# ✅ Trova PC e sincronizza (ethernet o WiFi)
# ✅ Bagclean verifica disco al login SSH
```

### **Scenario 3: Rasp Controllata Solo via Systemd**

Se NON vuoi l'esecuzione al login SSH:

```bash
nano ~/.bashrc
# Commenta le 2 sezioni mulinex

# Boot rimane automatico via systemd
# Login SSH rimane pulito (niente output mulinex)
```

### **Scenario 4: Disattivazione Temporanea**

```bash
sudo systemctl stop mulinex-timesync
# Ripristina: sudo systemctl start mulinex-timesync
```

---

## 📋 File di Configurazione

### **On Rasp**

```
/usr/local/bin/mulinex_timesync.sh      ← Script timesync
/usr/local/bin/mulinex_bagclean.sh      ← Script bagclean
/etc/chrony/chrony.conf                 ← Config NTP client
/etc/chrony/sources.d/                  ← Directory per sorgenti dinamiche
/etc/systemd/system/mulinex-timesync.service
/etc/sudoers.d/mulinex                  ← Permessi senza password
~/.bashrc                               ← Hook al login SSH
/var/log/mulinex_timesync.log          ← Log sincronizzazione
/var/log/mulinex_bagclean.log          ← Log pulizia bag
```

### **On PC Ubuntu**

```
/etc/chrony/chrony.conf                 ← Config NTP server
```

---

## 🎓 Struttura Finale

```
Sistema Mulinex Time Sync
│
├─ BOOT della Rasp
│  └─→ systemd: mulinex-timesync.service
│      └─→ /usr/local/bin/mulinex_timesync.sh
│          (sincronizzazione oraria)
│
├─ SSH Login (primo login dopo boot)
│  └─→ ~/.bashrc
│      ├─→ /usr/local/bin/mulinex_timesync.sh
│      │   (se flag /tmp/mulinex_timesync_done assente)
│      │
│      └─→ /usr/local/bin/mulinex_bagclean.sh
│          (se flag /tmp/mulinex_bagclean_done assente)
│          [Monitora disco e chiede conferma prima di eliminare]
│
├─ Esecuzione Manuale (quando serve)
│  ├─→ sudo /usr/local/bin/mulinex_timesync.sh
│  └─→ sudo /usr/local/bin/mulinex_bagclean.sh
│
└─ Disattivazione
   ├─ Servizio: sudo systemctl disable/stop mulinex-timesync
   └─ Bashrc: nano ~/.bashrc (commenta le sezioni)
```

---

## 🚨 Flag Temporanei (Non toccare)

Vengono creati automaticamente:

```bash
/tmp/mulinex_timesync_done     # Flag: timesync eseguito questo login
/tmp/mulinex_bagclean_done     # Flag: bagclean eseguito questo login
```

Vengono cancellati automaticamente al nuovo login o reboot.

---

## ✨ Tips & Tricks

### **Fai partire tutto una volta sola al boot (senza SSH)**

```bash
# Il servizio systemd già lo fa automaticamente
# Quando accendi Rasp, mulinex_timesync.sh parte da solo
```

### **Se accendi spesso la Rasp**

```bash
# Vedi i log:
journalctl -u mulinex-timesync --since "2 hours ago"
```

### **Se vuoi disabilitare SOLO bagclean temporaneamente**

```bash
# Tocca il flag bagclean per non eseguirlo questo login
touch /tmp/mulinex_bagclean_done

# Al prossimo reboot o nuovo terminal, verrà eseguito di nuovo
```

### **Se il disco è pieno e bagclean non riesce ad eliminare**

```bash
# Esegui manualmente con debug
sudo bash -x /usr/local/bin/mulinex_bagclean.sh 2>&1 | tail -100
```

---

## 📞 Support

**Se qualcosa non funziona:**

```bash
# 1. Leggi i log
tail -50 /var/log/mulinex_timesync.log
tail -50 /var/log/mulinex_bagclean.log

# 2. Verifica status
sudo systemctl status mulinex-timesync
chronyc status

# 3. Esegui manualmente per debug
sudo /usr/local/bin/mulinex_timesync.sh
sudo /usr/local/bin/mulinex_bagclean.sh

# 4. Controlla i flag
ls -la /tmp/mulinex_*
```

---

## ✅ Fine!

**Sei pronto a usare il sistema Mulinex!** 🚀

- ✅ Installazione automatica
- ✅ Sincronizzazione oraria intelligente
- ✅ Pulizia automatica bag
- ✅ Completo controllo (puoi disattivare quando vuoi)
- ✅ Esecuzione senza password

Buon lavoro! 🎉
