WinOpt è un tool di ottimizzazione per Windows 11 scritto in PowerShell puro, pensato per essere eseguito subito dopo un fresh install con una sola riga di codice. Niente installer, niente dipendenze, niente cartelle sparse — un unico file .ps1 che apre una GUI completa direttamente da PowerShell.

La GUI permette di selezionare e applicare tweaks divisi per categoria (Privacy, Performance, Debloat, Rete, UI, Avanzato), ognuno con indicatore di rischio (safe / caution / danger), descrizione inline e log colorato in real-time. I tweaks DANGER richiedono conferma esplicita. Tutto è reversibile tramite il Restore Point integrato.

Il progetto nasce dall'idea di avere qualcosa di simile a WinUtil ma personale, versionato su GitHub e modificabile direttamente nel JSON embedded — senza GUI esterne, senza fidarsi di script opachi.
asi)

- I tweaks DANGER richiedono conferma esplicita prima di eseguire
- Restore Point creabile con un click prima di qualsiasi tweak
- Log colorato in real-time per ogni operazione
- Nessun file esterno richiesto — tutto in un `.ps1`
