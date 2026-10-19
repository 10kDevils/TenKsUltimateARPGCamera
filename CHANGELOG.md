# Change log — 10k's Ultimate ARPG Camera

Versioning: the third digit counts meaningful changes since the second digit last went up (bumped automatically). The first two digits change only with explicit permission.

## 1.3.8
- **Smoother automatic field of view (widen with speed / many enemies).** The stutter came from three things: the extra was recalculated only 20 times a second while standing still or moving steadily (10 in low-CPU mode), the value was written in 0.1° steps (visible as ratcheting on a large widening), and a single quick exponential follow made every start, stop or enemy-count change show as a kink. Now the extras ease in two soft stages (quicker widening out, gentler settling back) with a smoothstep shape, are updated every frame (every other frame in low-CPU mode), and written in 0.01° steps. Resting view and the 50–90 range are unchanged.

## 1.3.7
- **Field of view fixed: 50–90 again, matching the game's own slider end to end.** The "FOV caps at 85" (1.2.0) and "stops at 80" reports were the addon's own doing: with speed / crowd widening on, the resting view was narrowed by the widening amount to "leave room" under the cap (90 - 5 = 85, later 85 - 5 = 80). Now the resting view is exactly the slider value and the widening adds on top, clipped at 90. Slider, `/acam fov`, saved settings, imports and the profile key range are 50–90. Tactical's wide views are back at 90.

## 1.3.6
- Over-the-shoulder reported not working at all (no gamepad). The addon now also manages `CameraReduceUnexpectedMovement` (sets 0 while on, original saved and restored like the other camera settings): since patch 11.0.2 it cancels `test_cameraOverShoulder` just like Keep Character Centered. Settings added in later versions are now filled into the saved originals on the next load.
- New `/acam shoulder`: shows Keep Character Centered, Reduce Unexpected Camera Movement, the shoulder offset written vs wanted, gamepad state, and any settings the game keeps changing back.

## 1.3.5
- New `/acam padtest` (about a minute, controller active): for each of 19 trials (baseline; GamePadTurnWithCamera 0/1; GamePadFaceMovementMaxAngle 180; ...Combat 0; GamePadCameraLookMaxYaw 90 / Pitch 45; cameraSmoothTrackingStyle 0; cameraSmoothStyle 1/2; GamePadCursorAutoEnable 0; GamePadCursorForTargeting 0; GamePadOverlapMouseMs 0; GamePadAnalogMovement 0; GamePadSingleActiveID 0; CameraReduceUnexpectedMovement 0; SetGamePadFreeLook true/false; GamePadEnable 0) it changes that one setting, waits 1.2 s, switches CameraKeepCharacterCentered off and watches it for 2.5 s, counting how often the game forces it back on; then restores the setting. Settings this client lacks are skipped. The guard pauses during the test. Results go to chat and `padTest` in the saved variables.

## 1.3.4
- In-game result of 1.3.3 on the Steam Deck: `CameraKeepCharacterCentered` was put back 785 times; the game re-forces it continuously while gamepad mode is active, so it can't be won by re-writing. The guard now treats a setting taken back 5 times within 30 s as locked: it only retries every 30 s (no per-second fight / flicker), prints a one-time "locked" message, and `/acam debug` shows the total, "locked by the game" and who changed it.
- New diagnostics: `SetCVar` and `C_CVar.SetCVar` are post-hooked (hooksecurefunc); when a setting the addon controls is changed by other Lua code, the first 5 call stacks are saved as `cvarWho[setting]` in the saved variables. Nothing recorded while it keeps flipping = the game engine does it (not fixable from an addon).

## 1.3.3
- **Fixed the gamepad camera overriding the addon on WoW Forever.** The Steam Deck dump showed `CameraKeepCharacterCentered = 1` with a controller active (the addon writes 0): gamepad mode puts it back on, which makes the game ignore the shoulder offset and most ActionCam settings. The addon only re-sent a setting when its own value changed, so it never noticed. New guard: about once a second (every 2 s with Battery saver), and on the next frame after GAME_PAD_ACTIVE_CHANGED / GAME_PAD_CONNECTED / GAME_PAD_DISCONNECTED / CVAR_UPDATE / PLAYER_ENTERING_WORLD, every setting the addon has written is read back and re-written if the game changed it (numbers compared with a small tolerance). If the game changes the same setting back 5 times within 30 s the addon prints a one-time chat warning naming it; `/acam debug` lists every setting it had to put back and what the game had set it to.
- `/acam cvars` also uses the older `ConsoleGetAllCommands` when `C_Console.GetAllCommands` is missing (on WoW Forever only the fixed list was captured).

## 1.3.2
- New `/acam cvars [label]`: saves every camera / gamepad / soft-target related setting this client has (found through the game's console command list, plus a fixed list of known names) with its current value into the saved variables under `cvarDump[label]` (label defaults to "gamepad" or "mouse"). For working out what WoW Forever's gamepad camera overrides.

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
