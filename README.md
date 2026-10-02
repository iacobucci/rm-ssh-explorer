# SSH Explorer per reMarkable 2

**SSH Explorer** è un'applicazione nativa per **reMarkable 2** basata sul framework **AppLoad** (estensione XOVI). Permette di navigare tramite SSH su file server remoti (Linux, macOS, NAS, Raspberry Pi, VPS) e importare direttamente file PDF nella libreria del tablet.

L'applicazione è progettata su misura per l'hardware del reMarkable 2 (schermo E-Ink Carta 1404×1872) e rispetta rigorosamente i requisiti del dispositivo stock e dell'ecosistema **Vellum**.

---

## 📋 Requisiti del Device

* **Dispositivo:** reMarkable 2 (OS 3.28.0.172 / Yocto Linux armv7).
* **Pacchetti Vellum installati:**
  * `appload` (`0.6.0-r0`)
  * `qt-command-executor` (`19.0.0-r4`)
  * `qt-resource-rebuilder` (`19.0.0-r4`)
  * `xovi` (`0.3.3-r2`) e `xovi-extensions`
* **SSH Device:** Dropbear (`dbclient` / `ssh` e `scp` integrati) con chiavi SSH configurate (es. `/home/root/.ssh/id_dropbear` o `/home/root/.ssh/id_rsa`).
* **Nessun pacchetto aggiuntivo richiesto:** non richiede Python né Node.js sul tablet.

---

## 🏗️ Architettura

```
┌────────────────────────────────────────────────────────┐
│             xochitl (reMarkable OS UI)                 │
│                          │                             │
│                  AppLoad Extension                     │
│                          │                             │
│    ┌─────────────────────▼───────────────────────┐     │
│    │               SSH Explorer                  │     │
│    │   (QML UI: ConnectionView, ExplorerView,    │     │
│    │    VirtualKeyboard, ImportModal)            │     │
│    └─────────────────────┬───────────────────────┘     │
│                          │ net.asivery.CommandExecutor │
│    ┌─────────────────────▼───────────────────────┐     │
│    │               ssh-helper.sh                 │     │
│    └─────────────┬───────────────────┬───────────┘     │
└──────────────────┼───────────────────┼─────────────────┘
                   │                   │
         [ Dropbear SSH / SCP ]        │ [ HTTP POST localhost ]
                   │                   ▼
                   │         reMarkable Library
                   │     (USB Web Interface / xochitl)
                   ▼
         [ Remote SSH Server ]
```

1. **Frontend QML (`ui/`):**
   * Realizzato per il toolkit grafico supportato da **AppLoad** (`QtQuick 2.5`, `QtQuick.Controls 2.5`).
   * Grafica ad alto contrasto bianco/nero (E-Ink friendly).
   * **Tastiera virtuale touch integrata** per digitare indirizzi IP, percorsi e credenziali senza dipendere da tastiere esterne.
   * **Controlli di paginazione E-Ink** (`Page Up` / `Page Down`) per evitare sfarfallii durante lo scroll.
   * Badge ad alta leggibilità (`[DIR]`, `[PDF]`, `[FILE]`).

2. **Backend Execution:**
   * Utilizza il modulo XOVI `net.asivery.CommandExecutor 1.0` per richiamare in modo trasparente e privo di overhead lo script `ssh-helper.sh`.
   * Nessun binario proprietario: tutto gira con i componenti standard di BusyBox/Dropbear e `sh`.

3. **Meccanismo di Import PDF:**
   * **Strategia Primaria (Zero-Restart):** invia il file PDF scaricato all'endpoint locale `http://127.0.0.1/upload` (utilizzato dall'interfaccia web USB di reMarkable). Il documento appare istantaneamente nella libreria "My Files" senza riavviare `xochitl`.
   * **Strategia Secondaria (Fallback Diretto):** genera un UUID casuale (`/proc/sys/kernel/random/uuid`) e scrive direttamente i file `.pdf`, `.metadata` (JSON) e `.content` (JSON) in `/home/root/.local/share/remarkable/xochitl/`.

