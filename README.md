**WinOpt** è un tool di ottimizzazione per Windows 11 scritto in PowerShell puro, pensato per essere eseguito subito dopo un fresh install con una sola riga di codice. Niente installer, niente dipendenze, niente cartelle sparse — un unico file `.ps1` che apre una GUI completa direttamente da PowerShell.

La GUI permette di selezionare e applicare tweaks divisi per categoria (Privacy, Performance, Debloat, Rete, UI, Avanzato), ognuno con indicatore di rischio (safe / caution / danger), descrizione inline e log colorato in real-time. I tweaks DANGER richiedono conferma esplicita. Tutto è reversibile tramite il Restore Point integrato.

Il progetto nasce dall'idea di avere qualcosa di simile a WinUtil ma personale, versionato su GitHub e modificabile direttamente nel JSON embedded — senza GUI esterne, senza fidarsi di script opachi.

---

## One-liner

Apri **Terminal come Admin** (tasto destro sul menu Start) e incolla:

```powershell
irm https://raw.githubusercontent.com/IOSSvl/winopt/main/winopt.ps1 | iex
```

Lo script rileva automaticamente se non è Admin e richiede elevazione UAC. Funziona sia da file locale che via `irm | iex`.

---

## Uso locale

```powershell
powershell -ExecutionPolicy Bypass -File winopt.ps1
```

Oppure doppio click su `run-as-admin.bat`.

---

## Tweaks inclusi

| Categoria | Tweaks |
|-----------|--------|
| Privacy | Telemetria, DiagTrack, Error Reporting, Location Tracking, Activity History |
| Performance | SysMain, Windows Search, Ultimate Power Plan, Fast Startup, TRIM, HAGS, Core Parking, Prefetch |
| Debloat | Xbox Services, Widgets, Copilot, OneDrive |
| Rete | DNS Cloudflare, Flush DNS, TCP Tuning |
| UI | Classic Right-Click, Visual Effects performance |
| Avanzato | Spectre/Meltdown mitigations ⚠️ |

---

## Aggiungere tweaks

Il JSON è embedded nello script, sezione `$tweaksJson`. Ogni tweak ha questa struttura:

```json
{
  "id":          "id_univoco",
  "label":       "Nome nella GUI",
  "category":    "Performance",
  "risk":        "safe",
  "description": "Cosa fa in una riga.",
  "script":      "comando-powershell"
}
```

**risk**: `safe` · `caution` · `danger`  
**category**: `Privacy` · `Performance` · `Debloat` · `Rete` · `UI` · `Avanzato`

Dopo la modifica, pusha con:

```bash
git add winopt.ps1
git commit -m "add tweak: nome"
git push
```

La one-liner aggiornerà automaticamente al prossimo utilizzo.

---

## Indicatori di rischio

- 🟢 **SAFE** — modifiche reversibili, consigliate per tutti
- 🟡 **CAUTION** — modifiche più profonde, leggere la descrizione prima
- 🔴 **DANGER** — richiedono conferma esplicita, solo per hardware dedicato

---

## Requisiti

- Windows 11
- PowerShell 5.1+
- Privilegi Administrator (gestiti automaticamente)
