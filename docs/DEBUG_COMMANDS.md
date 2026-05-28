# 🔍 Debug & Monitoring Commands - Quick Reference

## **Su RASP - Verificare Sincronizzazione**

### **Status generale:**
```bash
# Vedi se chronyd è running
sudo systemctl status chrony

# Vedi stato NTP (se sincronizzato)
chronyc status
# Output: Reference ID: IP (se sincronizzato)
#         Stratum: 2 (se client di server locale)

# Dettagli completi di tracking
chronyc tracking
# Mostra: Freq offset, RMS offset, Residual freq, Skew, Root delay, ecc.
```

### **Sorgenti NTP:**
```bash
# Vedi tutte le sorgenti configurate
chronyc sources
# Output: Remote, Ref clock, St, t, K, tlG, Tbox, G
#         ^* = preferred source (sta fornendo il tempo)
#         ^+ = good source (potrebbe diventare preferred)
#         ^- = outlier (non usato)

# Versione verbose (più dettagli)
chronyc sources -v
```

### **Log dello script:**
```bash
# Ultimi 50 righe
tail -50 /var/log/mulinex_timesync.log

# Monitoraggio in tempo reale
tail -f /var/log/mulinex_timesync.log

# Cerca errori
grep "✗\|ERROR" /var/log/mulinex_timesync.log

# Conta esecuzioni riuscite
grep "✓ Sync riuscito" /var/log/mulinex_timesync.log | wc -l
```

### **Systemd logging:**
```bash
# Ultimi 20 eventi del servizio
journalctl -u mulinex-timesync -n 20

# In tempo reale
journalctl -u mulinex-timesync -f

# Ultimi 2 ore
journalctl -u mulinex-timesync --since "2 hours ago"

# Con timestamp
journalctl -u mulinex-timesync --no-pager -o short-iso
```

### **Verifica connettività:**
```bash
# Internet disponibile?
ping -c 1 pool.ntp.org

# PC raggiungibile via ethernet?
ping -c 5 100.100.100.1   # Cambia con IP reale PC

# PC raggiungibile via WiFi?
ping -c 5 192.168.2.1     # Gateway AP

# Quale interfaccia ha IP?
ip addr show eth0
ip addr show wlan0
```

### **Forcza sincronizzazione immediata:**
```bash
# Step immediato (se scarto > 1 sec)
sudo chronyc makestep

# Recarica configurazione sorgenti
sudo chronyc reload sources

# Riavvia chronyd completamente
sudo systemctl restart chrony
```

---

## **Su PC UBUNTU - Verificare Server NTP**

### **Status server:**
```bash
# È in running?
sudo systemctl status chrony

# Stato generale
sudo chronyc status

# Tracking
sudo chronyc tracking
```

### **Client connessi:**
```bash
# Tutti i client che si sono connessi
sudo chronyc clients

# Dettagliato
sudo chronyc clients -v

# Output example:
# Hostname             NTP Drop N Drop Interval Idle    Samples Runs Score Recent
# 100.100.100.50      0   0      0      0         4      5      2   0      0
# 192.168.2.100       0   0      0      0         1      3      1   0      0
```

### **Sorgenti internet:**
```bash
# Da dove prende il tempo il PC
sudo chronyc sources

# Verbose
sudo chronyc sources -v
```

### **Log sync:**
```bash
# Se è abilitato il logging (in chrony.conf)
tail -f /var/log/chrony/measurements.log

# O da journalctl
journalctl -u chrony -f
```

---

## **Ciclo Completo di Debug**

### **1. Rasp non sincronizza - Debugging:**

