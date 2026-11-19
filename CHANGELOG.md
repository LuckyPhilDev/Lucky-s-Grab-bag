## [Unreleased]

### Added
- **Friends Overlay** Lists your online friends on screen as plain text with no window behind it, so you can see who is on without opening the friends list. Choose which friends and details it shows, coloured by class, faction and level difficulty. (Thanks for the suggestion Tuulani)

## [1.41.2] - 2026-11-16

### Added
- **Auto Sort Bags** Your bags sort after Auto Sell Junk finishes and when you close a vendor window, so you no longer have to sort them by hand after buying and selling. You can limit it to WoW Forever or to playing with a controller.

### Fixed
- Crafting at a profession table no longer leaves your action bar cooldowns throwing errors in combat, and TradeSkillMaster's crafting window fills again. (Thanks for the report Zelion)
- The Pierre button beside the Cooking window no longer errors while the game has not yet loaded your pet journal.

## [1.41.1] - 2026-11-14

### Added
- **Controller cast button** On a controller, press RT on a bag item you can disenchant, or an untranslated scroll as a Mage, to cast on it. The tooltip names the button, and you can rebind it under Key Bindings, Lucky's Grab-bag.

## [1.41.0] - 2026-11-14

### Added
- **Delver's Flare Gun for Keys** In a delve, when you hold fewer than 2 Restored Coffer Keys, a button appears for your Midnight Delver's Flare Gun so you can call Brann and buy this week's keys. It hides once you've bought both, and while you're below max level or the gun is on cooldown. (Thanks for the suggestion Halliday)

### Fixed
- The Boons Panel no longer errors every second while a Loa-Spirit conduit buff is active and one of your Boon stats is at 0%.
- On WoW Forever, controller navigation in combined bags moves to adjacent items and bag buttons instead of jumping to another part of the window.

## [1.40.1] - 2026-11-08

### Fixed
- Grab-bag loads again. In 1.40.0 it stopped at login with a Lua error and none of its features started.

## [1.40.0] - 2026-11-08

### Added
- **WoW Forever support** Grab-bag loads on WoW Forever. Features built on systems Forever lacks, such as delves, housing and the Trading Post, are switched off and listed last in settings under Not on WoW Forever.
- **Graphics** On WoW Forever, a settings page for engine options the game's Graphics menu leaves out, including far view distance, fog, grass density, shadow cascades and HDR brightness. Your choices go back on at every login, and Restore Previous Values puts the old ones back.
- **Alt Right-Click Spells** Hold Alt and right-click an item in your bags to disenchant it, or as a Mage to comprehend an untranslated scroll. The item's tooltip names the spell. Controller players can bind a button to it under Key Bindings, Lucky's Grab-bag.

## [1.39.4] - 2026-11-04

### Fixed
- The Combat Prep Window picture in settings now shows the current window instead of the old one.

## [1.39.3] - 2026-11-01

### Improved
- **Cooking buttons** The Campfire, Chef's Hat and Pierre buttons stop watching your auras, cooldowns and pets while the Professions window is closed, so they cost nothing in raids and dungeons.
- **Rotation Glow** Following the suggested spell uses far less memory in combat, so long fights stay smoother.
- **Mass Disenchant** The panel refreshes once per bag change instead of once for every bag touched, and not at all while it is closed.
- **Combat Prep Window** While the window is turned off it no longer reacts to group, combat and pull timer changes, so it costs nothing in raids.
- **Profession Quest Items** The button beside the Auction House only follows your quest log while the Auction House is open, so questing elsewhere costs nothing.

### Fixed
- Decor previews at vendors now appear when using Krowi's Extended Vendor UI.
- Purchase confirmation ticks now appear on vendor items when using Krowi's Extended Vendor UI.

## [1.39.2] - 2026-10-31

### Fixed
- Selecting an item in the Trading Post no longer shows an error, and your Combat Animation and Mount Special checkbox choices are remembered.
- **Reminders** The empty gem sockets reminder no longer counts filled sockets as empty after a reload. (Thanks for the report Halliday)

## [1.39.1] - 2026-10-29

### Fixed
- **Use Items Popup** The popup no longer moves when you log in on another character with its scale set below or above 100%. (Thanks for the report Halliday)

## [1.39.0] - 2026-10-29

### Added
- **Boons Panel** Shows the stats your delve Boons buff grants in a small panel, so you no longer have to find the buff and hover it. Only stats you have collected are listed, and a stat shimmers when it goes up and stays highlighted until your next pickup. Loa-Spirit conduit buffs in the Labyrinth of Kindo'jan are listed too, with a countdown of their two minutes. The game hides aura details in combat, so the panel dims until combat ends. Boons that raise health, movement speed, your primary stat or damage reduction still count up as you pick them up; the others show once combat ends. Click the X to turn it off; turn it back on in settings under Delves. (Thanks for the suggestion Tuulani)

### Improved
- **Use Items Popup** Set which way the popup grows, its scale, and how many buttons it shows at once, under the popup in settings. (Thanks for the suggestion Halliday)
