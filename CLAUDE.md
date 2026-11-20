# Guldbog – noter til Claude

WoW Forever-addon (Interface 16001, Mainline-API) til Anders' Alliance-karakterer.
Kilde til sandhed: README.md (status, beslutninger, idébank).

- Addon-koden ligger i `Guldbog/`. Mappen kopieres til `World of Warcraft\_forever_\Interface\AddOns\`.
- Kode og kommentarer på engelsk. Al UI-tekst ligger i `Guldbog/Locale.lua` på engelsk og dansk – tilføj altid begge. Dokumentation på dansk.
- Addon'et må aldrig købe, sælge eller handle automatisk.
- Test uden for spillet: `python3 tests/test_guldbog.py Guldbog` (kræver `pip install lupa`).
  Testen bruger en simuleret klient og erstatter ikke en test i spillet.
- Små skridt. Nye idéer i README'ens idébank, ikke i koden.

- Projektet er i Git (privat repo Andershauch/Guldbog). Commit-beskeder på engelsk. `dist/` er ikke i Git.
- Ny version: se "Ny version" i README. Zip bygges med `python3 tools/package.py`.