```bash
# Step 1: È running chronyd?
sudo systemctl status chrony
# → Se NO: sudo systemctl start chrony

# Step 2: Ha sorgenti configurate?
chronyc sources
# → Se empty: /etc/chrony/sources.d/ non ha file

# Step 3: Riesce a contattare il server?
ping 100.100.100.1  # (cambio con IP reale PC)
# → Se NO: problema rete, verifica eth0 / wlan0

# Step 4: PC accetta connessioni?
# Su PC:
sudo chronyc clients
# Vedi Rasp come client? → Se NO: check firewall PC

# Step 5: Forza sync manuale
sudo chronyc makestep

# Step 6: Verifica risultato
chronyc tracking
# → Se funziona: problema era nel timing automatico
# → Se fallisce ancora: problema config ou network
```

### **2. Orologio salta/oscilla:**

```bash
# Vedi parametri attuali
chronyc tracking

# Se "RMS offset" è alto (> 10ms), aumenta makestep threshold:
# In /etc/chrony/chrony.conf:
# makestep 0.1 3   (step anche per < 100ms, non solo 1 sec)

sudo systemctl restart chrony

# Dopo 1 minuto, ri-verifica
chronyc tracking
```

### **3. Drift del clock hardware (RTC):**

```bash
# Vedi drift file (quanto il clock è "storto")
cat /var/lib/chrony/chrony.drift
# Output: ad es. "37.5" = clock è 37.5ppm faster

# Sincronizza RTC adesso
sudo chronyc makestep

# Verifica sia stato aggiornato
hwclock --show
date
# Dovrebbero essere uguali
```

---

## **Pattern Log Importanti**

### **Sync riuscito:**
```
[2026-05-26 10:15:30] ✓ Sync riuscito da PC-ethernet (100.100.100.1) — ora: May 26 10:15:30 UTC 2026
```

### **Non trovato PC:**
```
[2026-05-26 10:15:15] Nessun host trovato su ethernet
[2026-05-26 10:15:20] wlan0 è in modalità client, skip scansione AP
[2026-05-26 10:15:21] ⚠ Nessuna fonte di tempo disponibile
```

### **Internet OK:**
```
[2026-05-26 10:15:05] Internet disponibile, uso NTP pubblici
[2026-05-26 10:15:35] ✓ Sync da internet riuscito — ora: May 26 10:15:35 UTC 2026
```

---

## **Performance Metrics**

### **Cosa è "buono":**
```
✅ Stratum: 2 (sincronizzato da server locale)
✅ Freq offset: < 1 ppm (clock stabile)
✅ RMS offset: < 1 ms (errore < 1 millisecondo)
✅ Residual freq: < 0.1 ppm (non drift)
✅ Skew: < 1 ms (incertezza bassa)
```

### **Cosa è "cattivo":**
```
❌ Stratum: 16 (non sincronizzato!)
❌ Freq offset: > 100 ppm (clock pazzo)
❌ RMS offset: > 100 ms (errore enorme)
❌ Root delay: > 1 second (latenza troppo alta)
```

---

## **Rapid Checks (30 secondi)**

```bash
# Tutto OK?
chronyc tracking | grep -E "Leap status|Stratum|RMS offset"

# Output ideal:
# Leap status : Normal
# Stratum     : 2
# RMS offset  : 0.000001 seconds
```

---

## **When Things Go Wrong**

### **Restart completo:**
```bash
# Option 1: Just chrony
sudo systemctl restart chrony

# Option 2: Everything
sudo systemctl restart chronyd
sudo chronyc makestep
```

### **Reset tutto (nuclear):**
```bash
# Reset drift file
sudo rm /var/lib/chrony/chrony.drift

# Reset log
sudo rm /var/log/mulinex_timesync.log

# Riavvia
sudo systemctl restart chrony
sudo chronyc makestep
```

### **Forza esecuzione script:**
```bash
# Manuale (vedrà prompt)
/usr/local/bin/mulinex_timesync.sh

# Via systemd
sudo systemctl start mulinex-timesync

# Con output live
sudo systemctl start mulinex-timesync && journalctl -u mulinex-timesync -f
```

---

**Buon debugging! 🔧**
