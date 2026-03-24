## [0.0.6] - 2026-03-24

### Added
- TestFlight Buy Next button — places a shortcut button next to the Auction House window that steps through Auctionator's purchase workflow one click at a time, buying each item on the shopping list in sequence.
  - Stacks below the CraftSim Quickbuy button when both are visible.
  - Enabled by default if TestFlight is installed; can be toggled independently in settings.

## [0.0.5] - 2026-03-23

### Added
- Minimap button — left-click or right-click to open settings, middle-click to toggle dev mode. Shift+drag to reposition around the minimap edge; position is saved across reloads.
- Use Items popup: a floating bar of buttons appears when consumable profession items are in your bags (Artisan's Consortium Payouts, Glimmers/Flickers of Midnight Knowledge, Thalassian Treatises). Click each button to use the item.
  - Draggable via right-click drag; position is saved account-wide across reloads.
  - Auto-hides when no matching items remain.
  - Respects combat lockdown — buttons update after combat ends.
  - Can be toggled in addon settings.
- Use Items now skips Thalassian Treatises that have already been used this week on the current character.

### Fixed
- Corrected the weekly-reset quest ID for Thalassian Treatise on Engineering.

## [0.0.4] - 2026-03-07

### Fixed
- Treatise auto-withdrawal now correctly handles characters with two eligible professions — withdrawals are processed sequentially with a short delay between each, preventing a cursor clash that caused only the first treatise to be withdrawn

## [0.0.3] - 2026-03-07

### Added
- Cooking utility buttons: a Campfire button and a Chef's Hat toggle button appear alongside the Cooking profession window.
  - Chef's Hat button glows when the buff is active; clicking it again cancels the buff.
  - Campfire button casts Basic Campfire.
  - Both buttons are hidden when the Cooking window is closed.
  - Can be toggled in addon settings.

## [0.0.2] - 2026-03-05

### Added
- Thalassian Treatise auto-withdrawal — when the Warband Bank is opened, automatically withdraws treatises for the character's active professions if the weekly cooldown hasn't been used
---

## [0.0.1] - 2026-03-01

### Added
- Initial release
- CraftSim Quickbuy button — places a coin icon button next to the Auction House window; each click purchases one row of items from your CraftSim crafting queue's shopping list
- Settings panel accessible via `/grabbag` or Escape → Options → Lucky's Grab-bag
- Per-feature toggles with descriptions and dependency warnings in the settings panel
- CraftSim Quickbuy button auto-enables when CraftSim is installed, auto-disables when it isn't, and respects the user's manual preference once set
