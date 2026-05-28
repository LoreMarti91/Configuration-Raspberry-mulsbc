# 🚀 Mulinex Time Sync System

**Sistema automatico di sincronizzazione oraria per Raspberry Pi con pulizia intelligente ROS2 bag**

![GitHub](https://img.shields.io/badge/GitHub-Ready-green)
![License](https://img.shields.io/badge/License-MIT-blue)
![Platform](https://img.shields.io/badge/Platform-Raspberry%20Pi%20%2B%20Ubuntu-orange)

---

## 🎯 Cosa Fa

✅ **Sincronizzazione oraria automatica** al boot della Rasp  
✅ **Esecuzione automatica** al login SSH (timesync + bagclean)  
✅ **Pulizia intelligente** di ROS2 bag quando disco pieno  
✅ **Esecuzione senza password** (abilitato via sudoers)  
✅ **Log completi** di ogni operazione  
✅ **Completamente disattivabile** - controllo totale  

---

## ⚡ Quick Start (3 Step)

### **1️⃣ Setup PC Ubuntu (una volta)**

```bash
# Copia la config di server NTP
sudo cp config/chronyc_pc /etc/chrony/chrony.conf

# Riavvia chrony
sudo systemctl restart chrony
sudo systemctl status chrony
```

### **2️⃣ Clona Repo su Rasp**

```bash
# SSH sulla Rasp
ssh mulsbc@192.168.2.1

# Clona repo
git clone https://github.com/tuonome/mulinex-timesync.git
cd mulinex-timesync

# Esegui setup
sudo bash setup.sh

# Attendi 2-3 minuti
```

### **3️⃣ Test**

```bash
# Verifica sincronizzazione
chronyc status

# Reboot
sudo reboot

# SSH nuovo → vedrai messaggi [Mulinex]
ssh mulsbc@192.168.2.1
```

**Fatto!** ✅

---

## 📂 Struttura Repo

```
mulinex-timesync/
├── setup.sh                         ← ⭐ Esegui questo!
├── config/
│   ├── chronyc_pc                   ← Config PC server
│   ├── chronyc_rasp                 ← Config Rasp (ref)
│   └── chronyc_rasp_CONFIG.conf     ← Config Rasp (usata)
├── scripts/
│   ├── mulinex_timesync.sh          ← Sincronizzazione
│   ├── mulinex_bagclean.sh          ← Pulizia bag
│   └── install_mulinex_timesync.sh  ← Setup manuale (alt)
├── system/
│   ├── mulinex-timesync.service     ← Servizio systemd
│   ├── bashrc_mulinex.sh            ← Hook bash
│   └── sudoers_mulinex              ← Permessi sudoers
├── docs/
│   ├── GUIDA_DEFINITIVA.md          ← ⭐ Leggi questa
│   ├── RIEPILOGO.md                 ← Riepilogo progetto
│   ├── GUIDA_DEPLOY_AUTOMATICO.md   ← Dettagli deploy
│   └── ... altre guide ...
└── examples/
    └── example_config.md
```

---

## 🎮 Flusso di Esecuzione

### **Al Boot della Rasp**

```
Boot
  ↓
systemd: mulinex-timesync.service
  ↓
mulinex_timesync.sh (sincronizzazione automatica)
  ↓
Rasp pronta
```

### **Al SSH Login (primo dopo boot)**

```
SSH Login
  ↓
~/.bashrc esegue:
  ├─ mulinex_timesync.sh (sincronizzazione)
  └─ mulinex_bagclean.sh (verifica disco + pulizia)
  ↓
Shell pronta
```

---

## 🔧 Utilizzo Manuale

```bash
# Sincronizzazione oraria
sudo /usr/local/bin/mulinex_timesync.sh

# Verifica e pulizia bag
sudo /usr/local/bin/mulinex_bagclean.sh

# Status
chronyc status
chronyc sources -v

# Log
tail -f /var/log/mulinex_timesync.log
tail -f /var/log/mulinex_bagclean.log
```

---

## ⏸️ Come Disattivare

### **Disabilita solo il login SSH (boot rimane automatico)**

```bash
nano ~/.bashrc
# Commenta le sezioni mulinex
```

### **Disabilita solo il boot (SSH rimane automatico)**

```bash
sudo systemctl disable mulinex-timesync
sudo systemctl stop mulinex-timesync
```

### **Disabilita tutto**

```bash
sudo systemctl disable mulinex-timesync
nano ~/.bashrc  # Commenta le sezioni
```

---

## 📖 Documentazione

| File | Descrizione |
|------|-------------|
| **docs/GUIDA_DEFINITIVA.md** | ⭐ Guida completa - LEGGI QUESTA |
| **docs/RIEPILOGO.md** | Riepilogo della struttura progetto |
| **docs/GUIDA_DEPLOY_AUTOMATICO.md** | Dettagli tecnici del deploy |
| **docs/GUIDA_IMPLEMENTAZIONE.md** | Installazione manuale (alternativa) |
| **docs/INIZIO_QUI.md** | Dove iniziare |
| **docs/FILE_SUMMARY.md** | Riepilogo di ogni file |

---

## 🔍 Monitoraggio

```bash
# Status servizio
sudo systemctl status mulinex-timesync
journalctl -u mulinex-timesync -f

# Verificare sincronizzazione
chronyc tracking
chronyc sources -v

# Log applicazione
tail -f /var/log/mulinex_timesync.log
tail -f /var/log/mulinex_bagclean.log

# Spazio disco
df -h /

# Verifica da PC
sudo chronyc clients
```

---

## 🧹 Mulinex Bagclean - Pulizia ROS2 Bag

Monitora spazio disco e pulisce automaticamente bag ROS2 quando necessario:

```bash
# Esecuzione manuale
sudo /usr/local/bin/mulinex_bagclean.sh

# Output tipico:
# [OK] Spazio disco: 45% occupato
# [INFO] Cerco bag molto vecchi (> 30 giorni)...
# [FOUND] /home/user/bags/2024-12-01_10-30-45 (177 giorni)
#   → Eliminarla? (y/n): y
```

### Logica

1. 📊 Monitora spazio disco root
2. 🚨 Se > 70% occupato → allarme
3. 🗑️ Propone eliminazione bag > 2 settimane
4. ⏰ Continua finché occupazione < 60%
5. 📝 Log completo in `/var/log/mulinex_bagclean.log`

### Personalizzazione

Edita `/usr/local/bin/mulinex_bagclean.sh` linee 25-27:

```bash
ALARM_THRESHOLD=70      # % disco → trigger allarme
TARGET_THRESHOLD=60     # % disco → obiettivo
OLD_WEEKS=2             # settimane → "vecchio"
OLD_MONTH=30            # giorni → "molto vecchio"
```

---

## 🐛 Troubleshooting

### Rasp non sincronizza

```bash
# 1. Controlla log
tail -30 /var/log/mulinex_timesync.log

# 2. Verifica PC raggiungibile
ping 100.100.100.X   # Ethernet
ping 192.168.2.X     # WiFi AP

# 3. Verifica chrony su PC
sudo systemctl status chrony  # Su PC

# 4. Riavvia chrony su Rasp
sudo systemctl restart chrony
```

### Bagclean non trova i bag

Assicurati che i bag siano in cartelle riconosciute:
- `bag/`, `bags/`, `bag_files/`
- `rosbag/`, `rosbags/`
- `ros_bags/`, `ros2bags/`

### Prompt "Sei pronto?" non appare

```bash
# Esegui manualmente
sudo /usr/local/bin/mulinex_timesync.sh
```

---

## 📋 Requisiti

- **Rasp**: Ubuntu 20.04+ con chrony installato
- **PC**: Ubuntu 20.04+ con chrony
- **Connessione**: Ethernet o WiFi tra Rasp e PC
- **Privilegi**: `sudo` abilitato

---

## 🔐 Configurazione Rete

```
PC Ubuntu (Server NTP)
├── IP Ethernet: 100.100.100.X
└── IP WiFi AP: 192.168.2.X
    ↓
Raspberry Pi (Client NTP)
├── Ethernet: 100.100.100.Y
└── WiFi: 192.168.2.Y
```

Lo script cerca automaticamente il PC su entrambe le subnet.

---

## 🎓 Come Funziona Internamente

### mulinex_timesync.sh

```bash
# 1. Controlla internet (ping pool.ntp.org)
# 2. Se YES → usa NTP pubblici
# 3. Se NO → scansiona ARP per trovare PC
# 4. Configura chrony, fa makestep
# 5. Log di ogni operazione
```

### mulinex_bagclean.sh

```bash
# 1. Calcola spazio disco (df /)
# 2. Se > 70% → cerca bag vecchi
# 3. Chiede conferma prima di eliminare
# 4. Continua finché < 60%
# 5. Log completo
```

### Esecuzione Automatica

```bash
# systemd (boot)
# └─ mulinex-timesync.service

# bashrc (SSH login)
# ├─ _TIMESYNC_STAMP flag
# ├─ mulinex_timesync.sh
# ├─ _BAGCLEAN_STAMP flag
# └─ mulinex_bagclean.sh
```

---

## 📝 File di Configurazione

### PC Ubuntu (`config/chronyc_pc`)

```bash
# Server NTP
server ntp.ubuntu.com iburst
server ubuntu.pool.ntp.org iburst

# Permette connessioni da subnet Rasp
allow 100.100.100.0/24    # Ethernet
allow 192.168.2.0/24      # WiFi AP
```

### Rasp (`config/chronyc_rasp_CONFIG.conf`)

```bash
# Client NTP
# Sorgenti specificate da mulinex_timesync.sh
sourcedir /etc/chrony/sources.d

# Step veloce al boot
makestep 1 3
```

---

## 🚀 Deployment su Più Rasp

Per distribuire su più Rasp:

```bash
# Setup PC (una volta)
sudo cp config/chronyc_pc /etc/chrony/chrony.conf
sudo systemctl restart chrony

# Per ogni Rasp:
ssh mulsbc@<ip_rasp>
git clone https://github.com/tuonome/mulinex-timesync.git
cd mulinex-timesync
sudo bash setup.sh
```

---

## 💡 Tips & Tricks

### Se accendi spesso la Rasp

```bash
# Visualizza log ultimi boot
journalctl -u mulinex-timesync --since "2 hours ago"
```

### Se il disco è pieno

```bash
# Debug bagclean
sudo bash -x /usr/local/bin/mulinex_bagclean.sh 2>&1 | tail -100
```

### Se vuoi disabilitare bagclean temporaneamente

```bash
# Tocca il flag per saltare questo login
touch /tmp/mulinex_bagclean_done
```

---

## 🤝 Contribuire

Contribuzioni sono benvenute!

```bash
# 1. Fork il repo
# 2. Crea branch feature
git checkout -b feature/my-feature

# 3. Commit
git commit -m "Aggiungi feature"

# 4. Push e crea Pull Request
```

---

## 📄 Licenza

MIT License - vedi LICENSE file

---

## 🆘 Support

**Domande o problemi?**

1. Leggi `docs/GUIDA_DEFINITIVA.md`
2. Controlla i log:
   ```bash
   tail -50 /var/log/mulinex_timesync.log
   tail -50 /var/log/mulinex_bagclean.log
   ```
3. Apri un issue su GitHub

---

## 📞 Contatti

- **Email**: tuo.email@example.com
- **GitHub**: https://github.com/tuonome/mulinex-timesync
- **Issues**: https://github.com/tuonome/mulinex-timesync/issues

---

## ✨ Changelog

### v1.0.0 (2026-05-28)
- ✅ Setup automatico completo
- ✅ Sincronizzazione oraria boot + SSH
- ✅ Pulizia automatica ROS2 bag
- ✅ Documentazione completa

---

**Fatto con ❤️ per Raspberry Pi**
