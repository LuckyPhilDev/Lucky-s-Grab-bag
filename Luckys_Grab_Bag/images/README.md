# Grab-bag Settings — Feature Images

Screenshots used by the **About** panel of the settings UI (and as documentation references in the project README).

## Folder layout

One folder per setting group, mirroring the section names in `Settings.lua`:

```
images/
├── general/
├── vendors/
├── auction-house/
├── crafting/
├── inventory/
├── combat/
└── delves/
```

## File naming

`<setting-key>.<ext>` — kebab-case, derived from the setting's stable identifier (the same key used in the saved-variables DB or the Settings.lua label, lowercased and dashed).

Examples:

| Setting | Path |
|---|---|
| Use Items Popup | `images/inventory/use-items-popup.tga` |
| Reagent Mains | `images/crafting/reagent-mains.tga` |
| Trovehunter's Bounty Map | `images/delves/trovehunters-bounty-map.tga` |
| Confirm Purchase Button | `images/vendors/confirm-purchase.tga` |

## Format & dimensions

**Runtime (in-game About panel):**
- Format: **TGA, 32-bit uncompressed**, or BLP. *(WoW does not load PNG at runtime.)*
- Width/height: **power of two** (256, 512, 1024). Crop the actual screenshot inside a power-of-two canvas.
- Recommended canvas: **256×256** (displayed scaled to ~190px in the About panel).
- Filename in Lua: `Interface\\AddOns\\Luckys_Grab_Bag\\images\\inventory\\use-items-popup`
  (no extension — WoW's texture loader resolves `.tga`/`.blp` automatically).

**Design source (optional, kept alongside):**
- PNG of the raw screenshot, same basename. Used for the project README and for re-exporting the TGA later if the UI changes.
- Not loaded at runtime — purely for the repo.

## Capture conventions

- Capture at the standard WoW UI scale (no zoom).
- Keep only the feature itself; trim chrome and unrelated UI.
- Use a dark, neutral backdrop where possible (the About panel background is `#0b0a07`, so the TGA blends in).
- Subjects should sit roughly centred within the canvas.

## Adding a new image

1. Drop the PNG source in the matching folder.
2. Export a TGA (32-bit) of the same image, padded into the nearest power-of-two square.
3. Reference it from the setting's About-panel metadata.

## Index

| Group | Setting | File | Status |
|---|---|---|---|
| Vendors | Confirm Purchase | `vendors/confirm-purchase.tga` | _done_ |
| Vendors | Confirm Purchase Overlay | `vendors/confirm-purchase-overlay.tga` | _done_ |
| Auction House | CraftSim Quickbuy | `auction-house/craftsim-quickbuy.tga` | _done_ |
| Crafting | Cooking Buttons | `crafting/cooking-buttons.tga` | _done_ |
| Inventory | Use Items Popup | `inventory/use-items-popup.tga` | _done_ |
| Inventory | Only in Cities | `inventory/use-items-popup.tga` (shared) | _done_ |
| Combat | Combat Prep Window | `combat/combat-prep-window.tga` | _done_ |
| Combat | Rotation Glow | `combat/rotation-glow.tga` | _done_ |

Add rows here as screenshots are captured.
