# 🚀 Mulinex Time Sync System - Avvio Veloce

**Leggi questi file in questo ordine:**

## 📖 GUIDE (Scegli una)

### ⭐ **GUIDA_DEFINITIVA.md** ← LEGGI SEMPRE QUESTA PRIMA
Guida completa e definitiva. Contiene:
- Quick start (3 step)
- Come disattivare i 2 check
- Monitoraggio e troubleshooting
- Scenario di utilizzo

### 📋 **RIEPILOGO.md**
Riepilogo della struttura del progetto. Perfetto per capire:
- Cosa c'è in ogni file
- Come funziona tutto
- Quale guida leggere per cosa

### 🔧 **GUIDA_DEPLOY_AUTOMATICO.md**
Guida tecnica del deploy automatico. Leggi se:
- Vuoi capire il deploy nel dettaglio
- Vuoi sapere cosa viene modificato sulla Rasp

### 📚 **Altre guide**
- `GUIDA_IMPLEMENTAZIONE.md` — Installazione manuale (alternativa)
- `README.md` — Quick start molto veloce (50 righe)
- `FILE_SUMMARY.md` — Riepilogo di ogni file
- `DEBUG_COMMANDS.md` — Comandi debug

---

## ⚡ Quick Start (Velocissimo)

```bash
# Step 1: PC Ubuntu (una volta)
# Copia la config del server NTP
sudo cp config/chronyc_pc /etc/chrony/chrony.conf
sudo systemctl restart chrony

# Step 2: Deploy su Rasp (via network 100.100.100.X)
ssh mulsbc@100.100.100.X
cd Configuration-Raspberry-mulsbc
sudo bash setup.sh

# Step 3: Test
chronyc status
sudo reboot

# SSH nuovo dopo reboot
ssh mulsbc@100.100.100.X
# → Vedrai messaggi [Mulinex]
```

**Fatto!** ✅

---

## 📂 Cosa Troverai Qui

```
├── 📖 GUIDE
│   ├── GUIDA_DEFINITIVA.md          ← LEGGI QUESTA
│   ├── RIEPILOGO.md                 ← Poi questa
│   ├── GUIDA_DEPLOY_AUTOMATICO.md   ← Se serve approfondire
│   └── ... altre guide ...
│
├── 📄 SCRIPT ESEGUIBILI
│   ├── mulinex_deploy_all.sh        ← ⭐ Quello da usare
│   ├── mulinex_timesync.sh          ← Sincronizzazione
│   ├── mulinex_bagclean.sh          ← Pulizia bag
│   └── ... altri script ...
│
└── 🌐 CONFIGURAZIONI
    ├── chronyc pc                   ← Config PC
    ├── chronyc_rasp_CONFIG.conf     ← Config Rasp
    └── ... altre config ...
```

---

## 🎯 Cosa Fa il Sistema

1. **Al Boot della Rasp** → sincronizza orario automaticamente
2. **Al Login SSH** → esegue sincronizzazione + pulizia bag
3. **Entrambi senza password** → abilitato via sudoers
4. **Puoi disattivare tutto** → controllo totale

---

## ❓ In Caso di Dubbi

1. Leggi `GUIDA_DEFINITIVA.md` (sez. "Troubleshooting")
2. Esegui i comandi debug elencati
3. Controlla i log in `/var/log/mulinex_*.log`

---

**Pronto?** → Leggi `GUIDA_DEFINITIVA.md` e inizia! 🚀
