# 🚀 Deploy Automatico Mulinex - Guida Completa

Questa guida spiega come usare lo script **`mulinex_deploy_all.sh`** per installare automaticamente tutto su una **Rasp nuova con Ubuntu** con chrony già installato.

---

## 📋 Cosa c'è nei tuoi file originali

Prima di usare lo script, ecco cosa fa ognuno dei tuoi file:

### **File Originali (NON MODIFICATI)**

| File | Destinazione | Cosa fa |
|------|-------------|---------|
| `mulinex_timesync.sh` | `/usr/local/bin/` | Script di sincronizzazione oraria con prompt interattivo "Sei pronto?" |
| `chronyc_rasp_CONFIG.conf` | `/etc/chrony/chrony.conf` | Configurazione di Rasp come client NTP |
| `chronyc pc` | PC: `/etc/chrony/chrony.conf` | Configurazione di PC come server NTP |
| `install_mulinex_timesync.sh` | - | Script manuale di installazione (alternativa a deploy automatico) |
| `mulinex_bagclean.sh` | `/usr/local/bin/` (opzionale) | Script pulizia ROS2 bag quando disco pieno - **ESECUZIONE MANUALE SOLTANTO** |
| `mulinex-timesync.service` | `/etc/systemd/system/` | Servizio systemd per avvio automatico al boot |

---

## 🎯 Cosa fa lo script `mulinex_deploy_all.sh`

**Installa AUTOMATICAMENTE tutto in una Rasp:**

```bash
✅ Verifica dipendenze (installa chrony se manca)
✅ Copia mulinex_timesync.sh in /usr/local/bin/
✅ Copia mulinex_bagclean.sh in /usr/local/bin/ (ma senza cron automatico)
✅ Configura /etc/chrony/chrony.conf come client NTP
✅ Installa servizio systemd mulinex-timesync
✅ Configura ~/.bashrc per esecuzione automatica al login SSH
✅ Configura sudoers per esecuzione senza password
✅ Mostra status finale
```

**Flusso di esecuzione:**

```
┌─ BOOT della Rasp ──────────────────────────────────┐
│                                                     │
│  systemd avvia mulinex-timesync.service            │
│  └─→ mulinex_timesync.sh (sincronizzazione)       │
│                                                     │
└──────────────────────────────────────────────────┬─┘
                                                  │
┌──────────────────────────────────────────────────▼─┐
│ SSH Login dell'utente                               │
│                                                     │
│  ~/.bashrc esegue automaticamente:                 │
│  1. mulinex_timesync.sh (sync oraria)             │
│  2. mulinex_bagclean.sh (verifica disco/pulizia)  │
│                                                     │
│  (Entrambi senza chiedere password via sudoers)   │
└──────────────────────────────────────────────────┬─┘
                                                  │
                               ┌─────────────────▼──┐
                               │ Sistema pronto     │
                               │ per operazioni     │
                               └────────────────────┘
```

---

## 🚀 Come usare (3 step)

### **Step 1: Prepara i file su PC**

```bash
# Sul PC, nella cartella con i file:
cd /home/lorenzo/Desktop/Rasp_PD

# Copia lo script deployment sulla Rasp
scp mulinex_deploy_all.sh mulsbc@192.168.2.1:~/
```

### **Step 2: Setup PC come server NTP**

```bash
# Sul PC Ubuntu (una sola volta)
sudo cp /home/lorenzo/Desktop/Rasp_PD/chronyc\ pc /etc/chrony/chrony.conf
sudo systemctl restart chrony
sudo systemctl status chrony   # Verifica che sia OK
```

### **Step 3: Esegui deploy su Rasp**

```bash
# SSH sulla Rasp
ssh mulsbc@192.168.2.1

# Esegui lo script di deploy
sudo bash ~/mulinex_deploy_all.sh

# Aspetta che finisca (2-3 minuti)
# Vedrai i messaggi di installazione

# Verifica che tutto sia OK
sudo systemctl status mulinex-timesync
tail /var/log/mulinex_timesync.log
```

**Fatto!** ✅ La Rasp è pronta e si sincronizzerà al prossimo boot.

---

## 🧹 Mulinex Bagclean - Esecuzione Automatica al Login SSH

