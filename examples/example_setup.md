# Esempio Setup - Mulinex Time Sync

Questo file mostra come è stato fatto il setup su una Rasp di esempio.

## Ambiente

- **PC**: Ubuntu 22.04 LTS (IP Ethernet: 100.100.100.1, WiFi: 192.168.2.1)
- **Rasp**: Ubuntu 22.04 for Raspberry Pi (IP Ethernet: 100.100.100.50, WiFi: 192.168.2.50)
- **Connessione**: Ethernet diretta + WiFi AP

## Step 1: Setup PC

```bash
# PC Ubuntu
cd /path/to/mulinex-timesync
sudo cp config/chronyc_pc /etc/chrony/chrony.conf
sudo systemctl restart chrony
sudo systemctl status chrony
sudo chronyc status
```

**Output atteso:**
```
chronyc> status
Reference ID    : 91.189.89.198 (au.ubuntu.com)
Stratum         : 2
Ref time (UTC)  : Tue May 28 08:47:30 2026
System time     : 0.000000000 seconds slow of NTP time
Frequency       : 0.000 ppm
Residual freq   : 0.000 ppm
Skew            : 0.000 ppm
Root delay      : 0.000000 seconds
Root dispersion : 0.000000 seconds
Update interval : 64.2 seconds
Leap status     : Normal
```

## Step 2: Clone e Setup su Rasp

```bash
# SSH sulla Rasp
ssh mulsbc@192.168.2.50

# Clone repo
git clone https://github.com/tuonome/mulinex-timesync.git
cd mulinex-timesync

# Setup
sudo bash setup.sh
```

**Output atteso:**
```
═══════════════════════════════════════════════════════════════
  CONTROLLI PRELIMINARI
═══════════════════════════════════════════════════════════════

[✓] In esecuzione come root
[✓] mulinex_timesync.sh trovato
[✓] mulinex_bagclean.sh trovato
[✓] chronyc_rasp_CONFIG.conf trovato
[✓] mulinex-timesync.service trovato
[✓] Tutte le dipendenze presenti

═══════════════════════════════════════════════════════════════
  INSTALLAZIONE MULINEX TIME SYNC
═══════════════════════════════════════════════════════════════

[INFO] Copia mulinex_timesync.sh in /usr/local/bin/
[✓] mulinex_timesync.sh installato
[INFO] Configura /etc/chrony/chrony.conf come client NTP...
[✓] chrony.conf configurato
[INFO] Installa servizio systemd...
[✓] Servizio installato
[INFO] Abilita e avvia servizio...
[✓] Servizio abilitato e avviato

... output continua ...

═══════════════════════════════════════════════════════════════
✅ SETUP COMPLETATO!
═══════════════════════════════════════════════════════════════

• Boot: mulinex-timesync.service (sincronizzazione automatica)
• SSH Login: ~/.bashrc esegue timesync → bagclean (automatico)
• Manuale: sudo /usr/local/bin/mulinex_timesync.sh

Documentazione: vedi docs/GUIDA_DEFINITIVA.md
```

## Step 3: Verifiche

```bash
# Sincronizzazione
chronyc status
chronyc sources -v
chronyc tracking

# Expected
chronyc> status
Reference ID    : 100.100.100.1 (PC)
Stratum         : 3
Sync status     : Synchronized
```

```bash
# Reboot
sudo reboot

# SSH nuovo (vedrai output mulinex)
ssh mulsbc@192.168.2.50

[Mulinex] Sincronizzazione orario in corso...
Step 1: Controlla Internet...
✓ Internet disponibile! Sincronizzazione da NTP pubblici
Step 2: Status NTP
Reference ID    : 91.189.89.198 (au.ubuntu.com)
Stratum         : 2
✓ Sincronizzazione riuscita!
[Mulinex] Ora attuale: Tue May 28 09:00:15 UTC 2026

[Mulinex] Verifica spazio disco e pulizia bag in corso...
[OK] Spazio disco: 48% occupato
[INFO] Cerco bag molto vecchi (> 30 giorni)...
[OK] Nessun bag da eliminare
```

## Step 4: Test Manuale

```bash
# Sincronizzazione
sudo /usr/local/bin/mulinex_timesync.sh

# Bagclean
sudo /usr/local/bin/mulinex_bagclean.sh
```

## Step 5: Disattivazione Temporanea (Test)

```bash
# Disabilita servizio
sudo systemctl disable mulinex-timesync
sudo systemctl stop mulinex-timesync

# Disabilita bashrc
nano ~/.bashrc
# Commenta le sezioni mulinex

# Verifica
sudo systemctl status mulinex-timesync
# Dovrebbe dire "inactive (dead)"

# Riabilita
sudo systemctl enable mulinex-timesync
sudo systemctl start mulinex-timesync
```

## Log Files

```bash
# Sincronizzazione
tail -f /var/log/mulinex_timesync.log

# Bagclean
tail -f /var/log/mulinex_bagclean.log

# Systemd
journalctl -u mulinex-timesync -f
```

## Monitoraggio da PC

```bash
# Su PC, verifica che Rasp sia connessa come client
sudo chronyc clients

# Expected
192.168.2.50                  0     0     0     0
100.100.100.50                0     0     0     0
```

## Troubleshooting

Se Rasp non sincronizza:

```bash
# 1. Ping PC
ping 100.100.100.1
ping 192.168.2.1

# 2. Check log
tail -30 /var/log/mulinex_timesync.log

# 3. Verifica chrony on PC
ssh <pc>
sudo systemctl status chrony

# 4. Restart chrony on Rasp
sudo systemctl restart chrony
```

## Note

- I flag temporanei `/tmp/mulinex_*_done` vengono cancellati automaticamente a ogni nuovo login
- Lo script è completamente reversibile (niente modifiche permanenti)
- Puoi eseguire setup.sh più volte senza problemi

---

Questo è un esempio di setup completo con successo! 🎉
