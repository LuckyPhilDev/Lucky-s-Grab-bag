[Join the Discord](https://discord.gg/87HRHcAYP)

**Lucky's Grab-bag** is a growing collection of small quality-of-life features for World of Warcraft — each one independent, toggleable, and out of the way until you need it.

---

## Features

### Confirm Purchase Button
Whenever the game pops a confirmation at a vendor or when using a still-refundable item, a large tick button appears so you can confirm with a quick second click.

- Overlays directly on the item you clicked, so a double-click (click item, click tick) completes the action.
- Works for vendor currency purchases, vendor sells, the "no longer refundable" popup when you use or equip a refundable item, and the "bind on equip" popup for soulbound gear.
- Works with both left and right mouse buttons. Right-click the item, right-click the tick, and the item is yours.
- Optionally anchor next to the vendor window instead of overlaying, with right-click drag to reposition.
- Appears only while the popup is visible; hides automatically when the popup closes.
- Can be toggled in the addon settings.

### Auto Repair
Automatically repairs all damaged gear whenever you open a vendor that offers repairs — no button clicks required.

- Uses guild bank funds by default if your guild allows it; falls back to your own gold if not.
- The "Use Guild Funds" preference is independently toggleable in settings.
- Prints a message confirming what was repaired and the cost, so you always know what was spent and from where.
- Can be toggled in the addon settings.

### Auto Sell Junk
Automatically sells all grey-quality junk items from your bags whenever you open a vendor, so you never have to clear them out by hand.

- Sells only Poor (grey) quality items; everything else is left untouched.
- Prints a chat summary of how many items sold and the total earned.
- Skips items with no sell value and anything currently locked.
- Off by default; enable it in settings under Vendors.

### Use Items Popup
Displays a floating bar of buttons when you have consumable profession items in your bags — click each one to use it.

- Detects a wide range of profession knowledge consumables — **Artisan's Consortium Payouts**, **Glimmers** and **Flickers of Midnight Knowledge**, **Thalassian Treatises** (all professions), **Brimming Mana Shards**, **Swirling Arcane Essences**, **Caches of Void-Touched Armor**, **crest upgrade and downgrade satchels** (all Dawncrest tiers), plus the unique books, treasure pickups, gathering drops, weekly quest rewards, catch-up items, and treasure-hunt rewards from The War Within and Midnight.
- Thalassian Treatises are automatically hidden if already used this week, if your character hasn't learned that profession for the current expansion, or if your Midnight skill is below 25.
- One button per item type; shows stack count when you have multiples.
- Optionally restrict to cities and inns only via the "Only in Cities" setting.
- Draggable via right-click drag; position is saved account-wide and persists across reloads.
- Auto-hides when no matching items remain in your bags.
- Respects combat lockdown — buttons won't change mid-combat.
- Can be toggled in the addon settings.

### Stat Badges
Marks enchants, missives, and gems in your bags with a small stat code so you can tell them apart at a glance.

- Short codes for each stat: H haste, C crit, M mastery, V versatility, Sp speed, Le leech, Av avoidance, plus primary-stat and weapon-proc codes.
- Two-stat items show both, like Crit and Haste as "C&H". On a gem the bigger stat is upper case and the smaller is lower case, like "H&c".
- A '+' marks the pricier, higher-stat version of an enchant.
- Works on the default Blizzard bags and Baganator. Other bag addons may not show them.
- Optionally tags item names in the Auction House browse list as well.
- Can be toggled in the addon settings under Inventory.

### Reagent Mains
Assigns each reagent category to one or more designated characters. When you open the warband bank on a character not in the list, reagents in those categories are deposited automatically — useful for keeping all your Herbs on the herbalist, all your Cloth on the tailor, and so on.

- Covers every tradegoods category — Herbs, Cloth, Gems, Leather, Metal & Stone, Cooking, Enchanting, Inscription, and more.
- Pick any combination of characters per category, or set **All** (everyone keeps these) or **None** (nobody auto-deposits).
- Suggests likely mains per category based on each character's professions.
- Opens via a **Configure mains…** button next to the toggle in settings.
- Existing assignments from Warband Stockist are imported automatically the first time you log in.
- Off by default; can be toggled in the addon settings.

### Auto-Deposit Warbound Items
Automatically sends warbound gear and tokens to the warband bank when you open it.

- **Warbound Armor** — toggle to auto-deposit all warbound armor pieces.
- **Warbound Weapons** — toggle to auto-deposit all warbound weapons.
- **Warbound Tokens** — toggle to auto-deposit tier tokens and other raid rewards.
- **Lumber** — toggle to auto-deposit lumber alongside your other warbound items.
- **Custom Whitelist** — add specific items by pasting their item links or IDs. Whitelisted items always deposit, regardless of type toggles.
- Each category can be toggled independently.
- Opens via a **Configure whitelist…** button in settings for managing custom items.
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
- Off by default; enable it in settings under Interface.

### Shift-Click Set Tracking
Shift-click a transmog set on the Appearances Sets tab to track every appearance you're still missing from it, just like shift-clicking an item on the Items tab.

- Works from the collection list, the NPC set browser, and the individual pieces in the set details pane.
- If a piece has more than one source and one can't be tracked, the others are tried automatically.
- Enabled by default; can be toggled in the addon settings under Interface.

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

### Power Infusion Picker
For priests: a small floating window in parties and raids that lets you choose who receives your Power Infusion, out of combat.

- Click a name to update the 'PI' macro, which casts Power Infusion on that player.
- The first click creates the macro and picks it up so you can drop it onto your action bar.
- Parties list everyone with damage dealers first; raids list damage dealers only.
- Each name shows its spec icon and the percentage damage gain Power Infusion gives that spec, using current-season simulation data. Hover a name for the full breakdown.
- Switch between single-target, 3-target, and 5-target tabs to compare gains for different fights. The list reorders to match, and a numbered star marks the best target for each scenario.
- In large raids only the top column is shown; a chevron expands the rest when you want them.
- Appears automatically when grouped and out of combat; hides during combat.
- Your chosen target is saved per character.
- Right-click drag to reposition; position is saved across reloads.
- Use `/pipicker` to test the window outside group content.
- Enabled by default; only appears for priests who know Power Infusion.

### Auto Combat Logging
Starts combat logging when you enter the raid or Mythic+ content you choose, and stops it when you leave, so your Warcraft Logs uploads never miss a pull.

- Separate toggles for Mythic+ and raids.
- Pick which raid difficulties to log (Raid Finder, Normal, Heroic, Mythic).
- Current season only by default: older raids never trigger logging.
- Prints a chat message when logging starts or stops.
- If you stop logging manually mid-run, it stays off until you leave.
- Off by default; enable it in settings under Combat.

### Per-Spec Omnium Folio Runes
The Omnium Folio keeps the same runes when you change specialization. This feature remembers the rune choices you use in each spec and swaps them back automatically when you switch.

- Restores your last-used runes for the spec you switch to, with a chat message listing what changed.
- The first time you visit a spec, your current runes become that spec's starting point.
- Rune memory is saved per character.
- On by default; turn it off in settings under Combat.

### Auto-dismiss Bonus Roll
> Temporarily disabled while we fix a bug. The setting is greyed out for now and will return once the fix is ready.

Automatically passes on Blizzard's Bonus Roll popup that appears at the end of instanced content, with per-character control over which content types are kept.

- Per-content toggles for **Mythic+**, **Raids**, **Delves**, **Dungeons**, and **Hunts** in the open world.
- For Mythic+, set a **minimum key level** to keep the roll for, so rolls from lower keys are dismissed automatically.
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

### 1s Tip on Alt Work Orders
When you submit a personal crafting work order to one of your own characters, the tip is automatically set to 1 silver so you don't have to clear the field each time.

- Detects alts via your account-wide character roster (same-realm name match).
- Only fires on Personal orders, never on Public or Guild orders.
- Always overwrites the tip when the recipient changes, even if you'd typed something larger.
- Enabled by default; can be toggled in the addon settings under Professions.

### Spend to Next Perk
Clicking a profession specialisation node automatically spends additional knowledge points until you reach the next perk, so you can unlock a perk in one click instead of five.

- Hooks the standard spec node click; works exactly like clicking a node normally, just keeps going.
- Stops at each 5-rank perk threshold so you can review before unlocking the next one.
- Stops early if you run out of knowledge points or the path is locked.
- Enabled by default; can be toggled in the addon settings under Professions.

### Concentration on Profession Book
Adds a Concentration bar above each profession's skill bar in the Profession Book, so you can check your Concentration for both professions at a glance without opening either crafting window.

![Concentration bars on the Profession Book](images/crafting/concentration-view.png)

- Shows the current amount and maximum for each primary crafting profession.
- Hover the bar to see how long until your Concentration is full again.
- Updates as you spend and recharge, including passive recharge over time.
- Enabled by default; can be toggled in the addon settings under Professions.

### Cooking Utility Buttons
Adds two buttons alongside the Cooking profession window for quick access to common cooking prep.

- **Campfire** — casts Basic Campfire right at your feet so you can cook anywhere, no ground placement needed.
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
| `/pipicker` | Force-show the Power Infusion Picker window (also `/pitarget`) |
| `/pipicker mock` | Fill the picker with a fake roster for testing outside a group; add a number for the roster size (e.g. `/pipicker mock 25`) |

---

## Settings

Open with `/grabbag` or via the game's Interface Options panel. Each feature has its own section with a toggle and a description.

**Developer Tools**
- *Enable Dev Mode* — Enables development-only logging and diagnostics. Has no visible effect for regular users.

**Auto Repair**
- *Auto Repair* — Automatically repairs all gear when you open a repair vendor.
  - *Use Guild Funds* — Pays repair costs from the guild bank if your guild allows it, falling back to your own gold if not.
- *Auto Sell Junk* — Automatically sells grey-quality junk items when you open a vendor, and reports the total earned in chat.

**Auctionator Enhancements**
- *Show Quickbuy button* — Places a shortcut button next to the Auction House window. Each click purchases one row of items from your CraftSim crafting queue's shopping list.
- *Show Buy Next button* — Places a shortcut button next to the Auction House window. Each click advances through Auctionator's purchase workflow to quickly buy all items on a shopping list.

**Professions**
- *Withdraw Treatise from Warbank* — When you open the Warband Bank, automatically withdraws any Thalassian Treatises for your current professions that you haven't used this week.
- *Show cooking utility buttons* — Displays a Campfire and Chef's Hat button alongside the Cooking profession window.
- *Spend to Next Perk* — When clicking a profession specialisation node, spends knowledge points up to the next 5-rank perk threshold.
- *Concentration on Profession Book* — Shows a Concentration bar above each profession's skill bar in the Profession Book, with a hover tooltip for the refill time.
- *1s Tip on Alt Work Orders* — Automatically sets the tip to 1 silver when sending a personal work order to one of your own characters.
- *Reagent Mains* — When the warband bank opens, deposits reagents whose category is assigned to a different character.
  - *Configure mains…* — Opens the assignment window where each reagent category can be linked to one or more characters, "All" (everyone keeps), or "None".

**Vendors**
- *Confirm Purchase Button* — Shows a large tick button on vendor currency, sell, "no longer refundable", and "bind on equip" popups; clicking it confirms.
  - *Overlay on Clicked Item* — Places the button directly over the vendor item you clicked instead of next to the window.

**Delves**
- *Trovehunter's Bounty Map* — Shows a clickable button for your Bounty Map when in a qualifying delve.
  - *Minimum Delve Level* — The minimum delve level required for the button to appear (1–11).

**Inventory**
- *Use Items Popup* — Displays a floating bar of buttons for consumable profession items in your bags.
  - *Only while rested* — Restricts the popup to cities and inns.

**Rotation Glow**
- *Rotation Glow* — Animates the suggested next-cast spell on the Essential Cooldown Viewer, using Blizzard's assisted combat data.

**Combat Prep**
- *Combat Prep Window* — Shows a floating window with pull timer, ready check, and break timer buttons in raids and dungeons.
  - *Ready Check Button* — Show or hide the ready check button.
  - *Pull Timer (Mythic+)* — How long the pull countdown lasts in dungeons (3–30 seconds).
  - *Pull Timer (Raid)* — How long the pull countdown lasts in raids (3–30 seconds).
  - *Break Timer Duration* — How long the break countdown lasts (1–15 minutes).
- *Power Infusion Picker*: Shows a window in groups for priests to pick their Power Infusion target; clicking a name updates the 'PI' macro.
- *Auto Combat Logging*: Starts combat logging in selected raid difficulties and Mythic+ keys, stops when you leave; current season only by default.
- *Create Kick Macro* — Generates a class-appropriate interrupt macro in a character macro slot.
- *Per-Spec Omnium Folio Runes*: Remembers your Omnium Folio rune choices for each specialization and restores them when you switch specs.

**Interface**
- *Keep Active Transmog Tab* — Keeps your active transmog tab when switching outfit slots.
- *Shift-Click Set Tracking* — Shift-click a set on the Appearances Sets tab to track every appearance you're still missing from it.
- *Auto-dismiss Bonus Roll* — Automatically passes on the Bonus Roll popup at the end of instanced content. Per-character toggles for Mythic+ (with a minimum key level), Raids (with individual difficulty selection), Delves, Dungeons, and Hunts.

Settings are saved per account, except for Bonus Roll preferences and Omnium Folio rune memory, which are saved per character.

---

## Notes

- More features will be added over time — hence the name.