Diversamente da prima, `mulinex_bagclean.sh` **viene eseguito automaticamente** subito dopo la sincronizzazione oraria quando fai SSH:

```bash
# Quando fai SSH sulla Rasp:
$ ssh mulsbc@192.168.2.1

# Nella shell troverai:
[Mulinex] Sincronizzazione orario in corso...
...
[Mulinex] Ora attuale: Tue May 27 14:35:22 UTC 2026

[Mulinex] Verifica spazio disco e pulizia bag in corso...
...
```

### **Come funziona**

1. **Nel bashrc (`~/.bashrc`)**
   - Controlla il flag `/tmp/mulinex_timesync_done`
   - Se non esiste → esegue `mulinex_timesync.sh` (una sola volta per login)
   - Poi controlla `/tmp/mulinex_bagclean_done`
   - Se non esiste → esegue `mulinex_bagclean.sh` (una sola volta per login)

2. **Nel sudoers (`/etc/sudoers.d/mulinex`)**
   - Permette esecuzione senza chiedere password
   - Così non blocca lo script al login

### **Se NON vuoi l'esecuzione automatica**

Puoi disabilitarla commentando le righe in `~/.bashrc`:

```bash
# Disabilita al login
nano ~/.bashrc

# Commenta le sezioni mulinex (aggiungi # all'inizio)
# # ── Mulinex: sincronizzazione orario all'avvio shell ──
# _TIMESYNC_STAMP="/tmp/mulinex_timesync_done"
# if [ ! -f "$_TIMESYNC_STAMP" ]; then
#   ...

# Salva: Ctrl+X, Y, Enter
```

### **Se vuoi eseguire manualmente comunque**

Anche se disabilitato dal bashrc, puoi sempre eseguire manualmente:

```bash
# Sincronizzazione
sudo /usr/local/bin/mulinex_timesync.sh

# Pulizia
sudo /usr/local/bin/mulinex_bagclean.sh
```

---

## ⏸️ Come Disattivare la Sincronizzazione Oraria

Se vuoi disabilitare il servizio di sincronizzazione:

```bash
# Disabilita avvio automatico (systemd)
sudo systemctl disable mulinex-timesync

# Ferma il servizio subito
sudo systemctl stop mulinex-timesync

# Verifica che sia disabilitato
sudo systemctl status mulinex-timesync
# Dovrebbe dire "inactive (dead)"
```

Se vuoi **riabilitarla**:

```bash
sudo systemctl enable mulinex-timesync
sudo systemctl start mulinex-timesync
```

### **Per disabilitare anche l'esecuzione al login SSH**

Edita il bashrc:

```bash
nano ~/.bashrc

# Commenta le sezioni Mulinex
# # ── Mulinex: sincronizzazione...
# # ── Mulinex: gestione bag...
```

Salva e riavvia il terminale

---

## 🔍 Cosa è stato toccato e perché

### **Su PC (una sola volta)**

**File modificato:**
- `/etc/chrony/chrony.conf` ← viene sovrascritto con la tua config `chronyc pc`

**Perché:** Il PC deve ascoltare su `100.100.100.0/24` (ethernet) e `192.168.2.0/24` (WiFi) per servire tempo alla Rasp

### **Su Rasp (durante deploy)**

**File creati/modificati:**
- `/usr/local/bin/mulinex_timesync.sh` ← copiato (nuovo)
- `/usr/local/bin/mulinex_bagclean.sh` ← copiato (nuovo)
- `/etc/chrony/chrony.conf` ← sovrascritto con `chronyc_rasp_CONFIG.conf`
- `/etc/systemd/system/mulinex-timesync.service` ← copiato (nuovo)
- `/etc/chrony/sources.d/` ← creata (directory nuova)
- `/var/log/mulinex_timesync.log` ← creato (log file nuovo)
- `/var/log/mulinex_bagclean.log` ← creato (log file nuovo)

**Perché:**
- **Script** → Per eseguire sincronizzazione e pulizia
- **Config chrony** → Rasp deve chiedere tempo al PC, non a NTP pubblici
- **Servizio systemd** → Per avvio automatico al boot
- **Log files** → Per tracciare operazioni

### **Niente Cron Automatico**

