# Change log — 10k's Ultimate ARPG Camera

Versioning: the third digit counts meaningful changes since the second digit last went up (bumped automatically). The first two digits change only with explicit permission.

## 1.3.1
- **New "Halo" targeting-frame style, now the default** (existing installs switch to it once; the other four styles stay selectable). 48 small segments around the target that drain clockwise-from-the-top as it loses health; thin inner hairline; four gold ticks that turn with the rotation setting (lock-on adds a twist); gold chevron above (doubled for elite / rare / boss, colored by classification); soft bloom behind (new texture Media/halo_glow.tga); outer orange ring that pulses while the target casts or channels and fills with cast progress when the game shares the timing. Health is secret in this client: each segment is a clipped window onto one long StatusBar the game fills, so the addon never reads or compares the value; if the client refuses, the ring stays fully lit.
- **Distance readout** under the frame (all styles): exact yards for group members (UnitDistanceSquared); otherwise a bracket from your spellbook's spell ranges (up to 3 spells per range, rescanned when spells/talents change) plus the interact distances (10 / 28 yd): "20-25 yd", "< 30 yd", "40+ yd" or "melee". Elite / Rare / Boss tag after it. The bracket also drives the frame's distance scaling, replacing the old 6/20/40 yd guesses.
- Targeting Frame tab: Halo style button (style buttons narrowed to fit five); Reticle effects re-flowed into two columns with new "Casting warning", "Show distance" and "Health on halo" tickboxes; "Ring on elite / rare / boss" renamed "Elite / rare marker". `/acam framestyle` cycles through Halo too.

## 1.3.0 (released 2026-10-18)
Rolls up 1.2.1 – 1.2.6: the Talk situation (renamed from Conversation) holds, eases out gently and no longer jolts; moving speeds the exit; turn/tilt strength halved; Indoors wider than Talk; grey situation buttons.

### 1.2.6
- Leaving Talk while moving speeds the transition out: progress runs 1 + 0.8 x ground speed times faster (about 3x walking, 6x running, capped at 8x). Standing still keeps the slow gentle ease.

### 1.2.5
- Fixed the camera jolt when an NPC window opens or closes (all presets). The game's interact focus snapped onto the NPC when the interaction started and let go when it ended. Now the focus is dropped the moment an interaction starts (interaction events, before the window draws), held off while any NPC window is open, during the Talk hold and while easing out of Talk, then faded back in over 2.5 s. Applies whether or not the Talk situation is switched on.

### 1.2.4
- Talk holds for 3 seconds after the last NPC window closes (gossip, quest, vendor, trainer, bank, auction house), so accepting / turning in several quests doesn't drop out of Talk between dialogs. Reopening a window restarts the hold; moving (any ground speed) ends it at once. Leaving Talk after the hold uses a 0.2 s switch delay (was 0.6 s).
- Leaving Talk (to anything but Combat / Dungeon) eases out over 1.5x the destination's transition time, at least 2.5 s and at most 4.5 s, and the game's camera-follow speed (yaw/pitch smoothing) starts at 30% and recovers to normal by the end of the transition, so the camera no longer snaps down or to the side when a dialog closes. Previews are unaffected.

### 1.2.3
- Target turn and tilt strength roughly halved in every preset and situation. Talk keeps a strong pull (0.7) so the camera stays on the NPC; Controller combat stays highest (0.55 / 0.45).

### 1.2.2
- The Conversation situation is now called Talk everywhere. Situation buttons are dark grey with no colored underline; the situation names keep their colors.

### 1.2.1

- Presets: Indoors is now wider than Conversation in every preset that uses both. Default indoors FOV 70 / 5 yd vs conversation 58 / 4 yd; Cinematic 60 / 4.5 yd vs 50 / 3.2 yd; Tactical conversation 72 / 5 yd vs indoors 85; Controller 70 / 5 yd vs 54 / 3.5 yd. Comfort is unchanged (one steady view, situations off).

## 1.2.0 (delivered)
- Field of view limited to 50–85 (the game caps at 85): slider, `/acam fov`, imports, presets, saved settings and the speed/crowd widening are all clamped to 85. Presets that used 88/90 now use 85.

- Targeting Frame tab: new "Nameplates" section (re-checks and re-writes each switch about once a second, reads back, reports any the game refuses; /acam nameplates lists them; skips and greys out kinds this client has no switch for, e.g. the friendly player/pet/totem switches are missing on WoW Forever; tries newer names such as nameplateShowFriendlyPlayers). "Control nameplates" plus 8 tickboxes (hostile/neutral/hostile players, critters & minor, enemy pets, enemy totems, friendly players, friendly NPCs, friendly pets, friendly totems). Off by default; original game values saved and restored. Not part of presets. (A nudge that re-read the options / flipped friendly players was tried and removed: it caused a taint error in the game's nameplate code.) Ticking friendly pets/minions switches friendly players off and on again (when enabled) so the game shows the pets.
- Targeting Frame tab: new "Show the frame on" section (8 tickboxes: hostile enemies, hostile players, neutral, critters, friendly NPCs, friendly players, party/raid, pets) in the right-hand column between Reticle effects and Frame position (window 672 tall). Part of presets.
- Settings window: backing plate behind the side tabs (dark panel with gold border, fades with the window opacity slider).
- **Controller situation removed; Controller preset added** (close over-the-shoulder third-person action camera: shoulder offset 2.2–3, tight follow distance 8–10, FOV 66–74, strong auto-focus, snappy combat, bigger targeting frame, no bobbing). Old saved Controller situation data is dropped on load. Welcome window and presets list show five presets.
- **Settings window works with a gamepad**: D-pad moves a gold cursor, A selects, B closes, LB/RB switch tabs, left/right adjust sliders (LT/RT = 5 steps), hint line at the bottom. Key Bindings > AddOns now has "Open the settings window" and "Turn the camera on or off" (new Bindings.xml). Gamepad note on the General tab.
- General tab: fixed the gamepad note overlapping the Macros heading (right column re-spaced).
- **Performance:** rare situations (instance, swimming, indoors, city) are checked ~3x/s instead of 10x/s and only if switched on (reset on loading screens and when previewing); targeting-frame/focus-marker checks sleep (about 1x/s) when there is no target or focus, and wake on target/focus change events; settled camera updates run 5x/s unless speed/crowd FOV is on (then 20x/s); crowd scan 2x/s with pre-built unit names; new **Battery saver** tickbox (General > Camera feel) slows all of these further and lowers targeting-frame animation rate (not part of presets).

## 1.1.1
- Situation buttons run across the top of the Situations tab with a colored "umbrella" line, tint and "Settings for:" label; switched-off situations are dimmed.
- Controller situation requires a connected controller, not just gamepad support being enabled.
- "Focus ALL targets" replaced by per-kind tickboxes (hostile, hostile players, neutral, critters, friendly NPCs, friendly players, party/raid, pets, dead) plus "Hostile targets only while in combat"; old settings and codes migrate.

## 1.1.0
- Welcome window, "Right now" panel and `/acam why`, localization (Locales.lua), `/acam version`/`new`, Export selected preset.
