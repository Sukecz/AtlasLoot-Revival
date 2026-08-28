# AtlasLoot Revival

**Maps, bosses and loot — revived for modern WoW Classic.**

AtlasLoot Revival combines dungeon and raid maps, boss locations, and loot
tables in one clean in-game browser. See where every boss is located and what
it can drop without leaving World of Warcraft.

## Features

- All original Classic dungeons and level-60 raids in both Era and TBC clients
- All 16 Burning Crusade dungeons with separate Normal and Heroic loot views
- All nine Burning Crusade raids across content phases 1–5
- Multi-floor instance maps with clickable boss markers
- Clear encounter pickers for bosses that share or overlap a map location
- Boss loot with estimated drop rates
- Boss-dropped quest items shown alongside regular loot
- Turn-in token labels for class, quest, and reputation rewards
- Curated Trash Drops for notable rare items, recipes, and raid materials
- Automatic detection of the dungeon or raid you are currently inside
- Separate Dungeons and Raids catalogs
- Native item tooltips and paged loot lists
- Minimap button and an assignable key binding
- Compact in-window options for display and opening behavior
- Movable and proportionally resizable window
- No Atlas or AtlasLootClassic installation required

## Usage

Open or close the browser with the minimap button, `/alr`, or
`/atlaslootrevival`. You can also assign **Toggle AtlasLoot Revival** under
**Key Bindings > AddOns**.

1. Select **Dungeons** or **Raids**.
2. Click the instance name to choose a dungeon or raid.
   Long instance lists support the mouse wheel and a draggable scrollbar.
3. Select a boss from the encounter list or click its numbered map marker.
4. In a Burning Crusade dungeon, choose **Normal** or **Heroic** above the loot list.
5. Click a cyan-ringed marker to choose between nearby encounters.
6. Hover over an item to see its complete in-game tooltip.
7. Use the map-section dropdown for multi-floor instances.
8. Open **Trash Drops** to browse notable non-boss loot.

When opened inside a supported dungeon or raid, AtlasLoot Revival automatically
selects that instance. Outside an instance, it restores your previous browser
selection.

Drag the window to move it and use the lower-right grip to resize it. Drag the
minimap button around the minimap to reposition it. Use `/alr reset` to restore
the default window position and size. The gear button beside the window close
button provides minimap visibility, opening behavior, drop estimate, marker
size, window scale, and reset controls.

## Content

The browser includes all 20 original Classic dungeons and the seven original
level-60 raids in both the Era and Burning Crusade clients.

Version 0.2.0 also includes all 16 Burning Crusade dungeons and all
nine Burning Crusade raids, with maps, reviewed encounter positions,
difficulty-scoped loot, 1,504 uniform-cohort numeric drop-rate variants,
content-phase labels, and raid turn-in tokens.
Positions explicitly known to be variable, unresolved, or template
placeholders are left without a marker instead of using a guessed coordinate.

## Drop rates

Drop percentages are estimates and do not guarantee the result of an individual
kill. Boss-dropped quest items are clearly labeled, while Trash Drops show
**Varies** when the chance depends on the enemy. A neutral **—** means the
boss-item relationship is confirmed but no reliable numeric estimate is
available. TBC percentages come only from direct Wowhead
`count/outof` samples of at least 100 kills. Every boss-and-difficulty table
uses one exact entity, phase, mode, page snapshot, and denominator; a row is
never filled from a second source or fallback cohort. The current audit resolves
1,504 variants. Another 205 ordinary variants lack a defensible sample. All 77
Badge of Justice and 12 conditional Winter Hat relationships also intentionally
show **—**, because their recorded `count/outof` is not a comparable per-kill
probability. No Atlas estimate, synthetic denominator, mixed cohort, or
undersampled percentage is displayed.

## Independent project

AtlasLoot Revival is a standalone community project. It is not affiliated with
or endorsed by Blizzard Entertainment, Atlas, AtlasLoot, or the original
AtlasLootClassic authors.

AtlasLoot Revival is released under the MIT License.
