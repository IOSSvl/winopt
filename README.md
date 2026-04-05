# WinOpt — Windows Optimization Tool

GUI PowerShell per ottimizzare Windows 11 dopo un fresh install.  
Un solo file, zero dipendenze, zero installazione.

---

## One-liner (da qualsiasi PC)

Apri **Terminal come Admin** (tasto destro sul menu Start) e incolla:

```powershell
irm https://raw.githubusercontent.com/TUONOME/winopt/main/winopt.ps1 | iex
```

> Sostituisci `TUONOME` con il tuo username GitHub e `winopt` con il nome del repo.

Lo script rileva automaticamente se non è Admin e richiede elevazione UAC.

---

## Uso locale

Scarica `winopt.ps1` e:

```powershell
powershell -ExecutionPolicy Bypass -File winopt.ps1
```

Oppure doppio click su `run-as-admin.bat`.

---

## Come pubblicare su GitHub

```bash
# 1. Crea il repo su github.com (nome suggerito: winopt)

# 2. Da terminale nella cartella del progetto:
git init
git add winopt.ps1 run-as-admin.bat README.md
git commit -m "initial commit"
git remote add origin https://github.com/TUONOME/winopt.git
git push -u origin main
```

La one-liner funziona subito dopo il push.

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

---

## Note tecniche

- Funziona sia da file che via `irm | iex` (gestione elevation separata per i due casi)
- I tweaks DANGER richiedono conferma esplicita prima di eseguire
- Restore Point creabile con un click prima di qualsiasi tweak
- Log colorato in real-time per ogni operazione
- Nessun file esterno richiesto — tutto in un `.ps1`
