# Guldbog

_First audited 2026-11-20 (then not under version control; since put under git - see the re-audit note below)._

> **Re-audit 2026-11-20 at commit `5b2fbe8`** (8 commits after the first audit earlier the same day). The project is now under git, public on GitHub (`Andershauch/guldbog`, confirmed via the GitHub API) and released as 0.17.0 beta. Completion ~85% (estimate). Verified: addon code is unchanged since 0.16.1 apart from the new icon (`Guldbog.lua` lines 1592-1599, `Guldbog.toc` `IconTexture`); `tests/test_guldbog.py` exits 0. **Found:** the release workflow (`.github/workflows/release.yml`) has had 0 runs, and GitHub has only the `v0.16.1` release/tag - 0.17.0 was uploaded to CurseForge by hand (README line 164; not verified by me). The working tree has ~2,200 lines of CRLF-only noise in five files, a really changed `grafik/curseforge/banner.png`, and untracked screenshots/gallery. Not tested: anything in the game, the CurseForge page, the workflow's upload step. The sections below are the first audit and are superseded where they say "not under git" / "Critical: put under git"; see `assessments.json` for the current task list.

## Summary
A World of Warcraft addon for **WoW Forever** (Interface 16001, version 0.16.1 per `Guldbog.toc`) that shows what all of Anders' Alliance characters hold in bags, bank and mail, what it is worth, and whether to use it, sell it on the Auction House or sell it to a vendor. Prices come from Auctionator (TSM as fallback). A Crafting tab lists recipes by profit; a Friends tab prepares a mail with gear a friend's class can wear. The addon never buys or sells by itself - every sale or mail needs the user's own click (rule in `CLAUDE.md`). English is the default language, Danish is a setting.

## Current Status
Used privately, actively developed 9-19 Nov (9 zip releases in `dist/`, 0.12.0 -> 0.16.1). Tested in the game on a Warrior and a Mage: bank, profession windows, Alt+click, tools, click-to-sell, profit/deposit, crafting list, minimap button, mail between own characters (README "Status"). Not yet confirmed in the game: own auctions, the Priest's bank, and the fallback sell tab without Auctionator.

## Completion Estimate
~78% (estimate). Feature-complete for private use; the CurseForge checklist in `README.md` is more than half open (class rules vs Forever, other setups, icon/screenshots, name check, licence, project page).

## Last Significant Changes
- **0.16.1 (19 Nov):** the addon listens for `ADDON_ACTION_FORBIDDEN` / `ADDON_ACTION_BLOCKED` and stores the blocked function name, mode, open frames and a stack trace in `GuldbogDB.blocked` (max 10; `Guldbog.lua` lines 1496-1506), after a "blocked from an action" box that could not be reproduced. This is diagnostics, not a fix - the cause is unknown.
- 0.16.0 (14 Nov): collapsible groups (Inventory by suggestion, Crafting by character, Friends by friend); settings screen (language, minimum deposit, auction duration, AH fee, deposit as lost, minimap button).
- 0.13-0.15 (13 Nov): English/Danish text, click-to-sell checks Auctionator internals before use and falls back to the game's own sell tab.

## Current Architecture
Plain Lua, no libraries: `Guldbog.toc` (SavedVariables `GuldbogDB`, OptionalDeps Auctionator/TradeSkillMaster), `Locale.lua` (131 lines, all UI text in en + da), `Data.lua` (140 lines, Classic item IDs and class/armour rules), `Guldbog.lua` (1660 lines). Tests: `tests/test_guldbog.py` (638 lines) runs the Lua 5.1 code against a simulated game client via `lupa`. Packaging is manual (`dist/*.zip`).

## Verified in this audit
- `dist/Guldbog-0.16.1.zip` is byte-identical to the working folder's `Guldbog.lua`, `Locale.lua`, `Data.lua` and `Guldbog.toc` - no unpackaged changes.
- `python3 tests/test_guldbog.py Guldbog` exits 0 (after `pip install lupa` in the local VM, not in the project folder). The simulation does not replace a test in the game.
- The two places that call protected functions (`UseContainerItem`, line 438, "Sell to vendor"; `PickupContainerItem`, line 744, friend mail) are user-click handlers. I did not read the whole file for the "never act automatically" rule.
- Not run: anything in the game.

## Outstanding Tasks
**Critical / High**
1. Put the project under git (`git init`, first commit, GitHub like the other projects). Everything exists in one folder plus nine zips; there is no history and no backup.

**Medium**
2. Reproduce the "blocked from an action" box with 0.16.1 and read `GuldbogDB.blocked`.
3. Test in the game what the README marks as untested: own auctions, Priest bank, fallback sell tab without Auctionator.
4. Check `Data.lua` class/armour rules and Classic item IDs against Forever.

**Low**
5. README header says "Status (v0.16.0)" while the toc says 0.16.1; the decision log has 2026-11-19 above 2026-11-14.
6. Decide on sharing with the guild / CurseForge; remaining checklist; plan step 3 (own AH scan, estimated 300-500 lines).

## Technical Debt
No version control; no CI; test depends on `lupa` and a simulation; Data.lua rules are Classic assumptions; click-to-sell imitates Auctionator's internal bag-click routine (no public API) and may break on Auctionator updates (guarded, with fallback); `Guldbog.lua` is one 1660-line file.

## Bugs
Unexplained "blocked from an action" box (diagnostics added in 0.16.1, not yet read). README version drift.

## Ideas
Friends exchange professions/wishes in the background; show only the best armour type per class; "disenchant or sell?" for greens; LibDBIcon for the minimap button.

## Next Recommended Actions
1. `git init` + commit + GitHub. 2. Read `GuldbogDB.blocked` next time the box appears. 3. Test the untested items in the game. 4. Fix the README version line.
