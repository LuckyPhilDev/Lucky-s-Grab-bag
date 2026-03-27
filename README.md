**Lucky's Grab-bag** is a growing collection of small quality-of-life features for World of Warcraft — each one independent, toggleable, and out of the way until you need it.

---

## Features

### Use Items Popup
Displays a floating bar of buttons when you have consumable profession items in your bags — click each one to use it.

- Detects **Artisan's Consortium Payouts**, **Glimmers of Midnight Knowledge**, **Flickers of Midnight Knowledge**, and **Thalassian Treatises** (all professions).
- Thalassian Treatises are automatically hidden if already used this week, or if your character hasn't learned that profession for the current expansion.
- One button per item type; shows stack count when you have multiples.
- Optionally restrict to cities and inns only via the "Only in Cities" setting.
- Draggable via right-click drag; position is saved account-wide and persists across reloads.
- Auto-hides when no matching items remain in your bags.
- Respects combat lockdown — buttons won't change mid-combat.
- Can be toggled in the addon settings.

### Thalassian Treatise Auto-Withdrawal
Automatically withdraws Thalassian Treatises for your current professions from the Warband Bank whenever you open it — but only if you haven't already used them this week.

- Checks your character's active professions and only withdraws the relevant treatises.
- Only withdraws treatises for professions your character has learned for the current expansion.
- Skips any treatise whose weekly cooldown has already been used.
- Skips withdrawal if the treatise is already in your bags (prevents duplicates).
- Prints a confirmation message for each treatise withdrawn.
- Enabled by default; can be toggled in the addon settings.

### Combat Prep Window
A small floating window that appears automatically in raids and dungeons when you're out of combat, giving quick access to pull timers, ready checks, and break countdowns.

- **Pull Timer** — starts a countdown for the configured duration (3–30 seconds, default 10s).
- **Ready Check** — initiates a ready check for the group. Can be hidden in settings.
- **Break Timer** — starts a long countdown for bio breaks (1–15 minutes, default 5m).
- Appears automatically when you enter a raid or dungeon instance and hides during combat.
- Right-click drag to reposition; position is saved across reloads.
- Use `/combatprep` to test the window outside of group content.
- Can be toggled in the addon settings.

### Trovehunter's Bounty Map
Shows a clickable button when you're inside a delve that meets the configured minimum level and you have a Trovehunter's Bounty Map in your bags.

- Appears automatically on entering a qualifying delve; hides when you leave or use the map.
- **Minimum delve level** is configurable in settings (default: level 8).
- Right-click drag to reposition; position is saved across reloads.
- Respects combat lockdown — the button won't change mid-combat.
- Can be toggled in the addon settings.

### Cooking Utility Buttons
Adds two buttons alongside the Cooking profession window for quick access to common cooking prep.

- **Campfire** — casts Basic Campfire so you can cook anywhere.
- **Chef's Hat** — uses the Chef's Hat toy to put it on. If the buff is already active, clicking the button cancels it instead (the button glows while active).
- Both buttons are hidden when the Cooking window is closed.
- Right-click drag any button to reposition the group; position is saved relative to the Cooking window.
- Can be toggled in the addon settings.

### CraftSim Quickbuy Button
> Requires: **CraftSim v19.7.0** or later.

Adds a coin icon button just outside the top-right corner of the Auction House window. One click invokes CraftSim's Quickbuy feature — no need to have a dedicated macro.

- Appears automatically when you open the Auction House.
- Hidden when the Auction House is closed.
- Enabled by default if CraftSim is installed; disabled by default if it isn't.
- Right-click drag either button to reposition the group; position is saved relative to the Auction House window.
- Can be toggled on or off in the addon settings.

### TestFlight Buy Next Button
> Requires: **TestFlight v5.07** or later (and **Auctionator**).

Adds a button next to the Auction House window that steps through Auctionator's purchase workflow one click at a time — selecting the next item, buying it, and confirming each dialog.

- Each click advances to the next step: select result, buy, confirm price warnings, and move on to the next item.
- Stacks below the CraftSim Quickbuy button when both are visible; takes its position when Quickbuy is hidden.
- Enabled by default if TestFlight is installed; disabled by default if it isn't.
- Can be toggled on or off in the addon settings.

### Minimap Button
A minimap button for quick access to the addon.

- **Left-click** or **Right-click** — open settings.
- **Middle-click** — toggle dev mode on/off.
- **Shift+drag** — reposition the button around the minimap edge; position is saved across reloads.

---

## Setup

1. Install the addon and reload your UI.
2. Open settings via `/grabbag`, the **minimap button**, or **Escape → Options → Lucky's Grab-bag**.
3. Toggle individual features on or off as needed.

---

## Slash Commands

| Command | Action |
|---|---|
| `/grabbag` | Open the addon settings panel |
| `/combatprep` | Force-show the Combat Prep window (for testing outside group content) |

---

## Settings

Open with `/grabbag` or via the game's Interface Options panel. Each feature has its own section with a toggle and a description.

**Developer Tools**
- *Enable Dev Mode* — Enables development-only logging and diagnostics. Has no visible effect for regular users.

**Auctionator Enhancements**
- *Show Quickbuy button* — Places a shortcut button next to the Auction House window. Each click purchases one row of items from your CraftSim crafting queue's shopping list.
- *Show Buy Next button* — Places a shortcut button next to the Auction House window. Each click advances through Auctionator's purchase workflow to quickly buy all items on a shopping list.

**Professions**
- *Auto-withdraw treatises from Warband Bank* — When you open the Warband Bank, automatically withdraws any Thalassian Treatises for your current professions that you haven't used this week.
- *Show use-item buttons* — Displays a floating row of buttons when consumable profession items are in your bags (Artisan's Consortium Payouts, Glimmers/Flickers of Midnight Knowledge, Thalassian Treatises). The bar is draggable and hides automatically when empty.
  - *Only in Cities* — Restricts the Use Items popup to cities and inns.
- *Show cooking utility buttons* — Displays a Campfire and Chef's Hat button alongside the Cooking profession window.

**Delves**
- *Trovehunter's Bounty Map* — Shows a clickable button for your Bounty Map when in a qualifying delve.
  - *Minimum Delve Level* — The minimum delve level required for the button to appear (1–11).

**Combat Prep**
- *Combat Prep Window* — Shows a floating window with pull timer, ready check, and break timer buttons in raids and dungeons.
  - *Ready Check Button* — Show or hide the ready check button.
  - *Pull Timer Duration* — How long the pull countdown lasts (3–30 seconds).
  - *Break Timer Duration* — How long the break countdown lasts (1–15 minutes).

Settings are saved per account.

---

## Notes

- More features will be added over time — hence the name.
