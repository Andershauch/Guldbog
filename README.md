# Guldbog

Addon til WoW Forever. Viser, hvad alle dine karakterer har i tasker og bank, hvad det er værd, og om du skal bruge det selv eller sælge det.

CurseForge: https://www.curseforge.com/wow/addons/guldbog

## Projektstruktur

- `Guldbog/` – selve addon'et (det er denne mappe, der kopieres til AddOns)
- `tests/` – test af logikken mod en simuleret spilklient
- `dist/` – zip-filer til at dele (kun selve addon'et, ingen gemte data). Ikke i Git.
- `grafik/` – ikon og billeder til CurseForge
- `LICENSE` – MIT
- `CHANGELOG.md` – ændringer pr. version (engelsk, bruges på CurseForge og GitHub)
- `curseforge/` – første udkast til tekster til CurseForge-siden
- `grafik/curseforge/` – banner, galleri, skærmbilleder fra spillet og den beskrivelse, der bruges på CurseForge
- `tools/package.py` – bygger zip-filen i `dist/`
- `tools/release.py` og `.github/workflows/release.yml` – automatisk udgivelse, når versionen ændres
- `Hent seneste version.cmd` – dobbeltklik for at hente den nyeste kode fra GitHub
- `CLAUDE.md` – noter til Claude

## Installation

1. Installér **Auctionator** eller **TradeSkillMaster** (Forever-versionen). Guldbog henter AH-priser fra Auctionator og bruger TSM som reserve. Klik-for-at-sælge på AH kræver Auctionator.
2. Kopiér undermappen `Guldbog` til `World of Warcraft\_forever_\Interface\AddOns\`.
   Tjek at filen ligger her: `...\AddOns\Guldbog\Guldbog.toc`
3. Genstart spillet og slå Guldbog til i AddOns-listen på karaktervalget.

## Sådan bruger du den

1. Log ind på **hver** karakter én gang. Så husker Guldbog deres tasker og fag.
2. Gå til banken på hver karakter, så banken også kommer med.
   Åbn også hvert fag-vindue (fx Mining, Blacksmithing, Cooking, First Aid) én gang. Så ved Guldbog, hvilke opskrifter du kan, og hvilke der er grå.
3. Lav en fuld scanning i Auctionator ved auktionshuset.
4. Klik på mønt-knappen ved minimappet, eller skriv `/guldbog`, for at åbne vinduet. Knappen kan trækkes rundt langs kanten, og `/guldbog ikon` skjuler eller viser den. Hold musen over en vare for at se, hvem der har den.
5. **Klik** på en "Sælg på AH"-linje, mens auktionshuset er åbent. Så åbner varen i Auctionators sælg-fane (eller spillets egen, hvis Auctionator mangler), og du trykker selv på Post. Varen skal ligge i tasken på den karakter, du spiller.
6. **Klik** på en "Sælg til vendor"-linje, mens du taler med en handler. Så sælges alle stakke fra tasken. Fortryd under handlerens Buyback (den husker kun de seneste 12).
7. **Klik på en kolonneoverskrift** for at sortere efter den. Klik igen for at vende. Klik på Forslag/Hvem for standardrækkefølgen.
8. **Alt+klik** på en vare for at beholde den (fx pile, potions, mad). Alt+klik igen for at fjerne det.

## Grupper

Listerne er delt i grupper, som foldes ud og sammen med et klik på overskriften. Guldbog husker, hvad du har foldet ud. Set i spillet 2026-11-14.

- **Lager:** Lær selv / Brug selv, Sælg på AH, Sælg til vendor, Behold / Værktøj, Behold / Dit valg, Til salg på AH, Ingen gevinst / Ingen pris. Sælg på AH og Sælg til vendor er foldet ud fra start. Beløbet ved overskriften er, hvad gruppen kan sælges for.
- **Crafting:** én gruppe pr. karakter. Den, du spiller, er foldet ud.
- **Venner:** én gruppe pr. ven, online først.
- Sortering ved klik på kolonnerne gælder inden for hver gruppe.

## Indstillinger

Knappen **Indstillinger** øverst i vinduet. Klik på en knap for at skifte værdi: sprog, minimum-depositum, auktionsvarighed, AH-gebyr (5 % faktion, 15 % neutral), om depositum regnes som tabt, og om minimap-knappen vises. Gælder for alle karakterer.

## Kolonnerne

- **Statuslinjen** nederst viser, hvornår Guldbog sidst så banken og postkassen på hver karakter, og hvor gamle AH-priserne er. Tip: Slå "Run autoscan when Auction House is opened" til i Auctionators indstillinger, så scannes priserne automatisk.

- **Antal** – i alt på alle karakterer, inkl. post. Varer du har sat på AH, tælles ikke med. I tooltippen står de som "(post)" og "(på AH)".
- Ligger alle dine af en vare på AH, står den nederst som **Til salg på AH**.
- **Her** – på den karakter, du spiller. Varer du ikke har her, er nedtonede.
- **Gevinst** – hvad du får mere på AH end hos vendor, efter 5 % gebyr og depositum. Depositum trækkes altid fra, også selvom du får det tilbage ved salg. Hold musen over linjen for at se depositum.
- Depositum hentes fra spillet, når du åbner AH. Indtil da regnes med 1 sølv (står som "anslået").

## Crafting (profit-listen)

Tryk **Crafting** nederst i vinduet. Du ser hver opskrift, dine karakterer kan, og som laver en vare:

- **Kan lave** – hvor mange gange, med materialer fra alle karakterer.
- **Materialer** – billigste af AH-pris og vendor-pris. Vendor-priser kender Auctionator, når du har besøgt en handler, der sælger varen.
- **Salg** – AH-pris efter 5 % og depositum, eller vendor-pris hvis den er bedre. Hold musen over linjen for at se materialerne og hvor du sælger.
- **Gevinst** – salg minus materialer. Tid er ikke regnet med.
- **Hvem · skill** – hvem kan lave den, og farven i fag-vinduet. En orange opskrift med lille tab kan være værd at lave for skillens skyld.

Opskrifter på ting, der hverken kan sælges på AH eller til vendor (fx lejr-ting), vises ikke. Smeltning er med, så listen viser også, om det kan betale sig at smelte malm.

Opskrifter læses, når du åbner fag-vinduet. Åbn det igen, når du har lært nye.

## Venner

Tryk **Venner** nederst. Du ser udstyr fra dine karakterer, som nogen på din venneliste kan bruge: rigtig rustningstype eller våben for klassen, og level til det. Online venner står øverst.

- Står du ved en postkasse, gør et **klik** brevet klar: Send-fanen åbnes, vennen udfyldes, og varen vedhæftes. Du trykker selv **Send**.
- Varen skal ligge i tasken på den karakter, du spiller.
- "Kan bruge" betyder kun, at de kan bære det. Ikke at det er bedre end det, de har. En warrior får også tilbudt cloth.
- Battle.net-venner kommer med, men kun når de er logget ind på en karakter i Forever på din faktion.
- Reglerne for klasser ligger i `Data.lua` og bygger på Classic. Forever kan afvige.

## Hvad forslagene betyder

- **Lær selv** – en opskrift, som en af dine karakterer har faget til og ikke kan i forvejen.
- **Brug selv** – en af dine karakterer har en opskrift, der bruger varen og stadig giver skill (ikke grå). Har du ikke åbnet fag-vinduet endnu, bruges en fast liste i stedet.
- **Sælg på AH** – du tjener mere på AH end hos vendor, efter 5 % gebyr og depositum (se kolonnen Gevinst).
- **Ingen gevinst** – AH giver mindre end depositum koster, og vendor vil ikke købe den.
- **Sælg til vendor** – der er ingen AH-pris, eller vendor giver mest.
- **Ingen pris** – scan AH i Auctionator og tryk Opdatér.
- **Behold** – værktøj til dine fag, eller noget du selv har valgt at beholde. Står nederst og tælles ikke med i salgsbeløbet.

Bundne ting (soulbound) vises ikke.

## Status og kendte begrænsninger (v0.17.0)

- Testet i spillet på Kriger og Trylle: bank, fag-vinduer, Alt+klik, værktøj, klik-for-at-sælge, gevinst/depositum, crafting-listen, minimap-knap og post til egne karakterer. Egne auktioner er ikke bekræftet i spillet endnu. Præstens bank er ikke prøvet endnu.
- Den faste materialeliste (`Data.lua`) bruger Classic-varenumre. Den bruges kun, indtil du har åbnet fag-vinduet.
- "Lær selv" tjekker ikke, om dit fagniveau er højt nok til opskriften.
- Depositum anslås ud fra den valgte varighed og minimum-depositum (se Indstillinger). Skifter du varighed, opdateres depositum først, når du åbner AH igen.
- Udstyr med tilfældig endelse ("of Arcane Protection") vises med det rigtige navn og pris. Har du to varianter af samme ting, slås de sammen til én linje med den senest sete variant.
- Post læses, når du åbner postkassen. Post til dine egne karakterer noteres, når du sender den. Egne auktioner læses, når du åbner AH.

## Beslutninger

- 2026-11-20: Ikon og stil er "Møntseglet": en guldmønt med en åben bog præget i midten. Rund, så den passer i minimap-knappen. Kildefiler og PNG i `grafik/`, spillets version i `Guldbog/Media/Guldbog.tga` (64×64).
- 2026-11-20: Udgivelser på CurseForge er **Release**, ikke Beta, fordi mange kun henter Release-versioner, og 0.17.0 allerede er Release. `.gitattributes` holder linjeskift ens på Windows og Linux.
- 2026-11-20: Udgivelsen starter, når versionen i toc-filen ændres på `main`, ikke ved tags, så Claude kan stå for det hele (Claudes GitHub-forbindelse må ikke sende tags).
- 2026-11-20: Automatisk udgivelse med eget GitHub-workflow og `tools/release.py` i stedet for BigWigs' packager, fordi addon'et ligger i en undermappe. Samme zip som ved manuel pakning. Uploader via CurseForges upload-API.
- 2026-11-20: Repoet er offentligt, så CurseForge kan linke til kildekoden. Automatisk pakning på CurseForge er slået fra; zip uploades manuelt, indtil en `.pkgmeta` er på plads.
- 2026-11-20: Zip-filen bygges med `tools/package.py`, som tager alt i `Guldbog/` med, så nye filer som ikonet ikke bliver glemt. Første CurseForge-udgivelse markeres som Beta.
- 2026-11-20: Git og GitHub-repo til versionsstyring (først privat, samme dag gjort offentligt, se ovenfor). MIT-licens. Zip-filer i `dist/` er ikke i Git; de hører til udgivelserne.
- 2026-11-19: Guldbog gemmer navnet på funktioner, spillet blokerer (`GuldbogDB.blocked` i SavedVariables), efter en "blocked from an action"-boks, der ikke kunne genskabes.
- 2026-11-14: Listerne er delt i grupper, der kan foldes ud, fordi én lang liste var uoverskuelig. Lager efter forslag, Crafting efter karakter, Venner efter ven.
- 2026-11-13: Klik-for-at-sælge tjekker Auctionators interne dele, før de bruges, og bruger ellers spillets egen sælg-fane. Så går en Auctionator-opdatering ikke i stykker for brugeren.
- 2026-11-13: Faste antagelser er blevet til indstillinger med de gamle værdier som standard. Knapper man klikker igennem i stedet for tekstfelter (enklest, ingen tastefejl).
- 2026-11-13: Engelsk er standard, dansk vælges med `/guldbog sprog da`. WoW findes ikke på dansk, så sproget er en indstilling. Eksisterende brugere beholder dansk. Al tekst ligger i `Locale.lua`.
- 2026-11-10: Forever har efternavne og shards (EU4, EU5 ...) i stedet for servere. Post til venner bruger det fulde navn uden shard.
- 2026-11-09: v0.1 er "lager og beslutning" frem for profit-liste, fordi karaktererne er lavt level.
- 2026-11-09: Priser hentes fra Auctionator i stedet for egen AH-scanning. Mindre kode, og TSM er ikke ude til Forever endnu.
- 2026-11-09: Addon'et køber og sælger aldrig selv. Det holder sig inden for Blizzards regler.
- 2026-11-09: Projektet ligger i D:\Projects\Guldbog med addon'et i undermappen `Guldbog/`.
- 2026-11-09: Egen pengeformatering, fordi Forever ikke har `GetCoinTextureString`.
- 2026-11-09: "Brug selv" bygger på opskrifterne i fag-vinduet (grå opskrifter tæller ikke), med den faste liste som reserve. Malm hører under Mining, fordi det er smeltningen, der bruger den.
- 2026-11-09: Klik for at sælge sender varen til Auctionators sælg-fane i stedet for at Guldbog selv opretter auktioner. Auctionator søger den aktuelle pris, og du trykker selv Post. Auctionator har ingen offentlig funktion til det, så Guldbog efterligner Auctionators egen tasker-klik-rutine. Kan gå i stykker ved Auctionator-opdateringer; så vises en besked.
- 2026-11-09: "Sælg på AH" kræver positiv gevinst efter 5 % og depositum. Depositum trækkes fra som tabt (forsigtigt regnet). Minimum 1s, fordi spillere har set det i Forever. Depositum anslås ud fra mellemste varighed.
- 2026-11-09: Kolonnen "Her" og nedtoning viser, hvad den aktuelle karakter har.
- 2026-11-09: Profit-listen bruger billigste af AH og vendor som materialepris, også for materialer du selv har samlet (det, du kunne have solgt dem for). Enchants uden vare er ikke med.
- 2026-11-09: Egen minimap-knap uden ekstra biblioteker (simpelt først). LibDBIcon kan komme senere, hvis knappen skal samles med andre addons' knapper.
- 2026-11-09: Venner-fanen viser kun, hvad vennen kan bære (klasse og level), fordi spillet ikke viser andres fag eller udstyr. Brevet gøres klar, men sendes aldrig automatisk.
- 2026-11-09: Sekundære fag (Cooking, First Aid, Fishing) tæller med. Et fag registreres også, når dets vindue åbnes, fordi spillet ikke altid oplyser First Aid.
- 2026-11-09: Priser fra Auctionator først, TSM (DBMinBuyout, ellers DBMarket; VendorBuy) som reserve. Mål: Guldbog skal kunne deles uden at alle har samme addons.
- 2026-11-09: Klik sælger til vendor kun for "Sælg til vendor"-linjer, så brug-selv-materialer ikke sælges ved et uheld.
- 2026-11-09: Bank og post kan ikke læses uden at vinduet er åbent (spillets regel). I stedet viser en statuslinje, hvor gamle dataene er.
- 2026-11-09: Udstyr huskes med fuldt link, så navn og AH-pris passer til netop den variant.
- 2026-11-09: Post til egne karakterer noteres, når du trykker Send, og tælles først hos modtageren, når spillet bekræfter afsendelsen (at koble sig på spillets send-funktion virkede ikke i Forever).
- 2026-11-09: Post tæller som tilgængelig (også i "Kan lave"). Egne auktioner vises, men tæller ikke med, fordi varen ikke er til rådighed.
- 2026-11-09: Værktøj beholdes altid, og Alt+klik markerer andre varer som "behold" på tværs af karakterer.

## Plan: deling med guilden

Trin, hvis Guldbog skal deles. Kun trin 1 er lavet.

1. ✅ Flere priskilder: Auctionator, ellers TSM.
2. ✅ Klik-for-at-sælge på AH bruger spillets egen sælg-fane, når Auctionator mangler eller har ændret sig (skal testes i spillet).
3. Egen AH-scanning som reserve, så Guldbog virker uden andre addons (stor opgave, ca. 300–500 linjer, skøn).
4. ✅ Engelsk tekst og sprogvalg (se `Tekster.md` og `Guldbog/Locale.lua`).

### Tjekliste før CurseForge

- [x] Engelsk tekst, med dansk som valg (`/guldbog sprog da`).
- [x] Indstillinger i stedet for faste antagelser: minimum-depositum, varighed, AH-gebyr, depositum som tabt, minimap-knap og sprog.
- [x] Klik-for-at-sælge på AH: tjekker Auctionators dele først og falder tilbage til spillets egen sælg-fane. Virker også uden Auctionator. Reserven er ikke testet i spillet endnu.
- [ ] Tjek klasse-reglerne i `Data.lua` mod Forever.
- [ ] Test på andre opsætninger: uden EllesmereUI, kun med TSM, ren installation, Mac.
- [x] Ikon i addon-listen (`## IconTexture`) og på minimap-knappen. Ikke set i spillet endnu.
- [ ] Skærmbilleder og beskrivelse på engelsk.
- [ ] Tjek at navnet er ledigt på CurseForge.
- [x] Licens: MIT (`LICENSE`).
- [x] CurseForge-projekt oprettet og koblet til GitHub-repoet (uden automatisk pakning).
- [x] 0.17.0 uploadet manuelt og godkendt på CurseForge 2026-11-20 (Release, Forever 1.60.1). Tekster i `curseforge/description.md`.
- [x] Automatisk udgivelse via GitHub Actions, når versionen ændres. `CF_API_KEY` og `CF_PROJECT_ID` er lagt ind (kan ikke ses udefra).
- [x] GitHub-delen af kæden er prøvet 2026-11-20: manuel kørsel lavede `v0.17.0` med zip.
- [ ] CurseForge-uploaden fra kæden prøves ved næste version.
- [x] Kode i Git, offentligt repo på GitHub (Andershauch/Guldbog).
- [ ] Senere: automatisk pakning og upload til CurseForge ved ny version.

Husk: Blizzards regler kræver, at addons er gratis, har synlig kode, ikke reklamerer og ikke beder om donationer i spillet.

## Ny version

Claude står for alt på GitHub:

1. Claude retter versionen i `Guldbog/Guldbog.toc`, skriver ændringerne i `CHANGELOG.md` og pusher til `main`.
2. GitHub opdager den nye version (`.github/workflows/release.yml`): kører testen, bygger zip med `tools/package.py`, laver udgivelsen og tagget på GitHub og uploader til CurseForge som Release til Forever 1.60.1.
3. En version, der allerede er udgivet, springes over, så intet udgives to gange.

Anders: dobbeltklik på **`Hent seneste version.cmd`** i projektmappen for at få den nyeste kode ned på computeren, og skriv `/reload` i spillet.

En manuel kørsel (*Actions → Release → Run workflow*) laver kun GitHub-udgivelsen, med mindre "Also upload to CurseForge" sættes til. Så kan en version, der allerede ligger på CurseForge, ikke uploades to gange.

Engangsopsætning på GitHub (gjort 2026-11-20): secret `CF_API_KEY` og variable `CF_PROJECT_ID` = 1818445.

## Idébank

- Venner med Guldbog kan udveksle fag og ønsker i baggrunden ("jeg mangler Wool Cloth"), så materialer og opskrifter også kan foreslås. Testes med en ven.
- Venner: vis kun den bedste rustningstype for klassen (ikke cloth til en warrior).

- "Disenchant eller sælg?" for grønne ting.
