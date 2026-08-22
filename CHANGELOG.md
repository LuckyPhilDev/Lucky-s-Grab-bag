## [Unreleased]

### Added
- **Easy buy profession quest items** A button beside the Auction House finds the reagents your profession quests still owe, at the quality each one asks for. Click again to price the first, once more to buy it.
- **Auto Accept profession quests** A profession quest is taken as soon as its giver offers it, including from an NPC who opens a shop or a trainer window first.
- **Auto Hand in profession quests** A profession quest goes back the moment you have what it asked for. Hold Shift as you talk to an NPC to leave one to yourself.

### Improved
- **Professions settings** The toggles are grouped under Quests, Crafting Window and Alts & Warband, so the page reads as a list of related things rather than one long column.

### Removed
- The Always Compare Items toggle has gone from the Interface settings. It only ever mirrored the game's own setting, which you can still change under Gameplay, Combat.
- The retired Keep Active Transmog Tab and Shift-Click Set Tracking rows have gone from the Interface settings. Both moved to Lucky's Wardrobe some time ago.

## [1.23.1] - 2026-08-20

### Improved
- **Under the hood** A tidy-up of the addon's internals. Nothing changes in how it looks or plays.

## [1.23.0] - 2026-08-19

### Improved
- **Under the hood** A tidy-up of the addon's internals. Nothing changes in how it looks or plays.
- **Lucky's Utils bundled** The shared library now ships inside the addon, so there is no separate download from CurseForge. If you have the standalone Lucky's Utils installed, you can remove it as long as no other Lucky addon still needs it.

### Fixed
- The Trovehunter's Bounty Map button no longer throws a blocked action error when you turn its setting off during combat. It waits for combat to end instead. (Thanks for the report Dubhe)

### Removed
- Warbound armor, weapon and token deposit has moved to Warband Stockist, on its Warbound tab, taking your settings with it. The whitelist and lumber deposits stay here.
