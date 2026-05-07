[Join the Discord](https://discord.gg/87HRHcAYP)

**Lucky's Grab-bag** is a growing collection of small quality-of-life features for World of Warcraft — each one independent, toggleable, and out of the way until you need it.

---

## Features

### Confirm Purchase Button
When a vendor shows a currency purchase confirmation popup, a large tick button appears so you can quickly confirm the buy.

- Overlays directly on the item you clicked, so a double-click (click item → click tick) completes the purchase.
- Works with both left and right mouse buttons — right-click the item, right-click the tick, and the item is yours.
- Optionally anchor next to the vendor window instead of overlaying, with right-click drag to reposition.
- Appears only while the popup is visible; hides automatically when the popup closes.
- Can be toggled in the addon settings.

### Auto Repair
Automatically repairs all damaged gear whenever you open a vendor that offers repairs — no button clicks required.

- Uses guild bank funds by default if your guild allows it; falls back to your own gold if not.
- The "Use Guild Funds" preference is independently toggleable in settings.
- Prints a message confirming what was repaired and the cost, so you always know what was spent and from where.
- Can be toggled in the addon settings.

### Use Items Popup
Displays a floating bar of buttons when you have consumable profession items in your bags — click each one to use it.

- Detects a wide range of profession knowledge consumables — **Artisan's Consortium Payouts**, **Glimmers** and **Flickers of Midnight Knowledge**, **Thalassian Treatises** (all professions), **Brimming Mana Shards**, **Swirling Arcane Essences**, **Caches of Void-Touched Armor**, plus the unique books, treasure pickups, gathering drops, weekly quest rewards, catch-up items, and treasure-hunt rewards from The War Within and Midnight.
- Thalassian Treatises are automatically hidden if already used this week, if your character hasn't learned that profession for the current expansion, or if your Midnight skill is below 25.
- One button per item type; shows stack count when you have multiples.
- Optionally restrict to cities and inns only via the "Only in Cities" setting.
- Draggable via right-click drag; position is saved account-wide and persists across reloads.
- Auto-hides when no matching items remain in your bags.
- Respects combat lockdown — buttons won't change mid-combat.
- Can be toggled in the addon settings.

### Reagent Mains
Assigns each reagent category to one or more designated characters. When you open the warband bank on a character not in the list, reagents in those categories are deposited automatically — useful for keeping all your Herbs on the herbalist, all your Cloth on the tailor, and so on.

- Covers every tradegoods category — Herbs, Cloth, Gems, Leather, Metal & Stone, Cooking, Enchanting, Inscription, and more.
- Pick any combination of characters per category, or set **All** (everyone keeps these) or **None** (nobody auto-deposits).
- Suggests likely mains per category based on each character's professions.
- Opens via a **Configure mains…** button next to the toggle in settings.
- Existing assignments from Warband Stockist are imported automatically the first time you log in.
- Off by default; can be toggled in the addon settings.

### Withdraw Treatise from Warbank
Automatically withdraws Thalassian Treatises for your current professions from the Warband Bank whenever you open it — but only if you haven't already used them this week.

- Checks your character's active professions and only withdraws the relevant treatises.
- Only withdraws treatises for professions your character has learned for the current expansion.
- Requires at least 25 Midnight skill in the profession before withdrawing.
- Skips any treatise whose weekly cooldown has already been used.
- Skips withdrawal if the treatise is already in your bags (prevents duplicates).
- Prints a confirmation message for each treatise withdrawn.
- Enabled by default; can be toggled in the addon settings.

### Keep Active Transmog Tab
Keeps your active tab in the transmog panel when switching outfit slots, instead of jumping back to Items each time.

- Works for any tab: Items, Sets, Custom Sets, and Situations.
- Off by default; enable it in settings under Items & Appearance.

### Rotation Glow
Animates the suggested next-cast spell on Blizzard's Cooldown Manager, using the game's built-in assisted combat data.

- Pulses an animated overlay on the cooldown icon matching the current rotation suggestion.
- Works automatically for every spec — no per-class setup.
- Requires the **Essential Cooldown Viewer** to be enabled in Edit Mode.
- Off by default; enable it in the addon settings.

### Combat Prep Window
A small floating window that appears automatically in raids and dungeons when you're out of combat, giving quick access to pull timers, ready checks, and break countdowns.

- **Pull Timer** — starts a countdown for the configured duration. Separate durations for Mythic+ (default 10s) and raids (default 12s); the button shows whichever applies to the content you're in. A cancel button beside it lets you stop the countdown early.
- **Ready Check** — initiates a ready check for the group. Can be hidden in settings.
- **Break Timer** — starts a long countdown for bio breaks (1–15 minutes, default 5m).
- Appears automatically when you enter a raid or dungeon instance and hides during combat.
- Right-click drag to reposition; position is saved across reloads.
- Use `/combatprep` to test the window outside of group content.
- Can be toggled in the addon settings.

### Auto-dismiss Bonus Roll
Automatically passes on Blizzard's Bonus Roll popup that appears at the end of instanced content, with per-character control over which content types are kept.

- Per-content toggles for **Mythic+**, **Raids**, **Delves**, **Dungeons**, and **Hunts** in the open world.
- Raid difficulties are individually selectable (Raid Finder, Normal, Heroic, Mythic).
- Settings are saved per character, so each alt can have its own preferences.
- Off by default; enable it in settings under Interface.

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

### Kick Macro Generator
Creates a class-appropriate interrupt macro in one of your character macro slots.

- Interrupts your focus target if you have one set, letting you kick a caster without switching away from your main target.
- With no focus, grabs the nearest enemy, kicks them, and clears focus so the next press does the same.
- Handles specs with different interrupts (e.g. Survival Hunter uses Muzzle, others use Counter Shot).
- Triggered via the **Create Kick Macro** button in settings under Combat.

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
| `/grabbag-reagent <itemID>` | Diagnose why a reagent is or isn't being auto-deposited |
| `/combatprep` | Force-show the Combat Prep window (for testing outside group content) |

---

## Settings

Open with `/grabbag` or via the game's Interface Options panel. Each feature has its own section with a toggle and a description.

**Developer Tools**
- *Enable Dev Mode* — Enables development-only logging and diagnostics. Has no visible effect for regular users.

**Auto Repair**
- *Auto Repair* — Automatically repairs all gear when you open a repair vendor.
  - *Use Guild Funds* — Pays repair costs from the guild bank if your guild allows it, falling back to your own gold if not.

**Auctionator Enhancements**
- *Show Quickbuy button* — Places a shortcut button next to the Auction House window. Each click purchases one row of items from your CraftSim crafting queue's shopping list.
- *Show Buy Next button* — Places a shortcut button next to the Auction House window. Each click advances through Auctionator's purchase workflow to quickly buy all items on a shopping list.

**Crafting**
- *Withdraw Treatise from Warbank* — When you open the Warband Bank, automatically withdraws any Thalassian Treatises for your current professions that you haven't used this week.
- *Show cooking utility buttons* — Displays a Campfire and Chef's Hat button alongside the Cooking profession window.
- *Reagent Mains* — When the warband bank opens, deposits reagents whose category is assigned to a different character.
  - *Configure mains…* — Opens the assignment window where each reagent category can be linked to one or more characters, "All" (everyone keeps), or "None".

**Vendors**
- *Confirm Purchase Button* — Shows a large tick button when a vendor currency purchase popup appears; clicking it confirms the buy.
  - *Overlay on Clicked Item* — Places the button directly over the vendor item you clicked instead of next to the window.

**Delves**
- *Trovehunter's Bounty Map* — Shows a clickable button for your Bounty Map when in a qualifying delve.
  - *Minimum Delve Level* — The minimum delve level required for the button to appear (1–11).

**Items & Appearance**
- *Use Items Popup* — Displays a floating bar of buttons for consumable profession items in your bags.
  - *Only while rested* — Restricts the popup to cities and inns.
- *Keep Active Transmog Tab* — Keeps your active transmog tab when switching outfit slots.

**Rotation Glow**
- *Rotation Glow* — Animates the suggested next-cast spell on the Essential Cooldown Viewer, using Blizzard's assisted combat data.

**Combat Prep**
- *Combat Prep Window* — Shows a floating window with pull timer, ready check, and break timer buttons in raids and dungeons.
  - *Ready Check Button* — Show or hide the ready check button.
  - *Pull Timer (Mythic+)* — How long the pull countdown lasts in dungeons (3–30 seconds).
  - *Pull Timer (Raid)* — How long the pull countdown lasts in raids (3–30 seconds).
  - *Break Timer Duration* — How long the break countdown lasts (1–15 minutes).
- *Create Kick Macro* — Generates a class-appropriate interrupt macro in a character macro slot.

**Interface**
- *Auto-dismiss Bonus Roll* — Automatically passes on the Bonus Roll popup at the end of instanced content. Per-character toggles for Mythic+, Raids (with individual difficulty selection), Delves, Dungeons, and Hunts.

Settings are saved per account, except for Bonus Roll preferences which are saved per character.

---

## Notes

- More features will be added over time — hence the name.
