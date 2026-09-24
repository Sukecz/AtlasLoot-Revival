# AtlasLoot Revival

**Maps, bosses and loot — revived for modern WoW Classic.**

AtlasLoot Revival is a standalone dungeon and raid browser for modern WoW
Classic. It brings instance maps, clickable boss locations, and boss loot
together in one clean in-game window, so you can plan a run or check an item
without leaving the game.

It supports WoW Classic Era, Hardcore, Anniversary, and Burning Crusade
Classic. Atlas and AtlasLootClassic are not required.

## Features

- All 20 original Classic dungeons and all seven level-60 raids
- All 16 Burning Crusade dungeons with separate Normal and Heroic loot
- All nine Burning Crusade raids across phases 1–5
- Multi-floor instance maps with clickable boss markers
- Clear encounter pickers for bosses that share or overlap a map location
- Boss loot with carefully sourced drop-rate estimates where reliable
- Boss-dropped quest items shown alongside regular loot
- Badge of Justice, raid-token, quest, class, and reputation reward labels
- Curated Trash Drops for notable rare items, recipes, and raid materials
- Automatic detection of the dungeon or raid you are currently inside
- Separate Classic 1–60 and Burning Crusade 60–70 catalogs on the TBC client
- Native item tooltips and paged loot lists
- Minimap button and an assignable key binding
- Compact in-window options for display and opening behavior
- Movable and proportionally resizable window
- Standalone operation with no required libraries or map addons

## Supported clients

- WoW Classic Era, Hardcore, and Anniversary — Interface `11509`
- WoW Burning Crusade Classic — Interface `20506`

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
size, and reset controls. Window size is adjusted with the lower-right grip.

## Included content

The Era catalog contains all 20 original Classic dungeons and the seven
original level-60 raids. The TBC client retains that complete Classic catalog
and adds all 16 Burning Crusade dungeons and all nine Burning Crusade raids,
including content-phase labels, Normal and Heroic dungeon views, Badge of
Justice drops, and raid turn-in tokens.

Boss markers use reviewed positions. Encounters whose position is genuinely
variable or cannot be placed reliably remain selectable from the encounter
list without displaying a guessed marker.

## Drop rates

Drop percentages are estimates and cannot guarantee the result of an
individual kill. TBC rates are shown only when a sufficiently large,
difficulty-specific sample is available from one consistent source. Normal and
Heroic data are never mixed to fill missing percentages.

A neutral **—** means the boss-item relationship is confirmed but a reliable
per-kill estimate is not available. Badge of Justice and conditional seasonal
items also intentionally omit a percentage when the available sample would be
misleading. Trash Drops show **Varies** when the chance depends on the enemy.

## Independent project

AtlasLoot Revival is a standalone community project. It is not affiliated with
or endorsed by Blizzard Entertainment, Atlas, AtlasLoot, or the original
AtlasLootClassic authors.

AtlasLoot Revival is released under the MIT License.

## Shared development and AtlasLoot Forever

This repository now builds two independent addons from the same UI sources.
Revival retains its existing Classic Era/TBC data, installation path, settings
and release workflow. AtlasLoot Forever is a development preview with its own
name, compass/infinity icon, saved settings and `/alf` command.

Forever currently contains a provisional snapshot of the 20 Vanilla dungeons
with their existing maps and Era loot, plus nine announced Forever dungeons.
The new dungeons contain names and announced level ranges only. No new maps,
bosses, loot or game IDs are inferred. Vanilla data is visibly marked as not
verified in Forever; inherited drop percentages are not displayed. Raids and
TBC content are not included in Forever's initial catalog.

Common runtime templates live in `shared/`, branding and TOCs in `products/`,
and client flavor code in `compat/`. Generated addon directories remain
checked in for installation and packaging. Edit the sources, then run:

```bash
python3 tools/build_products.py
python3 tools/build_products.py --check
lua5.1 tests/product_runtime.lua "$PWD"
```

The maintainer's local research workspace additionally supports
`python3 tools/build_products.py --with-data` and `bash tests/run.sh` for data
regeneration and provenance validation. Research JSON and its tools remain
outside the public repository.

Create a local Revival ZIP with
`python3 tools/build_products.py --product revival --package`. The builder
does not deploy or publish. Forever's development TOC uses Interface `0`
explicitly as an unknown value. A Forever ZIP requires `--product forever
--package --interface <verified-client-interface>`; this records an actual
client value but does not establish API or in-game compatibility. Existing
Revival release tags and the shared deployer at
`/home/msminipc/projects/wow-addon-deployer` do not publish or install Forever.
The stable local entrypoint is `/home/msminipc/bin/deploy-wow-addons-pc`; do not
add a private deploy-script copy to this repository.