---

## 📁 Struttura del Progetto

```
ssh-explorer/
├── manifest.json              # Descrittore AppLoad per il launcher
├── application.qrc            # Resource descriptor Qt
├── icon.png                   # Icona dell'app per il menu di AppLoad (200x200)
├── ssh-helper.sh              # Script helper POSIX per comandi SSH e importazione
├── build.sh                   # Script di compilazione e packaging
├── deploy.sh                  # Script per deploy rapido via SSH sul tablet
├── ui/
│   ├── main.qml               # Controller principale e barra di navigazione
│   ├── Style.qml              # Costanti grafiche E-Ink (colori, metriche, font)
│   ├── qmldir                 # Dichiarazione modulo QML
│   ├── ConnectionView.qml     # Gestione profili host, test connessione, form
│   ├── ExplorerView.qml       # Esploratore cartelle remote, filtri e paginazione
│   ├── VirtualKeyboard.qml    # Tastiera a schermo touch con caratteri speciali
│   └── ImportModal.qml        # Finestra di conferma, progresso e stato importazione
├── preview/                   # Ambiente di test su PC Linux (stesso motore Qt5)
│   ├── CommandExecutor.h
│   ├── main.cpp
│   └── preview.pro
└── dist/                      # Pacchetto pronto per reMarkable
    └── ssh-explorer/
        ├── manifest.json
        ├── icon.png
        ├── resources.rcc      # Binary resource QML compilato
        └── ssh-helper.sh
```

---

## 🚀 Guida Rapida: Compilazione e Installazione

### 1. Compilare il pacchetto

Sul tuo PC (con `rcc` installato):
```bash
./build.sh
```
Questo genererà la cartella `dist/ssh-explorer/` e il tarball `dist/ssh-explorer.tar.gz`.

### 2. Installare sul tablet reMarkable 2

Se il tablet è collegato via cavo USB (IP di default `10.11.99.1`):
```bash
./deploy.sh
```
Oppure specificando l'IP Wi-Fi del tablet:
```bash
./deploy.sh 192.168.1.150
```

*In alternativa (installazione manuale):*
Copia il contenuto di `dist/ssh-explorer/` nella cartella delle app di AppLoad:
```bash
scp -r dist/ssh-explorer root@10.11.99.1:/home/root/xovi/exthome/appload/
ssh root@10.11.99.1 "chmod +x /home/root/xovi/exthome/appload/ssh-explorer/ssh-helper.sh"
```

### 3. Avvio sul tablet
1. Apri il menu **AppLoad** sul reMarkable.
2. Tocca l'icona **SSH Explorer** (se non compare subito, premi *Reload* nel menu di AppLoad).
3. Tocca brevemente per aprirlo a schermo intero, oppure tieni premuto per aprirlo in modalità finestra.

---

## 💻 Test e Anteprima su PC

È disponibile un runner di anteprima che permette di verificare l'interfaccia direttamente su PC Linux con la risoluzione del tablet:
```bash
cd preview
qmake && make
./preview-app
```

---

## ⚙️ Funzionalità MVP

* **Gestione Profili di Connessione:**
  * Salvataggio e caricamento profili in `~/.config/ssh-explorer/config.json`.
  * Supporto per porta SSH personalizzata, chiave d'identità e cartella iniziale.
* **Test Connessione:**
  * Verifica istantanea della raggiungibilità del server con feedback chiaro.
* **Browser Remoto:**
  * Navigazione gerarchica delle cartelle (`..` / entra in directory).
  * Filtro rapido: *Tutti i file* oppure *Solo file PDF*.
  * Dimensioni file formattate in modo leggibile (B, KB, MB, GB).
  * Pulsanti di paginazione E-Ink per navigare agevolmente file list numerose.
* **Importazione PDF:**
  * Modalità anteprima con nome file, percorso e dimensione.
  * Possibilità di rinominare il documento prima dell'importazione.
  * Integrazione immediata nella libreria del reMarkable.
