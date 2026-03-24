**Lucky's Grab-bag** is a growing collection of small quality-of-life features for World of Warcraft — each one independent, toggleable, and out of the way until you need it.

---

## ✨ Features

### 📦 Use Items Popup
Displays a floating bar of buttons when you have consumable profession items in your bags — click each one to use it.

- Detects **Artisan's Consortium Payouts**, **Glimmers of Midnight Knowledge**, **Flickers of Midnight Knowledge**, and **Thalassian Treatises** (all professions).
- Thalassian Treatises are automatically hidden if already used this week on the current character.
- One button per item type; shows stack count when you have multiples.
- Draggable via right-click drag; position is saved account-wide and persists across reloads.
- Auto-hides when no matching items remain in your bags.
- Respects combat lockdown — buttons won't change mid-combat.
- Can be toggled in the addon settings.

### 📜 Thalassian Treatise Auto-Withdrawal
Automatically withdraws Thalassian Treatises for your current professions from the Warband Bank whenever you open it — but only if you haven't already used them this week.

- Checks your character's active professions and only withdraws the relevant treatises.
- Skips any treatise whose weekly cooldown has already been used.
- Skips withdrawal if the treatise is already in your bags (prevents duplicates).
- Prints a confirmation message for each treatise withdrawn.
- Enabled by default; can be toggled in the addon settings.

### 🍳 Cooking Utility Buttons
Adds two buttons alongside the Cooking profession window for quick access to common cooking prep.

- **Campfire** — casts Basic Campfire so you can cook anywhere.
- **Chef's Hat** — uses the Chef's Hat toy to put it on. If the buff is already active, clicking the button cancels it instead (the button glows while active).
- Both buttons are hidden when the Cooking window is closed.
- Can be toggled in the addon settings.

### 🪙 CraftSim Quickbuy Button
> Requires: **CraftSim v19.7.0** or later.
Adds a coin icon button just outside the top-right corner of the Auction House window. One click invokes CraftSim's Quickbuy feature — no need to have a dedicated macro.

- Appears automatically when you open the Auction House.
- Hidden when the Auction House is closed.
- Enabled by default if CraftSim is installed; disabled by default if it isn't.
- Can be toggled on or off in the addon settings.

### 🛒 TestFlight Buy Next Button
> Requires: **TestFlight v5.07** or later (and **Auctionator**).
Adds a button next to the Auction House window that steps through Auctionator's purchase workflow one click at a time — selecting the next item, buying it, and confirming each dialog.

- Each click advances to the next step: select result, buy, confirm price warnings, and move on to the next item.
- Stacks below the CraftSim Quickbuy button when both are visible; takes its position when Quickbuy is hidden.
- Enabled by default if TestFlight is installed; disabled by default if it isn't.
- Can be toggled on or off in the addon settings.

### 🗺️ Minimap Button
A minimap button for quick access to the addon.

- **Left-click** or **Right-click** — open settings.
- **Middle-click** — toggle dev mode on/off.
- **Shift+drag** — reposition the button around the minimap edge; position is saved across reloads.

---

## 📋 Setup

1. Install the addon and reload your UI.
2. Open settings via `/grabbag`, the **minimap button**, or **Escape → Options → Lucky's Grab-bag**.
3. Toggle individual features on or off as needed.

---

## ⚙️ Settings

Open with `/grabbag` or via the game's Interface Options panel. Each feature has its own section with a toggle and a description.

**Developer Tools**
- *Enable Dev Mode* — Enables development-only logging and diagnostics. Has no visible effect for regular users.

**CraftSim Quickbuy**
- *Show Quickbuy button* — Places a shortcut button next to the Auction House window. Each click purchases one row of items from your CraftSim crafting queue's shopping list.

**TestFlight Buy Next**
- *Show Buy Next button* — Places a shortcut button next to the Auction House window. Each click advances through Auctionator's purchase workflow to quickly buy all items on a shopping list.

**Thalassian Treatises**
- *Auto-withdraw treatises from Warband Bank* — When you open the Warband Bank, automatically withdraws any Thalassian Treatises for your current professions that you haven't used this week.

**Use Items**
- *Show use-item buttons* — Displays a floating row of buttons when consumable profession items are in your bags (Artisan's Consortium Payouts, Glimmers/Flickers of Midnight Knowledge, Thalassian Treatises). The bar is draggable and hides automatically when empty.

**Cooking**
- *Show cooking utility buttons* — Displays a Campfire and Chef's Hat button alongside the Cooking profession window.

Settings are saved per account.

---

## ⌨️ Commands

- `/grabbag` — open the addon settings panel.

---

## 🛑 Notes

- More features will be added over time — hence the name.