A differenza di altre soluzioni, **non installiamo cron job automatico per bagclean** perché:
- ✅ Tu vuoi controllo manuale su quando pulire i bag
- ✅ Ogni situazione è diversa (potrebbe servire i bag per debug, storage, ecc)
- ✅ Lo script è lì pronto quando serve

---

## 📊 Monitoraggio

### **Sincronizzazione oraria**

```bash
# Status corrente
sudo systemctl status mulinex-timesync

# Log tempo reale
tail -f /var/log/mulinex_timesync.log

# Status chrony
chronyc status          # Stato generale
chronyc sources -v      # Sorgenti NTP
chronyc tracking        # Parametri tracking
```

### **Bagclean**

```bash
# Log esecuzioni manuali
tail -50 /var/log/mulinex_bagclean.log

# Ultima esecuzione
grep "Pulizia completata" /var/log/mulinex_bagclean.log | tail -1
```

### **Verifica su PC (che Rasp sia connessa)**

```bash
# Sul PC
sudo chronyc clients

# Dovrebbe mostrare qualcosa tipo:
# 100.100.100.50 (IP Rasp) connessa
```

---

## 🔧 Come Personalizzare Bagclean

Se vuoi modificare il comportamento di bagclean, edita il file:

```bash
sudo nano /usr/local/bin/mulinex_bagclean.sh
```

**Parametri principali (linee 25-27):**

```bash
ALARM_THRESHOLD=70      # % disco → trigger allarme
TARGET_THRESHOLD=60     # % disco → obiettivo dopo pulizia
OLD_WEEKS=2             # settimane → considera "vecchio"
OLD_MONTH=30            # giorni → considera "molto vecchio"
```

**Esempio: Pulizia più aggressiva (soglia 50% invece di 70%)**

```bash
ALARM_THRESHOLD=60
TARGET_THRESHOLD=50
OLD_WEEKS=1
```

Salva e riavvia: `Ctrl+X`, `Y`, `Enter`

---

## 🐛 Troubleshooting

### **Script deployment fallisce**

```bash
# Verifica che la Rasp abbia internet
ping 8.8.8.8

# Se no, configura manualmente con Ethernet
sudo nano /etc/netplan/01-netcfg.yaml
# O WiFi:
sudo nmtui
```

### **Rasp non sincronizza**

```bash
# Verifica che chrony sia attivo
sudo systemctl status chrony

# Verifica che PC sia raggiungibile
ping 100.100.100.X   # Ethernet
ping 192.168.2.X     # WiFi AP

# Controlla log
tail -30 /var/log/mulinex_timesync.log
```

### **Prompt "Sei pronto?" non appare al boot**

```bash
# Se durante SSH al boot non vedi il prompt:
# 1. Accedi normalmente
# 2. Esegui manualmente
sudo /usr/local/bin/mulinex_timesync.sh
```

### **Bagclean non trova i tuoi bag**

```bash
# Verifica che siano in una cartella riconosciuta:
# bag/, bags/, bag_files/, rosbag/, rosbags/, ros_bags/, ros2bags/

# Se sono altrove, rinomina la cartella
mv /my/custom/bags /my/custom/bag   # Ora viene trovata
```

---

## ✅ Checklist Finale

- [ ] `chronyc pc` copiato su PC in `/etc/chrony/chrony.conf`
- [ ] Chrony riavviato su PC: `sudo systemctl restart chrony`
- [ ] `mulinex_deploy_all.sh` copiato su Rasp
- [ ] Script deployment eseguito: `sudo bash ~/mulinex_deploy_all.sh`
- [ ] Sincronizzazione verificata: `chronyc status` (su Rasp)
- [ ] PC mostra Rasp connessa: `sudo chronyc clients` (su PC)
- [ ] Reboot Rasp e verifica prompt: `sudo reboot`
- [ ] Digita "yes" al prompt e attendi sincronizzazione
- [ ] Ora Rasp corretta: `date`

---

## 🎉 Fatto!

La Rasp è pronta per:
- ✅ **Sincronizzazione oraria automatica** al boot (prompt interattivo)
- ✅ **Script bagclean disponibile** per pulizia manuale quando serve
- ✅ **Niente automazioni indesiderate** → controllo completo

**Buon lavoro!** 🚀
