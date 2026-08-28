# Changelog

## 0.2.0

- Restored all 20 original Classic dungeons and all seven Classic raids to the
  Burning Crusade catalog.
- Replaced the instance-list paging arrows with mouse-wheel scrolling and a
  draggable vertical scrollbar.
- Removed internal map-position review labels from the encounter details.
- Added all 16 Burning Crusade dungeons in separate TBC runtime data modules.
- Added Normal and Heroic encounter and loot filtering with a remembered
  per-instance difficulty selection.
- Added 63 TBC dungeon encounters and 979 difficulty-scoped loot records.
- Added all nine Burning Crusade raids across phases 1–5, including 59 raid
  encounters and 827 boss, quest, timed-reward, and curated trash relations.
- Added Tier 4, Tier 5, Tier 6, and Sunwell turn-in token labels.
- Added a content-phase label to the selected instance summary.
- Expanded the floor picker for Karazhan's 17 client map pages.
- Corrected the Old Hillsbrad tile naming mode and the Serpentshrine Cavern
  WorldMap texture folder.
- Completed 115 defensible TBC encounter markers from client-map skulls and
  shared event venues; seven variable or unmapped encounters intentionally
  remain selectable without a static marker.
- Split Sunwell Plateau into its outdoor and Shrine of the Eclipse map sections
  and corrected Shade of Akama to Black Temple floor 2.
- Added explicit pending states for independently confirmed loot relations that
  do not yet have a defensible numeric drop estimate.
- Reconciled TBC dungeon difficulty membership and added 138 independently
  confirmed Heroic Badge, gem, and seasonal loot relationships; removed one
  invalid Heroic quest-item relationship.
- Rebuilt every displayed TBC percentage from direct Wowhead `count/outof`
  samples of at least 100 kills. Each boss-and-difficulty table now uses one
  exact source entity, phase, mode, snapshot, and denominator.
- Retained Atlas-derived percentages only as historical reconciliation records;
  they no longer participate in canonical or runtime rate selection.
- Resolved 1,504 TBC boss-loot variants from 153 uniform cohorts. Another 205
  ordinary variants remain without a defensible sample, while all 77 Badge of
  Justice and 12 conditional Winter Hat relationships intentionally omit
  misleading `count/outof` percentages.
- Added 28 schema-valid quest-objective difficulty relations with exact quest
  IDs and reclassified four Mechanar cache-key relations as ordinary loot.
- Added regression audits for all Badge relationships, 150 confirmed Heroic
  gem relations, and all 54 raid turn-in token assignments.
- Replaced the user-facing Pending label with a neutral em dash while retaining
  the fail-closed review state in canonical data.
- Removed misleading numeric estimates from the conditional Red and Green
  Winter Hat relationships.
- Prepared version 0.2.0 packaging and CI for both the Era and TBC TOCs.
- Added the TBC-only Deadman's Hand relation, kept three unresolved Classic
  world-drop relations Era-only, and removed obsolete faction restrictions
  from 19 legacy Paladin/Shaman loot rows on the TBC client.

## 0.1.2

- Corrected every Classic dungeon recommended-level range and ordered the
  dungeon selector from lower to higher recommended level.
- Replaced the redundant `Recommended 60–60` raid range with `Level 60 raid`.
- Added compact in-window options for minimap visibility, automatic instance
  selection, drop estimates, map marker size, window scale, and UI reset.

## 0.1.1

- Enlarged the instance map while keeping its original 4:3 proportions.
- Compacted estimated drop values and moved the estimate label into the column heading.
- Added ellipsis truncation for long item names while preserving full native tooltips.
- Replaced the small feedback icon with a full-width clickable status link.

## 0.1.0

First full Classic Era release.

- Added all 20 original Classic dungeons and seven level-60 raids.
- Added multi-floor maps and clickable boss locations.
- Added complete boss-loot browsing with estimated drop rates.
- Added boss-dropped quest items directly to boss loot lists.
- Added turn-in token labels for class, quest, and reputation rewards.
- Added curated Trash Drops sections for notable non-boss loot.
- Added automatic current-instance selection when opening the browser.
- Added separate Dungeons and Raids catalogs.
- Added instance and map-section dropdowns for faster navigation.
- Added encounter pickers for nearby and shared map locations.
- Added native item tooltips and compact paging for long encounter and loot lists.
- Added a draggable minimap button and an assignable key binding.
- Added an in-game link for reporting data and marker issues on CurseForge.
- Added a movable, proportionally resizable window with saved position and size.
- Corrected and recalibrated map floors, texture paths, and encounter markers.
