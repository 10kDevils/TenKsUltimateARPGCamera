-- 10k's Ultimate ARPG Camera: an action-RPG style camera built on the game's own camera
-- settings.
--
--   * Target focus: when you target a hostile enemy, or ANY NPC (interactable
--     or not), the camera swings toward it. The strength blends in and out
--     smoothly instead of snapping.
--   * Always-on ARPG feel: dynamic pitch, over-the-shoulder offset, terrain
--     tilt, subtle head movement, smoother camera turning, no bobbing, and a
--     longer max zoom.
--   * Your original camera settings are saved the first time the addon changes
--     them and restored with /acam off.
--
-- /acam opens the settings window; /acam help lists commands.

local ADDON = "TenKsUltimateARPGCamera"
local db

-- Text for other languages: L["English text"] gives the translation from
-- Locales.lua for the player's locale, or the English text itself when there isn't one.
local L = setmetatable({}, { __index = function(_, key)
    local all = _G.TenKsUltimateARPGCamera_Locales
    local loc = all and GetLocale and all[GetLocale()]
    return loc and loc[key] or key
end })

-- Version information and release notes.
local Meta = { version = "1.3.12" }
do
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if get then
        local ok, v = pcall(get, ADDON, "Version")
        if ok and type(v) == "string" and v ~= "" then Meta.version = v end
    end
end
Meta.notes = {
    "Two new presets: Action RPG (Controller framing, steered with the mouse) and First Person (the field of view is narrow indoors and in Talk, medium in cities, combat and dungeons, wide exploring and swimming)",
    "New on the General tab: Lock the camera to the mouse, and a \"Free the cursor\" key (Key Bindings > AddOns) that frees the cursor while held, or toggles it. The cursor also comes back by itself while you type, aim a spell or have a window open. /acam mouselock",
    "Situations: a set zoom distance can now be 0 (first person)",
    "New under Situations > More: head tracking (strength, standing, moving, reaction speed) per situation, tuned for action in combat; zoom rules (exact, in only, out only, range); and, in Talk, fading the rest of the interface while a window is open",
    "New on the General tab: smooth, accelerating mouse-wheel zoom",
    "Presets now look further ahead: the camera tilts up more in exploration, cities, swimming, dungeons and combat",
    "Shoulder compensation is now set per situation: tick \"Compensate for zoom\" under Over-the-shoulder and press Edit curve to shape how the offset changes with camera distance (drag points, click to add, right-click to remove). \"Use this one curve for all situations\" shares one curve. The old Camera framing controls on the General tab are gone; your old setting became a curve",
    "Over the shoulder is now even across each preset's situations, and the presets are ordered from least to most: Comfort (0.3), Tactical (0.7), Default (1.0), Controller (1.6), Cinematic (2.2). Pick a preset again to get the new values",
    "Smoother speed and crowd field of view: the widening now eases in and out in two soft stages and is updated every frame in tiny steps, instead of in small jumps 20 times a second",
    "Field of view goes from 50 to 90 again, the same range as the game's slider, and the view now always matches the slider: speed and crowd widening add on top instead of narrowing the resting view",
    "The addon now also switches off \"Reduce unexpected camera movement\", which (since patch 11.0.2) cancels the shoulder offset. /acam shoulder checks everything the shoulder offset depends on",
    "/acam padtest: with a controller, finds which gamepad or camera setting makes the game keep the character centered",
    "When the game locks a camera setting (gamepad mode on WoW Forever keeps the character centered), the addon stops fighting it every second, so nothing flickers. /acam debug shows what is locked and who changed it",
    "Fixed: with a controller the game turned \"Keep character centered\" back on, which cancelled the shoulder offset and most of the camera. The addon now puts any camera setting the game changes back within a second",
    "/acam cvars saves every camera and gamepad setting into the addon's saved file, for troubleshooting",
    "New Halo targeting frame (now the default): a ring that drains with your target's health, pulses while it casts, and marks elites",
    "Distance under the targeting frame: exact for group members, a bracket such as 20-25 yd for anything else (worked out from your spells' ranges)",
    "Targeting Frame tab: Show distance, Health on halo and Casting warning tickboxes",
}

local DEFAULTS = {
    enabled = true,
    -- target focus
    yaw = 0.25,           -- how strongly the camera turns toward the target (0-1)
    pitch = 0.25,         -- how strongly it tilts toward the target (0-1)
    fx = true,           -- draw the four-triangle targeting frame around the target
    fxSize = 220,        -- frame height in pixels for a target about 10 yards away
    fxOffset = 0,        -- nudge the frame right (+) or left (-) in pixels
    fxSpeed = 10,        -- how fast the triangles circle the target (degrees/second, positive = clockwise, negative = counter-clockwise)
    fxAlpha = 0.75,       -- overall opacity of the targeting frame
    fxCurve = 0,       -- how much the triangles curve (0 = straight)
    fxDistShift = -8,    -- pixels the frame shifts up for far targets / down for near ones
    fxStyle = "halo",    -- "halo" (health ring), "reticle" (layered, glowing), "ring" (ground ring), "solid" triangles, or "outline" (lines)
    fxDist = true,       -- distance readout under the frame
    fxHealth = true,     -- the halo's ring drains with the target's health
    fxCast = true,       -- the halo pulses while the target is casting
    fxGlow = 0.75,        -- strength of the soft glow behind the reticle's lines (0 = none)
    fxLock = true,       -- lock-on animation when you pick a new target
    fxHit = true,        -- brief flash when the target's health changes
    fxElite = true,      -- extra ring around elite / rare / boss targets
    fxOoc = false,       -- fade the frame out while you're not in combat
    fxOocAlpha = 0.35,   -- how visible it stays out of combat (fraction of its normal opacity)
    fxEnemies = true, fxEnemyPlayers = true, fxNeutral = true, fxCritters = true, -- which targets get the frame
    fxFriendlyNpcs = true, fxFriendlyPlayers = true, fxGroup = true, fxPets = true,
    fxFriendScale = 0.8, -- friendly targets get a smaller frame (fraction of the normal size)
    fxFocus = true,      -- small marker over your focus target's nameplate
    -- which targets the camera swings toward
    focusEnemies = true,       -- hostile creatures
    focusEnemyPlayers = true,  -- hostile players (PvP)
    focusNeutral = true,       -- neutral creatures
    focusCritters = true,      -- critters
    focusFriendlyNpcs = true,  -- friendly NPCs: vendors, quest givers, guards...
    focusFriendlyPlayers = true, -- friendly players
    focusGroup = true,         -- party and raid members
    focusPets = true,          -- pets and companions
    focusDead = false,
    -- nameplates (only touched while npManage is on; the game's own values are put back when it goes off)
    lowCpu = false,   -- battery saver: slower updates for the targeting frame and the situation checks
    npManage = false,
    npEnemies = true, npEnemyMinor = true, npEnemyPets = true, npEnemyTotems = true,
    npFriendlyPlayers = true, npFriendlyNpcs = true, npFriendlyPets = true, npFriendlyTotems = true,         -- dead targets, such as a corpse you are about to loot
    combatOnly = false,  -- only focus hostile enemies while in combat
    rampTime = 1,      -- seconds to blend the focus in/out
    -- general ARPG feel
    dynamicPitch = true,
    terrainTilt = true,
    bobbing = true,     -- camera bob while moving
    shoulder = 1,        -- over-the-shoulder offset; positive = right, negative = left
    -- smooth mouse-wheel zoom (reactive zoom)
    rzOn = false,        -- bigger, quicker, accelerating wheel steps
    rzStep = 3,          -- yards per wheel notch
    rzSpeed = 40,        -- how fast the camera moves to the new distance (yards per second)
    -- Talk: fade the rest of the interface while a dialogue or vendor window is open
    talkFade = false,
    talkFadeAlpha = 0,   -- how visible the rest of the interface stays (0 = gone)
    talkKeepChat = true,
    talkKeepMinimap = false,
    talkKeepFrames = "", -- more frames to leave alone, by name, separated by commas
    mlOn = false,        -- mouse-look lock: the mouse always turns the camera, no button needed
    mlToggle = false,    -- the free-cursor key toggles the cursor (otherwise it frees it while held)
    shCompShare = false, -- one shoulder compensation curve shared by every situation
    shCompCurve = "0:1,50:1", -- the shared curve: "camera distance:multiplier" points
    zoom = 3.5,          -- max zoom factor (this client accepts up to 3.5)
    headMove = 0.75,      -- subtle camera sway from head movement (0-1)
    smooth = 1,        -- camera turning speed multiplier (lower = smoother/slower)
    followStyle = nil,   -- optional: raw value for cameraSmoothStyle (/acam follow)
    orig = nil,          -- saved original CVar values
    blendAll = false,     -- one transition time for every profile (otherwise each profile has its own)
    hideWarning = true,  -- suppress the game's "experimental camera features" popup
    taxiWorld = true,    -- use Exploration (instantly, no transitions) while on a flight path
    slowExit = false,     -- Indoors -> Exploration takes 2.5x as long
    menuAlpha = 1,       -- opacity of this settings window's background (0 = see-through, 1 = solid)
    blendTime = 1.5,     -- seconds a profile change takes to ease in (x2.5 for Indoors -> Exploration)
    profiles = nil,      -- situation profiles, built at load (see ADDON_LOADED)
}

local CV = {
    enemyEnable    = "test_cameraTargetFocusEnemyEnable",
    enemyYaw       = "test_cameraTargetFocusEnemyStrengthYaw",
    enemyPitch     = "test_cameraTargetFocusEnemyStrengthPitch",
    interactEnable = "test_cameraTargetFocusInteractEnable",
    interactYaw    = "test_cameraTargetFocusInteractStrengthYaw",
    interactPitch  = "test_cameraTargetFocusInteractStrengthPitch",
    dynamicPitch   = "test_cameraDynamicPitch",
    shoulder       = "test_cameraOverShoulder",
    headMove       = "test_cameraHeadMovementStrength",
    headStand      = "test_cameraHeadMovementStandingStrength",
    headMoving     = "test_cameraHeadMovementMovingStrength",
    headStandRate  = "test_cameraHeadMovementStandingDampRate",
    headMoveRate   = "test_cameraHeadMovementMovingDampRate",
    zoomSpeed      = "cameraZoomSpeed",
    zoom           = "cameraDistanceMaxZoomFactor",
    fov            = "cameraFov",
    terrainTilt    = "cameraTerrainTilt",
    bobbing        = "cameraBobbing",
    yawSmooth      = "cameraYawSmoothSpeed",
    pitchSmooth    = "cameraPitchSmoothSpeed",
    followStyle    = "cameraSmoothStyle",
    -- Since patch 9.0.1 the ActionCam features are mostly ignored while the
    -- character is kept centered on screen, so this must be off.
    keepCentered   = "CameraKeepCharacterCentered",
    -- Since patch 11.0.2 "Reduce unexpected camera movement" also switches the shoulder offset off.
    reduceMove     = "CameraReduceUnexpectedMovement",
}

-- Engine default turn speeds (degrees/second) that the smoothing slider scales.
local BASE_YAW_SPEED, BASE_PITCH_SPEED = 180, 90

local issecret = _G.issecretvalue or function() return false end
local getCVar = (C_CVar and C_CVar.GetCVar) or GetCVar
local setCVar = (C_CVar and C_CVar.SetCVar) or SetCVar

local missing = {}
local ramp = 0        -- current blend, 0..1
local rampGoal = 0
local focusYaw, focusPitch = 0, 0
local panel
local TargetPlate -- defined in the targeting-frame section below

local function Print(msg)
    print("|cff33ff9910k's Ultimate ARPG Camera:|r " .. msg)
end

---------------------------------------------------------------------------
-- Situation profiles
--
-- Each profile has its own field of view, shoulder offset, max zoom factor,
-- head movement, target turn/tilt strength, vignette, letterbox bars and so on:
--   world      - the base profile, used whenever no other profile applies
--   instance   - inside a dungeon, raid or scenario
--   combat     - while you're in combat
--   npc        - while talking to an NPC (gossip, quest, vendor, trainer, bank...)
--   swimming   - while swimming
--   indoors    - while you're indoors
--   city       - while resting (cities and inns)
-- When several apply, the first one in that order wins. Every profile except
-- the world profile only takes effect when it's switched on.
---------------------------------------------------------------------------

local PROFILES = { "world", "combat", "indoors", "swimming", "city", "npc", "instance" }
local PROFILE_NAMES = {
    world = L["Exploration"], combat = L["Combat"], indoors = L["Indoors"], swimming = L["Swimming"],
    city = L["City"], npc = L["Talk"], instance = L["Dungeon / Raid"],
}
local PROFILE_COLORS = {
    world = { 0.45, 0.85, 0.35 }, combat = { 1.00, 0.35, 0.30 }, indoors = { 1.00, 0.65, 0.25 }, swimming = { 0.35, 0.70, 1.00 },
    city = { 1.00, 0.85, 0.30 }, npc = { 0.75, 0.50, 1.00 }, instance = { 0.25, 0.85, 0.80 },
}
local PROFILE_INFO = { -- short button label, and what the situation means
    world      = { L["Explore"],  L["The base camera. Used whenever nothing else applies."] },
    combat     = { L["Combat"],   L["While you're in combat."] },
    indoors    = { L["Indoors"],  L["While you're inside a building or cave."] },
    swimming   = { L["Swim"],     L["While you're swimming."] },
    city       = { L["City"],     L["While you're resting: in cities and inns."] },
    npc        = { L["Talk"],     L["While a conversation or vendor window is open: gossip, quests, vendors, trainers, the bank, the auction house."] },
    instance   = { L["Dungeon"],  L["Inside a dungeon, raid or scenario. Wins over Combat there, so the whole run keeps one steady camera."] },
}
local PROFILE_KEYS = { "fov", "shoulder", "zoom", "headMove", "yaw", "pitch", "tilt", "vigAlpha", "vigRange", "vigCurve",
    "lbSize", "fovSpeed", "crowdFov", "headStand", "headMoving", "headReact" }
local PROFILE_KEY_DEFAULTS = { vigAlpha = 0, vigRange = 0.3, vigCurve = 2, lbSize = 0, fovSpeed = 0, crowdFov = 0,
    headStand = 0.3, headMoving = 0.5, headReact = 10 } -- the last three are the game's own values
local activeProfile = "world"
local editProfile = "world" -- the one shown in the settings window

-- Value of a profile setting for whichever profile is active right now.
local function Cur(key)
    local p = db.profiles and db.profiles[activeProfile]
    if p and p[key] ~= nil then return p[key] end
    return db.profiles.world[key]
end

-- True while riding a flight path / taxi.
local function OnTaxi()
    if not (db and db.taxiWorld ~= false and UnitOnTaxi) then return false end
    local ok, t = pcall(UnitOnTaxi, "player")
    return ok and not issecret(t) and t and true or false
end

-- Situation checks. Each answers true/false and never errors, even when the
-- game hands back a secret value.
local previewProfile -- set while the settings window is previewing a situation
local Detect = {}
function Detect.flag(fn, ...)
    if not fn then return false end
    local ok, v = pcall(fn, ...)
    return ok and not issecret(v) and v and true or false
end
local NPC_FRAMES = { "GossipFrame", "QuestFrame", "MerchantFrame", "ClassTrainerFrame", "TrainerFrame",
    "BankFrame", "AuctionHouseFrame" }
function Detect.npc()
    for _, name in ipairs(NPC_FRAMES) do
        local f = _G[name]
        if f and Detect.flag(f.IsShown, f) then return true end
    end
    return false
end
function Detect.instance()
    if not IsInInstance then return false end
    local ok, inside, kind = pcall(IsInInstance)
    if not ok or issecret(inside) or not inside then return false end
    return kind == "party" or kind == "raid" or kind == "scenario"
end
Detect.pad = { at = -100, on = false, why = "" }
-- A gamepad counts when the game's gamepad support is switched on AND a controller is actually connected.
-- (The setting alone is not enough: it can be on with nothing plugged in.)
function Detect.gamepad()
    local now = GetTime()
    local pad = Detect.pad
    if now - pad.at < 1 then return pad.on, pad.why end -- cheap to ask, but it hardly ever changes
    pad.at = now
    local on, why = false, "no gamepad support in this client"
    if C_GamePad and C_GamePad.IsEnabled then
        if not Detect.flag(C_GamePad.IsEnabled) then
            why = "gamepad support is switched off in the game's settings"
        elseif C_GamePad.GetAllDeviceIDs then
            local ok, ids = pcall(C_GamePad.GetAllDeviceIDs)
            if ok and not issecret(ids) and type(ids) == "table" then
                if #ids > 0 then on, why = true, "gamepad enabled and connected"
                else why = "gamepad support is on, but no controller is connected" end
            else
                on, why = true, "gamepad enabled"
            end
        else
            on, why = true, "gamepad enabled"
        end
    else
        local v = getCVar("GamePadEnable")
        if v == "1" or v == 1 then on, why = true, "gamepad enabled" else why = "gamepad support is off" end
    end
    pad.on, pad.why = on, why
    return on, why
end

-- One line per situation, in priority order: is it switched on, is its
-- condition true right now, and why. Used by the "Right now" panel and /acam why.
function Detect.explain()
    local P = db.profiles
    local rows = {}
    local function add(key, cond, yes, no)
        rows[#rows + 1] = { key = key, on = key == "world" or P[key].on and true or false, cond = cond, reason = cond and yes or no }
    end
    local open
    for _, name in ipairs(NPC_FRAMES) do
        local f = _G[name]
        if f and Detect.flag(f.IsShown, f) then open = name break end
    end
    local inInst, kind = false, nil
    if IsInInstance then
        local ok, a, b = pcall(IsInInstance)
        if ok and not issecret(a) and a then inInst, kind = true, b end
    end
    add("instance", Detect.instance(), L["inside an instance"] .. (kind and (" (" .. tostring(kind) .. ")") or ""),
        inInst and L["in an instance that doesn't count (battleground or arena)"] or L["not in a dungeon, raid or scenario"])
    add("combat", Detect.flag(UnitAffectingCombat, "player"), L["in combat"], L["not in combat"])
    add("npc", open ~= nil, open and (L["window open: "] .. open) or "", L["no conversation window open"])
    add("swimming", Detect.flag(IsSwimming), L["swimming"], L["not swimming"])
    add("indoors", Detect.flag(IsIndoors), L["indoors"], L["not indoors"])
    add("city", Detect.flag(IsResting), L["resting"], L["not resting"])
    rows[#rows + 1] = { key = "world", on = true, cond = true, reason = L["the base camera"] }
    return rows
end

-- The situations that change rarely (a loading screen, a swim, a doorway, an inn) are asked about a few times a
-- second instead of ten, and only for situations that are switched on. Combat and conversations stay quick.
Detect.slow = { at = -1, instance = false, swimming = false, indoors = false, city = false }
function Detect.refreshSlow(force)
    local sl = Detect.slow
    local now = GetTime and GetTime() or 0
    if not force and now - sl.at < (db and db.lowCpu and 0.6 or 0.3) then return sl end
    sl.at = now
    local P = db.profiles
    sl.instance = P.instance.on and Detect.instance() or false
    sl.swimming = P.swimming.on and Detect.flag(IsSwimming) or false
    sl.indoors = P.indoors.on and Detect.flag(IsIndoors) or false
    sl.city = P.city.on and Detect.flag(IsResting) or false
    return sl
end

-- Talk lingers: after the last NPC window closes, the Talk camera holds for a few seconds, so hopping
-- between quest dialogs (accept one, turn in the next) doesn't swing the camera out and back each time.
-- Moving ends the hold straight away.
Detect.TALK_HOLD = 3
function Detect.speed()
    if not GetUnitSpeed then return 0 end
    local ok, v = pcall(GetUnitSpeed, "player")
    return ok and type(v) == "number" and not issecret(v) and v or 0
end
function Detect.moving() return Detect.speed() > 0 end
function Detect.TalkHeld()
    local now = GetTime and GetTime() or 0
    if Detect.npc() then Detect.talkAt = now return true end
    local at = Detect.talkAt
    if not at then return false end
    if activeProfile ~= "npc" or now - at > Detect.TALK_HOLD or Detect.moving() then
        Detect.talkAt = nil
        return false
    end
    return true
end

-- Which profile should be active right now?
local function WantedProfile()
    if OnTaxi() then return "world" end
    if previewProfile then return previewProfile end
    local P = db.profiles
    local sl = Detect.refreshSlow(previewProfile ~= nil)
    if sl.instance then return "instance" end
    if P.combat.on and Detect.flag(UnitAffectingCombat, "player") then return "combat" end
    if P.npc.on and Detect.TalkHeld() then return "npc" end
    if sl.swimming then return "swimming" end
    if sl.indoors then return "indoors" end
    if sl.city then return "city" end
    return "world"
end

---------------------------------------------------------------------------
-- CVar helpers
---------------------------------------------------------------------------

local hasCache = {}      -- does this client have this CVar? (asked once)
local written = {}       -- last text written to each CVar, so unchanged values aren't re-sent
local function Has(name)
    local h = hasCache[name]
    if h == nil then
        h = getCVar(name) ~= nil
        hasCache[name] = h
    end
    return h
end

-- Forget what we think the CVars hold (they may have been changed elsewhere,
-- e.g. by the game on a loading screen), so the next write really goes out.
local NP = { written = {} } -- nameplate switches, filled in below
local function ForgetWrites()
    written = {}
    NP.written = {}
end

local function SaveOriginals()
    -- saved once (cleared again by RestoreOriginals); settings added in later versions are filled in
    db.orig = db.orig or {}
    for _, name in pairs(CV) do
        if db.orig[name] ~= nil then name = nil end
        local v = name and getCVar(name)
        if v ~= nil then db.orig[name] = v end
    end
end

local function SetC(name, value)
    if not Has(name) then
        missing[name] = true
        return
    end
    if type(value) == "boolean" then value = value and 1 or 0 end
    local text = tostring(value)
    if written[name] == text then return end
    written[name] = text
    pcall(setCVar, name, text)
end

-- Guard: the game can put camera settings back behind the addon's back. Switching to a gamepad on
-- WoW Forever turns "Keep character centered" back on, for example, which silently cancels the shoulder
-- offset and most of the action camera. About once a second (and straight away on gamepad and setting
-- changes) every setting the addon has written is read back and written again if it was changed.
do
    local fixes, warned = {}, {}
    local function differs(a, b)
        local x, y = tonumber(a), tonumber(b)
        if x and y then return math.abs(x - y) > 0.005 end
        return tostring(a) ~= tostring(b)
    end
    -- A setting the game takes back again and again is locked by the game (WoW Forever's gamepad mode
    -- does this to "Keep character centered"). Fighting it every second only causes flicker, so after
    -- 5 take-backs in 30 seconds the addon only tries again every 30 seconds.
    function Detect.guard()
        if not (db and db.enabled) or Detect.testing then return end
        local now = GetTime and GetTime() or 0
        for name, text in pairs(written) do
            local f = fixes[name]
            if not (f and f.locked and now - f.last < 30) then
                local ok, cur = pcall(getCVar, name)
                if ok and cur ~= nil and not issecret(cur) and differs(cur, text) then
                    Detect.guardWriting = true
                    pcall(setCVar, name, text)
                    Detect.guardWriting = nil
                    f = f or { n = 0, total = 0, since = now }
                    if now - f.since > 30 then f.n, f.since = 0, now end
                    f.n, f.total = f.n + 1, f.total + 1
                    f.last, f.from = now, tostring(cur)
                    f.locked = f.n >= 5 or nil
                    fixes[name] = f
                    if f.locked and not warned[name] then
                        warned[name] = true
                        Print(string.format(L["The game keeps switching %s back to %s, so this setting is locked while it does. /acam debug has details."], name, tostring(cur)))
                    end
                end
            end
        end
    end

    -- Who changes it? Records the Lua call stack (if a Lua file does it) the first few times a setting the
    -- addon controls is changed by someone else, into the saved file as cvarWho. If nothing is ever recorded
    -- while the setting keeps flipping, the game engine itself is doing it.
    local function Watch(name, value)
        if Detect.guardWriting or type(name) ~= "string" or written[name] == nil then return end
        if not differs(value, written[name]) then return end
        db.cvarWho = db.cvarWho or {}
        local list = db.cvarWho[name] or {}
        db.cvarWho[name] = list
        if #list < 5 then
            list[#list + 1] = { value = tostring(value), when = date and date("%H:%M:%S") or "",
                stack = debugstack and debugstack(3, 8, 0) or "?" }
        end
    end
    if hooksecurefunc then
        if SetCVar then pcall(hooksecurefunc, "SetCVar", Watch) end
        if C_CVar and C_CVar.SetCVar then pcall(hooksecurefunc, C_CVar, "SetCVar", Watch) end
    end
    Detect.guardFixes = fixes

    -- /acam padtest: with the controller in use, tries one gamepad / camera setting at a time and checks whether
    -- "Keep character centered" stays off with it. Each trial: change the setting, wait, switch centering off,
    -- then watch it for 2.5 seconds. Everything is put back afterwards. Results go to chat and to the saved file.
    local KC = "CameraKeepCharacterCentered"
    local TRIALS = {
        { "nothing changed (baseline)" },
        { "GamePadTurnWithCamera = 0", cvar = "GamePadTurnWithCamera", v = "0" },
        { "GamePadTurnWithCamera = 1", cvar = "GamePadTurnWithCamera", v = "1" },
        { "GamePadFaceMovementMaxAngle = 180", cvar = "GamePadFaceMovementMaxAngle", v = "180" },
        { "GamePadFaceMovementMaxAngleCombat = 0", cvar = "GamePadFaceMovementMaxAngleCombat", v = "0" },
        { "GamePadCameraLookMaxYaw = 90", cvar = "GamePadCameraLookMaxYaw", v = "90" },
        { "GamePadCameraLookMaxPitch = 45", cvar = "GamePadCameraLookMaxPitch", v = "45" },
        { "cameraSmoothTrackingStyle = 0", cvar = "cameraSmoothTrackingStyle", v = "0" },
        { "cameraSmoothStyle = 1", cvar = "cameraSmoothStyle", v = "1" },
        { "cameraSmoothStyle = 2", cvar = "cameraSmoothStyle", v = "2" },
        { "GamePadCursorAutoEnable = 0", cvar = "GamePadCursorAutoEnable", v = "0" },
        { "GamePadCursorForTargeting = 0", cvar = "GamePadCursorForTargeting", v = "0" },
        { "GamePadOverlapMouseMs = 0", cvar = "GamePadOverlapMouseMs", v = "0" },
        { "GamePadAnalogMovement = 0", cvar = "GamePadAnalogMovement", v = "0" },
        { "GamePadSingleActiveID = 0", cvar = "GamePadSingleActiveID", v = "0" },
        { "CameraReduceUnexpectedMovement = 0", cvar = "CameraReduceUnexpectedMovement", v = "0" },
        { "free look on", fn = "SetGamePadFreeLook", v = true },
        { "free look off", fn = "SetGamePadFreeLook", v = false },
        { "GamePadEnable = 0 (controller switched off)", cvar = "GamePadEnable", v = "0" },
    }
    local pt = { frame = CreateFrame("Frame") }
    local function apply(t, undo)
        if t.cvar then
            if undo then
                if t.old ~= nil then pcall(setCVar, t.cvar, t.old) end
            else
                local ok, old = pcall(getCVar, t.cvar)
                t.old = ok and old or nil
                if t.old == nil then return false end
                pcall(setCVar, t.cvar, t.v)
            end
        elseif t.fn then
            local f = _G[t.fn]
            if not f then return false end
            if undo then pcall(f, false) else pcall(f, t.v) end
        end
        return true
    end
    local function finish()
        pt.frame:SetScript("OnUpdate", nil)
        Detect.testing = nil
        pcall(setCVar, KC, "0")
        Print(L["Pad test done. Results:"])
        for _, line in ipairs(db.padTest.results) do print("  " .. line) end
        Print(L["Type /reload and send the saved file if you want me to look at it."])
        Detect.guardSoon = true
    end
    function Detect.padTest()
        if Detect.testing then Print(L["The pad test is already running."]) return end
        local on, why = Detect.gamepad()
        Detect.testing = true
        db.padTest = { when = date and date("%Y-%m-%d %H:%M:%S") or "", gamepad = on and true or false, why = why, results = {} }
        Print(L["Pad test: keep the controller in your hands and stand still for about a minute. Touch a stick now and then so the game keeps treating the controller as active."])
        local i, phase, t0, reverts, okTrial = 0, "next", 0, 0, true
        pt.frame:SetScript("OnUpdate", function(_, dt)
            local now = GetTime()
            if phase == "next" then
                if i > 0 then apply(TRIALS[i], true) end
                i = i + 1
                if i > #TRIALS then finish() return end
                okTrial = apply(TRIALS[i])
                if not okTrial then
                    table.insert(db.padTest.results, TRIALS[i][1] .. ": not in this game, skipped")
                    return
                end
                phase, t0 = "settle", now
            elseif phase == "settle" and now - t0 >= 1.2 then
                pcall(setCVar, KC, "0")
                phase, t0, reverts = "watch", now, 0
            elseif phase == "watch" then
                local ok, v = pcall(getCVar, KC)
                if ok and tostring(v) ~= "0" then
                    reverts = reverts + 1
                    pcall(setCVar, KC, "0")
                end
                if now - t0 >= 2.5 then
                    local line = string.format("%s: %s", TRIALS[i][1], reverts == 0 and "CENTERING STAYS OFF" or ("forced back on " .. reverts .. " times"))
                    table.insert(db.padTest.results, line)
                    phase = "next"
                end
            end
        end)
    end
    local g = CreateFrame("Frame") -- the regular check runs from the main update loop below
    for _, ev in ipairs({ "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED", "CVAR_UPDATE",
        "PLAYER_ENTERING_WORLD" }) do
        pcall(g.RegisterEvent, g, ev)
    end
    g:SetScript("OnEvent", function() Detect.guardSoon = true end) -- check on the next frame
end

-- Nameplates ------------------------------------------------------------
-- The game decides which kinds of unit get a nameplate with a handful of switches. Several kinds share one
-- switch (hostile creatures, hostile players and neutral creatures are all "enemies" to the game), so each
-- tickbox here is one of those switches. Nothing is touched until "Control nameplates" is ticked; the
-- values the game had are saved then and put back when it is unticked or the addon is turned off.
NP.kinds = {
    { "npEnemies", "nameplateShowEnemies" },
    { "npEnemyMinor", "nameplateShowEnemyMinus" },
    { "npEnemyPets", "nameplateShowEnemyPets", "nameplateShowEnemyMinions" },
    { "npEnemyTotems", "nameplateShowEnemyTotems", "nameplateShowEnemyGuardians" },
    { "npFriendlyPlayers", "nameplateShowFriends", "nameplateShowFriendlyPlayers" },
    { "npFriendlyNpcs", "nameplateShowFriendlyNPCs" },
    { "npFriendlyPets", "nameplateShowFriendlyPets", "nameplateShowFriendlyMinions", "nameplateShowFriendlyPlayerPets", "nameplateShowFriendlyPlayerMinions" },
    { "npFriendlyTotems", "nameplateShowFriendlyTotems", "nameplateShowFriendlyGuardians", "nameplateShowFriendlyPlayerTotems", "nameplateShowFriendlyPlayerGuardians" },
}
function NP.supported(k) -- does this client have at least one switch for the kind?
    for i = 2, #k do if getCVar(k[i]) ~= nil then return true end end
    return false
end
function NP.readCurrent() -- copy what the game has now into the tickboxes (first time only)
    for _, k in ipairs(NP.kinds) do
        for i = 2, #k do
            local v = getCVar(k[i])
            if v ~= nil then db[k[1]] = (tostring(v) == "1") break end
        end
    end
    db.npInit = true
end
-- Writes every switch (no cache: the game or another addon can change them, so each call checks what is really
-- set and writes again if it differs), then reads each back. Returns the names that did not take.
-- Turn the friendly players switch off now and back on a moment later.
function NP.cyclePlayers()
    if InCombatLockdown and InCombatLockdown() then return end
    local names = {}
    for i = 2, #NP.kinds[5] do if getCVar(NP.kinds[5][i]) ~= nil then names[#names + 1] = NP.kinds[5][i] end end
    if #names == 0 then return end
    NP.cycling = true
    for _, n in ipairs(names) do pcall(setCVar, n, "0") end
    local function back()
        for _, n in ipairs(names) do pcall(setCVar, n, "1") end
        NP.cycling = false
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.25, back) else back() end
end
function NP.apply(report)
    if not (db and db.npManage) or NP.cycling then return end
    if InCombatLockdown and InCombatLockdown() then return end -- the game refuses these in combat; retried on the next refresh
    local now = GetTime and GetTime() or 0
    if not report and now - (NP.at or -10) < 1 then return end
    NP.at = now
    if not db.npOrig then
        db.npOrig = {}
        for _, k in ipairs(NP.kinds) do
            for i = 2, #k do
                local v = getCVar(k[i])
                if v ~= nil then db.npOrig[k[i]] = v end
            end
        end
    end
    local failed, changed = {}, false
    for _, k in ipairs(NP.kinds) do
        local want = db[k[1]] ~= false and "1" or "0"
        for i = 2, #k do
            local cur = getCVar(k[i])
            if cur ~= nil and tostring(cur) ~= want then -- a switch this client doesn't have is skipped
                pcall(setCVar, k[i], want)
                changed = true
                local after = getCVar(k[i])
                if after == nil or tostring(after) ~= want then failed[#failed + 1] = k[i] .. "=" .. tostring(after) end
            end
        end
    end
    NP.failed = failed
    if report then
        if #failed > 0 then
            Print(L["The game did not accept these nameplate settings: "] .. table.concat(failed, ", "))
        end
    end
    return failed
end
function NP.restore()
    if db and db.npOrig then
        if InCombatLockdown and InCombatLockdown() then return end
        for name, v in pairs(db.npOrig) do pcall(setCVar, name, v) end
        db.npOrig = nil
    end
    NP.written = {}
end

local function RestoreOriginals()
    if db.orig then
        for name, v in pairs(db.orig) do
            pcall(setCVar, name, v)
        end
        db.orig = nil
    end
    written = {}
end

---------------------------------------------------------------------------
-- Applying settings
---------------------------------------------------------------------------

-- Returns "hostile", "npc" or nil for the current target.
local focusWhy = ""   -- why FocusKind last answered what it did (shown by /acam debug)
local function Truth(fn, ...)
    local ok, v = pcall(fn, ...)
    if not ok then return nil, "error" end
    if issecret(v) then return nil, "secret" end
    return v and true or false
end

-- Critters are recognized by their creature type: id 8, or the local word for it.
-- The kinds of target the addon can focus, each with its own tick box.
local FRIENDLY_FOCUS_KEYS = { "focusFriendlyNpcs", "focusFriendlyPlayers", "focusGroup", "focusPets", "focusCritters" }
local FocusKind
do
local CRITTER_WORDS = {
    Critter = true, Kleintier = true, ["Alimaña"] = true, Bestiole = true, Animale = true, Bicho = true,
    ["Существо"] = true, ["동물"] = true, ["小动物"] = true, ["小動物"] = true,
}
local function IsCritter()
    if not UnitCreatureType then return false end
    local ok, name, id = pcall(UnitCreatureType, "target")
    if not ok or issecret(name) then return false end
    return id == 8 or (type(name) == "string" and CRITTER_WORDS[name] == true)
end


-- What kind of target is it, and is that kind switched on? Returns the kind, or nil when the camera shouldn't focus it.
-- What kind of target is this? Returns a description and the focus key for its kind (no on/off checks).
Detect.targetKind = function()
    local isPlayer = Truth(UnitIsPlayer, "target") == true
    local canAttack, why = Truth(UnitCanAttack, "player", "target")
    if canAttack == nil then canAttack = true; focusWhy = "attackable check " .. why .. ", treating as hostile" end
    local kind, key
    if canAttack then
        if isPlayer then kind, key = "hostile player", "focusEnemyPlayers"
        elseif IsCritter() then kind, key = "critter", "focusCritters"
        else
            local ok, r = pcall(UnitReaction, "player", "target")
            if ok and not issecret(r) and r == 4 then kind, key = "neutral creature", "focusNeutral"
            else kind, key = "hostile creature", "focusEnemies" end
        end
    elseif isPlayer then
        if Truth(UnitInParty, "target") or Truth(UnitInRaid, "target") then kind, key = "group member", "focusGroup"
        else kind, key = "friendly player", "focusFriendlyPlayers" end
    elseif IsCritter() then kind, key = "critter", "focusCritters"
    elseif Truth(UnitPlayerControlled, "target") then kind, key = "pet", "focusPets"
    else kind, key = "friendly NPC", "focusFriendlyNpcs" end
    return kind, key, canAttack
end

FocusKind = function()
    if not db.enabled then focusWhy = "addon disabled" return nil end
    local exists = Truth(UnitExists, "target")
    if not exists then focusWhy = "no target" return nil end
    if Truth(UnitIsDead, "target") and not db.focusDead then focusWhy = "target is dead ('Dead targets' is off)" return nil end

    local kind, key, canAttack = Detect.targetKind()
    if canAttack and db.combatOnly and not Truth(UnitAffectingCombat, "player") then
        focusWhy = kind .. ", but 'Only while you're in combat' is on and you're not in combat"
        return nil
    end

    if db[key] == false then
        focusWhy = kind .. " (that kind is switched off)"
        return nil
    end
    focusWhy = kind
    return kind
end
end

-- The over-the-shoulder offset is a fixed distance in the world, so the
-- farther the camera sits from you, the smaller that offset looks and the
-- closer the character drifts to screen center (and the nearer, the farther
-- to the side). Scaling the offset with camera distance cancels that out.
-- Values that hardly ever change, read from the game at most every few seconds.
local cachedBase, cachedBaseAt = 15, -100
local function BaseDist()
    local now = GetTime()
    if now - cachedBaseAt > 3 then
        cachedBaseAt = now
        cachedBase = tonumber(getCVar("cameraDistanceMax")) or 15
    end
    return cachedBase
end


-- Smoothed profile values -------------------------------------------------
-- `shown` holds the values actually in use (field of view, shoulder, max zoom
-- factor, head movement, turn and tilt strength). When the profile changes they
-- ease from where they were to the new profile's values over a fixed time
-- (smoothstep), rather than snapping. Leaving Indoors for Exploration takes
-- 2.5x as long, so stepping out of a building doesn't lurch.
local shown, from = {}, {}
local trans                   -- { t = 0..1, dur = seconds } while easing
local lastSet = {}            -- last value written to each CVar
local shoulderShown           -- shoulder after zoom compensation, lightly smoothed
local lastYaw, lastPitch
local zoomGlide               -- { goal, pos } while the camera is gliding to a new distance

local function Target(key)
    local v = Cur(key)
    if v == nil then v = PROFILE_KEY_DEFAULTS[key] or 0 end
    if key == "fov" then v = math.max(50, math.min(90, v)) end
    return v
end

local function Ease(t) return t * t * (3 - 2 * t) end

-- Shoulder compensation -----------------------------------------------------
-- The over-the-shoulder slider is the offset at "1.0". When a situation turns compensation on, its curve gives a
-- multiplier for every camera distance, so the character can stay put on screen as you zoom. A curve is a short
-- text, "yards:multiplier,yards:multiplier,...", with at least two points sorted by distance.
do
local Comp = {}
Detect.comp = Comp
Comp.ZMAX, Comp.VMAX, Comp.FLAT = 50, 4, "0:1,50:1"
local cache, cached = {}, 0
function Comp.parse(str)
    if type(str) ~= "string" or #str > 400 then return nil end
    local hit = cache[str]
    if hit ~= nil then return hit or nil end
    local pts = {}
    for z, v in str:gmatch("([%-%d%.]+):([%-%d%.]+)") do
        z, v = tonumber(z), tonumber(v)
        if not z or not v or z ~= z or v ~= v then pts = nil break end
        pts[#pts + 1] = { z = z, v = v }
    end
    local ok = pts ~= nil and #pts >= 2 and #pts <= 24
    if ok then
        for i, pt in ipairs(pts) do
            if pt.z < 0 or pt.z > Comp.ZMAX or pt.v < 0 or pt.v > Comp.VMAX or (i > 1 and pt.z <= pts[i - 1].z) then ok = false break end
        end
    end
    if cached > 200 then wipe(cache); cached = 0 end
    cached = cached + 1
    cache[str] = ok and pts or false
    return ok and pts or nil
end
function Comp.valid(str) return Comp.parse(str) ~= nil end
local function Num(x) return (string.format("%.3f", x):gsub("0+$", ""):gsub("%.$", "")) end
function Comp.str(pts)
    local out = {}
    for i, pt in ipairs(pts) do out[i] = Num(pt.z) .. ":" .. Num(pt.v) end
    return table.concat(out, ",")
end
-- The multiplier at a camera distance (the curve's ends hold beyond the first and last point).
function Comp.eval(pts, zoom)
    if zoom <= pts[1].z then return pts[1].v end
    local n = #pts
    if zoom >= pts[n].z then return pts[n].v end
    for i = 1, n - 1 do
        local a, b = pts[i], pts[i + 1]
        if zoom <= b.z then return a.v + (b.v - a.v) * (zoom - a.z) / (b.z - a.z) end
    end
    return pts[n].v
end
-- A curve that holds the character at the same place on screen to the degree k (0 = never, 1 = exactly).
function Comp.fromPower(k)
    local pts = {}
    for _, z in ipairs({ 0, 2, 4, 7, 10, 15, 20, 30, 40, 50 }) do
        pts[#pts + 1] = { z = z, v = math.max(0, math.min(Comp.VMAX, (math.max(z, 1) / 10) ^ k)) }
    end
    return Comp.str(pts)
end
function Comp.enabled(name)
    local p = db and db.profiles and db.profiles[name]
    return p ~= nil and p.shComp == true
end
-- The curve text a situation uses: the shared one, or its own.
function Comp.curveStr(name)
    if db.shCompShare then return db.shCompCurve end
    local p = db.profiles and db.profiles[name]
    return p and p.shCurve
end
function Comp.points(name)
    if not Comp.enabled(name) then return nil end
    return Comp.parse(Comp.curveStr(name))
end
function Comp.zoom()
    local z = GetCameraZoom and GetCameraZoom()
    if type(z) ~= "number" or issecret(z) then return 10 end
    return z
end
-- True while a curve is in play (or was, a moment ago, in the situation being left).
function Comp.active()
    return Comp.points(activeProfile) ~= nil or (trans ~= nil and trans.shFrom ~= nil and trans.shFrom ~= false)
end
-- The multiplier in use right now, easing from the old situation's curve to the new one's during a transition.
function Comp.current()
    local zoom = Comp.zoom()
    local pts = Comp.points(activeProfile)
    local m = pts and Comp.eval(pts, zoom) or 1
    if trans and trans.shFrom ~= nil then
        local fr = trans.shFrom and Comp.eval(trans.shFrom, zoom) or 1
        m = fr + (m - fr) * Ease(trans.t)
    end
    return m
end
end

-- Smooth mouse-wheel zoom ---------------------------------------------------
-- The game moves the camera one yard per wheel notch. With this on, a notch moves `rzStep` yards, notches in
-- quick succession move further (up to 3x), and the camera is allowed to travel at `rzSpeed` yards per second, so
-- zooming feels immediate instead of crawling. Only wheel-sized calls (an increment of exactly 1) are changed;
-- the addon's own glides use the original functions.
do
local Rz = { notches = {}, installed = false }
Detect.rz = Rz
Rz.rawIn, Rz.rawOut = CameraZoomIn, CameraZoomOut
local function Wrap(raw)
    return function(inc, ...)
        if inc == 1 and db and db.enabled and db.rzOn then
            local now = GetTime()
            local list = Rz.notches
            list[#list + 1] = now
            while list[1] and now - list[1] > 0.3 do table.remove(list, 1) end
            inc = (db.rzStep or 3) * (1 + math.min(2, (#list - 1) * 0.4))
        end
        return raw(inc, ...)
    end
end
-- Puts the wrappers in (or takes them out) to match the settings; call after any change.
function Rz.sync()
    local want = db and db.enabled and db.rzOn and Rz.rawIn and Rz.rawOut and true or false
    if want and not Rz.installed then
        Rz.wrapIn, Rz.wrapOut = Wrap(Rz.rawIn), Wrap(Rz.rawOut)
        CameraZoomIn, CameraZoomOut = Rz.wrapIn, Rz.wrapOut
        Rz.installed = true
    elseif not want and Rz.installed then
        if CameraZoomIn == Rz.wrapIn then CameraZoomIn = Rz.rawIn end -- someone else may have wrapped it since: leave theirs
        if CameraZoomOut == Rz.wrapOut then CameraZoomOut = Rz.rawOut end
        Rz.installed = false
    end
    if want then
        SetC(CV.zoomSpeed, string.format("%.0f", db.rzSpeed or 40))
    elseif db and db.enabled and db.orig and db.orig[CV.zoomSpeed] ~= nil then
        SetC(CV.zoomSpeed, db.orig[CV.zoomSpeed])
    end
end
end

-- Talk: fade the rest of the interface ------------------------------------------
-- While a dialogue or vendor window is open in the Talk situation, everything on screen except the windows you
-- are using fades out. The windows (and bags, popups, tooltips, and chat / minimap if wanted) are told to ignore
-- their parent's transparency, then the whole interface fades. It all goes back the moment the window closes.
do
local F = { t = 0, saved = nil, held = {}, scan = 0, closeAt = -10, prevOpen = false }
Detect.fade = F
local KEEP = { "GossipFrame", "QuestFrame", "MerchantFrame", "ClassTrainerFrame", "BankFrame", "AuctionHouseFrame",
    "PetStableFrame", "ItemTextFrame", "TabardFrame", "GuildRegistrarFrame", "PetitionFrame", "TaxiFrame", "MailFrame",
    "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4", "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1",
    "ShoppingTooltip2", "UIErrorsFrame", "ContainerFrameCombinedBags", "TenKsARPGCameraPanel", "TenKsARPGCameraCurve" }
for i = 1, 13 do KEEP[#KEEP + 1] = "ContainerFrame" .. i end
local function Keepers()
    local list = {}
    for _, n in ipairs(KEEP) do list[#list + 1] = n end
    if db.talkKeepChat ~= false then
        list[#list + 1] = "GeneralDockManager"
        for i = 1, 10 do
            list[#list + 1] = "ChatFrame" .. i
            list[#list + 1] = "ChatFrame" .. i .. "Tab"
            list[#list + 1] = "ChatFrame" .. i .. "EditBox"
        end
        list[#list + 1] = "ChatFrameMenuButton"
        list[#list + 1] = "ChatFrameChannelButton"
    end
    if db.talkKeepMinimap then list[#list + 1] = "MinimapCluster" end
    for name in tostring(db.talkKeepFrames or ""):gmatch("[^,%s]+") do list[#list + 1] = name end
    return list
end
-- Frames that exist now and are not yet ignoring the fade.
local function Hold()
    for _, name in ipairs(Keepers()) do
        local f = _G[name]
        if type(f) == "table" and f.SetIgnoreParentAlpha and F.held[f] == nil then
            local ok, was = pcall(f.IsIgnoringParentAlpha or function() return false end, f)
            F.held[f] = ok and was and true or false
            pcall(f.SetIgnoreParentAlpha, f, true)
        end
    end
end
local function Release()
    for f, was in pairs(F.held) do pcall(f.SetIgnoreParentAlpha, f, was) end
    wipe(F.held)
    if F.saved then pcall(UIParent.SetAlpha, UIParent, F.saved) end
    F.saved = nil
    F.t = 0
end
function F.reset() if F.saved or F.t > 0 then Release() end end
function F.wanted()
    if not (db and db.enabled and db.talkFade and activeProfile == "npc") then return false end
    local now = GetTime()
    local open = Detect.npc() and true or false
    if open or F.prevOpen then F.closeAt = now end
    F.prevOpen = open
    return open or now - F.closeAt < 0.6 -- a short grace so one window opening after another does not flash the interface
end
function F.step(dt)
    local want = F.wanted()
    if not want and F.t == 0 then return end
    if want and not F.saved then
        local ok, a = pcall(UIParent.GetAlpha, UIParent)
        F.saved = (ok and type(a) == "number") and a or 1
        Hold()
    end
    F.t = want and math.min(1, F.t + dt / 0.3) or math.max(0, F.t - dt / 0.5)
    F.scan = F.scan + dt
    if F.scan >= 0.25 then F.scan = 0; if F.saved then Hold() end end
    if F.saved then
        local to = math.max(0, math.min(1, db.talkFadeAlpha or 0))
        pcall(UIParent.SetAlpha, UIParent, F.saved * (1 - (1 - to) * Ease(F.t)))
    end
    if F.t <= 0 and not want then Release() end
end
end

-- Mouse-look lock ---------------------------------------------------------------
-- With mlOn the camera follows the mouse at all times, like holding the right mouse button, so you play with the
-- mouse aiming the view. The cursor comes back on its own while you type, carry an item or aim a spell, and while
-- a window such as bags, a vendor, the map, the game menu or this settings window is open. The "Free the cursor"
-- key gives it back too: while held, or until pressed again with mlToggle on.
do
local M = { owned = false, free = false, t = 1 }
Detect.ml = M
local WINDOWS = { "GameMenuFrame", "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4", "ContainerFrameCombinedBags",
    "TenKsARPGCameraPanel", "TenKsARPGCameraCurve", "TenKsARPGCameraWelcome", "LootFrame", "GroupLootFrame1" }
for i = 1, 13 do WINDOWS[#WINDOWS + 1] = "ContainerFrame" .. i end
local function Shown(name)
    local f = _G[name]
    if type(f) ~= "table" or not f.IsShown then return false end
    local ok, v = pcall(f.IsShown, f)
    return ok and v == true
end
-- true while something on screen needs the cursor
function M.busy()
    if M.free then return true end
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then return true end
    if SpellIsTargeting and Truth(SpellIsTargeting) then return true end
    if GetCursorInfo and GetCursorInfo() then return true end
    if Detect.npc and Detect.npc() then return true end
    for _, n in ipairs(WINDOWS) do if Shown(n) then return true end end
    if UISpecialFrames then
        for _, n in ipairs(UISpecialFrames) do if Shown(n) then return true end end
    end
    return false
end
local function Stop()
    if M.owned and IsMouselooking and IsMouselooking() and MouselookStop then pcall(MouselookStop) end
    M.owned = false
end
function M.reset() M.free = false; Stop() end
function M.step(dt)
    M.t = M.t + dt
    if M.t < 0.05 then return end
    M.t = 0
    if not (MouselookStart and IsMouselooking) then return end
    if not (db and db.enabled and db.mlOn) then if M.owned then Stop() end return end
    local looking = IsMouselooking()
    if M.busy() then
        if M.owned then Stop() end
        return
    end
    if looking then return end -- already turning (ours, or a held mouse button)
    M.owned = false
    if IsMouseButtonDown and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) then return end
    if pcall(MouselookStart) then M.owned = true end
end
-- the key binding: "down" / "up"
function M.key(state)
    if not db then return end
    if db.mlToggle then
        if state ~= "up" then M.free = not M.free end
    else
        M.free = state ~= "up"
    end
    M.t = 1
    M.step(0)
end
end

local function BeginTransition(oldName, newName)
    for _, k in ipairs(PROFILE_KEYS) do from[k] = shown[k] end
    local dur = db.blendTime or 1.2
    if db.blendAll == false and db.profiles and db.profiles[newName] then
        dur = db.profiles[newName].blend or dur
    end
    if db.slowExit ~= false and oldName == "indoors"
        and (newName == "world" or newName == "city") then dur = dur * 2.5 end
    -- leaving Talk: a long, gentle ease out of the close dialogue shot, and the game's own
    -- camera-follow is slowed while it runs so the view doesn't swing back behind you
    local calm = oldName == "npc" and newName ~= "combat" and newName ~= "instance" and not Detect.skipDelay
    if calm then dur = math.min(math.max(dur * 1.5, 2.5), 4.5) end
    trans = { t = 0, dur = math.max(0.2, dur), calm = calm, shFrom = Detect.comp.points(oldName) or false }
end

local function StepShown(dt)
    if next(shown) == nil then
        for _, k in ipairs(PROFILE_KEYS) do shown[k] = Target(k) end
        return
    end
    if trans then
        -- leaving Talk while moving: the faster you go, the faster the camera gets there
        -- (walking about 3x, running about 6x)
        local rush = 1
        if trans.calm then rush = 1 + math.min(7, Detect.speed() * 0.8) end
        trans.t = math.min(1, trans.t + dt * rush / trans.dur)
        local e = Ease(trans.t)
        for _, k in ipairs(PROFILE_KEYS) do
            shown[k] = from[k] + (Target(k) - from[k]) * e
        end
        if trans.t >= 1 then trans = nil end
    else
        -- no transition: follow edits to the active profile (a slider moved)
        local k = 1 - math.exp(-dt * 12)
        for _, key in ipairs(PROFILE_KEYS) do
            local t = Target(key)
            shown[key] = shown[key] + (t - shown[key]) * k
            if math.abs(t - shown[key]) < 0.002 then shown[key] = t end
        end
    end
end

local function Put(name, value, tol, fmt)
    if lastSet[name] == nil or math.abs(value - lastSet[name]) >= tol then
        lastSet[name] = value
        SetC(name, string.format(fmt or "%.3f", value))
    end
end

local function EffectiveShoulder()
    return math.max(-20, math.min(20, (shown.shoulder or 0) * Detect.comp.current()))
end

local ApplyRamp -- defined below

-- Glide the camera to a new distance with small zoom steps instead of one jump.
local function StepZoomGlide(dt)
    local g = zoomGlide
    if not g then return end
    local zin, zout = Detect.rz.rawIn or CameraZoomIn, Detect.rz.rawOut or CameraZoomOut
    if not (zin and zout) then zoomGlide = nil return end
    local rate = 3 / math.max(0.4, trans and trans.dur or (db.blendTime or 1.2))
    local nextPos = g.pos + (g.goal - g.pos) * (1 - math.exp(-dt * rate))
    local delta = nextPos - g.pos
    if math.abs(delta) > 0.004 then
        pcall(delta < 0 and zin or zout, math.abs(delta))
        g.pos = nextPos
    end
    if math.abs(g.goal - g.pos) < 0.05 then zoomGlide = nil end
end


-- Screen-edge vignette ------------------------------------------------------
-- Darkens the edges of the screen. Each situation sets how dark it gets
-- (opacity), how far it reaches in (range, as a fraction of the screen), and the
-- curve of the fade: opacity = max * (1 - d)^curve, where d runs from 0 at the
-- screen edge to 1 at the inner end of the range. 1 is a straight fade; higher
-- values keep it hugging the edge, lower values let it reach further in.
-- It is four edges, each cut into slices with a gradient across each slice, so
-- the fade is smooth. It sits under the interface (BACKGROUND strata).
local VigApply, VigHide
do
local VIG_SLICES = 10
local vigFrame, vigSlices
local vigLast = { a = -1, r = -1, c = -1 }
local vigLayoutKey, vigWidth, vigHeight
local vigStamp = 0

local function VigGradient(tx, vertical, lowA, highA)
    -- "low" is the bottom (vertical) or left (horizontal) end of the slice
    local orient = vertical and "VERTICAL" or "HORIZONTAL"
    if tx.SetGradientAlpha then
        tx:SetGradientAlpha(orient, 0, 0, 0, lowA, 0, 0, 0, highA)
    elseif tx.SetGradient and CreateColor then
        tx:SetGradient(orient, CreateColor(0, 0, 0, lowA), CreateColor(0, 0, 0, highA))
    else
        tx:SetColorTexture(0, 0, 0, (lowA + highA) / 2)
    end
end

local function VigBuild()
    vigFrame = CreateFrame("Frame", nil, UIParent)
    vigFrame:SetAllPoints(UIParent)
    vigFrame:SetFrameStrata("BACKGROUND")
    vigFrame:EnableMouse(false)
    vigSlices = { top = {}, bottom = {}, left = {}, right = {} }
    for _, edge in ipairs({ "top", "bottom", "left", "right" }) do
        for i = 1, VIG_SLICES do
            local tx = vigFrame:CreateTexture(nil, "BACKGROUND")
            tx:SetColorTexture(0, 0, 0, 1)
            vigSlices[edge][i] = tx
        end
    end
end

VigHide = function()
    if vigFrame and vigFrame:IsShown() then vigFrame:Hide() end
    vigLast.a = -1
end

-- a = opacity (0 = off), r = range (0.05 - 0.5), c = curve
VigApply = function(a, r, c)
    if not a or a <= 0.004 then VigHide() return end
    -- while it's easing, redraw at most 20 times a second
    local now = GetTime()
    if math.abs(a - vigLast.a) < 0.004 and math.abs(r - vigLast.r) < 0.002 and math.abs(c - vigLast.c) < 0.01 then return end
    if now - vigStamp < 0.05 and vigLast.a >= 0 then return end
    vigStamp = now

    if not vigFrame then VigBuild() end
    if not vigFrame:IsShown() then vigFrame:Show() end
    local w = tonumber(UIParent:GetWidth()) or 1920
    local h = tonumber(UIParent:GetHeight()) or 1080
    local depthH, depthW = h * r, w * r
    local layoutKey = depthH * 1000 + depthW
    if layoutKey ~= vigLayoutKey then
        vigLayoutKey = layoutKey
        for i = 1, VIG_SLICES do
            local d0, d1 = (i - 1) / VIG_SLICES, i / VIG_SLICES
            local t = vigSlices.top[i]
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", vigFrame, "TOPLEFT", 0, -d0 * depthH)
            t:SetPoint("TOPRIGHT", vigFrame, "TOPRIGHT", 0, -d0 * depthH)
            t:SetHeight(math.max(0.5, (d1 - d0) * depthH))
            local b = vigSlices.bottom[i]
            b:ClearAllPoints()
            b:SetPoint("BOTTOMLEFT", vigFrame, "BOTTOMLEFT", 0, d0 * depthH)
            b:SetPoint("BOTTOMRIGHT", vigFrame, "BOTTOMRIGHT", 0, d0 * depthH)
            b:SetHeight(math.max(0.5, (d1 - d0) * depthH))
            local l = vigSlices.left[i]
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", vigFrame, "TOPLEFT", d0 * depthW, 0)
            l:SetPoint("BOTTOMLEFT", vigFrame, "BOTTOMLEFT", d0 * depthW, 0)
            l:SetWidth(math.max(0.5, (d1 - d0) * depthW))
            local rt = vigSlices.right[i]
            rt:ClearAllPoints()
            rt:SetPoint("TOPRIGHT", vigFrame, "TOPRIGHT", -d0 * depthW, 0)
            rt:SetPoint("BOTTOMRIGHT", vigFrame, "BOTTOMRIGHT", -d0 * depthW, 0)
            rt:SetWidth(math.max(0.5, (d1 - d0) * depthW))
        end
    end
    for i = 1, VIG_SLICES do
        local d0, d1 = (i - 1) / VIG_SLICES, i / VIG_SLICES
        local a0 = a * (1 - d0) ^ c   -- opacity on the screen-edge side of the slice
        local a1 = a * (1 - d1) ^ c   -- opacity on the inner side
        VigGradient(vigSlices.top[i], true, a1, a0)       -- top edge: outer end is the top
        VigGradient(vigSlices.bottom[i], true, a0, a1)    -- bottom edge: outer end is the bottom
        VigGradient(vigSlices.left[i], false, a0, a1)     -- left edge: outer end is the left
        VigGradient(vigSlices.right[i], false, a1, a0)    -- right edge: outer end is the right
    end
    vigLast.a, vigLast.r, vigLast.c = a, r, c
end

-- the screen size or UI scale changed: lay the slices out again on the next update
local vigEvents = CreateFrame("Frame")
vigEvents:RegisterEvent("DISPLAY_SIZE_CHANGED")
vigEvents:RegisterEvent("UI_SCALE_CHANGED")
vigEvents:SetScript("OnEvent", function() vigLayoutKey = nil; vigLast.a = -1 end)
end

-- Letterbox bars -------------------------------------------------------------
-- Two black bars, top and bottom, for a cinematic frame. Each situation sets
-- their height as a fraction of the screen height (0 = none). They sit under
-- the interface, so your frames and bars stay on top of them.
local LbApply, LbHide
do
local lbFrame, lbTop, lbBottom
local lbLast, lbScreen = -1, 0

LbHide = function()
    if lbFrame and lbFrame:IsShown() then lbFrame:Hide() end
    lbLast = -1
end

LbApply = function(size)
    if not size or size <= 0.001 then LbHide() return end
    local h = tonumber(UIParent:GetHeight()) or 1080
    if math.abs(size - lbLast) < 0.0005 and h == lbScreen then return end
    if not lbFrame then
        lbFrame = CreateFrame("Frame", nil, UIParent)
        lbFrame:SetAllPoints(UIParent)
        lbFrame:SetFrameStrata("BACKGROUND")
        lbFrame:SetFrameLevel(5)
        lbFrame:EnableMouse(false)
        lbTop = lbFrame:CreateTexture(nil, "BACKGROUND")
        lbTop:SetColorTexture(0, 0, 0, 1)
        lbTop:SetPoint("TOPLEFT", lbFrame, "TOPLEFT", 0, 0)
        lbTop:SetPoint("TOPRIGHT", lbFrame, "TOPRIGHT", 0, 0)
        lbBottom = lbFrame:CreateTexture(nil, "BACKGROUND")
        lbBottom:SetColorTexture(0, 0, 0, 1)
        lbBottom:SetPoint("BOTTOMLEFT", lbFrame, "BOTTOMLEFT", 0, 0)
        lbBottom:SetPoint("BOTTOMRIGHT", lbFrame, "BOTTOMRIGHT", 0, 0)
    end
    lbLast, lbScreen = size, h
    lbTop:SetHeight(h * size)
    lbBottom:SetHeight(h * size)
    if not lbFrame:IsShown() then lbFrame:Show() end
end
end

-- Speed and crowd field of view ---------------------------------------------
-- Two optional extras on top of a situation's field of view. Speed widens it
-- as you move faster (full effect at mounted speed); crowd widens it when
-- several enemies are fighting you. Both are smoothed, and the extra is
-- capped at 90 degrees, the game's own maximum. The resting view always matches the slider.
local DynFov = { speed = 0, crowd = 0, enemies = 0, yps = 0 }
do
local crowdAt = -100
local NPUNITS = {}
for i = 1, 40 do NPUNITS[i] = "nameplate" .. i end -- built once, not on every scan
function DynFov.step(dt, wantSpeed, wantCrowd)
    local goalS, goalC = 0, 0
    if wantSpeed and GetUnitSpeed then
        local ok, v = pcall(GetUnitSpeed, "player")
        if ok and type(v) == "number" and not issecret(v) then
            DynFov.yps = v
            goalS = math.max(0, math.min(1, v / 14))
        end
    end
    if wantCrowd and Detect.flag(UnitAffectingCombat, "player") then
        local now = GetTime()
        if now - crowdAt > 0.5 then
            crowdAt = now
            local n = 0
            for i = 1, 40 do
                local unit = NPUNITS[i]
                if Detect.flag(UnitExists, unit) and Detect.flag(UnitCanAttack, "player", unit)
                    and Detect.flag(UnitAffectingCombat, unit) and not Detect.flag(UnitIsDead, unit) then
                    n = n + 1
                end
            end
            DynFov.enemies = n
        end
        goalC = math.max(0, math.min(1, (DynFov.enemies - 1) / 4)) -- 5 or more fighting you = full effect
    else
        DynFov.enemies = 0
    end
    -- two stages of easing (a soft, critically-damped-like follow) so starts, stops and enemy count changes never
    -- show as steps; the wide-out is quicker than the settle-back, and the result is shaped with a smoothstep
    DynFov.aS, DynFov.aC = DynFov.aS or 0, DynFov.aC or 0
    DynFov.bS, DynFov.bC = DynFov.bS or 0, DynFov.bC or 0
    local k1s = 1 - math.exp(-dt * (goalS > DynFov.aS and 1.6 or 0.7))
    local k1c = 1 - math.exp(-dt * (goalC > DynFov.aC and 0.9 or 0.5))
    DynFov.aS = DynFov.aS + (goalS - DynFov.aS) * k1s
    DynFov.aC = DynFov.aC + (goalC - DynFov.aC) * k1c
    local k2s, k2c = 1 - math.exp(-dt * 3), 1 - math.exp(-dt * 2)
    DynFov.bS = DynFov.bS + (DynFov.aS - DynFov.bS) * k2s
    DynFov.bC = DynFov.bC + (DynFov.aC - DynFov.bC) * k2c
    if DynFov.bS < 0.001 and goalS == 0 then DynFov.aS, DynFov.bS = 0, 0 end
    if DynFov.bC < 0.001 and goalC == 0 then DynFov.aC, DynFov.bC = 0, 0 end
    DynFov.speed = DynFov.bS * DynFov.bS * (3 - 2 * DynFov.bS)
    DynFov.crowd = DynFov.bC * DynFov.bC * (3 - 2 * DynFov.bC)
end
end

-- Runs every frame: advances the easing and writes whatever changed.
local calmWas
-- Talking to an NPC: the game's interact focus grabs the NPC the instant a window opens and lets go the
-- instant it closes, which jolts the camera. While a window is open, during the Talk hold and while easing
-- out of Talk, the focus is faded out; afterwards it fades back in slowly.
Detect.talkMul = 1
function Detect.talking()
    return (db.profiles.npc.on and Detect.talkAt ~= nil) or Detect.npc() or (trans ~= nil and trans.calm) or false
end
function Detect.stepTalkFocus(dt)
    local goal = Detect.talking() and 0 or 1
    local m = Detect.talkMul
    if m == goal then return end
    if goal < m then m = math.max(0, m - dt / 0.3) else m = math.min(1, m + dt / 2.5) end
    Detect.talkMul = m
    ApplyRamp()
end
-- the moment an NPC interaction starts, drop the focus straight away (before the window is even drawn)
do
    local f = CreateFrame("Frame")
    for _, ev in ipairs({ "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL",
        "QUEST_PROGRESS", "QUEST_COMPLETE", "MERCHANT_SHOW", "TRAINER_SHOW", "BANKFRAME_OPENED", "AUCTION_HOUSE_SHOW" }) do
        pcall(f.RegisterEvent, f, ev)
    end
    f:SetScript("OnEvent", function()
        if not (db and db.enabled) then return end
        Detect.talkMul = 0
        if ApplyRamp then ApplyRamp() end
    end)
end
-- field of view: the slider value plus the eased speed / crowd extras, written in fine steps (0.01 degree)
-- every frame while the extras are moving, so there is nothing for the eye to catch
function Detect.stepFov(dt)
    local fov = shown.fov
    local fs, cf = shown.fovSpeed or 0, shown.crowdFov or 0
    if fs > 0.05 or cf > 0.05 then
        DynFov.step(dt, fs > 0.05, cf > 0.05)
        -- the resting view is exactly what the slider says; the extras widen it up to the game's 90
        fov = fov + fs * DynFov.speed + cf * DynFov.crowd
    end
    Put(CV.fov, math.max(50, math.min(90, fov)), 0.01, "%.2f")
end
-- shoulder: the profile's value times its zoom compensation curve, lightly smoothed
function Detect.stepShoulder(dt)
    local ts = EffectiveShoulder()
    shoulderShown = shoulderShown and (shoulderShown + (ts - shoulderShown) * (1 - math.exp(-dt * 12))) or ts
    if math.abs(ts - shoulderShown) < 0.003 then shoulderShown = ts end
    Put(CV.shoulder, shoulderShown, 0.003)
end
local function StepBlend(dt, skipFov, skipSh)
    if not db or not db.enabled then return end
    StepShown(dt)
    Detect.stepTalkFocus(dt)

    -- while easing out of Talk, the camera's follow speed starts slow and recovers by the end
    local calm = trans and trans.calm
    if calm or calmWas then
        local f = calm and (0.3 + 0.7 * Ease(trans.t)) or 1
        SetC(CV.yawSmooth, string.format("%.0f", BASE_YAW_SPEED * (db.smooth or 1) * f))
        SetC(CV.pitchSmooth, string.format("%.0f", BASE_PITCH_SPEED * (db.smooth or 1) * f))
        calmWas = calm and true or nil
    end

    if not skipFov then Detect.stepFov(dt) end
    VigApply(shown.vigAlpha, shown.vigRange or 0.3, shown.vigCurve or 2)
    LbApply(shown.lbSize)

    if not skipSh then Detect.stepShoulder(dt) end

    Put(CV.headMove, shown.headMove, 0.004, "%.2f")
    Put(CV.headStand, shown.headStand or 0.3, 0.004, "%.2f")
    Put(CV.headMoving, shown.headMoving or 0.5, 0.004, "%.2f")
    Put(CV.headStandRate, shown.headReact or 10, 0.05, "%.1f")
    Put(CV.headMoveRate, shown.headReact or 10, 0.05, "%.1f")

    -- max zoom factor. While the camera is still gliding in, hold the factor at
    -- what it needs so the game doesn't snap it to the new limit mid-glide.
    local zf = shown.zoom
    if zoomGlide and GetCameraZoom then
        local cur = GetCameraZoom()
        local base = BaseDist()
        if type(cur) == "number" and not issecret(cur) then zf = math.max(zf, cur / base + 0.02) end
    end
    Put(CV.zoom, math.min(3.5, zf), 0.01, "%.2f")

    -- target focus strengths follow the eased turn/tilt values
    if lastYaw == nil or math.abs(shown.yaw - lastYaw) > 0.002 or math.abs(shown.pitch - lastPitch) > 0.002 then
        lastYaw, lastPitch = shown.yaw, shown.pitch
        if rampGoal == 1 then focusYaw, focusPitch = shown.yaw, shown.pitch end
        ApplyRamp()
    end

    StepZoomGlide(dt)
end

-- Camera tilt offset: nudges the camera's pitch up or down by the profile's
-- tilt (degrees). There's no setting for a
-- vertical camera offset, so this uses the game's own look-up / look-down
-- controls and keeps track of how far it has moved, easing there rather than
-- jumping. It pauses while you're mouse-looking and gives the tilt back when
-- the addon is turned off.
local tiltApplied, tiltMoving, tiltBase = 0, false, nil
local function StepTilt(dt)
    if not MoveViewUpStart then return end
    local wanted = 0
    if db and db.enabled then
        wanted = shown.tilt or 0
    end
    local pending = wanted - tiltApplied
    local blocked = IsMouselooking and IsMouselooking() and not Detect.ml.owned -- a held mouse button, not the lock
    if math.abs(pending) < 0.1 or blocked or dt <= 0 then
        if tiltMoving then
            pcall(MoveViewUpStart, 0); pcall(MoveViewDownStart, 0)
            tiltMoving = false
        end
        return
    end
    local rate = math.min(60, math.max(8, math.abs(pending) * 4)) -- degrees/second, slows as it arrives
    local step = math.min(math.abs(pending), rate * dt)
    local base = 90 -- the game's default pitch speed; MoveView speed is a multiplier of it
    if tiltBase == nil then tiltBase = tonumber(getCVar("cameraPitchMoveSpeed")) or 90 end
    base = tiltBase
    local m = (step / dt) / base
    if pending > 0 then
        pcall(MoveViewDownStart, 0); pcall(MoveViewUpStart, m)
        tiltApplied = tiltApplied + step
    else
        pcall(MoveViewUpStart, 0); pcall(MoveViewDownStart, m)
        tiltApplied = tiltApplied - step
    end
    tiltMoving = true
end

-- Snap the shoulder straight to its value (used when a setting changes).
local function ApplyShoulder(force)
    if force then shoulderShown = nil end
end

-- Zoom limit per profile. The farthest the camera may sit is the game's base
-- camera distance times the active profile's max zoom factor. When a profile
-- switch (or a lowered factor) puts the camera beyond that, it glides in; when
-- you switch back, the zoom you had when you left that profile returns.
local zoomMemory = {}     -- profile name -> camera distance when you left it
local lastConstrain = 0
local function ConstrainZoom(restore)
    if not (GetCameraZoom and CameraZoomIn and CameraZoomOut) then return end
    local cur = GetCameraZoom()
    if type(cur) ~= "number" or issecret(cur) then return end
    local now = GetTime()
    if not restore then
        if zoomGlide or now - lastConstrain < 1 then return end -- let a zoom in progress finish
    end

    local base = BaseDist()
    local limit = base * Cur("zoom")
    local pr = db.profiles[activeProfile]
    -- zoom rules (with "use a set zoom distance"): exactly there, only closer, only farther, or inside a range
    local kind = (pr and pr.zoomSet and pr.zoomKind) or 0
    local zlo, zhi = (pr and pr.zoomMin) or 5, (pr and pr.zoomMax) or 20
    if zlo > zhi then zlo, zhi = zhi, zlo end
    local target = cur
    if restore then
        if pr and pr.zoomSet then
            local want = pr.zoomDist or cur
            if kind == 1 then target = math.min(cur, want)           -- only zoom in
            elseif kind == 2 then target = math.max(cur, want)       -- only zoom out
            elseif kind == 3 then target = math.max(zlo, math.min(zhi, cur)) -- within a range
            else target = want end                                   -- a fixed distance for this profile
        elseif zoomMemory[activeProfile] and not (pr and pr.zoomRemember == false) then
            target = zoomMemory[activeProfile]               -- the zoom you last used here
        end
    elseif kind == 3 then
        target = math.max(zlo, math.min(zhi, cur))           -- the range also holds while you zoom
    end
    target = math.min(target, limit)

    local d = target - cur
    if (d < -0.05) or (d > 0.05 and (restore or kind == 3)) then
        lastConstrain = now
        zoomGlide = { goal = target, pos = cur }
    end
end

local function ApplyStatic()
    if not db.enabled then return end
    SetC(CV.keepCentered, 0)
    SetC(CV.reduceMove, 0)
    SetC(CV.dynamicPitch, db.dynamicPitch)
    SetC(CV.terrainTilt, db.terrainTilt)
    SetC(CV.bobbing, db.bobbing)
    -- field of view, shoulder, head movement and max zoom are eased every
    -- frame by StepBlend
    SetC(CV.yawSmooth, string.format("%.0f", BASE_YAW_SPEED * db.smooth))
    SetC(CV.pitchSmooth, string.format("%.0f", BASE_PITCH_SPEED * db.smooth))
    if db.followStyle ~= nil then SetC(CV.followStyle, db.followStyle) end
    Detect.rz.sync()
end

ApplyRamp = function()
    local tm_ = Detect.talkMul or 1
    if Detect.npc() then tm_ = 0 end -- a window is open: never let the game's focus grab the NPC
    local r_ = ramp * tm_
    local on = r_ > 0.001
    local yaw = string.format("%.3f", focusYaw * r_)
    local pitch = string.format("%.3f", focusPitch * r_)

    -- Both focus systems get the same strength so the camera focuses the
    -- target whichever category the game files it under. Between targets the
    -- interact system idles at a gentler baseline.
    SetC(CV.enemyEnable, on)
    SetC(CV.enemyYaw, yaw)
    SetC(CV.enemyPitch, pitch)

    -- the interact system also idles at a gentler baseline, but only while friendly NPCs are switched on
    local base = db.focusFriendlyNpcs ~= false and tm_ > 0.001
    SetC(CV.interactEnable, on or base)
    SetC(CV.interactYaw, string.format("%.3f", math.max(base and (shown.yaw or Cur("yaw")) * 0.6 * tm_ or 0, focusYaw * r_)))
    SetC(CV.interactPitch, string.format("%.3f", math.max(base and (shown.pitch or Cur("pitch")) * 0.6 * tm_ or 0, focusPitch * r_)))
end

local ramper = CreateFrame("Frame")
local function StartRamp()
    ramper:SetScript("OnUpdate", function(self, dt)
        local speed = 1 / math.max(0.05, db.rampTime)
        if ramp < rampGoal then
            ramp = math.min(rampGoal, ramp + dt * speed)
        elseif ramp > rampGoal then
            ramp = math.max(rampGoal, ramp - dt * speed)
        end
        ApplyRamp()
        if ramp == rampGoal then self:SetScript("OnUpdate", nil) end
    end)
end

local function Refresh()
    if not db then return end
    if not db.enabled then
        rampGoal = 0
        ramp = 0
        return
    end
    SaveOriginals()
    NP.apply()
    ApplyStatic()
    ConstrainZoom(false)

    local kind = FocusKind()
    if kind then
        focusYaw, focusPitch = shown.yaw or Cur("yaw"), shown.pitch or Cur("pitch")
        rampGoal = 1
    else
        rampGoal = 0 -- keep the last focus strengths while blending out
    end

    if ramp ~= rampGoal then
        StartRamp()
    else
        ApplyRamp()
    end
end

-- The game asks "You have enabled one or more experimental camera features..."
-- at login and after every reload whenever an ActionCam setting is on. This
-- stops that popup: the event that triggers it is taken away from the default
-- UI, and if a copy still slips through it is closed again straight away.
local function ApplyWarningSuppression()
    if not (UIParent and UIParent.UnregisterEvent) then return end
    local suppress = db and db.hideWarning ~= false
    pcall(suppress and UIParent.UnregisterEvent or UIParent.RegisterEvent, UIParent, "EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
end
if hooksecurefunc and StaticPopup_Show and StaticPopup_Hide then
    hooksecurefunc("StaticPopup_Show", function(which)
        if db and db.hideWarning ~= false and type(which) == "string" and which:upper():find("EXPERIMENTAL", 1, true) then
            StaticPopup_Hide(which)
            if C_Timer and C_Timer.After then C_Timer.After(0, function() StaticPopup_Hide(which) end) end
        end
    end)
end

local function Enable()
    db.enabled = true
    Refresh()
end

local function Disable()
    db.enabled = false
    ramp, rampGoal = 0, 0
    ramper:SetScript("OnUpdate", nil)
    shown, from, trans, lastSet, shoulderShown, zoomGlide = {}, {}, nil, {}, nil, nil
    lastYaw, lastPitch = nil, nil
    zoomMemory = {}
    VigHide()
    LbHide()
    Detect.fade.reset()
    Detect.ml.reset()
    RestoreOriginals()
    Detect.rz.sync()
    NP.restore()
end

TargetPlate = function()
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "target")
    if ok and plate then return plate end
    return nil
end

---------------------------------------------------------------------------
-- Targeting frame
--
-- Four triangles circling the target, each pointing inward, colored by how the
-- target feels about you. It's anchored to the target's nameplate (addons can
-- anchor to a nameplate but not measure one), so it needs a nameplate on the
-- target.
--   hated / unfriendly = orange, hostile (aggressive) = red,
--   neutral = yellow, friendly = green
---------------------------------------------------------------------------

local fx = CreateFrame("Frame", "TenKsARPGCameraTargetFrame", UIParent)
fx:SetSize(1, 1)
fx:SetFrameStrata("LOW")
fx:Hide()

-- The triangles live on `body`, centered on fx. Scaling body makes the whole
-- frame "breathe" with a single cheap call instead of moving every corner.
local body = CreateFrame("Frame", nil, fx)
body:SetSize(1, 1)
body:SetPoint("CENTER", fx, "CENTER", 0, 0)

-- Each triangle is built from thin slices (so its edges can curve), and each
-- slice is a solid quad whose four corners are moved (vertex offsets) to where
-- we want them. Vertices: 1 = top left, 2 = bottom left, 3 = top right,
-- 4 = bottom right. Slices go from the triangle's base to its tip, and a
-- vertical gradient on each slice gives the shading and transparency.
local STRIPS = 4
local QUAD = 8 -- the slices' untouched size; corners sit at (+-4, +-4)
local strips, lines = {}, {}
for i = 1, 4 do
    strips[i] = {}
    for j = 1, STRIPS do
        local t = body:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(1, 1, 1, 1)
        t:SetPoint("CENTER", body, "CENTER", 0, 0)
        t:SetSize(QUAD, QUAD)
        strips[i][j] = t
    end
end
local canWarp = strips[1][1].SetVertexOffset ~= nil

-- Outline fallback (three lines per triangle) if slices can't be warped or
-- you pick it with /acam framestyle.
if body.CreateLine then
    for i = 1, 12 do
        local l = body:CreateLine(nil, "OVERLAY")
        l:SetThickness(2.5)
        l:SetColorTexture(1, 1, 1, 1)
        l:Hide()
        lines[i] = l
    end
end

-- A point on triangle `ang` (0 = base ... 1 = tip along t, -1..1 across u),
-- relative to the target's center. The triangle hugs the circle around the
-- target (arc) and its sides curve inward slightly (bow); both scale with
-- `curve`.
local function TriPoint(ang, radius, base, height, curve, t, u)
    local c, s = math.cos(ang), math.sin(ang)
    local half = (base / 2) * (1 - t) * (1 - curve * 2.0 * t * (1 - t))
    local lateral = u * half
    local along = (0.5 - t) * height
    -- the base edge dips in at its middle; the corners and the tip stay put, so
    -- the solid triangle covers the same footprint as the outline one
    local arc = curve * base * 0.35 * (1 - u * u) * (1 - t)
    local out = radius + along - arc
    return out * c - lateral * s, out * s + lateral * c
end

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function HideStrips(i)
    for j = 1, STRIPS do strips[i][j]:Hide() end
end

local function HideLines(i)
    for k = 1, 3 do
        local l = lines[(i - 1) * 3 + k]
        if l then l:Hide() end
    end
end

local function PlaceOutline(i, ang, radius, base, height)
    local ax, ay = TriPoint(ang, radius, base, height, 0, 0, -1)
    local bx, by = TriPoint(ang, radius, base, height, 0, 0, 1)
    local tx, ty = TriPoint(ang, radius, base, height, 0, 1, 0)
    local pts = { { tx, ty, ax, ay }, { ax, ay, bx, by }, { bx, by, tx, ty } }
    for k = 1, 3 do
        local l = lines[(i - 1) * 3 + k]
        local q = pts[k]
        l:SetStartPoint("CENTER", body, q[1], q[2])
        l:SetEndPoint("CENTER", body, q[3], q[4])
        if not l:IsShown() then l:Show() end
    end
end

-- Vertical gradient on a texture: (r1,g1,b1,a1) at the top, (r2,g2,b2,a2) at
-- the bottom. Older and newer clients spell this differently.
local function SetGradient(tx, r1, g1, b1, a1, r2, g2, b2, a2)
    if tx.SetGradientAlpha then
        tx:SetGradientAlpha("VERTICAL", r2, g2, b2, a2, r1, g1, b1, a1)
    elseif tx.SetGradient and CreateColor then
        tx:SetGradient("VERTICAL", CreateColor(r2, g2, b2, a2), CreateColor(r1, g1, b1, a1))
    else
        tx:SetColorTexture(r2, g2, b2, a2)
    end
end

-- Shading: each triangle is darker and see-through at its base and brighter
-- and denser at its tip.
local function ApplyColors(r, g, b)
    for i = 1, 4 do
        for j = 1, STRIPS do
            local t0, t1 = (j - 1) / STRIPS, j / STRIPS
            local k0, a0 = 0.55 + 0.45 * t0, 0.25 + 0.75 * t0
            local k1, a1 = 0.55 + 0.45 * t1, 0.25 + 0.75 * t1
            SetGradient(strips[i][j], r * k0, g * k0, b * k0, a0, r * k1, g * k1, b * k1, a1)
        end
    end
    for _, l in ipairs(lines) do l:SetColorTexture(r, g, b, 1) end
end


-- Reticle style ----------------------------------------------------------
-- A plain, old-world targeting mark: a thin gilded ring broken at the four
-- points of the compass, with a slim curved blade standing in each gap and
-- pointing inward. The whole thing turns slowly as one piece, with a soft glow
-- behind the ring. Elite / rare / boss targets get a second, fine outer ring.
local RING_ARCS, RING_SEGS = 4, 5
local ELITE_SEGS = 40
local GROUND_SEGS, SWEEP_SEGS = 40, 9      -- the ground ring style: the ring, and its traveling highlight
local eliteDrawn                           -- radius the elite ring was last drawn at
local ret                                   -- built the first time the reticle is shown
local Halo = {}                             -- the health halo style (filled in below)

local function NewLine(sub, thick, additive)
    local l = body:CreateLine(nil, "OVERLAY", nil, sub)
    l:SetThickness(thick)
    if additive then l:SetBlendMode("ADD") end
    l:SetColorTexture(1, 1, 1, 1)
    l:Hide()
    return l
end

local function NewSet(n, thick, glowThick)
    local set = { core = {}, glow = {} }
    for i = 1, n do set.glow[i] = NewLine(1, glowThick, true) end
    for i = 1, n do set.core[i] = NewLine(2, thick, false) end
    return set
end

local function BuildReticle()
    if ret or not body.CreateLine then return end
    ret = {
        ring = NewSet(RING_ARCS * RING_SEGS, 1.8, 5.5),
        elite = NewSet(ELITE_SEGS, 1.1, 4),
        ground = NewSet(GROUND_SEGS, 1.8, 5.5),
        sweep = NewSet(SWEEP_SEGS, 2.6, 7),
    }
    -- a soft burst of light when the frame locks on (skipped silently if the client lacks the texture)
    local flash = body:CreateTexture(nil, "OVERLAY", nil, 3)
    flash:SetTexture("Interface\\Cooldown\\star4")
    flash:SetBlendMode("ADD")
    flash:SetPoint("CENTER", body, "CENTER", 0, 0)
    flash:SetSize(10, 10)
    flash:SetAlpha(0)
    flash:Hide()
    ret.flash = flash
end

local function SetSegment(l, x1, y1, x2, y2)
    l:SetStartPoint("CENTER", body, x1, y1)
    l:SetEndPoint("CENTER", body, x2, y2)
    if not l:IsShown() then l:Show() end
end

local function HideSet(set)
    for i = 1, #set.core do set.core[i]:Hide() end
    for i = 1, #set.glow do set.glow[i]:Hide() end
end

local function HideReticle()
    if not ret then return end
    HideSet(ret.ring); HideSet(ret.elite); HideSet(ret.ground); HideSet(ret.sweep)
    eliteDrawn = nil; ret.groundDrawn = nil
    ret.flash:Hide()
    if Halo.hide then Halo.hide() end
end

-- Broken ring: `arcs` arcs each covering `span` radians, built from `segs` segments.
local function PlaceArcs(set, arcs, segs, radius, span, start)
    local n = 0
    local step = 2 * math.pi / arcs
    for a = 0, arcs - 1 do
        local base = start + a * step
        local px, py = radius * math.cos(base), radius * math.sin(base)
        for sgm = 1, segs do
            local th = base + span * sgm / segs
            local qx, qy = radius * math.cos(th), radius * math.sin(th)
            n = n + 1
            SetSegment(set.core[n], px, py, qx, qy)
            SetSegment(set.glow[n], px, py, qx, qy)
            px, py = qx, qy
        end
    end
end

-- Part of an ellipse (rx by ry, centered at cx, cy) from angle `start` covering `span` radians.
local function PlaceEllipse(set, segs, cx, cy, rx, ry, start, span)
    local px, py = cx + rx * math.cos(start), cy + ry * math.sin(start)
    for i = 1, segs do
        local th = start + span * i / segs
        local qx, qy = cx + rx * math.cos(th), cy + ry * math.sin(th)
        SetSegment(set.core[i], px, py, qx, qy)
        SetSegment(set.glow[i], px, py, qx, qy)
        px, py = qx, qy
    end
end

local function SetColor(set, r, g, b, coreA, glowA)
    for i = 1, #set.core do set.core[i]:SetColorTexture(r, g, b, coreA) end
    for i = 1, #set.glow do set.glow[i]:SetColorTexture(r, g, b, glowA) end
end

-- Elite ring colors by classification.
local ELITE_RGB = {
    elite = { 1.0, 0.82, 0.25 }, rare = { 0.82, 0.90, 1.0 },
    rareelite = { 0.82, 0.90, 1.0 }, worldboss = { 1.0, 0.35, 0.20 },
}
local eliteKind                       -- classification of the target, or nil for ordinary ones

local function ReticleColors(r, g, b)
    if not ret then return end
    local glow = Clamp(db.fxGlow or 0.6, 0, 1) * 0.4
    -- the ring is lightly gilded; the blades keep the pure reaction color
    local gr, gg, gb = r * 0.78 + 0.22, g * 0.78 + 0.18, b * 0.78 + 0.07
    SetColor(ret.ring, gr, gg, gb, 0.95, glow)
    SetColor(ret.ground, gr, gg, gb, 0.7, glow * 0.8)
    SetColor(ret.sweep, r * 0.45 + 0.55, g * 0.45 + 0.5, b * 0.45 + 0.35, 1, math.min(1, glow * 1.4))
    local e = ELITE_RGB[eliteKind or "elite"]
    SetColor(ret.elite, e[1], e[2], e[3], 0.9, glow)
    ret.flash:SetVertexColor(r * 0.6 + 0.4, g * 0.6 + 0.4, b * 0.5 + 0.3)
end

local function ReactionColor()
    local ok, r = pcall(UnitReaction, "player", "target")
    if not ok or type(r) ~= "number" or issecret(r) then return 1, 1, 1 end
    if r == 1 then return 1.0, 0.55, 0.05 end   -- hated: orange
    if r == 2 then return 1.0, 0.10, 0.10 end   -- hostile / aggressive: red
    if r == 3 then return 1.0, 0.55, 0.05 end   -- unfriendly: orange
    if r == 4 then return 1.0, 0.90, 0.10 end   -- neutral: yellow
    return 0.2, 1.0, 0.3                        -- friendly: green
end


-- Health halo style ------------------------------------------------------------
-- A ring of small segments around the target that drains as it loses health, a thin
-- inner hairline, four slowly turning ticks, a marker above (doubled for elites), a soft
-- bloom behind, and an outer ring that pulses (and fills, when the game says how long)
-- while the target is casting. Distance sits underneath.
--
-- Health is secret in this client, so the addon never reads the number. Each segment is
-- a small clipped window onto one long health bar: the game fills the bar, and a
-- segment shows lit when the bar's fill reaches it. No comparisons on our side.
do
local PIPS, HAIR, CAST = 48, 48, 48
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
local h -- built on first use

local function Build()
    if h or not body.CreateLine then return h end
    h = { pips = {} }
    h.canClip = body.SetClipsChildren ~= nil
    for k = 1, PIPS do
        local clip = CreateFrame("Frame", nil, body)
        if h.canClip then clip:SetClipsChildren(true) end
        local base = clip:CreateTexture(nil, "BACKGROUND")
        base:SetAllPoints()
        base:SetColorTexture(1, 1, 1, 1)
        local bar = CreateFrame("StatusBar", nil, clip)
        bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
        if not h.canClip then bar:Hide() end -- without clipping the bars would spill out: segments just stay lit
        clip:Hide()
        h.pips[k] = { clip = clip, base = base, bar = bar }
    end
    h.hair = NewSet(HAIR, 1.1, 4)
    h.ticks = NewSet(4, 2, 6)
    h.chev = NewSet(4, 2, 6)
    h.cast = NewSet(CAST, 2.4, 8)
    local glow = body:CreateTexture(nil, "BACKGROUND")
    glow:SetPoint("CENTER", body, "CENTER", 0, 0)
    glow:SetBlendMode("ADD")
    h.glowOk = glow:SetTexture(MEDIA .. "halo_glow") ~= false
    glow:Hide()
    h.glow = glow
    return h
end
Halo.build = Build

function Halo.hide()
    if not h then return end
    for _, p in ipairs(h.pips) do p.clip:Hide() end
    HideSet(h.hair); HideSet(h.ticks); HideSet(h.chev); HideSet(h.cast)
    h.glow:Hide()
    h.drawn, h.castShown = nil, nil
end

-- Lights the segments from the target's health (secret values go straight to the bars).
function Halo.health()
    if not h then return end
    local okH, hp = pcall(UnitHealth, "target")
    local okM, mx = pcall(UnitHealthMax, "target")
    local good = okH and okM and hp ~= nil and mx ~= nil and h.canClip and db.fxHealth ~= false
    for _, p in ipairs(h.pips) do
        local b = p.bar
        if not (good and pcall(b.SetMinMaxValues, b, 0, mx) and pcall(b.SetValue, b, hp)) then
            good = false
            b:SetMinMaxValues(0, 1); b:SetValue(1)
        end
    end
    h.healthOk = good
end

-- Is the target casting or channeling? Timing is used only when the game shares it.
function Halo.checkCast()
    if not h then return end
    local casting, st, en = false, nil, nil
    for _, fn in ipairs({ UnitCastingInfo, UnitChannelInfo }) do
        if fn and not casting then
            local ok, name, _, _, startMs, endMs = pcall(fn, "target")
            if ok and (issecret(name) or name ~= nil) then
                casting = true
                if type(startMs) == "number" and type(endMs) == "number" and not issecret(startMs) and not issecret(endMs)
                    and endMs > startMs then
                    st, en = startMs / 1000, endMs / 1000
                end
            end
        end
    end
    h.casting, h.castStart, h.castEnd = casting, st, en
end

function Halo.colors(r, g, b)
    if not h then return end
    local glow = Clamp(db.fxGlow or 0.6, 0, 1)
    for _, p in ipairs(h.pips) do
        p.bar:SetStatusBarColor(r * 0.35 + 0.65 * r, g * 0.9 + 0.1, b * 0.9 + 0.1, 1)
        p.base:SetColorTexture(r * 0.5, g * 0.5, b * 0.5, 0.35)
    end
    local gr, gg, gb = r * 0.6 + 0.4, g * 0.6 + 0.33, b * 0.6 + 0.15
    SetColor(h.hair, gr, gg, gb, 0.55, glow * 0.25)
    SetColor(h.ticks, 1, 0.84, 0.45, 0.95, glow * 0.45)
    local e = eliteKind and ELITE_RGB[eliteKind] or { 1, 0.84, 0.45 }
    SetColor(h.chev, e[1], e[2], e[3], 1, glow * 0.5)
    SetColor(h.cast, 1, 0.62, 0.18, 1, glow * 0.6)
    h.glow:SetVertexColor(r, g, b)
    h.glowA = glow * 0.55
end

local function Chevron(i, cx, cy, w, hgt)
    SetSegment(h.chev.core[i], cx - w, cy + hgt, cx, cy); SetSegment(h.chev.glow[i], cx - w, cy + hgt, cx, cy)
    SetSegment(h.chev.core[i + 1], cx, cy, cx + w, cy + hgt); SetSegment(h.chev.glow[i + 1], cx, cy, cx + w, cy + hgt)
end

-- Places everything for a ring of `radius`. The still parts are only moved when the size changes.
function Halo.place(radius, spin, eb)
    if not Build() then return false end
    if h.drawn ~= radius or h.eliteDrawn ~= eliteKind then
        local pip = math.max(3, math.floor(2 * math.pi * radius / PIPS * 0.42 + 0.5))
        for k, p in ipairs(h.pips) do
            local a = math.pi / 2 - (k - 0.5) * 2 * math.pi / PIPS -- clockwise from the top
            p.clip:SetSize(pip, pip)
            p.clip:ClearAllPoints()
            p.clip:SetPoint("CENTER", body, "CENTER", radius * math.cos(a), radius * math.sin(a))
            p.bar:SetSize(pip * PIPS, pip)
            p.bar:ClearAllPoints()
            p.bar:SetPoint("LEFT", p.clip, "LEFT", -(k - 1) * pip, 0)
            if not p.clip:IsShown() then p.clip:Show() end
        end
        PlaceArcs(h.hair, 1, HAIR, radius * 0.86, 2 * math.pi - 0.0001, 0)
        HideSet(h.chev)
        local top = radius * 1.12
        Chevron(1, 0, top + 4, radius * 0.07, radius * 0.07)
        if eliteKind then Chevron(3, 0, top + 4 + radius * 0.08, radius * 0.07, radius * 0.07) end
        if h.glowOk then
            h.glow:SetSize(radius * 2.6, radius * 2.6)
        end
        h.drawn, h.eliteDrawn, h.castShown = radius, eliteKind, nil
        Halo.health()
    end
    if h.glowOk and db.fxGlow ~= 0 then h.glow:Show() else h.glow:Hide() end
    -- four ticks outside the ring turn slowly; a lock-on adds a quick twist
    local turn = spin + (1 - (eb or 1)) * math.pi * 0.7
    for i = 1, 4 do
        local a = turn + (i - 1) * math.pi / 2 + math.pi / 4
        local c, sn = math.cos(a), math.sin(a)
        local r1, r2 = radius * 1.07, radius * 1.17
        SetSegment(h.ticks.core[i], r1 * c, r1 * sn, r2 * c, r2 * sn)
        SetSegment(h.ticks.glow[i], r1 * c, r1 * sn, r2 * c, r2 * sn)
    end
    return true
end

-- ~30 times a second: the bloom breathes, and the cast ring pulses and fills.
function Halo.animate(now)
    if not h or not h.drawn then return end
    if h.glowOk then h.glow:SetAlpha((h.glowA or 0.3) * (0.8 + 0.2 * math.sin(now * 2.2))) end
    local want = h.casting and db.fxCast ~= false
    if not want then
        if h.castShown then HideSet(h.cast); h.castShown = nil end
        return
    end
    local frac = 1
    if h.castStart and h.castEnd then frac = Clamp((now - h.castStart) / (h.castEnd - h.castStart), 0, 1) end
    local n = math.max(1, math.ceil(frac * CAST))
    if h.castShown ~= n then
        local radius = h.drawn * 1.24
        local px, py = 0, radius
        for i = 1, CAST do
            local th = math.pi / 2 - i * 2 * math.pi / CAST
            local qx, qy = radius * math.cos(th), radius * math.sin(th)
            if i <= n then
                SetSegment(h.cast.core[i], px, py, qx, qy); SetSegment(h.cast.glow[i], px, py, qx, qy)
            else
                h.cast.core[i]:Hide(); h.cast.glow[i]:Hide()
            end
            px, py = qx, qy
        end
        h.castShown = n
    end
    local pulse = 0.55 + 0.45 * math.sin(now * 9)
    for i = 1, n do h.cast.core[i]:SetAlpha(pulse); h.cast.glow[i]:SetAlpha(pulse) end
end

-- Distance readout under the frame (any style). The text sits on the outer frame so it doesn't breathe.
function Halo.label(text, radius)
    if not Halo.fs then
        local fs = fx:CreateFontString(nil, "OVERLAY")
        fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        fs:SetTextColor(1, 0.93, 0.78)
        fs:SetShadowOffset(1, -1)
        Halo.fs = fs
    end
    local fs = Halo.fs
    if not text then fs:Hide() return end
    if Halo.fsR ~= radius then
        fs:ClearAllPoints()
        fs:SetPoint("TOP", fx, "CENTER", 0, -(radius * 1.3 + 2))
        Halo.fsR = radius
    end
    if Halo.fsText ~= text then fs:SetText(text); Halo.fsText = text end
    if not fs:IsShown() then fs:Show() end
end

-- Distance by spell range --------------------------------------------------------
-- The game only gives exact distances for group members. For anything else the addon asks
-- whether the target is in range of your own spells (each has a known range) and of the
-- game's interact distances, and narrows that to a bracket such as "20-25 yd".
local R = { spells = {}, dirty = true, at = -1 }
Halo.range = R
local function Scan()
    R.dirty = false
    wipe(R.spells)
    local per = {}
    local function add(id, name, maxR)
        if type(maxR) ~= "number" or issecret(maxR) then return end
        if maxR <= 0 then maxR = 5 end -- melee abilities report no range
        maxR = math.floor(maxR + 0.5)
        per[maxR] = per[maxR] or 0
        if per[maxR] >= 3 or #R.spells >= 36 then return end
        per[maxR] = per[maxR] + 1
        R.spells[#R.spells + 1] = { id = id, name = name, r = maxR }
    end
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemInfo and C_Spell and C_Spell.GetSpellInfo then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
        local ok, n = pcall(C_SpellBook.GetNumSpellBookSkillLines)
        for i = 1, (ok and type(n) == "number") and n or 0 do
            local ok2, line = pcall(C_SpellBook.GetSpellBookSkillLineInfo, i)
            if ok2 and type(line) == "table" and not line.offSpecID and line.itemIndexOffset and line.numSpellBookItems then
                for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                    local ok3, info = pcall(C_SpellBook.GetSpellBookItemInfo, slot, bank)
                    if ok3 and type(info) == "table" and info.spellID and not info.isPassive
                        and (spellType == nil or info.itemType == spellType) then
                        local ok4, si = pcall(C_Spell.GetSpellInfo, info.spellID)
                        if ok4 and type(si) == "table" then add(info.spellID, si.name, si.maxRange) end
                    end
                end
            end
        end
    elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo and GetSpellInfo then
        local ok, tabs = pcall(GetNumSpellTabs)
        for t = 1, (ok and type(tabs) == "number") and tabs or 0 do
            local ok2, _, _, offset, num = pcall(GetSpellTabInfo, t)
            if ok2 and type(offset) == "number" and type(num) == "number" then
                for slot = offset + 1, offset + num do
                    local ok3, kind, id = pcall(GetSpellBookItemInfo, slot, "spell")
                    local passive = IsPassiveSpell and select(2, pcall(IsPassiveSpell, slot, "spell"))
                    if ok3 and kind == "SPELL" and id and not passive then
                        local ok4, name, _, _, _, _, maxR = pcall(GetSpellInfo, id)
                        if ok4 and name then add(id, name, maxR) end
                    end
                end
            end
        end
    end
    table.sort(R.spells, function(a, b) return a.r < b.r end)
end
local function InRange(sp)
    local ok, v
    if C_Spell and C_Spell.IsSpellInRange then
        ok, v = pcall(C_Spell.IsSpellInRange, sp.id, "target")
    elseif IsSpellInRange then
        ok, v = pcall(IsSpellInRange, sp.name, "target")
    end
    if not ok or v == nil or issecret(v) then return nil end
    return v == true or v == 1
end
-- Returns lo, hi (either may be nil): the target is farther than lo and no farther than hi.
function R.query()
    if R.dirty then Scan() end
    local now = GetTime()
    if now - R.at < 0.2 then return R.lo, R.hi end
    R.at = now
    local lo, hi
    local done = {}
    for _, sp in ipairs(R.spells) do
        if not done[sp.r] then
            local v = InRange(sp)
            if v ~= nil then
                done[sp.r] = true
                if v then hi = math.min(hi or sp.r, sp.r) else lo = math.max(lo or 0, sp.r) end
            end
        end
    end
    if CheckInteractDistance then
        for _, band in ipairs({ { 3, 10 }, { 4, 28 } }) do
            local ok, v = pcall(CheckInteractDistance, "target", band[1])
            if ok and not issecret(v) and v ~= nil then
                if v then hi = math.min(hi or band[2], band[2]) else lo = math.max(lo or 0, band[2]) end
            end
        end
    end
    if lo and hi and lo >= hi then lo = nil end
    R.lo, R.hi = lo, hi
    return lo, hi
end
local rescan = CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_LOGIN", "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED", "LEARNED_SPELL_IN_TAB" }) do
    pcall(rescan.RegisterEvent, rescan, ev)
end
rescan:SetScript("OnEvent", function() R.dirty = true end)

-- health and casting events for the target
local ev = CreateFrame("Frame")
for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP" }) do
    pcall(ev.RegisterUnitEvent, ev, e, "target")
end
pcall(ev.RegisterEvent, ev, "PLAYER_TARGET_CHANGED")
ev:SetScript("OnEvent", function(_, e)
    if not h then return end
    if e == "UNIT_HEALTH" or e == "UNIT_MAXHEALTH" then Halo.health() return end
    if e == "PLAYER_TARGET_CHANGED" then Halo.health() end
    Halo.checkCast()
end)
end

-- Distance to the target in yards, if the game will tell us.
local distSmooth, distSource = nil, "none"
local function RawDistance()
    if UnitDistanceSquared then
        local ok, d2 = pcall(UnitDistanceSquared, "target")
        if ok and type(d2) == "number" and not issecret(d2) and d2 > 0 then
            Halo.range.lo, Halo.range.hi = nil, nil
            return math.sqrt(d2), "UnitDistanceSquared"
        end
    end
    -- Otherwise: a bracket from your spells' ranges and the game's interact distances.
    local lo, hi = Halo.range.query()
    if lo and hi then return (lo + hi) / 2, "spell ranges" end
    if hi then return hi <= 5 and 3 or hi * 0.75, "spell ranges" end
    if lo then return lo + 6, "spell ranges" end
    return nil, "unavailable"
end
local function TargetDistance(dt)
    local d, src = RawDistance()
    distSource = src
    if not d then distSmooth = nil return nil end
    distSmooth = distSmooth and (distSmooth + (d - distSmooth) * (1 - math.exp(-(dt or 0.1) * 3))) or d
    return distSmooth
end

-- Focus marker ---------------------------------------------------------------
-- A small gilded diamond above your focus target's nameplate (when it isn't
-- also your current target, which already has the frame around it).
local FocusMarkUpdate, FocusMarkHide
do
local mark, parts
local anchored
local function Build()
    mark = CreateFrame("Frame", nil, UIParent)
    mark:SetSize(1, 1)
    mark:SetFrameStrata("LOW")
    mark:Hide()
    parts = {}
    if not mark.CreateLine then return end
    local pts = { { 0, 7 }, { 7, 0 }, { 0, -7 }, { -7, 0 } }
    for i = 1, 4 do
        local a, b = pts[i], pts[i % 4 + 1]
        for layer = 1, 2 do
            local l = mark:CreateLine(nil, "OVERLAY", nil, layer)
            l:SetThickness(layer == 1 and 5 or 1.6)
            if layer == 1 then l:SetBlendMode("ADD"); l:SetColorTexture(1, 0.8, 0.3, 0.3)
            else l:SetColorTexture(1, 0.88, 0.45, 1) end
            l:SetStartPoint("CENTER", mark, a[1], a[2])
            l:SetEndPoint("CENTER", mark, b[1], b[2])
            parts[#parts + 1] = l
        end
    end
end

FocusMarkHide = function()
    if mark and mark:IsShown() then mark:Hide() end
    anchored = nil
end

FocusMarkUpdate = function()
    if not (db and db.enabled and db.fx and db.fxFocus ~= false) or fxBlocked then FocusMarkHide() return end
    if not (Truth(UnitExists, "focus") and C_NamePlate and C_NamePlate.GetNamePlateForUnit) then FocusMarkHide() return end
    if Truth(UnitIsUnit, "focus", "target") or Truth(UnitIsDead, "focus") then FocusMarkHide() return end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "focus")
    if not (ok and plate) then FocusMarkHide() return end
    if not mark then Build() end
    if #parts == 0 then return end
    if anchored ~= plate then
        mark:ClearAllPoints()
        if not pcall(mark.SetPoint, mark, "CENTER", plate, "CENTER", 0, 34) then FocusMarkHide() return end
        anchored = plate
    end
    mark:SetAlpha(Clamp(db.fxAlpha + 0.15, 0, 1))
    if not mark:IsShown() then mark:Show() end
end
end

local shownColor
local fxOoc = { mul = 1, goal = 1, last = 0 }   -- fade-out-of-combat: current and wanted opacity multiplier
local fxBlocked = false
local fxTest = false            -- /acam frametest: draw at screen center to check the drawing itself
local fxState = "not run yet"   -- what the last update did; shown by /acam debug

-- The frame's work is split in two so it costs very little:
--   FXState    ~10 times a second: is there a target to frame, where does it
--              attach, how far away is it, what color is it.
--   FXGeometry ~30 times a second, and only while the frame is on screen:
--              spin, breathe, and move the triangles' corners.
local fxVisible = false
local plateChanged = false
local fxSize, fxFade = 110, 1
local anchorPlate, anchorX, anchorY
local shapeMode                 -- "solid", "outline" or nil (nothing shown)

local FXShape, FXAnimate -- defined below

-- Lock-on and hit-flash timing
local lockStart, lockActive = 0, false
local hitStart = -10
local function StartLock()
    if (db.fxStyle == "reticle" or db.fxStyle == "ring" or db.fxStyle == "halo") and db.fxLock ~= false then
        lockStart, lockActive = GetTime(), true
    end
end
-- 0 at the start of a lock-on, 1 when done, overshooting a little in between
local function LockEase()
    if not lockActive then return 1, 1 end
    local p = (GetTime() - lockStart) / 0.42 -- lock-on takes 0.42 s
    if p >= 1 then return 1, 1 end
    local q = p - 1
    return 1 + 2.4 * q * q * q + 1.4 * q * q, p
end

local function FXHide()
    fxVisible = false
    if fx:IsShown() then fx:Hide() end
end

local function FXState(dt)
    if not db or not db.enabled then FXHide(); FocusMarkHide() return end
    FocusMarkUpdate()

    local size = db.fxSize
    local fade, shift = 1, 0
    local plate
    local label

    if fxTest then
        if anchorPlate ~= UIParent then
            anchorPlate, anchorX, anchorY = UIParent, 0, 0
            fx:ClearAllPoints()
            fx:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        fxState = "test mode (screen center)"
    else
        if fxBlocked or not db.fx then fxState = "off"; FXHide() return end
        if not UnitExists("target") or UnitIsDead("target") then fxState = "no living target"; FXHide() return end
        local okSelf, isSelf = pcall(UnitIsUnit, "target", "player")
        if okSelf and not issecret(isSelf) and isSelf then fxState = "target is you"; FXHide() return end

        local tKind, tKey = Detect.targetKind()
        if tKey and db["fx" .. tKey:sub(6)] == false then fxState = tKind .. " (the frame is switched off for that kind)"; FXHide() return end

        plate = TargetPlate()
        if not plate then fxState = "target has no nameplate (turn nameplates on)"; FXHide() return end

        if C_NamePlateManager and C_NamePlateManager.IsNamePlateUnitBehindCamera then
            local okB, behind = pcall(C_NamePlateManager.IsNamePlateUnitBehindCamera, "target")
            if okB and not issecret(behind) and behind then fxState = "target behind camera"; FXHide() return end
        end

        -- Distance: a model looks smaller (and the frame fainter) the farther
        -- away it is, and the frame sits a touch higher on far targets and
        -- lower on near ones, the way the camera's downward view puts distant
        -- things nearer the horizon.
        local dist = TargetDistance(dt)
        if dist and db.fxDist ~= false then
            local R = Halo.range
            if distSource == "UnitDistanceSquared" then label = string.format("%d yd", math.floor(dist + 0.5))
            elseif R.lo and R.hi then label = string.format("%d-%d yd", R.lo, R.hi)
            elseif R.hi then label = R.hi <= 5 and L["melee"] or string.format("< %d yd", R.hi)
            elseif R.lo then label = string.format("%d+ yd", R.lo) end
            if label and eliteKind then
                label = label .. "  |cffffd75a" .. (eliteKind == "worldboss" and L["Boss"] or (eliteKind == "elite" and L["Elite"] or L["Rare"])) .. "|r"
            end
        end
        if dist then
            -- shrinks more slowly than true perspective so far targets stay readable
            size = db.fxSize * Clamp((10 / math.max(dist, 1)) ^ 0.6, 0.6, 1.8)
            fade = Clamp(1.15 - dist / 80, 0.45, 1)
            shift = db.fxDistShift * Clamp((dist - 10) / 20, -1, 1)
        end

        -- We can't measure a nameplate, but we can anchor to it: the frame
        -- rides on the nameplate, just below it where the model's middle is.
        -- Only re-anchored when something actually moved.
        local ax, ay = db.fxOffset, -(size * 0.5 + 18) + shift
        if plate ~= anchorPlate then plateChanged = true end
        if db.fxElite ~= false then
            local okC, cls = pcall(UnitClassification, "target")
            if okC and not issecret(cls) and ELITE_RGB[cls] then
                if cls ~= eliteKind then eliteKind = cls; shownColor = nil end
            elseif eliteKind then
                eliteKind = nil; shownColor = nil
            end
        elseif eliteKind then
            eliteKind = nil; shownColor = nil
        end
        if plate ~= anchorPlate or math.abs(ax - (anchorX or 1e9)) > 0.4 or math.abs(ay - (anchorY or 1e9)) > 0.4 then
            fx:ClearAllPoints()
            local ok, err = pcall(fx.SetPoint, fx, "CENTER", plate, "CENTER", ax, ay)
            if not ok then
                fxBlocked = true
                fxState = "anchoring to the nameplate was refused: " .. tostring(err)
                FXHide()
                Print(L["This client won't let the targeting frame attach to nameplates, so it's disabled. (/acam debug for details)"])
                return
            end
            anchorPlate, anchorX, anchorY = plate, ax, ay
        end
        fxState = "anchored to the target's nameplate"
    end

    -- friendly targets get a smaller frame
    if not fxTest and (db.fxFriendScale or 1) < 0.999 and Truth(UnitCanAttack, "player", "target") == false then
        size = size * Clamp(db.fxFriendScale, 0.4, 1)
    end
    -- out of combat the frame can fade back
    if db.fxOoc and Truth(UnitAffectingCombat, "player") == false then
        fxOoc.goal = Clamp(db.fxOocAlpha or 0.35, 0, 1)
    else
        fxOoc.goal = 1
    end
    fxSize, fxFade = size, fade

    local r, g, b = ReactionColor()
    local key = r * 1000 + g * 100 + b + (db.fxGlow or 0.6) * 0.0001
    if (db.fxStyle == "reticle" or db.fxStyle == "ring") and not ret then BuildReticle(); shownColor = nil end
    if db.fxStyle == "halo" and Halo.build() and not ret then BuildReticle() end
    if key ~= shownColor then
        shownColor = key
        ApplyColors(r, g, b)
        ReticleColors(r, g, b)
        Halo.colors(r, g, b)
    end
    if fxTest and db.fxDist ~= false then label = "24 yd" end
    Halo.label(label, size * 0.5)

    if not fxVisible or plateChanged then
        if plateChanged or not fxVisible then StartLock() end
        plateChanged = false
    end
    if not fxVisible then
        fxVisible = true
        if Halo.health then Halo.health(); Halo.checkCast() end
        shapeMode = nil -- force the shape to be set up again
        FXShape(true)
        FXAnimate()
    end
    if not fx:IsShown() then fx:Show() end
end

-- Triangle corner positions in the triangle's own frame (pointing along +x),
-- computed once per update and then just rotated for each of the four.
local edgeOut, edgeHalf = {}, {}

-- Cheap, ~30 times a second: shimmer and "breathing" (opacity and one scale).
FXAnimate = function()
    local now = GetTime()
    local scale, alpha = 1 + (1 + math.sin(now * 5)) * 0.04, 1
    if lockActive then
        local eb, p = LockEase()
        if p >= 1 then
            lockActive = false
            if ret then ret.flash:Hide() end
        else
            scale = scale * (1.8 - 0.8 * eb)
            alpha = math.min(1, p * 5)
            if ret and db.fxGlow ~= 0 then
                -- a quick burst of light at the moment of locking on
                local f = math.max(0, 1 - p * 2.5)
                ret.flash:SetSize(fxSize * 1.5, fxSize * 1.5)
                ret.flash:SetAlpha(f * 0.8 * (db.fxGlow or 0.6))
                if not ret.flash:IsShown() then ret.flash:Show() end
            end
        end
    end
    if db.fxHit ~= false and (db.fxStyle == "reticle" or db.fxStyle == "ring" or db.fxStyle == "halo") then
        local h = 1 - (now - hitStart) / 0.25
        if h > 0 then
            scale = scale * (1 + 0.06 * h)
            alpha = alpha * (1 + 0.35 * h)
        end
    end
    local dt = math.min(1, now - fxOoc.last)
    fxOoc.last = now
    fxOoc.mul = fxOoc.mul + (fxOoc.goal - fxOoc.mul) * (1 - math.exp(-dt * 4))
    fx:SetAlpha(Clamp(db.fxAlpha * fxFade * fxOoc.mul * alpha * (0.88 + 0.12 * math.sin(now * 3)), 0, 1))
    body:SetScale(scale)
    if shapeMode == "halo" then Halo.animate(now) end
end

-- Moves the triangles' corners. It only needs to run as fast as the spin does:
-- the interval keeps each step under about half a degree (a slow spin needs far
-- fewer updates than a fast one), and with no spin it runs only when the size
-- or curvature changes.
local shapeKey

-- The four solid triangles, circling at `radius` from the center.
local function DrawSolid(radius, base, height, curve, spin)
    for k = 0, STRIPS do
        local t = k / STRIPS
        edgeOut[k] = radius + (0.5 - t) * height
        edgeHalf[k] = (base / 2) * (1 - t) * (1 - curve * 2.0 * t * (1 - t))
    end
    local h = QUAD / 2
    for i = 1, 4 do
        local ang = spin + (i - 1) * math.pi / 2
        local c, sn = math.cos(ang), math.sin(ang)
        local row = strips[i]
        for j = 1, STRIPS do
            local o0, w0, o1, w1 = edgeOut[j - 1], edgeHalf[j - 1], edgeOut[j], edgeHalf[j]
            local tx = row[j]
            -- left edge (lateral = -w) then right edge (lateral = +w)
            tx:SetVertexOffset(1, o0 * c + w0 * sn + h, o0 * sn - w0 * c - h)
            tx:SetVertexOffset(2, o1 * c + w1 * sn + h, o1 * sn - w1 * c + h)
            tx:SetVertexOffset(3, o0 * c - w0 * sn - h, o0 * sn + w0 * c - h)
            tx:SetVertexOffset(4, o1 * c - w1 * sn - h, o1 * sn + w1 * c + h)
        end
    end
end

FXShape = function(force)
    local size = fxSize
    local radius = size * 0.5
    local base = math.max(10, size * 0.2)
    local height = base * 0.85
    local curve = db.fxCurve
    local spin = -math.rad(db.fxSpeed) * GetTime()
    local style = db.fxStyle
    if (style == "reticle" or style == "ring") and not (ret or (BuildReticle() or ret)) then style = "solid" end
    if style == "halo" and not Halo.build() then style = "reticle" end
    if style == "halo" and not ret then BuildReticle() end -- the lock-on flash lives there
    local outline = (style == "outline") or (not canWarp and style ~= "ring" and style ~= "halo")
    local mode
    if style == "halo" then mode = "halo"
    elseif style == "ring" then mode = "ring"
    elseif style == "reticle" and canWarp then mode = "reticle"
    else mode = outline and "outline" or "solid" end

    local eb = LockEase()
    local key = size * 1000 + curve + (eliteKind and 0.01 or 0) + (db.fxGlow or 0) * 0.0001
    if not force and not lockActive and db.fxSpeed == 0 and shapeKey == key and shapeMode == mode then
        return
    end
    shapeKey = key

    if shapeMode ~= mode then
        -- switching style: clear whatever the old one drew, then show what the new one uses
        HideReticle()
        for i = 1, 4 do HideLines(i); HideStrips(i) end
        if mode == "solid" or mode == "reticle" then
            for i = 1, 4 do for j = 1, STRIPS do strips[i][j]:Show() end end
        end
        shapeMode = mode
    end

    if mode == "outline" then
        for i = 1, 4 do
            PlaceOutline(i, spin + (i - 1) * math.pi / 2, radius, base, height)
        end
        return
    end

    if mode == "solid" then
        DrawSolid(radius, base, height, curve, spin)
        return
    end

    if mode == "halo" then
        Halo.place(radius, spin, eb)
        return
    end

    if mode == "ring" then
        -- a ring on the ground at the target's feet, with a bright arc that travels around it
        local rx, ry, cy = radius * 0.72, radius * 0.25, -radius * 0.9
        if ret.groundDrawn ~= radius then -- the ring itself is still; draw it only when the size changes
            PlaceEllipse(ret.ground, GROUND_SEGS, 0, cy, rx, ry, 0, 2 * math.pi - 0.0001)
            ret.groundDrawn = radius
        end
        local turn = spin + (1 - eb) * math.pi * 0.8
        PlaceEllipse(ret.sweep, SWEEP_SEGS, 0, cy, rx, ry, turn, math.rad(65))
        if eliteKind then
            if eliteDrawn ~= radius then
                PlaceEllipse(ret.elite, ELITE_SEGS, 0, cy, rx * 1.16, ry * 1.16, 0, 2 * math.pi - 0.0001)
                eliteDrawn = radius
            end
        elseif eliteDrawn then
            HideSet(ret.elite); eliteDrawn = nil
        end
        return
    end

    -- reticle: the ring and blades turn together; a lock-on adds a short extra twist
    local turn = spin + (1 - eb) * math.pi * 0.6
    PlaceArcs(ret.ring, RING_ARCS, RING_SEGS, radius * 0.97, math.rad(70), turn + math.rad(10))
    if eliteKind then
        if eliteDrawn ~= radius then -- the fine outer ring doesn't turn, so draw it only when the size changes
            PlaceArcs(ret.elite, 1, ELITE_SEGS, radius * 1.1, 2 * math.pi - 0.0001, 0)
            eliteDrawn = radius
        end
    elseif eliteDrawn then
        HideSet(ret.elite); eliteDrawn = nil
    end
    DrawSolid(radius * 0.90, radius * 0.13, radius * 0.27, curve, turn)
end

-- Hit flash: any change to the target's health nudges the frame. The health
-- numbers themselves are secret in this client, so only "it changed" is used.
local hitFrame = CreateFrame("Frame")
hitFrame:RegisterUnitEvent("UNIT_HEALTH", "target")
hitFrame:SetScript("OnEvent", function()
    if fxVisible then hitStart = GetTime() end
end)

-- An OnUpdate only runs while its frame is shown, so everything is driven by
-- one always-shown frame. It does as little as it can:
--   * switched off and settled  -> returns straight away
--   * nothing animating         -> the camera blend runs 20 times a second
--   * a transition or zoom glide -> every frame, so it stays smooth
local fxDriver = CreateFrame("Frame")
local tm = { profile = 0, state = 0, geo = 0, anim = 0, idle = 0, awake = true } -- the driver's timers
do
    local wake = CreateFrame("Frame")
    wake:RegisterEvent("PLAYER_TARGET_CHANGED")
    wake:RegisterEvent("PLAYER_FOCUS_CHANGED")
    wake:RegisterEvent("PLAYER_ENTERING_WORLD")
    wake:SetScript("OnEvent", function(_, event)
        tm.awake = true
        if event == "PLAYER_ENTERING_WORLD" then Detect.slow.at = -1 end
    end)
end
local RefreshProfiles -- defined below
fxDriver:SetScript("OnUpdate", function(self, elapsed)
    if not db then return end
    if not db.enabled and tiltApplied == 0 and not tiltMoving then
        if fxVisible then FXHide() end
        FocusMarkHide()
        return
    end

    -- targeting frame. With no target and no focus (and nothing drawn) there is nothing to do, so it only looks
    -- again about once a second; target and focus changes wake it at once.
    local lazy = db.lowCpu
    tm.state = tm.state + elapsed
    if tm.awake or fxVisible or fxTest or tm.state >= 1 then
        if tm.state >= (lazy and 0.2 or 0.1) or tm.state >= 1 then
            FXState(tm.state)
            tm.state = 0
            tm.awake = Truth(UnitExists, "target") or Truth(UnitExists, "focus") or false
        end
    end
    if fxVisible then
        tm.anim = tm.anim + elapsed
        if tm.anim >= (lazy and 0.066 or 0.033) then
            tm.anim = 0
            FXAnimate()
        end
        tm.geo = tm.geo + elapsed
        local spinDeg = math.abs(db.fxSpeed)
        if lockActive then
            if tm.geo >= 1 / 30 then tm.geo = 0; FXShape() end
        elseif spinDeg ~= 0 then
            -- keep each step under ~0.5 degree, but never faster than 30 Hz
            local reticle = db.fxStyle == "reticle" or db.fxStyle == "ring" or db.fxStyle == "halo"
                local interval = math.max(lazy and 1 / 12 or (reticle and 1 / 15 or 1 / 30), math.min(0.1, (reticle and 0.7 or 0.5) / spinDeg))
            if tm.geo >= interval then
                tm.geo = 0
                FXShape()
            end
        elseif tm.geo >= 0.1 then
            tm.geo = 0
            FXShape() -- returns at once unless size or curvature changed
        end
    end

    -- camera blend and tilt
    if trans or zoomGlide or tiltMoving or Detect.talkMul < 1 or Detect.talkAt then
        StepBlend(elapsed)
        StepTilt(elapsed)
        tm.idle = 0
    else
        -- settled: only the speed / crowd field-of-view extras need a quick pace; otherwise a slow check is plenty
        tm.idle = tm.idle + elapsed
        local dyn = shown and ((shown.fovSpeed or 0) > 0.05 or (shown.crowdFov or 0) > 0.05)
        if dyn then
            -- the field of view extras are stepped every frame (every other frame in low-CPU mode)
            tm.fovT = (tm.fovT or 0) + elapsed
            if tm.fovT >= (lazy and 0.033 or 0) then
                Detect.stepFov(tm.fovT)
                tm.fovT = 0
            end
        end
        local comp = Detect.comp.active()
        if comp then
            -- zooming moves the compensated shoulder, so it is stepped every frame while a curve is in use
            tm.shT = (tm.shT or 0) + elapsed
            if tm.shT >= (lazy and 0.033 or 0) then
                Detect.stepShoulder(tm.shT)
                tm.shT = 0
            end
        end
        if tm.idle >= 0.2 then
            StepBlend(tm.idle, dyn, comp)
            StepTilt(tm.idle)
            tm.idle = 0
        end
    end

    Detect.ml.step(elapsed) -- mouse-look lock
    Detect.fade.step(elapsed) -- Talk: fades the rest of the interface while a window is open

    -- settings the game may have changed back
    tm.guard = (tm.guard or 0) + elapsed
    if Detect.guardSoon or tm.guard >= (lazy and 2 or 1) then
        tm.guard, Detect.guardSoon = 0, nil
        Detect.guard()
    end

    -- situation profile
    tm.profile = tm.profile + elapsed
    if tm.profile > (lazy and 0.2 or 0.1) then
        RefreshProfiles(tm.profile)
        tm.profile = 0
    end
end)

-- How long a new situation must hold before the profile switches. Instant for
-- dungeons and combat, short for talking to an NPC, a little longer for water
-- and cities (whose checks flicker at the edges), and longest for leaving a
-- building or combat, so a doorway can't make the camera flip back and forth.
local function SwitchDelay(oldName, newName)
    if Detect.skipDelay then return 0 end
    if newName == "instance" or newName == "combat" then return 0 end
    if oldName == "combat" then return 1.0 end
    if oldName == "instance" then return 1.0 end
    if newName == "npc" then return 0.1 end
    if oldName == "npc" then return 0.2 end -- Talk already holds for a few seconds on its own
    if newName == "swimming" then return 0.4 end
    if oldName == "swimming" then return 1.0 end
    if oldName == "indoors" then return 1.5 end
    if oldName == "city" then return 1.0 end
    if newName == "city" then return 0.5 end
    return 0.3
end

-- Preview a situation from the settings window (nil stops the preview).
local function SetPreview(name)
    if previewProfile == name then return end
    previewProfile = name
    Detect.skipDelay = true
end

local pending, pendingFor = nil, 0
RefreshProfiles = function(dt)
    if not db or not db.enabled then return end
    local want = WantedProfile()
    if want == activeProfile then
        pending, Detect.skipDelay = nil, false
        ConstrainZoom(false)
        return
    end
    if pending ~= want then pending, pendingFor = want, 0 else pendingFor = pendingFor + dt end
    local taxi = OnTaxi()
    if not taxi and pendingFor < SwitchDelay(activeProfile, want) then return end

    pending, Detect.skipDelay = nil, false
    -- remember how far out you were in the profile you're leaving
    local z = GetCameraZoom and GetCameraZoom()
    if type(z) == "number" and not issecret(z) then zoomMemory[activeProfile] = z end
    if taxi then
        -- flight path: jump straight to Exploration with no easing
        trans = nil
        wipe(shown)
    else
        BeginTransition(activeProfile, want)
    end
    activeProfile = want
    Refresh()
    ConstrainZoom(true)
end

---------------------------------------------------------------------------
-- Settings window
---------------------------------------------------------------------------

local controls = {}

-- Look: a dark parchment-style box with the classic thin tooltip border, gold
-- headings and hairline rules; nothing else.
local BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 32, edgeSize = 14,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local GOLD = { 1, 0.82, 0 }

local function MakeCheck(parent, label, key, x, y, onChange, tblFn)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x - 2, y)
    cb:SetSize(26, 26) -- not SetScale: that would also stretch the offsets above
    local t = cb.Text or cb.text or _G[cb:GetName() and (cb:GetName() .. "Text") or ""]
    if not t then
        t = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        t:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    end
    t:SetText(L[label])
    if t.SetFontObject then t:SetFontObject("GameFontHighlightSmall") end
    cb.tkLabel = t -- the gamepad cursor wraps the label too
    cb:SetScript("OnClick", function(self)
        local t = tblFn and tblFn() or db
        t[key] = self:GetChecked() and true or false
        if onChange then onChange() else Refresh() end
    end)
    controls[#controls + 1] = function() cb:SetChecked((tblFn and tblFn() or db)[key]) end
    return cb
end

local sliderCount = 0
local function MakeSlider(parent, label, key, minV, maxV, step, cx, y, noRefresh, tblFn)
    sliderCount = sliderCount + 1
    local name = "TenKsARPGCameraSlider" .. sliderCount
    local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    s:SetPoint("TOP", parent, "TOPLEFT", cx, y)
    s:SetWidth(220)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end

    local text = s.Text or _G[name .. "Text"]
    local low  = s.Low  or _G[name .. "Low"]
    local high = s.High or _G[name .. "High"]
    if low then low:SetText(minV) end
    if high then high:SetText(maxV) end
    if text and text.SetFontObject then text:SetFontObject("GameFontHighlightSmall") end

    local function Show(v)
        if text then text:SetText(string.format("%s: %.2f", L[label], v)) end
    end

    s:SetScript("OnValueChanged", function(self, value)
        if self.refreshing then return end
        value = math.floor(value / step + 0.5) * step
        local t = tblFn and tblFn() or db
        t[key] = value
        Show(value)
        if (key == "zoomDist" or key == "zoomMin" or key == "zoomMax") and ConstrainZoom and editProfile == activeProfile then ConstrainZoom(true) end
        if key == "menuAlpha" and panel then panel:SetBackgroundOpacity(value) end
        if not noRefresh then Refresh() end
    end)

    controls[#controls + 1] = function()
        s.refreshing = true
        local v = (tblFn and tblFn() or db)[key]
        s:SetValue(v)
        s.refreshing = false
        Show(v)
    end
    return s
end

---------------------------------------------------------------------------
-- Presets: snapshots of every setting, built-in styles, your own saved ones,
-- and a text code for sharing a configuration between installations.
--
-- A snapshot is a flat table. Plain settings use their own names ("fxSize"),
-- situation-profile values use paths ("profiles.combat.fov"). Anything a
-- snapshot leaves out keeps its current value when applied.
---------------------------------------------------------------------------

-- Not part of a snapshot: runtime/bookkeeping data, window preferences, and
-- the old top-level copies of values that now live in the profiles.
local SNAPSHOT_SKIP = {
    enabled = true, orig = true, profiles = true, presets = true, menuTab = true,
    menuAlpha = true, hideWarning = true, followStyle = true, reticleV1 = true,
    shoulder = true, zoom = true, headMove = true, yaw = true, pitch = true,
    activePreset = true, lowCpu = true, npOrig = true, npInit = true, npManage = true, npEnemies = true, npEnemyMinor = true,
    npEnemyPets = true, npEnemyTotems = true, npFriendlyPlayers = true, npFriendlyNpcs = true,
    npFriendlyPets = true, npFriendlyTotems = true, rzOn = true, rzStep = true, rzSpeed = true, talkKeepFrames = true, mlToggle = true, -- nameplates are a personal screen preference, not part of a preset
}
local PROFILE_FIELDS = {
    on = "boolean", tilt = "number", fov = "number", shoulder = "number", zoom = "number",
    headMove = "number", yaw = "number", pitch = "number", blend = "number",
    zoomRemember = "boolean", zoomSet = "boolean", zoomDist = "number",
    vigAlpha = "number", vigRange = "number", vigCurve = "number",
    lbSize = "number", fovSpeed = "number", crowdFov = "number",
    shComp = "boolean", shCurve = "string",
    headStand = "number", headMoving = "number", headReact = "number",
    zoomKind = "number", zoomMin = "number", zoomMax = "number",
}
local RANGES = {
    fov = { 50, 90 }, zoom = { 1, 3.5 }, shoulder = { -10, 10 }, headMove = { 0, 1 }, yaw = { 0, 1 },
    pitch = { 0, 1 }, tilt = { -20, 20 }, blend = { 0.2, 5 }, zoomDist = { 0, 40 }, blendTime = { 0.2, 5 },
    rampTime = { 0.1, 2 }, smooth = { 0.2, 1 }, fxSize = { 40, 300 },
    fxOffset = { -100, 100 }, fxSpeed = { -180, 180 }, fxAlpha = { 0.2, 1 }, fxCurve = { 0, 1 },
    fxDistShift = { -40, 40 }, fxGlow = { 0, 1 },
    headStand = { 0, 1 }, headMoving = { 0, 1 }, headReact = { 1, 20 }, zoomKind = { 0, 3 }, zoomMin = { 1, 40 }, zoomMax = { 1, 40 },
    rzStep = { 0.5, 8 }, rzSpeed = { 10, 80 }, talkFadeAlpha = { 0, 1 },
    vigAlpha = { 0, 1 }, vigRange = { 0.05, 0.5 }, vigCurve = { 0.5, 4 },
    lbSize = { 0, 0.15 }, fovSpeed = { 0, 20 }, crowdFov = { 0, 20 }, fxOocAlpha = { 0, 1 }, fxFriendScale = { 0.4, 1 },
}
local STYLES = { halo = true, reticle = true, ring = true, solid = true, outline = true }
local SNAPSHOT_VERSION = "TKAC1"

-- Which kind of value does this snapshot key hold? Returns type and range key, or nil if it isn't a setting.
local function KeyInfo(key)
    local prof, field = key:match("^profiles%.(%a+)%.(%a+)$")
    if prof then
        if not PROFILE_NAMES[prof] then return nil end
        if field == "on" and prof == "world" then return nil end
        local t = PROFILE_FIELDS[field]
        return t, field
    end
    if SNAPSHOT_SKIP[key] or DEFAULTS[key] == nil then return nil end
    return type(DEFAULTS[key]), key
end

-- A cleaned value for this key (right type, inside its range), or nil to reject it.
local function CleanValue(key, v)
    local t, rk = KeyInfo(key)
    if not t or type(v) ~= t then return nil end
    if t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return nil end
        local r = RANGES[rk]
        if r then v = math.max(r[1], math.min(r[2], v)) end
    elseif t == "string" then
        if key == "fxStyle" then
            if not STYLES[v] then return nil end
        elseif rk == "shCurve" or key == "shCompCurve" then
            if not Detect.comp.valid(v) then return nil end
        else
            return nil
        end
    end
    return v
end

local function CurrentSnapshot()
    local snap = {}
    for k, def in pairs(DEFAULTS) do
        if not SNAPSHOT_SKIP[k] and def ~= nil and db[k] ~= nil then snap[k] = db[k] end
    end
    for _, name in ipairs(PROFILES) do
        local pr = db.profiles and db.profiles[name]
        if pr then
            for f in pairs(PROFILE_FIELDS) do
                if pr[f] ~= nil and KeyInfo("profiles." .. name .. "." .. f) then
                    snap["profiles." .. name .. "." .. f] = pr[f]
                end
            end
        end
    end
    return snap
end

-- Built-in presets are the factory configuration plus a list of changes.
local BUILTIN_ORDER = { "Default", "Cinematic", "Tactical", "Comfort", "Controller", "Action RPG", "First Person" }
local BUILTIN_NOTES = {
    Default = L["The addon's signature look: a tilted, easy-going exploration view, a steady wide combat view with a light edge vignette, a close indoor view, and a cinematic Talk view with letterbox bars."],
    Cinematic = L["Film-like. Long lenses, high smooth camera, slow transitions. Indoors it tightens into a close shot, Talk gets a tight portrait with wide letterbox bars, swimming drifts. Light vignettes add depth without darkening the scene."],
    Tactical = L["For raids and dungeons: the view stays wide, level and steady in every situation, with quick, subtle changes, almost no pull toward targets, and no letterbox bars."],
    Controller = L["Close over-the-shoulder action camera for a controller, from the couch or on a handheld: the character sits low to one side with a tight follow distance, strong pull toward targets so you rarely need the right stick, a snappy combat camera that widens as enemies and speed pick up, a bigger targeting frame, and no head bob. The settings window also works with a controller."],
    ["Action RPG"] = L["Plays like a modern action RPG with mouse and keyboard: the camera is locked to the mouse, so you aim and steer by moving it, with the Controller preset's close over-the-shoulder framing and snappy combat camera, but a lighter pull toward targets so it never fights your hand. Bind \"Free the cursor\" to get the pointer back."],
    ["First Person"] = L["Through your character's eyes, with the camera locked to the mouse. The field of view tells you where you are: narrow indoors and in Talk, medium in cities, combat and dungeons, wide out exploring and swimming. Scroll out any time; the next situation change brings you back in."],
    Comfort = L["One steady view everywhere, for anyone who gets motion sick. No bobbing, sway, terrain tilt or dynamic pitch, a constant field of view, no situation changes, slow soft turning, and a light vignette to rest the eyes."],
}
local FactorySnapshot, BUILTIN_CHANGES
do
local Flatten, Situations
-- Every situation starts from these values; a preset lists only what differs.
local PROFILE_BASE = {
    on = true, tilt = 0, fov = 85, shoulder = 1, zoom = 3.5, headMove = 0.75, yaw = 0.25, pitch = 0.25,
    blend = 1.5, zoomRemember = true, zoomSet = false, zoomDist = 10,
    vigAlpha = 0, vigRange = 0.3, vigCurve = 2, lbSize = 0, fovSpeed = 0, crowdFov = 0,
    shComp = false, shCurve = "0:1,50:1",
    headStand = 0.3, headMoving = 0.5, headReact = 10, zoomKind = 0, zoomMin = 5, zoomMax = 20,
}

-- Turns { top-level settings, per-situation tables } into a flat snapshot-style table.
Flatten = function(top, sit)
    local out = {}
    for k, v in pairs(top or {}) do out[k] = v end
    for name, t in pairs(sit or {}) do
        for k, v in pairs(t) do out["profiles." .. name .. "." .. k] = v end
    end
    return out
end

-- The factory situations (the "Default" look).
local FACTORY_SITUATIONS = {
    world      = { tilt = 14, headMove = 0.75, blend = 3.5 },
    combat     = { headReact = 12, headStand = 0.2, headMoving = 0.85, tilt = 8, fov = 80, headMove = 0.8, yaw = 0.4, pitch = 0.35, zoom = 3, blend = 1, zoomDist = 15,
                   vigAlpha = 0.3, vigRange = 0.28, vigCurve = 2.2, crowdFov = 8 },
    indoors    = { tilt = 2, fov = 70, headMove = 0.4, yaw = 0.5, pitch = 0.5, zoom = 1.5, blend = 1, zoomRemember = false,
                   zoomSet = true, zoomDist = 5, vigAlpha = 0.35 },
    swimming   = { tilt = 6, fov = 80, headMove = 0.6, zoom = 2.5, blend = 2,
                   vigAlpha = 0.25, vigRange = 0.35 },
    city       = { tilt = 10, fov = 85, headMove = 0.5, yaw = 0.15, pitch = 0.15, zoom = 3, blend = 3 },
    npc        = { fov = 58, headMove = 0.3, yaw = 0.7, pitch = 0.7, zoom = 1.5, blend = 1.2,
                   zoomRemember = false, zoomSet = true, zoomDist = 4, vigAlpha = 0.25, vigRange = 0.35, lbSize = 0.05 },
    instance   = { tilt = 6, fov = 84, headMove = 0.2, yaw = 0.3, pitch = 0.25, blend = 1.2,
                   vigAlpha = 0.22, vigRange = 0.26, vigCurve = 2.2 },
}

-- A complete set of situations: the base values, then each situation's own.
Situations = function(over)
    local sit = {}
    for _, name in ipairs(PROFILES) do
        local t = {}
        for k, v in pairs(PROFILE_BASE) do t[k] = v end
        if name == "world" then t.on = nil end
        for k, v in pairs(over[name] or {}) do t[k] = v end
        sit[name] = t
    end
    return sit
end

-- The addon's out-of-the-box configuration.
FactorySnapshot = function()
    local snap = {}
    for k, def in pairs(DEFAULTS) do
        if not SNAPSHOT_SKIP[k] and def ~= nil then snap[k] = def end
    end
    for k, v in pairs(Flatten(nil, Situations(FACTORY_SITUATIONS))) do snap[k] = v end
    return snap
end

local top = {
    Cinematic = {
        smooth = 0.4, rampTime = 0.6, blendAll = false, slowExit = true, blendTime = 2.4,
        bobbing = true, terrainTilt = true, dynamicPitch = true, shCompShare = true, shCompCurve = Detect.comp.fromPower(0.4), talkFade = true, talkFadeAlpha = 0,
        fxSize = 210, fxGlow = 0.9, fxAlpha = 0.8, fxSpeed = 6, fxLock = true, fxHit = true,
    },
    Tactical = {
        smooth = 0.9, rampTime = 0.15, blendAll = false, slowExit = false, blendTime = 0.7,
        bobbing = false, terrainTilt = false, dynamicPitch = false,
        fxSize = 240, fxGlow = 0.35, fxAlpha = 0.85, fxSpeed = 0, fxLock = false, fxHit = false, fxElite = true,
    },
    Controller = {
        smooth = 0.65, rampTime = 0.3, blendAll = false, slowExit = false, blendTime = 1.2,
        bobbing = false, terrainTilt = true, dynamicPitch = true, shCompShare = true, shCompCurve = Detect.comp.fromPower(0.6),
        fxSize = 260, fxGlow = 0.9, fxAlpha = 0.9, fxSpeed = 4, fxLock = true, fxHit = true, fxElite = true,
        fxFriendScale = 0.7,
    },
    Comfort = {
        smooth = 0.5, rampTime = 0.5, blendAll = false, slowExit = true, blendTime = 1.8,
        bobbing = false, terrainTilt = false, dynamicPitch = false,
        fxSize = 200, fxGlow = 0.4, fxAlpha = 0.8, fxSpeed = 0, fxLock = false, fxHit = false,
    },
}
local cinematic = {
    world      = { shoulder = 2.2, fov = 74, headMove = 1, tilt = 12, yaw = 0.25, pitch = 0.2, blend = 2.4,
                   vigAlpha = 0.15, vigCurve = 2.4, fovSpeed = 6 },
    indoors    = { shoulder = 2.2, fov = 60, headMove = 0.6, tilt = 0, yaw = 0.45, pitch = 0.45, zoom = 1, zoomSet = true,
                   zoomRemember = false, zoomDist = 4.5, blend = 2.8, vigAlpha = 0.26, vigCurve = 2.6 },
    combat     = { headReact = 9, headStand = 0.25, headMoving = 0.9, shoulder = 2.2, fov = 62, headMove = 0.9, tilt = 9, yaw = 0.45, pitch = 0.45, zoom = 2.2,
                   zoomSet = true, zoomRemember = false, zoomDist = 8, blend = 1.1,
                   vigAlpha = 0.22, vigRange = 0.24, vigCurve = 3, crowdFov = 6 },
    swimming   = { shoulder = 2.2, fov = 66, headMove = 1, tilt = 5, yaw = 0.25, pitch = 0.2, zoom = 3, blend = 2.8,
                   vigAlpha = 0.22, vigRange = 0.32, vigCurve = 2.4 },
    city       = { shoulder = 2.2, fov = 70, headMove = 0.8, tilt = 10, yaw = 0.2, pitch = 0.15, blend = 3,
                   vigAlpha = 0.1, vigCurve = 2.4, fovSpeed = 4 },
    npc        = { shoulder = 2.2, fov = 50, headMove = 0.3, yaw = 0.7, pitch = 0.7, zoom = 1.2, zoomSet = true,
                   zoomRemember = false, zoomDist = 3.2, blend = 2, vigAlpha = 0.28, vigCurve = 2.6, lbSize = 0.09 },
    instance   = { shoulder = 2.2, fov = 72, headMove = 0.5, tilt = 8, yaw = 0.3, pitch = 0.25, zoom = 3, blend = 1.6,
                   vigAlpha = 0.2, vigCurve = 2.4 },
}
local tactical = {
    world      = { shoulder = 0.7, fov = 80, headMove = 0.3, tilt = 6, yaw = 0.3, pitch = 0.2, blend = 0.8,
                   vigRange = 0.25 },
    indoors    = { tilt = 0, shoulder = 0.7, fov = 90, headMove = 0, yaw = 0.15, pitch = 0.05, zoom = 2.5, blend = 0.6,
                   vigAlpha = 0.12, vigRange = 0.2, vigCurve = 3 },
    combat     = { tilt = 3, shoulder = 0.7, fov = 90, headMove = 0, yaw = 0.06, pitch = 0, blend = 0.35, zoomDist = 15,
                   vigAlpha = 0.2, vigRange = 0.16, vigCurve = 3.5 },
    swimming   = { tilt = 2, shoulder = 0.7, fov = 90, headMove = 0, yaw = 0.15, pitch = 0.1, zoom = 3, blend = 0.6 },
    city       = { shoulder = 0.7, fov = 90, headMove = 0.2, tilt = 5, yaw = 0.15, pitch = 0.1, blend = 0.8 },
    npc        = { shoulder = 0.7, fov = 72, headMove = 0, yaw = 0.5, pitch = 0.35, zoom = 2, zoomSet = true,
                   zoomRemember = false, zoomDist = 5, blend = 0.5, vigAlpha = 0.1, vigRange = 0.2, vigCurve = 3 },
    instance   = { tilt = 3, shoulder = 0.7, fov = 90, headMove = 0, yaw = 0.06, pitch = 0, blend = 0.35,
                   vigAlpha = 0.16, vigRange = 0.16, vigCurve = 3.5 },
}
-- Controller: cinematic action, wide for a TV across the room or a handheld's small screen (the game caps the
-- field of view at 90), strong auto-focus so the right stick is rarely needed, snappy combat.
local controller = {
    world      = { shoulder = 1.6, fov = 70, headMove = 0.4, tilt = 9, yaw = 0.35, pitch = 0.3, zoom = 3, zoomSet = true,
                   zoomRemember = false, zoomDist = 10, blend = 1.6, vigAlpha = 0.12, vigCurve = 2.4, fovSpeed = 5 },
    indoors    = { shoulder = 1.6, fov = 70, headMove = 0.3, tilt = 2, yaw = 0.5, pitch = 0.5, zoom = 1.6, zoomSet = true,
                   zoomRemember = false, zoomDist = 5, blend = 1, vigAlpha = 0.25, vigCurve = 2.6 },
    combat     = { headReact = 14, headStand = 0.15, headMoving = 0.9, shoulder = 1.6, fov = 74, headMove = 0.7, tilt = 8, yaw = 0.55, pitch = 0.45, zoom = 2.6,
                   zoomSet = true, zoomRemember = false, zoomDist = 8, blend = 0.6,
                   vigAlpha = 0.25, vigRange = 0.26, vigCurve = 3, fovSpeed = 4, crowdFov = 8 },
    swimming   = { shoulder = 1.6, fov = 72, headMove = 0.5, tilt = 5, yaw = 0.3, pitch = 0.25, zoom = 3, zoomSet = true,
                   zoomRemember = false, zoomDist = 10, blend = 2, vigAlpha = 0.2, vigRange = 0.32, vigCurve = 2.4 },
    city       = { shoulder = 1.6, fov = 70, headMove = 0.4, tilt = 9, yaw = 0.25, pitch = 0.2, zoom = 3, zoomSet = true,
                   zoomRemember = false, zoomDist = 10, blend = 2.5, vigAlpha = 0.1, vigCurve = 2.4, fovSpeed = 4 },
    npc        = { shoulder = 1.6, fov = 54, headMove = 0.2, yaw = 0.7, pitch = 0.7, zoom = 1.3, zoomSet = true,
                   zoomRemember = false, zoomDist = 3.5, blend = 1.2, vigAlpha = 0.28, vigCurve = 2.6, lbSize = 0.06 },
    instance   = { shoulder = 1.6, fov = 74, headMove = 0.2, tilt = 8, yaw = 0.5, pitch = 0.4, zoom = 3, zoomSet = true,
                   zoomRemember = false, zoomDist = 10, blend = 0.7,
                   vigAlpha = 0.24, vigRange = 0.24, vigCurve = 3, fovSpeed = 4, crowdFov = 8 },
}
-- Cinematic and Controller keep the character where it is on screen as you zoom, in every situation
for _, set in ipairs({ { cinematic, 0.4 }, { controller, 0.6 } }) do
    for _, name in ipairs(PROFILES) do
        set[1][name].shComp, set[1][name].shCurve = true, Detect.comp.fromPower(set[2])
    end
end
-- Action RPG: the Controller framing, steered with the mouse (camera locked to it). Target pull is lighter so it
-- never fights the mouse, and the camera turns quicker.
local arpg = {}
for _, name in ipairs(PROFILES) do
    local t = {}
    for k, v in pairs(controller[name]) do t[k] = v end
    t.yaw, t.pitch = (t.yaw or 0.25) * 0.6, (t.pitch or 0.25) * 0.6
    arpg[name] = t
end
arpg.combat.zoomDist, arpg.world.zoomDist, arpg.city.zoomDist = 9, 11, 11
top["Action RPG"] = {}
for k, v in pairs(top.Controller) do top["Action RPG"][k] = v end
top["Action RPG"].mlOn, top["Action RPG"].smooth, top["Action RPG"].rampTime, top["Action RPG"].fxSize = true, 0.85, 0.25, 230
-- First Person: in your character's eyes in every situation; the field of view marks the situation.
local NARROW, MEDIUM, WIDE = 60, 75, 90
local fpFov = { indoors = NARROW, npc = NARROW, city = MEDIUM, combat = MEDIUM, instance = MEDIUM, world = WIDE, swimming = WIDE }
local fp = {}
for _, name in ipairs(PROFILES) do
    fp[name] = { fov = fpFov[name], shoulder = 0, shComp = false, tilt = 0, zoom = 3, zoomSet = true, zoomRemember = false,
                 zoomKind = 0, zoomDist = 0, headMove = 0.35, headStand = 0.15, headMoving = 0.35, headReact = 10,
                 yaw = 0.12, pitch = 0.08, blend = 1.2, vigAlpha = 0.1, vigRange = 0.25, vigCurve = 2.6, fovSpeed = 0, crowdFov = 0 }
end
fp.combat.yaw, fp.combat.pitch, fp.combat.blend, fp.combat.headMove, fp.combat.headMoving = 0.2, 0.12, 0.8, 0.5, 0.5
fp.npc.yaw, fp.npc.pitch, fp.npc.lbSize, fp.npc.vigAlpha = 0.5, 0.4, 0.04, 0.2
fp.indoors.vigAlpha = 0.18
top["First Person"] = {
    mlOn = true, smooth = 0.9, rampTime = 0.3, blendAll = false, slowExit = false, blendTime = 1.2,
    bobbing = false, terrainTilt = false, dynamicPitch = false, shCompShare = false,
    fxSize = 220, fxGlow = 0.7, fxAlpha = 0.8, fxSpeed = 4, fxLock = true, fxHit = true,
}
-- Comfort: the same steady view everywhere; only the world profile is in use.
local comfort = {}
for _, name in ipairs(PROFILES) do
    comfort[name] = { on = false, fov = 85, shoulder = 0.3, headMove = 0, tilt = 4, yaw = 0.12, pitch = 0.08,
                      blend = 1.8, vigAlpha = 0.12, vigRange = 0.3, vigCurve = 2 }
end
comfort.world.on = nil
BUILTIN_CHANGES = {
    Default = {},
    Cinematic = Flatten(top.Cinematic, Situations(cinematic)),
    Tactical = Flatten(top.Tactical, Situations(tactical)),
    Comfort = Flatten(top.Comfort, Situations(comfort)),
    Controller = Flatten(top.Controller, Situations(controller)),
    ["Action RPG"] = Flatten(top["Action RPG"], Situations(arpg)),
    ["First Person"] = Flatten(top["First Person"], Situations(fp)),
}
end
local function BuiltinSnapshot(name)
    local snap = FactorySnapshot()
    for k, v in pairs(BUILTIN_CHANGES[name] or {}) do snap[k] = v end
    return snap
end
local function IsBuiltin(name) return BUILTIN_CHANGES[name] ~= nil end

local MAX_CUSTOM_PRESETS = 9
local function CustomNames()
    local names = {}
    for n in pairs(db.presets or {}) do names[#names + 1] = n end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    return names
end
local function FindPresetName(text)
    text = (text or ""):lower()
    for _, n in ipairs(BUILTIN_ORDER) do if n:lower() == text then return n, true end end
    for n in pairs(db.presets or {}) do if n:lower() == text then return n, false end end
end
local function PresetSnapshot(name)
    if IsBuiltin(name) then return BuiltinSnapshot(name) end
    return db.presets and db.presets[name]
end
local function CleanName(text)
    text = (text or ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("[^%w _%-%.']", "")
    return text:sub(1, 24)
end

-- Write a snapshot's values into the saved settings (no re-apply).
local function WriteSnapshot(snap)
    local applied = 0
    db.profiles = db.profiles or {}
    for key, raw in pairs(snap) do
        local v = CleanValue(key, raw)
        if v ~= nil then
            local prof, field = key:match("^profiles%.(%a+)%.(%a+)$")
            if prof then
                db.profiles[prof] = db.profiles[prof] or {}
                db.profiles[prof][field] = v
            else
                db[key] = v
            end
            applied = applied + 1
        end
    end
    if snap.focusAll == false then -- older presets and codes: "Focus ALL targets" off meant no friendly targets
        for _, k in ipairs(FRIENDLY_FOCUS_KEYS) do
            if snap[k] == nil then db[k] = false end
        end
    end
    return applied
end

-- Does the current configuration differ from the preset last applied?
-- The settings from just before the last preset was applied or imported (kept until you log out).
local PresetUndo = {}

function PresetUndo.isModified()
    local snap = db.activePreset and (IsBuiltin(db.activePreset) and BuiltinSnapshot(db.activePreset)
        or (db.presets and db.presets[db.activePreset]))
    if not snap then return false end
    local cur = CurrentSnapshot()
    for k, v in pairs(snap) do
        local want = CleanValue(k, v)
        local have = cur[k]
        if want ~= nil and have ~= nil then
            if type(want) == "number" then
                if math.abs(want - have) > 1e-4 then return true end
            elseif want ~= have then
                return true
            end
        end
    end
    return false
end

-- Write a snapshot and re-apply everything.
local ApplySnapshot
ApplySnapshot = function(snap, label, isUndo)
    if not isUndo then PresetUndo.snap, PresetUndo.label = CurrentSnapshot(), db.activePreset end
    local applied = WriteSnapshot(snap)
    db.activePreset = label
    -- start the camera from the new values cleanly
    if db.enabled then Disable(); Enable() end
    shownColor = nil; eliteKind = nil
    if panel then
        if panel.RefreshProfileWidgets then panel.RefreshProfileWidgets() end
        if panel.ShowBlend then panel.ShowBlend() end
    end
    return applied
end

-- Go back to what you had before the last preset was applied (and again to redo it).
function PresetUndo.undo()
    if not PresetUndo.snap then return false end
    local snap, label = PresetUndo.snap, PresetUndo.label
    PresetUndo.snap, PresetUndo.label = CurrentSnapshot(), db.activePreset
    ApplySnapshot(snap, label, true)
    return true
end

-- Text form: "TKAC1;key=value;key=value;..." sorted by key, no spaces.
local function ExportString(snap)
    local keys = {}
    for k in pairs(snap) do keys[#keys + 1] = k end
    table.sort(keys)
    local parts = { SNAPSHOT_VERSION }
    for _, k in ipairs(keys) do
        local v = snap[k]
        local text
        if type(v) == "number" then text = string.format("%.6g", v)
        elseif type(v) == "boolean" then text = v and "true" or "false"
        else text = tostring(v) end
        parts[#parts + 1] = k .. "=" .. text
    end
    return table.concat(parts, ";")
end

-- Returns a snapshot (only valid entries) plus counts, or nil and a reason.
local function ParseString(text)
    text = (text or ""):gsub("%s+", "")
    local header, rest = text:match("^(%w+);(.*)$")
    if header ~= SNAPSHOT_VERSION then
        return nil, "That doesn't look like a settings code (it should start with " .. SNAPSHOT_VERSION .. ";)."
    end
    local snap, good, bad = {}, 0, 0
    for pair in rest:gmatch("[^;]+") do
        local k, v = pair:match("^([%w%.]+)=(.+)$")
        if k == "focusAll" then
            if v == "false" then snap.focusAll = false end -- applied by WriteSnapshot, never stored as a setting
        elseif k then
            local value
            if v == "true" then value = true elseif v == "false" then value = false
            else value = tonumber(v) or v end
            local clean = CleanValue(k, value)
            if clean ~= nil then snap[k] = clean; good = good + 1 else bad = bad + 1 end
        else
            bad = bad + 1
        end
    end
    if good == 0 then return nil, "No usable settings were found in that code." end
    return snap, good, bad
end

-- Welcome window ---------------------------------------------------------------
-- Shown once, the first time the addon runs: pick a starting look. /acam welcome opens it again.
do
local WELCOME = {
    { "Default", { 1.00, 0.82, 0.20 }, "The signature look. A good place to start." },
    { "Cinematic", { 0.75, 0.50, 1.00 }, "Long lenses, a slow smooth camera, letterbox Talk scenes." },
    { "Tactical", { 1.00, 0.35, 0.30 }, "Wide, level and steady. Made for dungeons and raids." },
    { "Comfort", { 0.45, 0.85, 0.35 }, "One steady view, no bobbing or sway. Easy on the eyes." },
    { "Controller", { 1.00, 0.50, 0.75 }, "Close over-the-shoulder action camera for a gamepad, from the couch or a handheld." },
    { "Action RPG", { 1.00, 0.55, 0.20 }, "Camera locked to the mouse, over the shoulder. Aim and steer like an action game." },
    { "First Person", { 0.30, 0.75, 0.95 }, "Through your own eyes, mouse-locked. The field of view changes with the situation." },
}
local win
function TenKsUltimateARPGCamera_ShowWelcome()
    if win then win:Show() return end
    local native = false
    local ok, f = pcall(CreateFrame, "Frame", "TenKsARPGCameraWelcome", UIParent, "BasicFrameTemplateWithInset")
    if ok and f and (type(f.Bg) == "table" or type(f.InsetBg) == "table" or type(f.CloseButton) == "table") then
        native = true
    else
        f = CreateFrame("Frame", "TenKsARPGCameraWelcome", UIParent)
        local base = f:CreateTexture(nil, "BACKGROUND")
        base:SetAllPoints()
        base:SetColorTexture(0.09, 0.07, 0.05, 0.97)
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)
    end
    win = f
    f:SetSize(440, 440)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, "TenKsARPGCameraWelcome")
    local title = L["Welcome to 10k's Ultimate ARPG Camera"]
    if native and f.SetTitle then f:SetTitle(title)
    elseif native and type(f.TitleText) == "table" then f.TitleText:SetText(title)
    else
        local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        t:SetPoint("TOPLEFT", 16, -12)
        t:SetText(title)
    end
    local intro = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    intro:SetPoint("TOPLEFT", 20, -40)
    intro:SetWidth(400)
    intro:SetJustifyH("LEFT")
    intro:SetText(L["Pick a starting look. You can change it any time: type /acam and open the Presets tab."])
    for i, w in ipairs(WELCOME) do
        local y = -92 - (i - 1) * 40
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(110, 28)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", 20, y)
        b:SetText(L[w[1]])
        local fs = b.GetFontString and b:GetFontString()
        if fs and fs.SetTextColor then fs:SetTextColor(w[2][1], w[2][2], w[2][3]) end
        local bar = b:CreateTexture(nil, "OVERLAY")
        bar:SetColorTexture(w[2][1], w[2][2], w[2][3], 0.9)
        bar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 6, 4)
        bar:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -6, 4)
        bar:SetHeight(2)
        local d = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        d:SetPoint("LEFT", b, "RIGHT", 12, 0)
        d:SetWidth(280)
        d:SetJustifyH("LEFT")
        d:SetText(L[w[3]])
        b:SetScript("OnClick", function()
            ApplySnapshot(BuiltinSnapshot(w[1]), w[1])
            if panel and panel.RefreshPresetList then panel.RefreshPresetList() end
            Print(L["Applied preset"] .. " \"" .. w[1] .. "\".")
            f:Hide()
        end)
    end
    local skip = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    skip:SetSize(200, 24)
    skip:SetPoint("BOTTOM", f, "BOTTOM", 0, 36)
    skip:SetText(L["Keep my current settings"])
    skip:SetScript("OnClick", function() f:Hide() end)
    local foot = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    foot:SetPoint("BOTTOM", f, "BOTTOM", 0, 14)
    foot:SetText(L["This window only appears once. /acam welcome shows it again."])
    f:Show()
end
end

local SetAddonEnabled, CreateMacros -- defined further down

local function BuildPanel()
    local COL1, COL2 = 20, 312 -- left edge of each of a page's two columns
    local CW = 250              -- column width
    local PANEL_W, PANEL_H = 584, 672
    local TAB_W, TAB_H = 112, 32
    -- The window is built on the game's own frame template, so it looks like the
    -- rest of the client's windows (title bar, stone border, close button). If
    -- the client doesn't have it, a hand-drawn dark frame is used instead.
    local native = false
    do
        local ok, f = pcall(CreateFrame, "Frame", "TenKsARPGCameraPanel", UIParent, "BasicFrameTemplateWithInset")
        if ok and f and (type(f.Bg) == "table" or type(f.InsetBg) == "table" or type(f.TitleBg) == "table"
            or type(f.NineSlice) == "table" or type(f.CloseButton) == "table") then
            panel, native = f, true
        else
            panel = CreateFrame("Frame", "TenKsARPGCameraPanel", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        end
    end
    panel:SetSize(PANEL_W, PANEL_H)
    panel:SetScale(1.1)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    panel:SetFrameStrata("DIALOG")
    local bgParts = {}
    local function edge(a1, a2, x1, y1, x2, y2, w, h, r, g, b)
        local t = panel:CreateTexture(nil, "BORDER")
        t:SetColorTexture(r, g, b, 1)
        t:SetPoint(a1, panel, a1, x1, y1)
        t:SetPoint(a2, panel, a2, x2, y2)
        bgParts[#bgParts + 1] = { t, 1 }
        if w then t:SetWidth(w) end
        if h then t:SetHeight(h) end
    end
    if native then
        -- only the window's background fades with the opacity setting; the border, widgets and text stay solid
        for _, key in ipairs({ "Bg", "InsetBg", "TitleBg", "TopTileStreaks" }) do
            if type(panel[key]) == "table" and panel[key].SetAlpha then bgParts[#bgParts + 1] = { panel[key], 1 } end
        end
        if panel.SetTitle then panel:SetTitle("10k's Ultimate ARPG Camera")
        elseif type(panel.TitleText) == "table" then panel.TitleText:SetText(L["10k's Ultimate ARPG Camera"]) end
    else
        -- Dark parchment box with a thin double border.
        local base = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
        base:SetAllPoints()
        base:SetColorTexture(0.09, 0.07, 0.05, 0.97)
        local paper = panel:CreateTexture(nil, "BACKGROUND", nil, -7)
        paper:SetPoint("TOPLEFT", 3, -3)
        paper:SetPoint("BOTTOMRIGHT", -3, 3)
        paper:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background", "REPEAT", "REPEAT")
        paper:SetHorizTile(true); paper:SetVertTile(true)
        paper:SetVertexColor(0.55, 0.45, 0.30, 0.55)
        bgParts[#bgParts + 1] = { base, 1 }
        bgParts[#bgParts + 1] = { paper, 1 }
        for _, c in ipairs({ { 0, 0, 0.02, 0.02, 0.02 }, { 2, 2, 0.62, 0.52, 0.30 } }) do
            local o, w, r, g, b = c[1], c[2], c[3], c[4], c[5]
            edge("TOPLEFT", "TOPRIGHT", o, -o, -o, -o, nil, w, r, g, b)
            edge("BOTTOMLEFT", "BOTTOMRIGHT", o, o, -o, o, nil, w, r, g, b)
            edge("TOPLEFT", "BOTTOMLEFT", o, -o, o, o, w, nil, r, g, b)
            edge("TOPRIGHT", "BOTTOMRIGHT", -o, -o, -o, o, w, nil, r, g, b)
        end
        local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)
        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 20, -14)
        title:SetText(L["10k's Ultimate ARPG Camera"])
    end
    panel.SetBackgroundOpacity = function(_, a)
        a = math.max(0, math.min(1, tonumber(a) or 1))
        for _, part in ipairs(bgParts) do part[1]:SetAlpha(a * part[2]) end
    end
    panel:SetBackgroundOpacity(db.menuAlpha)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:Hide()
    tinsert(UISpecialFrames, "TenKsARPGCameraPanel") -- Esc closes it

    MakeCheck(panel, "Enabled", "enabled", PANEL_W - (native and 110 or 130), native and -27 or -10, function()
        SetAddonEnabled(db.enabled)
    end)

    -- Each page has its own accent color: headings, rules, its tab, and the stripe under the title.
    local function rule(parent, x1, x2, y, a, color, h)
        local c = color or GOLD
        local line = parent:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(c[1], c[2], c[3], a or 0.45)
        line:SetPoint("TOPLEFT", panel, "TOPLEFT", x1, y)
        line:SetPoint("TOPRIGHT", panel, "TOPLEFT", x2, y)
        line:SetHeight(h or 1)
    end
    local function Header(parent, text, x, y)
        local c = parent.accent or GOLD
        local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
        h:SetText(L[text])
        h:SetTextColor(c[1], c[2], c[3])
        rule(parent, x, x + CW, y - 17, 0.7, c)
    end

    local c1, c2 = COL1 + CW / 2, COL2 + CW / 2 -- slider centers

    -- Pages: one frame per tab, each covering the whole window ------------
    local PAGES = {
        { id = "general", label = "General", color = { 1.00, 0.82, 0.20 } },
        { id = "targeting", label = "Targeting Frame", color = { 1.00, 0.38, 0.30 } },
        { id = "situations", label = "Situations", color = { 0.38, 0.72, 1.00 } },
        { id = "presets", label = "Presets", color = { 0.52, 0.92, 0.42 } },
    }
    local pages = {}
    for _, pg in ipairs(PAGES) do
        local f = CreateFrame("Frame", nil, panel)
        f:SetAllPoints(panel)
        f:Hide()
        pages[pg.id] = f
        f.accent = pg.color
        local stripe = f:CreateTexture(nil, "ARTWORK") -- colored band under the title
        stripe:SetColorTexture(pg.color[1], pg.color[2], pg.color[3], 0.85)
        stripe:SetPoint("TOPLEFT", panel, "TOPLEFT", native and 8 or 6, native and -52 or -42)
        stripe:SetPoint("TOPRIGHT", panel, "TOPRIGHT", native and -8 or -6, native and -52 or -42)
        stripe:SetHeight(2)
        local div = f:CreateTexture(nil, "ARTWORK")
        div:SetColorTexture(pg.color[1], pg.color[2], pg.color[3], 0.3)
        div:SetPoint("TOPLEFT", panel, "TOPLEFT", COL2 - 14, pg.id == "situations" and -98 or -54)
        div:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", COL2 - 14, 36)
        div:SetWidth(1)
    end
    local G, T, S, R = pages.general, pages.targeting, pages.situations, pages.presets

    -- General -----------------------------------------------------------
    Header(G, "Focus these targets", COL1, -58)
    local function Tip(widget, title, text)
        widget:SetScript("OnEnter", function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L[title], 1, 0.82, 0)
                GameTooltip:AddLine(L[text], 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        widget:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end
    local KINDS = {
        { "Hostile enemies", "focusEnemies", "Hostile creatures: monsters, bosses and anything that will attack you." },
        { "Hostile players", "focusEnemyPlayers", "Players you can attack, such as enemy faction players in PvP." },
        { "Neutral creatures", "focusNeutral", "Creatures that only fight back if attacked (yellow nameplate)." },
        { "Critters", "focusCritters", "Small harmless animals." },
        { "Friendly NPCs", "focusFriendlyNpcs", "Vendors, quest givers, trainers, guards and other friendly characters. This also controls the game's gentle pull toward NPCs you talk to." },
        { "Friendly players", "focusFriendlyPlayers", "Players who are not in your group and that you can't attack." },
        { "Group members", "focusGroup", "Players in your party or raid." },
        { "Pets", "focusPets", "Pets, companions and other creatures a player controls." },
    }
    for i, k in ipairs(KINDS) do
        local col, row = math.floor((i - 1) / 4), (i - 1) % 4
        local cb = MakeCheck(G, k[1], k[2], COL1 + col * 130, -80 - row * 24)
        Tip(cb, k[1], k[3])
    end
    local deadCb = MakeCheck(G, "Dead targets", "focusDead", COL1, -176)
    Tip(deadCb, "Dead targets", "Also swing toward a target that has died, such as a corpse you are about to loot.")
    local combatCb = MakeCheck(G, "Hostile targets only while in combat", "combatOnly", COL1, -202)
    Tip(combatCb, "Hostile targets only while in combat", "Applies to hostile enemies, hostile players, neutral creatures and critters you could attack. Friendly targets are not affected.")
    MakeSlider(G, "Turn smoothing", "smooth", 0.2, 1, 0.05, c1, -246)
    MakeSlider(G, "Blend time (sec)", "rampTime", 0.1, 2, 0.1, c1, -291)

    Header(G, "Camera feel", COL1, -328)
    MakeCheck(G, "Dynamic pitch", "dynamicPitch", COL1, -350)
    MakeCheck(G, "Terrain tilt", "terrainTilt", COL1, -376)
    MakeCheck(G, "Camera bobbing", "bobbing", COL1, -402)
    local lowCb = MakeCheck(G, "Battery saver (lighter updates)", "lowCpu", COL1, -428, function() end)
    Tip(lowCb, "Battery saver (lighter updates)", "Checks situations and updates the targeting frame less often. Saves a little CPU and battery on a handheld; the camera may react a fraction of a second later and the frame animates a little less smoothly.")

    Header(G, "Mouse-wheel zoom", COL1, -470)
    local rzCb = MakeCheck(G, "Smooth, accelerating wheel zoom", "rzOn", COL1, -492)
    Tip(rzCb, "Smooth, accelerating wheel zoom", "Each wheel notch moves the camera a set distance instead of one yard, and turning the wheel quickly moves it further. The camera also travels faster. Turn it off to get the game's own zoom back.")
    MakeSlider(G, "Yards per wheel notch", "rzStep", 0.5, 8, 0.5, c1, -534)
    MakeSlider(G, "Zoom speed (yards per second)", "rzSpeed", 10, 80, 5, c1, -579)

    Header(G, "Settings window", COL2, -58)
    MakeSlider(G, "Window opacity", "menuAlpha", 0, 1, 0.05, c2, -102, true)
    MakeCheck(G, "Hide the game's experimental-camera popup", "hideWarning", COL2, -130, ApplyWarningSuppression)

    local padNote = G:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    padNote:SetPoint("TOPLEFT", panel, "TOPLEFT", COL2, -162)
    padNote:SetWidth(CW)
    padNote:SetHeight(40)
    padNote:SetJustifyV("TOP")
    padNote:SetJustifyH("LEFT")
    padNote:SetText(L["Gamepad: bind a button to \"Open the settings window\" in Key Bindings > AddOns."])

    Header(G, "Transitions", COL2, -332)
    local sAll
    local function ShowBlend()
        local all = db.blendAll ~= false
        sAll:SetShown(all)
        if panel.sOwn then panel.sOwn:SetShown(not all) end
        if panel.ownNote then panel.ownNote:SetShown(all) end
        for _, refresh in ipairs(controls) do refresh() end
    end
    MakeCheck(G, "Same transition time for all situations", "blendAll", COL2, -354, ShowBlend)
    sAll = MakeSlider(G, "Transition time (sec)", "blendTime", 0.2, 5, 0.1, c2, -400, true)
    MakeCheck(G, "Slower Indoors to Exploration", "slowExit", COL2, -428, function() end)
    MakeCheck(G, "Exploration on flight paths (no transition)", "taxiWorld", COL2, -454, function() end)

    Header(G, "Right now", COL2, -494)
    local whyText = G:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    whyText:SetPoint("TOPLEFT", panel, "TOPLEFT", COL2, -518)
    whyText:SetWidth(CW)
    whyText:SetJustifyH("LEFT")
    whyText:SetJustifyV("TOP")
    local function RefreshWhy()
        if not db then return end
        local lines = {}
        local winner = activeProfile
        if OnTaxi() then lines[#lines + 1] = "|cff9aa4b6" .. L["On a flight path: Exploration is used."] .. "|r"
        elseif previewProfile then lines[#lines + 1] = "|cff66ccff" .. L["Previewing: "] .. PROFILE_NAMES[previewProfile] .. "|r" end
        for _, r in ipairs(Detect.explain()) do
            local c = PROFILE_COLORS[r.key]
            local hex = string.format("%02x%02x%02x", math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
            local mark = (r.key == winner) and "|cffffd100>|r " or "   "
            local state = (r.key == "world" or r.on) and "" or (" |cff7c8596(" .. L["off"] .. ")|r")
            lines[#lines + 1] = string.format("%s|cff%s%s|r%s  |cff%s%s|r", mark, hex, PROFILE_NAMES[r.key], state,
                r.cond and "d8d2c0" or "7c8596", r.reason)
        end
        whyText:SetText(table.concat(lines, "\n"))
    end
    panel.RefreshWhy = RefreshWhy

    Header(G, "Mouse look", COL2, -206)
    local mlCb = MakeCheck(G, "Lock the camera to the mouse", "mlOn", COL2, -228, function() Detect.ml.reset() end)
    Tip(mlCb, "Lock the camera to the mouse", "The mouse turns the camera all the time, as if you were holding the right mouse button, so you aim and steer with the mouse like an action game. The cursor comes back on its own while you type, aim a spell, carry an item, or have bags, a vendor, the map, the game menu or this window open.")
    local mlTg = MakeCheck(G, "Free-cursor key toggles (instead of hold)", "mlToggle", COL2, -254, function() Detect.ml.reset() end)
    Tip(mlTg, "Free-cursor key toggles (instead of hold)", "Bind \"Free the cursor\" in Key Bindings > AddOns. Off: the cursor is free while you hold the key. On: press once for the cursor, press again to go back to mouse look.")
    local mlNote = G:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    mlNote:SetPoint("TOPLEFT", panel, "TOPLEFT", COL2, -280)
    mlNote:SetWidth(CW)
    mlNote:SetJustifyH("LEFT")
    mlNote:SetText(L["Free-cursor key: Key Bindings > AddOns."])

    local macroBtn = CreateFrame("Button", nil, G, "UIPanelButtonTemplate")
    macroBtn:SetSize(CW, 22)
    macroBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", COL2, -300)
    macroBtn:SetText(L["Create / update macros"])
    macroBtn:SetScript("OnClick", CreateMacros)
    Tip(macroBtn, "Create / update macros", "Makes \"ACAM Menu\" (opens this window) and \"ACAM Toggle\" (turns the addon on/off). Find them in /macro and drag them onto a bar.")

    -- Targeting frame ---------------------------------------------------
    Header(T, "Shape and style", COL1, -58)
    MakeCheck(T, "Show targeting frame", "fx", COL1, -80, function() end)
    local styleBtns = {}
    for n, st in ipairs({ { "halo", "Halo" }, { "reticle", "Reticle" }, { "ring", "Ring" }, { "solid", "Solid" }, { "outline", "Outline" } }) do
        local b = CreateFrame("Button", nil, T, "UIPanelButtonTemplate")
        b:SetSize(48, 20)
        b:SetPoint("TOPLEFT", panel, "TOPLEFT", COL1 + (n - 1) * 50.5, -108)
        b:SetText(L[st[2]])
        if b.GetFontString and b:GetFontString() then b:GetFontString():SetFontObject("GameFontNormalSmall") end
        b:SetScript("OnClick", function()
            db.fxStyle = st[1]
            for key, btn in pairs(styleBtns) do
                if key == db.fxStyle then btn:LockHighlight() else btn:UnlockHighlight() end
            end
        end)
        styleBtns[st[1]] = b
    end
    controls[#controls + 1] = function()
        for key, btn in pairs(styleBtns) do
            if key == db.fxStyle then btn:LockHighlight() else btn:UnlockHighlight() end
        end
    end
    MakeSlider(T, "Size (px at ~10 yards)", "fxSize", 40, 300, 10, c1, -148, true)
    MakeSlider(T, "Opacity", "fxAlpha", 0.2, 1, 0.05, c1, -193, true)
    MakeSlider(T, "Curvature (triangles)", "fxCurve", 0, 1, 0.05, c1, -238, true)
    MakeSlider(T, "Rotation (deg/s, - = counter-cw)", "fxSpeed", -180, 180, 10, c1, -283, true)

    Header(T, "Nameplates", COL1, -330)
    local npMaster = MakeCheck(T, "Control nameplates", "npManage", COL1, -352, function()
        if db.npManage then
            if not db.npInit then NP.readCurrent() end
            NP.apply(true)
        else
            NP.restore()
        end
        for _, refresh in ipairs(controls) do refresh() end
    end)
    Tip(npMaster, "Control nameplates", "Turn this on to choose which kinds of unit get a nameplate. Off leaves your game's nameplate settings alone; turning it off again puts back what the game had. The targeting frame needs a nameplate on its target.")
    local NPLABELS = {
        { "Hostile and neutral creatures, hostile players", "Hostile creatures, neutral creatures and hostile players. The game treats all of these as \"enemies\", so they share one switch." },
        { "Critters and minor enemies", "Critters and trivial enemies the game calls \"minor\"." },
        { "Enemy pets and minions", "Pets, minions and guardians that belong to hostile units." },
        { "Enemy totems", "Totems and similar objects of hostile units." },
        { "Friendly players and party", "Friendly players, including your party and raid. The game has one switch for all friendly players." },
        { "Friendly NPCs", "Vendors, quest givers, guards and other friendly creatures." },
        { "Friendly pets and minions", "Your pets and companions, and other players' pets. Turning this on briefly switches friendly player nameplates off and on again (if they are enabled), which makes the game show the pets." },
        { "Friendly totems", "Friendly totems, guardians and similar objects." },
    }
    local npChecks = {}
    for i, k in ipairs(NP.kinds) do
        local cb = MakeCheck(T, NPLABELS[i][1], k[1], COL1 + 10, -374 - (i - 1) * 22, function()
            -- the game doesn't show pets and minions that were just switched on until the friendly players
            -- switch is turned off and on again, so do that when it was enabled
            local cycle = k[1] == "npFriendlyPets" and db.npFriendlyPets and db.npFriendlyPlayers ~= false
            NP.apply(true)
            if cycle then NP.cyclePlayers() end
            for _, refresh in ipairs(controls) do refresh() end
        end)
        Tip(cb, NPLABELS[i][1], NPLABELS[i][2] .. (NP.supported(k) and "" or " (This game client has no setting for this kind.)"))
        npChecks[#npChecks + 1] = cb
    end
    controls[#controls + 1] = function()
        for i, cb in ipairs(npChecks) do
            local ok = NP.supported(NP.kinds[i])
            cb:SetAlpha(ok and (db.npManage and 1 or 0.45) or 0.3)
            if cb.SetEnabled then cb:SetEnabled(ok) end
        end
    end

    Header(T, "Reticle effects", COL2, -58)
    MakeSlider(T, "Glow", "fxGlow", 0, 1, 0.05, c2, -102, true)
    MakeCheck(T, "Lock-on animation", "fxLock", COL2, -126, function() end)
    MakeCheck(T, "Hit flash", "fxHit", COL2 + 125, -126, function() end)
    MakeCheck(T, "Elite / rare marker", "fxElite", COL2, -152, function() eliteKind = nil; shownColor = nil end)
    local castCb = MakeCheck(T, "Casting warning", "fxCast", COL2 + 125, -152, function() end)
    Tip(castCb, "Casting warning", "Halo style: an outer ring pulses while your target is casting, and fills up as the cast goes when the game says how long it takes.")
    local distCb = MakeCheck(T, "Show distance", "fxDist", COL2, -178, function() end)
    Tip(distCb, "Show distance", "Distance to your target under the frame. Exact for group members; for anything else it's worked out from your own spells' ranges, so it shows a bracket such as 20-25 yd.")
    local hpCb = MakeCheck(T, "Health on halo", "fxHealth", COL2 + 125, -178, function() if Halo.health then Halo.health() end end)
    Tip(hpCb, "Health on halo", "Halo style: the ring drains as your target loses health.")

    Header(T, "Show the frame on", COL2, -216)
    local FXKINDS = {
        { "Hostile enemies", "fxEnemies", "Hostile creatures: monsters, bosses and anything that will attack you." },
        { "Hostile players", "fxEnemyPlayers", "Players you can attack, such as in PvP." },
        { "Neutral creatures", "fxNeutral", "Creatures that only fight back if attacked." },
        { "Critters", "fxCritters", "Small harmless animals." },
        { "Friendly NPCs", "fxFriendlyNpcs", "Vendors, quest givers, guards and other friendly creatures." },
        { "Friendly players", "fxFriendlyPlayers", "Players who are not in your group." },
        { "Party and raid", "fxGroup", "Members of your party or raid." },
        { "Pets", "fxPets", "Pets, companions and other creatures a player controls." },
    }
    for i, k in ipairs(FXKINDS) do
        local cb = MakeCheck(T, k[1], k[2], COL2 + math.floor((i - 1) / 4) * 125, -238 - ((i - 1) % 4) * 22, function() end)
        Tip(cb, k[1], k[3] .. " " .. L["The targeting frame is drawn on targets of the ticked kinds."])
    end

    Header(T, "Frame position", COL2, -336)
    MakeSlider(T, "Horizontal nudge (px)", "fxOffset", -100, 100, 5, c2, -380, true)
    MakeSlider(T, "Distance shift (px)", "fxDistShift", -40, 40, 2, c2, -425, true)

    Header(T, "Behavior", COL2, -466)
    MakeCheck(T, "Fade out while not in combat", "fxOoc", COL2, -488, function() end)
    MakeSlider(T, "Opacity out of combat", "fxOocAlpha", 0, 1, 0.05, c2, -534, true)
    MakeSlider(T, "Friendly target size", "fxFriendScale", 0.4, 1, 0.05, c2, -579, true)
    MakeCheck(T, "Mark your focus target", "fxFocus", COL2, -607, function() end)

    -- Situations --------------------------------------------------------
    local EP = function() return db.profiles[editProfile] end

    -- The situation buttons run across the whole top of the page: everything below belongs to the selected one.
    -- A line in its color and a faint wash of it behind the page's controls show which one that is.
    local umbrella = S:CreateTexture(nil, "ARTWORK")
    umbrella:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -91)
    umbrella:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -14, -91)
    umbrella:SetHeight(3)
    local wash = S:CreateTexture(nil, "BACKGROUND")
    wash:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -94)
    wash:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 34)
    local editLabel = S:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    editLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", COL1, -99)

    local tabs, profileWidgets = {}, {}
    local activeLabel = S:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    activeLabel:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -22, -101)
    activeLabel:SetJustifyH("RIGHT")
    local previewBtn
    local function InUseText()
        local pc = PROFILE_COLORS[activeProfile] or GOLD
        local txt = string.format(L["In use right now: "] .. "|cff%02x%02x%02x%s|r", math.floor(pc[1] * 255), math.floor(pc[2] * 255), math.floor(pc[3] * 255), PROFILE_NAMES[activeProfile])
        if previewProfile then txt = txt .. " |cff66ccff(" .. L["preview"] .. ")|r" end
        return txt
    end

    local function RefreshProfileWidgets()
        for name, tab in pairs(tabs) do
            if name == editProfile then tab:LockHighlight() else tab:UnlockHighlight() end
        end
        local on = editProfile == "world" or db.profiles[editProfile].on
        for _, w in ipairs(profileWidgets) do w:SetAlpha(on and 1 or 0.45) end
        local pc = PROFILE_COLORS[editProfile]
        umbrella:SetColorTexture(pc[1], pc[2], pc[3], 0.95)
        wash:SetColorTexture(pc[1], pc[2], pc[3], 0.05)
        editLabel:SetText(L["Settings for: "] .. string.format("|cff%02x%02x%02x%s|r", math.floor(pc[1] * 255), math.floor(pc[2] * 255), math.floor(pc[3] * 255), PROFILE_NAMES[editProfile])
            .. (on and "" or (" |cff7c8596(" .. L["switched off"] .. ")|r")))
        for name, tab in pairs(tabs) do -- situations that are switched off are dimmed
            local tabOn = name == "world" or db.profiles[name].on
            tab:SetAlpha((tabOn or name == editProfile) and 1 or 0.55)
        end
        panel.profileCheck:SetShown(editProfile ~= "world")
        activeLabel:SetText(InUseText())
        if previewBtn then previewBtn:SetText(previewProfile == editProfile and L["Stop preview"] or L["Preview this situation"]) end
        for _, refresh in ipairs(controls) do refresh() end
        if panel.ZoomUI then panel.ZoomUI() end
        if panel.CurveRefresh then panel.CurveRefresh() end
    end
    panel.RefreshProfileWidgets = RefreshProfileWidgets

    for n, name in ipairs(PROFILES) do
        local b = CreateFrame("Button", nil, S, "UIPanelButtonTemplate")
        b:SetSize(65, 26)
        b:SetPoint("TOPLEFT", panel, "TOPLEFT", COL1 + (n - 1) * 68, -60)
        b:SetText(PROFILE_INFO[name][1])
        local pc = PROFILE_COLORS[name]
        local fs = b.GetFontString and b:GetFontString()
        if fs and fs.SetTextColor then fs:SetTextColor(pc[1], pc[2], pc[3]) end
        for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do -- plain dark grey instead of the red template
            local tx = b[getter] and b[getter](b)
            if tx then
                if tx.SetDesaturated then tx:SetDesaturated(true) end
                if tx.SetVertexColor then tx:SetVertexColor(0.32, 0.32, 0.34) end
            end
        end
        b:SetScript("OnClick", function()
            editProfile = name
            if previewProfile then SetPreview(name) end -- a running preview follows the selection
            RefreshProfileWidgets()
        end)
        b:SetScript("OnEnter", function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(PROFILE_NAMES[name], 1, 0.82, 0)
                GameTooltip:AddLine(PROFILE_INFO[name][2], 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        tabs[name] = b
    end

    -- The situation buttons above are shared; everything below is one of two sub-pages: the basics (S) and
    -- "More" (S2): head tracking, zoom rules, and the Talk interface fade.
    local Sroot = S
    S = CreateFrame("Frame", nil, Sroot)
    S:SetAllPoints(panel)
    S.accent = Sroot.accent
    local S2 = CreateFrame("Frame", nil, Sroot)
    S2:SetAllPoints(panel)
    S2:Hide()
    S2.accent = Sroot.accent
    previewBtn = CreateFrame("Button", nil, S, "UIPanelButtonTemplate")
    previewBtn:SetSize(CW, 22)
    previewBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", COL1, -124)
    previewBtn:SetScript("OnClick", function()
        if not db.enabled then Print(L["Turn the camera on (Enabled) to preview a situation."]) return end
        SetPreview(previewProfile ~= editProfile and editProfile or nil)
        RefreshProfileWidgets()
    end)
    panel.previewBtn = previewBtn

    panel.profileCheck = MakeCheck(S, "Use these settings in this situation", "on", COL1, -152, function() Refresh(); RefreshProfileWidgets() end, EP)
    local function PS(label, key, lo, hi, step, y)
        profileWidgets[#profileWidgets + 1] = MakeSlider(S, label, key, lo, hi, step, c1, y, false, EP)
    end
    PS("Field of view", "fov", 50, 90, 1, -198)
    PS("Over-the-shoulder", "shoulder", -10, 10, 0.1, -243)
    -- zoom compensation for the shoulder offset: a tick per situation and a curve to shape it
    local compCb = MakeCheck(S, "Compensate for zoom", "shComp", COL1, -279, function()
        ApplyShoulder(true); Refresh(); RefreshProfileWidgets()
    end, EP)
    local curveBtn = CreateFrame("Button", nil, S, "UIPanelButtonTemplate")
    curveBtn:SetSize(100, 22)
    curveBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", COL1 + 150, -281)
    curveBtn:SetText(L["Edit curve"])
    curveBtn:SetScript("OnClick", function() if panel.OpenCurve then panel.OpenCurve() end end)
    profileWidgets[#profileWidgets + 1] = compCb
    profileWidgets[#profileWidgets + 1] = curveBtn
    Tip(compCb, "Compensate for zoom", "Scales the over-the-shoulder offset as you zoom in and out, so the character can stay where it is on screen. Each situation has its own tick; the curve says how much to scale at every camera distance.")
    Tip(curveBtn, "Edit curve", "Opens the compensation curve: camera distance along the bottom, how strongly the shoulder offset is multiplied up the side. 1.0 is the slider's value.")
    PS("Target turn strength", "yaw", 0, 1, 0.05, -322)
    PS("Target tilt strength", "pitch", 0, 1, 0.05, -367)
    PS("Camera tilt (deg, + = up, looks further ahead)", "tilt", -20, 20, 0.5, -412)
    panel.sOwn = MakeSlider(S, "Transition into this situation (sec)", "blend", 0.2, 5, 0.1, c1, -457, true, EP)
    panel.ownNote = S:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.ownNote:SetPoint("TOPLEFT", panel, "TOPLEFT", COL1, -448)
    panel.ownNote:SetWidth(CW)
    panel.ownNote:SetJustifyH("LEFT")
    panel.ownNote:SetText(L["Transition times are set for all situations together on the General tab."])


    -- The compensation curve editor ----------------------------------------
    -- Camera distance runs left to right, the multiplier bottom to top (1.0 = the slider's value). Drag a point,
    -- click empty space to add one, right-click a point to remove it. The little buttons nudge the selected point
    -- for gamepad or touch use.
    do
        local Comp = Detect.comp
        local GW, GH, GX, GY = 340, 200, 48, -96 -- graph size and its place in the window
        local ED, pts, sel
        local frames, lines = {}, {}
        local function Dst()
            if db.shCompShare then return db, "shCompCurve" end
            return db.profiles[editProfile], "shCurve"
        end
        local function Load()
            local t, k = Dst()
            local src = Comp.parse(t[k]) or Comp.parse(Comp.FLAT)
            pts = {}
            for i, pt in ipairs(src) do pts[i] = { z = pt.z, v = pt.v } end
            if pts[1].z > 0 then table.insert(pts, 1, { z = 0, v = pts[1].v }) end
            if pts[#pts].z < Comp.ZMAX then pts[#pts + 1] = { z = Comp.ZMAX, v = pts[#pts].v } end
            if not sel or sel > #pts then sel = nil end
        end
        local function Save()
            local t, k = Dst()
            t[k] = Comp.str(pts)
        end
        local function PX(z) return z / Comp.ZMAX * GW end
        local function PY(v) return v / Comp.VMAX * GH end
        local Redraw
        local function Snap(x, step) return math.floor(x / step + 0.5) * step end
        local function CursorToData()
            local x, y = GetCursorPosition()
            local sc = ED.graph:GetEffectiveScale()
            x, y = x / sc, y / sc
            local z = (x - ED.graph:GetLeft()) / GW * Comp.ZMAX
            local v = (y - ED.graph:GetBottom()) / GH * Comp.VMAX
            return math.max(0, math.min(Comp.ZMAX, z)), math.max(0, math.min(Comp.VMAX, v))
        end
        local function MovePoint(i, z, v)
            local pt = pts[i]
            if i > 1 and i < #pts then
                z = math.max(pts[i - 1].z + 0.5, math.min(pts[i + 1].z - 0.5, z))
                pt.z = Snap(z, 0.5)
            end
            pt.v = math.max(0, math.min(Comp.VMAX, Snap(v, 0.05)))
            Save(); Redraw()
        end
        local function Line(i, x1, y1, x2, y2, r, g, b, a, w)
            local ln = lines[i]
            if not ln then
                ln = ED.graph:CreateLine(nil, "ARTWORK")
                lines[i] = ln
            end
            ln:SetColorTexture(r, g, b, a)
            ln:SetThickness(w)
            ln:SetStartPoint("BOTTOMLEFT", ED.graph, x1, y1)
            ln:SetEndPoint("BOTTOMLEFT", ED.graph, x2, y2)
            ln:Show()
        end
        function Redraw()
            if not ED then return end
            -- points
            for i, pt in ipairs(pts) do
                local fr = frames[i]
                if not fr then
                    fr = CreateFrame("Button", nil, ED.graph)
                    fr:SetSize(16, 16)
                    fr:RegisterForClicks("LeftButtonDown", "RightButtonDown", "LeftButtonUp")
                    fr.tex = fr:CreateTexture(nil, "OVERLAY")
                    fr.tex:SetAllPoints()
                    fr.idx = i
                    fr:SetScript("OnMouseDown", function(self, btn)
                        if btn == "RightButton" then
                            if self.idx > 1 and self.idx < #pts and #pts > 2 then
                                table.remove(pts, self.idx); sel = nil; Save(); Redraw()
                            end
                        else
                            sel = self.idx; ED.dragging = self.idx; Redraw()
                        end
                    end)
                    fr:SetScript("OnMouseUp", function() ED.dragging = nil end)
                    frames[i] = fr
                end
                fr.idx = i
                fr:ClearAllPoints()
                fr:SetPoint("CENTER", ED.graph, "BOTTOMLEFT", PX(pt.z), PY(pt.v))
                local c = (i == sel) and { 1, 1, 1 } or { 1, 0.82, 0 }
                fr.tex:SetColorTexture(c[1], c[2], c[3], 1)
                fr:SetSize(i == sel and 14 or 11, i == sel and 14 or 11)
                fr:Show()
            end
            for i = #pts + 1, #frames do frames[i]:Hide() end
            -- the curve
            if ED.graph.CreateLine then
                for i = 1, #pts - 1 do
                    Line(i, PX(pts[i].z), PY(pts[i].v), PX(pts[i + 1].z), PY(pts[i + 1].v), 1, 0.82, 0, 0.95, 2.5)
                end
                for i = #pts, #lines do if lines[i] then lines[i]:Hide() end end
            end
            -- text
            local sh = db.shCompShare
            local pc = PROFILE_COLORS[editProfile] or GOLD
            local name = sh and L["All situations"] or string.format("|cff%02x%02x%02x%s|r", math.floor(pc[1] * 255), math.floor(pc[2] * 255), math.floor(pc[3] * 255), PROFILE_NAMES[editProfile])
            local on = Comp.enabled(editProfile)
            ED.sub:SetText(L["Situation: "] .. name .. (on and "" or ("  |cffff8866" .. L["compensation is off here"] .. "|r")))
            ED.share:SetChecked(sh and true or false)
            if sel and pts[sel] then
                ED.selTxt:SetText(string.format(L["Point %d: %.1f yd, x%.2f"], sel, pts[sel].z, pts[sel].v))
            else
                ED.selTxt:SetText(L["Click a point to select it."])
            end
        end
        local function Build()
            local f = CreateFrame("Frame", "TenKsARPGCameraCurve", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
            f:SetSize(430, 440)
            f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            f:SetFrameStrata("FULLSCREEN_DIALOG")
            f:SetClampedToScreen(true)
            f:SetMovable(true)
            f:EnableMouse(true)
            f:RegisterForDrag("LeftButton")
            f:SetScript("OnDragStart", function(self) self:StartMoving() end)
            f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
            if f.SetBackdrop then
                f:SetBackdrop(BACKDROP)
                f:SetBackdropColor(0.04, 0.05, 0.08, 0.97)
                f:SetBackdropBorderColor(0.7, 0.7, 0.75, 1)
            end
            f:Hide()
            if UISpecialFrames then tinsert(UISpecialFrames, "TenKsARPGCameraCurve") end
            local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            title:SetPoint("TOPLEFT", 16, -14)
            title:SetText(L["Shoulder compensation curve"])
            f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            f.sub:SetPoint("TOPLEFT", 16, -38)
            local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
            close:SetPoint("TOPRIGHT", -2, -2)
            -- one curve for everything
            f.share = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
            f.share:SetSize(24, 24)
            f.share:SetPoint("TOPLEFT", 12, -54)
            local st = f.share.Text or f.share.text
            if not st then st = f.share:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); st:SetPoint("LEFT", f.share, "RIGHT", 4, 0) end
            st:SetText(L["Use this one curve for all situations"])
            if st.SetFontObject then st:SetFontObject("GameFontHighlightSmall") end
            f.share:SetScript("OnClick", function(self)
                local want = self:GetChecked() and true or false
                if want then
                    local cur = Comp.str(pts)       -- the curve on screen becomes the shared one
                    db.shCompShare, db.shCompCurve = true, cur
                else
                    db.shCompShare = false          -- every situation keeps a copy of it
                    for _, name in ipairs(PROFILES) do db.profiles[name].shCurve = db.shCompCurve end
                end
                Load(); Redraw(); ApplyShoulder(true)
            end)
            f.share:SetScript("OnEnter", function(self)
                if GameTooltip then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(L["Use this one curve for all situations"], 1, 0.82, 0)
                    GameTooltip:AddLine(L["Every situation follows the same curve. Each one still decides for itself whether compensation is on. Turning this off gives every situation its own copy of the curve."], 1, 1, 1, true)
                    GameTooltip:Show()
                end
            end)
            f.share:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            -- graph
            local g = CreateFrame("Frame", nil, f)
            g:SetSize(GW, GH)
            g:SetPoint("TOPLEFT", f, "TOPLEFT", GX, GY)
            f.graph = g
            local bg = g:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.02, 0.02, 0.03, 0.9)
            g:EnableMouse(true)
            g:SetScript("OnMouseDown", function(_, btn)
                if btn ~= "LeftButton" or #pts >= 24 then return end
                local z, v = CursorToData()
                z = Snap(z, 0.5)
                if z <= 0 or z >= Comp.ZMAX then return end
                for _, pt in ipairs(pts) do if math.abs(pt.z - z) < 1 then return end end
                table.insert(pts, { z = z, v = math.max(0, math.min(Comp.VMAX, Snap(v, 0.05))) })
                table.sort(pts, function(a, b) return a.z < b.z end)
                for i, pt in ipairs(pts) do if pt.z == z then sel = i end end
                Save(); Redraw()
            end)
            -- grid and labels
            for gz = 0, Comp.ZMAX, 10 do
                local t = g:CreateTexture(nil, "BORDER")
                t:SetColorTexture(1, 1, 1, gz == 0 and 0.35 or 0.1)
                t:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", PX(gz), 0)
                t:SetSize(1, GH)
                local lb = g:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                lb:SetPoint("TOP", g, "BOTTOMLEFT", PX(gz), -3)
                lb:SetText(gz)
            end
            for gv = 0, Comp.VMAX do
                local t = g:CreateTexture(nil, "BORDER")
                t:SetColorTexture(gv == 1 and 0.4 or 1, gv == 1 and 0.9 or 1, gv == 1 and 0.5 or 1, gv == 1 and 0.55 or (gv == 0 and 0.35 or 0.1))
                t:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", 0, PY(gv))
                t:SetSize(GW, 1)
                local lb = g:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                lb:SetPoint("RIGHT", g, "BOTTOMLEFT", -5, PY(gv))
                lb:SetText(gv == 1 and "1.0" or gv)
            end
            local xcap = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            xcap:SetPoint("TOP", g, "BOTTOM", 0, -18)
            xcap:SetText(L["Camera distance (yards)"])
            local ycap = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            ycap:SetPoint("BOTTOMLEFT", g, "TOPLEFT", -30, 4)
            ycap:SetText(L["Shoulder multiplier (1.0 = slider value)"])
            -- where the camera is right now
            f.mark = g:CreateTexture(nil, "ARTWORK")
            f.mark:SetColorTexture(0.4, 0.8, 1, 0.9)
            f.mark:SetSize(1, GH)
            f.dot = g:CreateTexture(nil, "OVERLAY")
            f.dot:SetColorTexture(0.4, 0.8, 1, 1)
            f.dot:SetSize(7, 7)
            f.nowTxt = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            f.nowTxt:SetPoint("TOPLEFT", g, "BOTTOMLEFT", -30, -38)
            f.nowTxt:SetTextColor(0.55, 0.85, 1)
            f.selTxt = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            f.selTxt:SetPoint("TOPLEFT", g, "BOTTOMLEFT", -30, -60)
            local function Nudge(label, x, dz, dv)
                local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
                b:SetSize(26, 22)
                b:SetPoint("TOPLEFT", g, "BOTTOMLEFT", x, -56)
                b:SetText(label)
                b:SetScript("OnClick", function()
                    if not sel or not pts[sel] then return end
                    MovePoint(sel, pts[sel].z + dz, pts[sel].v + dv)
                end)
                return b
            end
            Nudge("<", 190, -0.5, 0); Nudge(">", 218, 0.5, 0); Nudge("-", 250, 0, -0.05); Nudge("+", 278, 0, 0.05)
            -- starting shapes
            local function Shape(label, x, w, fn, tip)
                local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
                b:SetSize(w, 22)
                b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, 44)
                b:SetText(label)
                b:SetScript("OnClick", function()
                    local t, k = Dst()
                    t[k] = fn(); sel = nil; Load(); Redraw(); ApplyShoulder(true)
                end)
                b:SetScript("OnEnter", function(self)
                    if GameTooltip then
                        GameTooltip:SetOwner(self, "ANCHOR_TOP")
                        GameTooltip:SetText(label, 1, 0.82, 0)
                        GameTooltip:AddLine(tip, 1, 1, 1, true)
                        GameTooltip:Show()
                    end
                end)
                b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            end
            Shape(L["Flat"], 16, 70, function() return Comp.FLAT end, L["The slider's value at every distance (no compensation)."])
            Shape(L["Gentle"], 90, 70, function() return Comp.fromPower(0.4) end, L["The offset grows a little as you zoom out."])
            Shape(L["Full"], 164, 70, function() return Comp.fromPower(1) end, L["The offset grows in step with the distance, which keeps the character at the same place on screen."])
            local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 14)
            hint:SetWidth(398)
            hint:SetJustifyH("LEFT")
            hint:SetText(L["Drag a point to shape the curve. Click empty space to add a point, right-click a point to remove it. Preview the situation to watch the blue marker follow your zoom."])
            -- dragging and the live marker
            local acc = 0
            f:SetScript("OnUpdate", function(self, el)
                if self.dragging and IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then self.dragging = nil end
                if self.dragging and GetCursorPosition and pts[self.dragging] then
                    local z, v = CursorToData()
                    MovePoint(self.dragging, z, v)
                end
                acc = acc + el
                if acc < 0.05 then return end
                acc = 0
                local zoom = Comp.zoom()
                local m = Comp.eval(pts, zoom)
                local x = PX(math.max(0, math.min(Comp.ZMAX, zoom)))
                self.mark:ClearAllPoints(); self.mark:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", x, 0)
                self.dot:ClearAllPoints(); self.dot:SetPoint("CENTER", g, "BOTTOMLEFT", x, PY(m))
                local sh = db.profiles[editProfile].shoulder or 0
                self.nowTxt:SetText(string.format(L["Now: %.1f yd, x%.2f, shoulder %.2f"], zoom, m, sh * m))
            end)
            f:SetScript("OnHide", function(self) self.dragging = nil end)
            return f
        end
        panel.OpenCurve = function()
            if not ED then ED = Build() end
            sel = nil
            Load(); Redraw()
            ED:Show()
            ED:Raise()
        end
        panel.CurveRefresh = function()
            if ED and ED:IsShown() then sel = nil; Load(); Redraw() end
        end
        panel:HookScript("OnHide", function() if ED then ED:Hide() end end)
    end

    Header(S, "Screen-edge vignette", COL2, -114)
    MakeSlider(S, "Opacity (0 = off)", "vigAlpha", 0, 1, 0.05, c2, -158, true, EP)
    MakeSlider(S, "Range (fraction of the screen)", "vigRange", 0.05, 0.5, 0.01, c2, -202, true, EP)
    MakeSlider(S, "Falloff (1 = straight, higher = edge only)", "vigCurve", 0.5, 4, 0.1, c2, -246, true, EP)

    Header(S, "Letterbox bars", COL2, -286)
    MakeSlider(S, "Bar height (0 = off, fraction of screen)", "lbSize", 0, 0.15, 0.005, c2, -330, true, EP)

    Header(S, "Dynamic field of view", COL2, -368)
    MakeSlider(S, "Widen with speed (up to, degrees)", "fovSpeed", 0, 20, 1, c2, -412, true, EP)
    MakeSlider(S, "Widen with many enemies (up to, deg)", "crowdFov", 0, 20, 1, c2, -456, true, EP)

    local fovNote = S:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    fovNote:SetPoint("TOPLEFT", panel, "TOPLEFT", COL1, -500)
    fovNote:SetWidth(CW)
    fovNote:SetJustifyH("LEFT")
    fovNote:SetText(L["Priority: Dungeon/Raid, Combat, Talk, Swimming, Indoors, City, then Exploration. Field of view: 50 to 90, the same range as the game's own slider. Speed and crowd widening add to it, up to 90. Head tracking, zoom rules and the Talk interface fade are under More."])

    -- More: head tracking, zoom rules, Talk interface fade ------------------------------
    local function PS2(label, key, lo, hi, step, y, cx, noRefresh)
        profileWidgets[#profileWidgets + 1] = MakeSlider(S2, label, key, lo, hi, step, cx or c1, y, noRefresh or false, EP)
    end
    Header(S2, "Head tracking", COL1, -114)
    PS2("Strength", "headMove", 0, 1, 0.05, -158)
    PS2("Strength while standing", "headStand", 0, 1, 0.05, -203)
    PS2("Strength while moving", "headMoving", 0, 1, 0.05, -248)
    PS2("Reaction speed (higher = snappier)", "headReact", 1, 20, 1, -293)
    local headNote = S2:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    headNote:SetPoint("TOPLEFT", panel, "TOPLEFT", COL1, -332)
    headNote:SetWidth(CW)
    headNote:SetJustifyH("LEFT")
    headNote:SetText(L["Head tracking makes the camera follow the movement of your character's head. Strength is the overall amount; standing and moving set it for each case, and a higher reaction speed follows faster, which suits combat. Keep it low if camera motion makes you queasy."])

    -- zoom rules
    Header(S2, "Zoom distance", COL2, -114)
    PS2("Max zoom factor", "zoom", 1, 3.5, 0.1, -158, c2)
    local zoomSlider, minSlider, maxSlider, kindBtns, talkWidgets = nil, nil, nil, {}, {}
    local function ZoomUI()
        local pr = db.profiles[editProfile]
        local set = pr.zoomSet and true or false
        local kind = pr.zoomKind or 0
        for i, b in ipairs(kindBtns) do
            b:SetAlpha(set and 1 or 0.45)
            if set and kind == i - 1 then b:LockHighlight() else b:UnlockHighlight() end
        end
        if zoomSlider then zoomSlider:SetShown(set and kind ~= 3); zoomSlider:SetAlpha(1) end
        if minSlider then minSlider:SetShown(set and kind == 3) end
        if maxSlider then maxSlider:SetShown(set and kind == 3) end
        for _, w in ipairs(talkWidgets) do w:SetShown(editProfile == "npc") end
    end
    MakeCheck(S2, "Remember last zoom in this situation", "zoomRemember", COL2, -194, function()
        local pr = EP(); if pr.zoomRemember then pr.zoomSet = false end
        for _, refresh in ipairs(controls) do refresh() end
        ZoomUI()
    end, EP)
    MakeCheck(S2, "Use a set zoom distance", "zoomSet", COL2, -220, function()
        local pr = EP(); if pr.zoomSet then pr.zoomRemember = false end
        for _, refresh in ipairs(controls) do refresh() end
        ZoomUI()
        if editProfile == activeProfile then ConstrainZoom(true) end
    end, EP)
    local KINDS2 = {
        { "Exact", "Goes to exactly this distance when the situation starts." },
        { "In only", "Moves in to this distance if the camera is farther away; leaves it alone if it is already closer." },
        { "Out only", "Moves out to this distance if the camera is closer; leaves it alone if it is already farther." },
        { "Range", "Keeps the camera between a nearest and a farthest distance, also while you zoom." },
    }
    for i, k in ipairs(KINDS2) do
        local b = CreateFrame("Button", nil, S2, "UIPanelButtonTemplate")
        b:SetSize(60, 20)
        b:SetPoint("TOPLEFT", panel, "TOPLEFT", COL2 + (i - 1) * 63.3, -250)
        b:SetText(L[k[1]])
        if b.GetFontString and b:GetFontString() then b:GetFontString():SetFontObject("GameFontNormalSmall") end
        b:SetScript("OnClick", function()
            local pr = EP()
            pr.zoomSet, pr.zoomRemember, pr.zoomKind = true, false, i - 1
            for _, refresh in ipairs(controls) do refresh() end
            ZoomUI()
            if editProfile == activeProfile then ConstrainZoom(true) end
        end)
        Tip(b, k[1], k[2])
        kindBtns[i] = b
    end
    zoomSlider = MakeSlider(S2, "Zoom distance (yards)", "zoomDist", 0, 40, 0.5, c2, -292, true, EP)
    minSlider = MakeSlider(S2, "Nearest distance (yards)", "zoomMin", 1, 40, 0.5, c2, -292, true, EP)
    maxSlider = MakeSlider(S2, "Farthest distance (yards)", "zoomMax", 1, 40, 0.5, c2, -337, true, EP)
    panel.ZoomUI = ZoomUI

    -- Talk only: fade the rest of the interface while a window is open
    local function Talk(w) talkWidgets[#talkWidgets + 1] = w return w end
    local talkHead = S2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local tc = S2.accent or GOLD
    talkHead:SetPoint("TOPLEFT", panel, "TOPLEFT", COL2, -388)
    talkHead:SetText(L["Fade the interface while talking"])
    talkHead:SetTextColor(tc[1], tc[2], tc[3])
    Talk(talkHead)
    local talkRule = S2:CreateTexture(nil, "ARTWORK")
    talkRule:SetColorTexture(tc[1], tc[2], tc[3], 0.7)
    talkRule:SetPoint("TOPLEFT", panel, "TOPLEFT", COL2, -405)
    talkRule:SetPoint("TOPRIGHT", panel, "TOPLEFT", COL2 + CW, -405)
    talkRule:SetHeight(1)
    Talk(talkRule)
    local fadeCb = Talk(MakeCheck(S2, "Fade the rest of the interface", "talkFade", COL2, -412, function() Detect.fade.reset(); Refresh() end))
    Tip(fadeCb, "Fade the rest of the interface", "While a dialogue or vendor window is open, everything else on screen fades out, so only the conversation and the world remain. The window itself, your bags, popups and tooltips stay. It comes back as soon as the window closes.")
    Talk(MakeSlider(S2, "Opacity of the rest (0 = hidden)", "talkFadeAlpha", 0, 1, 0.05, c2, -458, true))
    Talk(MakeCheck(S2, "Keep the chat visible", "talkKeepChat", COL2, -486, function() end))
    Talk(MakeCheck(S2, "Keep the minimap visible", "talkKeepMinimap", COL2, -512, function() end))
    local keepLabel = S2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    keepLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", COL2, -544)
    keepLabel:SetText(L["Also keep these frames (names, comma separated):"])
    Talk(keepLabel)
    local keepBox = CreateFrame("EditBox", nil, S2, "InputBoxTemplate")
    keepBox:SetSize(CW - 12, 20)
    keepBox:SetPoint("TOPLEFT", panel, "TOPLEFT", COL2 + 8, -562)
    keepBox:SetAutoFocus(false)
    keepBox:SetMaxLetters(200)
    keepBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    keepBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    keepBox:SetScript("OnTextChanged", function(self, user) if user then db.talkKeepFrames = self:GetText() or "" end end)
    controls[#controls + 1] = function() keepBox:SetText(db.talkKeepFrames or "") end
    Talk(keepBox)

    -- the toggle between the two sub-pages, beside the situation buttons
    local moreBtn = CreateFrame("Button", nil, Sroot, "UIPanelButtonTemplate")
    moreBtn:SetSize(66, 26)
    moreBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", COL1 + 7 * 68, -60)
    local function SubPage(n)
        panel.subPage = n
        S:SetShown(n == 1)
        S2:SetShown(n == 2)
        moreBtn:SetText(n == 1 and L["More >"] or L["< Back"])
        if n == 2 then ZoomUI() end
    end
    moreBtn:SetScript("OnClick", function() SubPage(panel.subPage == 2 and 1 or 2) end)
    Tip(moreBtn, "More", "Head tracking, zoom rules for this situation, and (in Talk) fading the interface.")
    panel.SubPage = SubPage

    panel.ShowBlend = ShowBlend

    -- Presets -----------------------------------------------------------
    local selectedPreset = db.activePreset or "Default"
    local status = R:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", panel, "TOPLEFT", COL1, -452)
    status:SetWidth(CW)
    status:SetJustifyH("LEFT")
    local function Say(msg)
        status:SetText(msg)
        Print(msg)
    end

    Header(R, "Presets", COL1, -58)
    local rows = {}
    local nameBox, shareBox, noteText, undoBtn
    local function RefreshPresetList()
        local names = {}
        for _, n in ipairs(BUILTIN_ORDER) do names[#names + 1] = n end
        for _, n in ipairs(CustomNames()) do names[#names + 1] = n end
        if not (IsBuiltin(selectedPreset) or (db.presets and db.presets[selectedPreset])) then selectedPreset = "Default" end
        local modified = PresetUndo.isModified()
        if undoBtn then undoBtn:SetEnabled(PresetUndo.snap ~= nil) end
        for i = 1, #BUILTIN_ORDER + MAX_CUSTOM_PRESETS do
            local row = rows[i]
            local n = names[i]
            if n then
                row.preset = n
                row.label:SetText(IsBuiltin(n) and ("|cffffd34d" .. n .. "|r  |cff8a98b0(built-in)|r") or ("|cff8ce86b" .. n .. "|r"))
                row:Show()
                if n == selectedPreset then row:LockHighlight() else row:UnlockHighlight() end
                row.current:SetShown(n == db.activePreset)
                if n == db.activePreset then row.current:SetText(modified and "in use (modified)" or "in use") end
            else
                row:Hide()
            end
        end
        if noteText then
            noteText:SetText(BUILTIN_NOTES[selectedPreset] or "Your saved preset.")
        end
    end
    for i = 1, #BUILTIN_ORDER + MAX_CUSTOM_PRESETS do
        local row = CreateFrame("Button", nil, R)
        row:SetSize(CW, 17)
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", COL1, -80 - (i - 1) * 18)
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(); hl:SetColorTexture(1, 0.82, 0, 0.12)
        row:SetHighlightTexture(hl)
        local sel = row:CreateTexture(nil, "BACKGROUND")
        sel:SetAllPoints(); sel:SetColorTexture(1, 0.82, 0, 0.18); sel:Hide()
        row.sel = sel
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.label:SetPoint("LEFT", 6, 0)
        row.current = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.current:SetPoint("RIGHT", -6, 0)
        row.current:SetText(L["in use"])
        row.current:SetTextColor(0.52, 0.92, 0.42)
        row.current:Hide()
        row:SetScript("OnClick", function(self)
            selectedPreset = self.preset
            nameBox:SetText(IsBuiltin(selectedPreset) and "" or selectedPreset)
            RefreshPresetList()
        end)
        rows[i] = row
    end
    -- the selected row is drawn with its own tint (LockHighlight alone is faint on dark parchment)
    local origRefresh = RefreshPresetList
    RefreshPresetList = function()
        origRefresh()
        for _, row in ipairs(rows) do row.sel:SetShown(row:IsShown() and row.preset == selectedPreset) end
    end

    noteText = R:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    noteText:SetPoint("TOPLEFT", panel, "TOPLEFT", COL1, -372)
    noteText:SetWidth(CW)
    noteText:SetHeight(58)
    noteText:SetJustifyH("LEFT")
    noteText:SetJustifyV("TOP")

    local nameLabel = R:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", COL1, -440)
    nameLabel:SetText(L["Preset name:"])
    nameBox = CreateFrame("EditBox", nil, R, "InputBoxTemplate")
    nameBox:SetSize(160, 20)
    nameBox:SetPoint("TOPLEFT", panel, "TOPLEFT", COL1 + 86, -436)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(24)
    nameBox:SetScript("OnEscapePressed", nameBox.ClearFocus)
    nameBox:SetScript("OnEnterPressed", nameBox.ClearFocus)

    local function Button(parent, text, x, y, w, onClick)
        local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        b:SetSize(w, 22)
        b:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
        b:SetText(L[text])
        b:SetScript("OnClick", onClick)
        return b
    end
    local half = (CW - 6) / 2
    Button(R, "Apply", COL1, -464, half, function()
        local snap = PresetSnapshot(selectedPreset)
        if not snap then return end
        ApplySnapshot(snap, selectedPreset)
        RefreshPresetList()
        Say("Applied preset \"" .. selectedPreset .. "\".")
    end)
    local function SaveAs(overwrite)
        local name = CleanName(nameBox:GetText())
        if name == "" then Say(L["Type a name for the preset first."]); return end
        if IsBuiltin(name) then Say("\"" .. name .. "\" is a built-in preset; pick another name."); return end
        db.presets = db.presets or {}
        local existing = FindPresetName(name)
        if existing and not overwrite then
            Say("A preset named \"" .. existing .. "\" exists. Select it and use Overwrite, or choose another name.")
            return
        end
        name = existing or name
        if not existing and #CustomNames() >= MAX_CUSTOM_PRESETS then
            Say("You can keep up to " .. MAX_CUSTOM_PRESETS .. " custom presets. Delete one first.")
            return
        end
        db.presets[name] = CurrentSnapshot()
        db.activePreset = name
        selectedPreset = name
        RefreshPresetList()
        Say("Saved your current settings as \"" .. name .. "\".")
    end
    Button(R, "Save as new", COL1 + half + 6, -464, half, function() SaveAs(false) end)
    Button(R, "Overwrite selected", COL1, -490, half, function()
        if IsBuiltin(selectedPreset) then Say(L["Built-in presets can't be changed. Save under your own name instead."]); return end
        nameBox:SetText(selectedPreset)
        SaveAs(true)
    end)
    Button(R, "Delete selected", COL1 + half + 6, -490, half, function()
        if IsBuiltin(selectedPreset) then Say(L["Built-in presets can't be deleted."]); return end
        db.presets[selectedPreset] = nil
        if db.activePreset == selectedPreset then db.activePreset = nil end
        Say("Deleted preset \"" .. selectedPreset .. "\".")
        selectedPreset = "Default"
        RefreshPresetList()
    end)
    undoBtn = Button(R, "Undo last preset change", COL1, -516, CW, function()
        if PresetUndo.undo() then
            RefreshPresetList()
            Say(L["Went back to your previous settings (press again to redo)."])
        end
    end)
    status:ClearAllPoints()
    status:SetPoint("TOPLEFT", panel, "TOPLEFT", COL1, -546)

    -- Sharing: a text code for the current settings
    Header(R, "Share settings", COL2, -58)
    local shareNote = R:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    shareNote:SetPoint("TOPLEFT", panel, "TOPLEFT", COL2, -76)
    shareNote:SetWidth(CW)
    shareNote:SetJustifyH("LEFT")
    shareNote:SetText(L["Export writes a code for your current settings into the box. To import, paste someone's code into the box and click Import."])

    local bg = R:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", panel, "TOPLEFT", COL2 - 2, -176)
    bg:SetSize(CW + 4, 306)
    bg:SetColorTexture(0, 0, 0, 0.45)
    local sf = CreateFrame("ScrollFrame", "TenKsARPGCameraShareScroll", R, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", panel, "TOPLEFT", COL2 + 2, -180)
    sf:SetSize(CW - 26, 298)
    shareBox = CreateFrame("EditBox", nil, sf)
    shareBox:SetMultiLine(true)
    shareBox:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    shareBox:SetWidth(CW - 28)
    shareBox:SetHeight(298)
    shareBox:SetAutoFocus(false)
    shareBox:SetMaxLetters(30000)
    shareBox:SetScript("OnEscapePressed", shareBox.ClearFocus)
    shareBox:SetScript("OnTextChanged", function(self)
        self:SetHeight(math.max(298, (self:GetNumLines() or 1) * 14 + 8))
    end)
    sf:SetScrollChild(shareBox)

    Button(R, "Export current", COL2, -116, half, function()
        shareBox:SetText(ExportString(CurrentSnapshot()))
        shareBox:SetFocus()
        shareBox:HighlightText()
        Say(L["Exported. Press Ctrl+C to copy the code."])
    end)
    Button(R, "Export selected preset", COL2, -142, CW, function()
        local snap = PresetSnapshot(selectedPreset)
        if not snap then return end
        shareBox:SetText(ExportString(snap))
        shareBox:SetFocus()
        shareBox:HighlightText()
        Say("Code for \"" .. selectedPreset .. "\" is in the box. Press Ctrl+C to copy it.")
    end)
    Button(R, "Import", COL2 + half + 6, -116, half, function()
        local snap, good, bad = ParseString(shareBox:GetText())
        if not snap then Say(good); return end
        local name = CleanName(nameBox:GetText())
        local msg = "Imported " .. good .. " settings" .. ((bad or 0) > 0 and (" (" .. bad .. " unknown or invalid ones skipped)") or "") .. "."
        local label = "Imported"
        if name ~= "" and not IsBuiltin(name) then
            db.presets = db.presets or {}
            local existing = FindPresetName(name)
            if existing or #CustomNames() < MAX_CUSTOM_PRESETS then
                name = existing or name
                -- a saved preset is a complete snapshot: start from the factory settings, then the import
                local full = FactorySnapshot()
                for k, v in pairs(snap) do full[k] = v end
                db.presets[name] = full
                selectedPreset = name
                label = name
                msg = msg .. " Saved as preset \"" .. name .. "\"."
            else
                msg = msg .. " (Preset list is full, so it wasn't saved as a preset.)"
            end
        end
        ApplySnapshot(snap, label)
        RefreshPresetList()
        Say(msg)
    end)
    local shareFoot = R:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    shareFoot:SetPoint("TOPLEFT", panel, "TOPLEFT", COL2, -492)
    shareFoot:SetWidth(CW)
    shareFoot:SetJustifyH("LEFT")
    shareFoot:SetText(L["Type a name on the left before importing to also keep the import as a preset. Your window position and opacity are never part of a code."])
    panel.RefreshPresetList = RefreshPresetList
    RefreshPresetList()

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOM", 0, 14)
    hint:SetText(L["Untick Enabled to restore your original camera settings."])
    local ver = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ver:SetPoint("BOTTOMRIGHT", -14, 14)
    ver:SetText("v" .. Meta.version)

    -- Side tabs ---------------------------------------------------------
    -- They hang off the window's left edge. The selected one sits flush with
    -- the window (its right side covers the border, so it reads as part of it)
    -- and is brighter; the others are darker and pushed back a little.
    local tabButtons = {}
    local function SetTabSelected(tb, sel)
        local c = tb.color
        tb:ClearAllPoints()
        tb:SetPoint("TOPRIGHT", panel, "TOPLEFT", sel and 4 or -3, tb.y)
        tb:SetFrameLevel(panel:GetFrameLevel() + (sel and 12 or 6))
        if sel then
            tb.bg:SetColorTexture(c[1] * 0.28 + 0.05, c[2] * 0.28 + 0.05, c[3] * 0.28 + 0.05, 1)
            tb.accent:Show()
            tb.edgeR:Hide()
            tb.text:SetTextColor(math.min(1, c[1] + 0.15), math.min(1, c[2] + 0.15), math.min(1, c[3] + 0.15))
            for _, e in ipairs(tb.edges) do e:SetColorTexture(c[1], c[2], c[3], 1) end
        else
            tb.bg:SetColorTexture(c[1] * 0.10 + 0.03, c[2] * 0.10 + 0.03, c[3] * 0.10 + 0.04, 1)
            tb.accent:Hide()
            tb.edgeR:Show()
            tb.text:SetTextColor(c[1] * 0.7, c[2] * 0.7, c[3] * 0.7)
            for _, e in ipairs(tb.edges) do e:SetColorTexture(c[1] * 0.45, c[2] * 0.45, c[3] * 0.45, 1) end
            tb.edgeR:SetColorTexture(c[1] * 0.45, c[2] * 0.45, c[3] * 0.45, 1)
        end
    end
    local function SelectTab(id)
        db.menuTab = id
        for _, pg in ipairs(PAGES) do
            pages[pg.id]:SetShown(pg.id == id)
            SetTabSelected(tabButtons[pg.id], pg.id == id)
        end
    end
    -- A backing plate behind the tabs, in the window's own dark tone, so they read as part of the window.
    do
        local rail = CreateFrame("Frame", nil, panel)
        rail:SetPoint("TOPRIGHT", panel, "TOPLEFT", -1, -46)
        rail:SetSize(TAB_W + 14, #PAGES * (TAB_H + 4) + 20)
        rail:SetFrameLevel(panel:GetFrameLevel() + 3)
        local bg = rail:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.06, 0.09, 0.96)
        bgParts[#bgParts + 1] = { bg, 0.96 }
        local function edge(p1, p2, w, h)
            local t = rail:CreateTexture(nil, "BORDER")
            t:SetPoint(p1); t:SetPoint(p2)
            if w then t:SetWidth(w) end
            if h then t:SetHeight(h) end
            t:SetColorTexture(0.55, 0.45, 0.22, 1)
            bgParts[#bgParts + 1] = { t, 1 }
        end
        edge("TOPLEFT", "TOPRIGHT", nil, 2)
        edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 2)
        edge("TOPLEFT", "BOTTOMLEFT", 2, nil)
        local head = rail:CreateTexture(nil, "ARTWORK") -- a faint band along the top, like the window's title strip
        head:SetPoint("TOPLEFT", 2, -2); head:SetPoint("TOPRIGHT", 0, -2); head:SetHeight(6)
        head:SetColorTexture(1, 0.82, 0.3, 0.18)
        bgParts[#bgParts + 1] = { head, 0.18 }
    end
    for n, pg in ipairs(PAGES) do
        local tb = CreateFrame("Button", nil, panel)
        tb:SetSize(TAB_W, TAB_H)
        tb.y = -58 - (n - 1) * (TAB_H + 4)
        tb.color = pg.color
        tb.bg = tb:CreateTexture(nil, "BACKGROUND")
        tb.bg:SetAllPoints()
        local function line(point1, point2, w, h)
            local t = tb:CreateTexture(nil, "BORDER")
            t:SetPoint(point1); t:SetPoint(point2)
            if w then t:SetWidth(w) end
            if h then t:SetHeight(h) end
            return t
        end
        tb.edges = { line("TOPLEFT", "TOPRIGHT", nil, 1), line("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1), line("TOPLEFT", "BOTTOMLEFT", 1, nil) }
        tb.edgeR = line("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
        tb.accent = tb:CreateTexture(nil, "ARTWORK")        -- gold stripe on the selected tab
        tb.accent:SetColorTexture(pg.color[1], pg.color[2], pg.color[3], 1)
        tb.accent:SetPoint("TOPLEFT", 1, -1)
        tb.accent:SetPoint("BOTTOMLEFT", 1, 1)
        tb.accent:SetWidth(3)
        tb.text = tb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tb.text:SetPoint("CENTER", -2, 0)
        tb.text:SetText(L[pg.label])
        tb:SetScript("OnClick", function() SelectTab(pg.id) end)
        tb:SetScript("OnEnter", function(self) if db.menuTab ~= pg.id then self.text:SetTextColor(pg.color[1], pg.color[2], pg.color[3]) end end)
        tb:SetScript("OnLeave", function(self) if db.menuTab ~= pg.id then self.text:SetTextColor(pg.color[1] * 0.7, pg.color[2] * 0.7, pg.color[3] * 0.7) end end)
        tabButtons[pg.id] = tb
        -- fade with the window's background opacity setting
        bgParts[#bgParts + 1] = { tb.bg, 1 }
        for _, e in ipairs(tb.edges) do bgParts[#bgParts + 1] = { e, 1 } end
        bgParts[#bgParts + 1] = { tb.edgeR, 1 }
    end
    panel:SetBackgroundOpacity(db.menuAlpha)

    -- Gamepad control ----------------------------------------------------
    -- D-pad moves a gold cursor between the window's controls, A presses (ticks a box, clicks a button), left/right
    -- change a slider, the bumpers switch tab, B closes. The cursor appears once a pad button is pressed.
    do
        local cursor = CreateFrame("Frame", nil, panel)
        cursor:SetFrameLevel(panel:GetFrameLevel() + 30)
        local function cedge(p1, p2, w, h)
            local t = cursor:CreateTexture(nil, "OVERLAY")
            t:SetPoint(p1); t:SetPoint(p2)
            if w then t:SetWidth(w) end
            if h then t:SetHeight(h) end
            t:SetColorTexture(1, 0.82, 0.2, 1)
        end
        cedge("TOPLEFT", "TOPRIGHT", nil, 2); cedge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 2)
        cedge("TOPLEFT", "BOTTOMLEFT", 2, nil); cedge("TOPRIGHT", "BOTTOMRIGHT", 2, nil)
        cursor:Hide()
        local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", COL1, 12)
        hint:SetText(L["Controller: D-pad move   A select   B close   LB / RB tabs   LT / RT big slider steps"])
        hint:Hide()
        local current

        local function Focusables()
            local list = {}
            local function scan(f, depth)
                if depth > 6 then return end
                for _, child in ipairs({ f:GetChildren() }) do
                    if child:IsShown() and child ~= cursor then
                        local kind = child:GetObjectType()
                        local usable = kind == "CheckButton" or kind == "Button" or kind == "Slider"
                        if usable then
                            for _, tb in pairs(tabButtons) do if tb == child then usable = false end end
                            if child.IsEnabled and not child:IsEnabled() then usable = false end
                            if not child:GetCenter() then usable = false end
                        end
                        if usable then list[#list + 1] = child end
                        scan(child, depth + 1)
                    end
                end
            end
            scan(panel, 0)
            return list
        end
        local function Place(w)
            current = w
            cursor:ClearAllPoints()
            local extra, up = 3, 3
            if w.tkLabel and w.tkLabel.GetStringWidth then extra = (w.tkLabel:GetStringWidth() or 0) + 10 end
            if w:GetObjectType() == "Slider" then up = 16 end
            cursor:SetPoint("TOPLEFT", w, "TOPLEFT", -3, up)
            cursor:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", extra, -3)
            cursor:Show()
        end
        local function Pick(list) -- the control nearest the top-left of the page
            local best, bs
            for _, w in ipairs(list) do
                local x, y = w:GetCenter()
                local sc = -y * 2 + x
                if not bs or sc < bs then best, bs = w, sc end
            end
            if best then Place(best) end
        end
        local function Move(dx, dy)
            local list = Focusables()
            if #list == 0 then return end
            local valid = false
            for _, w in ipairs(list) do if w == current then valid = true end end
            if not valid then Pick(list) return end
            local cx, cy = current:GetCenter()
            local best, bs
            for _, w in ipairs(list) do
                if w ~= current then
                    local x, y = w:GetCenter()
                    local ddx, ddy = x - cx, y - cy
                    local along = ddx * dx + ddy * dy
                    if along > 4 then
                        local perp = math.abs(dx ~= 0 and ddy or ddx)
                        local sc = along + perp * 2.5
                        if not bs or sc < bs then best, bs = w, sc end
                    end
                end
            end
            if best then Place(best) end
        end
        local function Nudge(slider, dir, mult)
            local lo, hi = slider:GetMinMaxValues()
            local step = (slider.GetValueStep and slider:GetValueStep()) or 0.05
            if not step or step <= 0 then step = (hi - lo) / 20 end
            slider:SetValue(math.max(lo, math.min(hi, slider:GetValue() + dir * step * mult)))
        end
        local function CycleTab(dir)
            local idx = 1
            for i, pg in ipairs(PAGES) do if pg.id == (db.menuTab or "general") then idx = i end end
            idx = (idx - 1 + dir) % #PAGES + 1
            SelectTab(PAGES[idx].id)
            current = nil
            cursor:Hide()
            Pick(Focusables())
        end
        local function Press(btn)
            if not cursor:IsShown() then -- the first press just shows where the cursor is
                hint:Show()
                local list = Focusables()
                local valid = false
                for _, w in ipairs(list) do if w == current then valid = true end end
                if valid then Place(current) else Pick(list) end
                if btn == "PADDUP" or btn == "PADDDOWN" or btn == "PADDLEFT" or btn == "PADDRIGHT" or btn == "PAD1" then return true end
            end
            local sliderNow = current and current:IsShown() and current:GetObjectType() == "Slider"
            if btn == "PADDUP" or btn == "PADLSTICKUP" then Move(0, 1)
            elseif btn == "PADDDOWN" or btn == "PADLSTICKDOWN" then Move(0, -1)
            elseif btn == "PADDLEFT" or btn == "PADLSTICKLEFT" then
                if sliderNow then Nudge(current, -1, 1) else Move(-1, 0) end
            elseif btn == "PADDRIGHT" or btn == "PADLSTICKRIGHT" then
                if sliderNow then Nudge(current, 1, 1) else Move(1, 0) end
            elseif btn == "PADLTRIGGER" and sliderNow then Nudge(current, -1, 5)
            elseif btn == "PADRTRIGGER" and sliderNow then Nudge(current, 1, 5)
            elseif btn == "PAD1" then
                if current and current:IsShown() and current.Click and current:GetObjectType() ~= "Slider" then
                    current:Click()
                    if current:IsShown() then Place(current) end
                end
            elseif btn == "PAD2" then panel:Hide()
            elseif btn == "PADLSHOULDER" then CycleTab(-1)
            elseif btn == "PADRSHOULDER" then CycleTab(1)
            else return false end
            return true
        end
        if panel.EnableGamePadButton then pcall(panel.EnableGamePadButton, panel, true) end
        pcall(panel.SetScript, panel, "OnGamePadButtonDown", function(self, btn)
            local handled = Press(btn)
            if self.SetPropagateKeyboardInput then pcall(self.SetPropagateKeyboardInput, self, not handled) end
        end)
        panel:HookScript("OnShow", function()
            current = nil
            cursor:Hide()
            hint:SetShown(Detect.gamepad() and true or false)
        end)
        panel.PadPress = Press -- used by the tests
    end

    panel:SetScript("OnShow", function()
        RefreshWhy()
        RefreshProfileWidgets()
        ShowBlend()
        RefreshPresetList()
        SelectTab(db.menuTab or "general")
    end)
    SelectTab(db.menuTab or "general")
    -- keep the "in use right now" line current while the window is open
    local acc = 0
    panel:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc > 0.5 then
            acc = 0
            activeLabel:SetText(InUseText())
            if pages.general:IsShown() then RefreshWhy() end
            if pages.presets:IsShown() and panel.RefreshPresetList then panel.RefreshPresetList() end
        end
    end)
    panel:SetScript("OnHide", function() SetPreview(nil) end)
end

-- Turn the addon on or off (shared by the settings window, the slash commands and the toggle macro).
SetAddonEnabled = function(on)
    if on then Enable() else Disable() end
    if panel and panel:IsShown() then
        for _, refresh in ipairs(controls) do refresh() end
    end
end

-- Macros the player can drag onto an action bar:
--   "ACAM Menu"   opens the settings window
--   "ACAM Toggle" switches the addon on or off
do
local MACROS = {
    { name = "ACAM Menu",   icon = "INV_Misc_Gear_01",       body = "/acam" },
    { name = "ACAM Toggle", icon = "Ability_Hunter_Camouflage", body = "/acam toggle" },
}
local FALLBACK_ICON = 134400 -- question mark

CreateMacros = function()
    if InCombatLockdown and InCombatLockdown() then
        Print(L["Macros can't be created in combat. Try again once combat ends."])
        return
    end
    if not (CreateMacro and EditMacro and GetMacroInfo) then
        Print(L["This client doesn't allow addons to create macros."])
        return
    end
    for _, m in ipairs(MACROS) do
        local index
        for i = 1, 150 do
            local name = GetMacroInfo(i)
            if name == m.name then index = i break end
        end
        -- an earlier version made these as character macros (slots 121+); move them to the General tab
        if index and index > 120 and DeleteMacro then
            pcall(DeleteMacro, index)
            index = nil
        end
        if index then
            local ok = pcall(EditMacro, index, m.name, m.icon, m.body)
            if not ok then ok = pcall(EditMacro, index, m.name, FALLBACK_ICON, m.body) end
            Print(ok and ("Updated macro \"" .. m.name .. "\".") or ("Couldn't update macro \"" .. m.name .. "\"."))
        else
            -- General (account-wide) macros: the last argument, perCharacter, is false
            local ok, id = pcall(CreateMacro, m.name, m.icon, m.body, false)
            if not (ok and id) then ok, id = pcall(CreateMacro, m.name, FALLBACK_ICON, m.body, false) end
            Print((ok and id) and ("Created General macro \"" .. m.name .. "\" (" .. m.body .. ").")
                or ("Couldn't create \"" .. m.name .. "\": your General macro slots may be full."))
        end
    end
    Print(L["Open /macro, find them on the General tab, and drag them onto an action bar."])
end
end

local function TogglePanel()
    if not panel then BuildPanel() end
    if panel:IsShown() then panel:Hide() else panel:Show() end
end

-- Key Bindings > AddOns: open the window or switch the camera on and off with any key or gamepad button.
BINDING_HEADER_TENKSARPGCAMERA = "10k's Ultimate ARPG Camera"
BINDING_NAME_TENKSARPGCAMERA_MENU = L["Open the settings window"]
BINDING_NAME_TENKSARPGCAMERA_TOGGLE = L["Turn the camera on or off"]
BINDING_NAME_TENKSARPGCAMERA_CURSOR = L["Free the cursor (mouse-look lock)"]
function TenKsUltimateARPGCamera_ToggleMenu() TogglePanel() end
function TenKsUltimateARPGCamera_ToggleCamera() SetAddonEnabled(not db.enabled) end
function TenKsUltimateARPGCamera_CursorKey(state) Detect.ml.key(state) end

---------------------------------------------------------------------------
-- Slash commands & events
---------------------------------------------------------------------------

local function Help()
    Print(L["Commands (/acam):"])
    print("  (no argument)         open the settings window")
    print("  presets / preset <name>  list the presets / apply one")
    print("  mouselock             lock the camera to the mouse (bind \"Free the cursor\" to get the cursor back)")
    print("  toggle                switch the camera on or off (used by the toggle macro)")
    print("  undo                  go back to the settings you had before the last preset (again to redo)")
    print("  why                   show which situation is active and why")
    print("  welcome / version / new   the welcome window / version number / what changed")
    print("  macros                create the \"ACAM Menu\" and \"ACAM Toggle\" macros")
    print("  on / off              enable the camera (off restores your original settings)")
    print("  yaw <0-1>  pitch <0-1>   how strongly the camera turns/tilts toward targets")
    print("  frame                 toggle the four-triangle targeting frame")
    print("  framesize <40-300>    frame height in pixels at ~10 yards;  framenudge <-100..100> moves it left/right")
    print("  framespin <0-360>     how fast the triangles circle the target, degrees/second (0 = still)")
    print("  fx                    open the targeting frame settings window")
    print("  framealpha <0.2-1>  framecurve <0-1>  frameshift <-40..40>   opacity / curvature / distance shift")
    print("  frametest             draw the frame at the screen center to check it draws at all")
    print("  framestyle            cycle the style: reticle, ground ring, solid triangles, outline")
    print("  shoulder              check everything that decides whether the shoulder offset can work")
    print("  padtest               with a controller: find which setting makes the game keep the character centered")
    print("  cvars [label]         save every camera and gamepad setting the game has into the addon's saved file (for troubleshooting)")
    print("  npcs                  switch focusing of all friendly targets (NPCs, players, group, pets, critters) on or off together")
    print("  combat                toggle 'focus enemies only in combat'")
    print("  shoulder <-10..10>      over-the-shoulder offset")
    print("  shouldercomp [-1.5..1.5]  toggle, or set the strength of, keeping the character in place on screen as you zoom (0 = off, 1 = full, negative exaggerates the drift)")
    print("  camtilt <-20..20>     camera tilt offset of the base profile, degrees (+ = up)")
    print("  fov <50-90>           field of view of the base (exploration) profile")
    print("  profile               show the active situation profile and every profile's values")
    print("  zoom <1-3.5>          max zoom factor")
    print("  head <0-1>            head-movement sway")
    print("  smooth <0.2-1>        turn smoothing (lower = smoother)")
    print("  tilt / bob            toggle terrain tilt / camera bobbing")
    print("  follow <value|off>    set cameraSmoothStyle directly (camera auto-follow)")
    print("  status                show which camera settings your client supports")
    print("  nameplates            show the nameplate switches and what the game has for each")
    print("  debug                 with a target selected, show what the targeting frame is doing")
end

SLASH_ACAM1 = "/acam"
SlashCmdList["ACAM"] = function(msg)
    local cmd, rest = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    local n = tonumber(rest)

    if cmd == "" then
        TogglePanel()
        return
    elseif cmd == "on" then
        Enable()
        Print(L["Enabled."])
    elseif cmd == "presets" then
        local names = {}
        for _, n in ipairs(BUILTIN_ORDER) do names[#names + 1] = n end
        for _, n in ipairs(CustomNames()) do names[#names + 1] = n end
        Print("Presets: " .. table.concat(names, ", ") .. ((db.activePreset and ("  (last applied: " .. db.activePreset .. ")")) or ""))
    elseif cmd == "preset" then
        local name = FindPresetName(rest)
        local snap = name and PresetSnapshot(name)
        if not snap then
            Print("No preset called \"" .. rest .. "\". /acam presets lists them.")
        else
            ApplySnapshot(snap, name)
            if panel and panel.RefreshPresetList then panel.RefreshPresetList() end
            Print("Applied preset \"" .. name .. "\".")
        end
    elseif cmd == "mouselock" then
        db.mlOn = not db.mlOn
        Detect.ml.reset()
        Print(string.format("Mouse-look lock: %s.", db.mlOn and "on" or "off"))
    elseif cmd == "welcome" then
        TenKsUltimateARPGCamera_ShowWelcome()
        return
    elseif cmd == "version" then
        Print("v" .. Meta.version)
    elseif cmd == "new" then
        Print(L["What's new in"] .. " v" .. Meta.version .. ":")
        for _, line in ipairs(Meta.notes) do print("  - " .. L[line]) end
    elseif cmd == "nameplates" then
        Print("Nameplate switches (managed: " .. tostring(db.npManage) .. "):")
        for _, k in ipairs(NP.kinds) do
            for i = 2, #k do
                local cur = getCVar(k[i])
                if cur ~= nil then
                    print(string.format("  %s: game has %s, addon wants %s", k[i], tostring(cur), db[k[1]] ~= false and "1" or "0"))
                end
            end
            if not NP.supported(k) then print("  (this client has no switch for: " .. k[1] .. ")") end
        end
        if C_Console and C_Console.GetAllCommands then -- every nameplate-related setting the game lists
            local ok, cmds = pcall(C_Console.GetAllCommands)
            if ok and type(cmds) == "table" then
                local names = {}
                for _, c in ipairs(cmds) do
                    local n = type(c) == "table" and c.command or c
                    if type(n) == "string" and n:lower():find("nameplateshow") then names[#names + 1] = n end
                end
                table.sort(names)
                print("  the game lists: " .. (#names > 0 and table.concat(names, ", ") or "none"))
            end
        end
        if InCombatLockdown and InCombatLockdown() then print("  (in combat: changes wait until combat ends)") end
    elseif cmd == "shoulder" then
        -- everything that decides whether the shoulder offset can work
        local function cv(n) local ok, v = pcall(getCVar, n) return ok and tostring(v) or "?" end
        Print(L["Shoulder offset check:"])
        local kc, rm = cv("CameraKeepCharacterCentered"), cv("CameraReduceUnexpectedMovement")
        print(string.format("  Keep character centered: %s %s", kc, kc == "0" and "(ok)" or "|cffff6060(ON: the game ignores the shoulder offset)|r"))
        print(string.format("  Reduce unexpected camera movement: %s %s", rm, (rm == "0" or rm == "?") and "(ok)" or "|cffff6060(ON: the game ignores the shoulder offset)|r"))
        print(string.format("  shoulder offset written: %s (the situation wants %.2f)", cv("test_cameraOverShoulder"), Cur("shoulder") or 0))
        local on, why = Detect.gamepad()
        print(string.format("  gamepad: %s (%s)  addon on: %s", tostring(on), tostring(why), tostring(db.enabled)))
        for name, f in pairs(Detect.guardFixes or {}) do
            print(string.format("  the game changed %s back %d times%s", name, f.total or f.n, f.locked and " (locked)" or ""))
        end
    elseif cmd == "why" then
        Print(L["Situation checks right now (the one marked > is in use):"])
        for _, r in ipairs(Detect.explain()) do
            print(string.format("  %s%s%s: %s", r.key == activeProfile and "> " or "  ", PROFILE_NAMES[r.key],
                (r.key == "world" or r.on) and "" or (" (" .. L["off"] .. ")"), r.reason))
        end
        if OnTaxi() then print("  " .. L["On a flight path: Exploration is used."]) end
        if previewProfile then print("  " .. L["Previewing: "] .. PROFILE_NAMES[previewProfile]) end
    elseif cmd == "undo" then
        if PresetUndo.undo() then
            if panel and panel.RefreshPresetList then panel.RefreshPresetList() end
            Print("Went back to your previous settings" .. (db.activePreset and (" (" .. db.activePreset .. ")") or "") .. ". Run /acam undo again to redo.")
        else
            Print(L["Nothing to undo yet: no preset has been applied this session."])
        end
    elseif cmd == "toggle" then
        SetAddonEnabled(not db.enabled)
        Print(db.enabled and "Enabled." or "Disabled; original camera settings restored.")
    elseif cmd == "macros" then
        CreateMacros()
    elseif cmd == "off" then
        Disable()
        Print(L["Disabled; original camera settings restored."])
    elseif cmd == "yaw" and n then
        db.profiles.world.yaw = math.max(0, math.min(1, n)); Refresh()
    elseif cmd == "pitch" and n then
        db.profiles.world.pitch = math.max(0, math.min(1, n)); Refresh()
    elseif cmd == "debug" then
        print("|cff33ff9910k's Ultimate ARPG Camera debug:|r")
        print(string.format("  profile in use: %s | fov set %.1f, game reports %s", PROFILE_NAMES[activeProfile], shown.fov or 0, tostring(getCVar(CV.fov))))
        print(string.format("  enabled=%s focusKind=%s (%s) target nameplate=%s",
            tostring(db.enabled), tostring(FocusKind()), focusWhy, TargetPlate() and "yes" or "NO"))
        do
            local function show(fn, ...)
                local ok, v = pcall(fn, ...)
                if not ok then return "error" end
                if issecret(v) then return "secret" end
                return tostring(v)
            end
            print(string.format("  target: isPlayer=%s canAttack=%s reaction=%s | enemy focus enable=%s, interact focus enable=%s",
                show(UnitIsPlayer, "target"), show(UnitCanAttack, "player", "target"), show(UnitReaction, "player", "target"),
                tostring(getCVar(CV.enemyEnable)), tostring(getCVar(CV.interactEnable))))
        end
        print(string.format("  combatOnly=%s yaw=%.2f pitch=%.2f", tostring(db.combatOnly), Cur("yaw"), Cur("pitch")))
        for name, f in pairs(Detect.guardFixes or {}) do
            print(string.format("  put back %s %d times (game had set it to %s)%s", name, f.total or f.n, tostring(f.from),
                f.locked and " - locked by the game, retrying every 30 s" or ""))
            local who = db.cvarWho and db.cvarWho[name]
            print("    changed by: " .. (who and who[1] and ((who[1].stack or ""):match("[^\n]+") or "?") or "the game itself (no addon or UI code)"))
        end
        print(string.format("  game focus blend=%.2f (goal %d)", ramp, rampGoal))
        print(string.format("  dynamic fov: speed %.1f yd/s (level %.2f), %d enemies fighting you (level %.2f) | letterbox %.3f | gamepad %s",
            DynFov.yps, DynFov.speed, DynFov.enemies, DynFov.crowd, shown.lbSize or 0, tostring(Detect.gamepad())))
        print(string.format("  situation checks: instance=%s npc=%s swimming=%s indoors=%s resting=%s",
            tostring(Detect.instance()), tostring(Detect.npc()), tostring(Detect.flag(IsSwimming)),
            tostring(Detect.flag(IsIndoors)), tostring(Detect.flag(IsResting))))
        print(string.format("  targeting frame: %s | blocked=%s style=%s shown=%s anchoringSecret=%s",
            fxState, tostring(fxBlocked), tostring(db.fxStyle), tostring(fx:IsShown()),
            tostring(fx.IsAnchoringSecret and fx:IsAnchoringSecret() or "n/a")))
        print(string.format("  distance: %s (source: %s) curve=%.2f distShift=%d",
            distSmooth and string.format("%.1f yd", distSmooth) or "unknown", distSource, db.fxCurve, db.fxDistShift))
    elseif cmd == "frame" then
        db.fx = not db.fx
        Print("Targeting frame " .. (db.fx and "on." or "off."))
    elseif cmd == "framesize" and n then
        db.fxSize = math.max(40, math.min(300, n))
    elseif cmd == "framenudge" and n then
        db.fxOffset = math.max(-100, math.min(100, n))
    elseif cmd == "framespin" and n then
        db.fxSpeed = math.max(-180, math.min(180, n))
    elseif cmd == "fx" then
        TogglePanel()
        return
    elseif cmd == "framealpha" and n then
        db.fxAlpha = math.max(0.2, math.min(1, n))
    elseif cmd == "framecurve" and n then
        db.fxCurve = math.max(0, math.min(1, n))
    elseif cmd == "frameshift" and n then
        db.fxDistShift = math.max(-40, math.min(40, n))
    elseif cmd == "frametest" then
        fxTest = not fxTest
        Print(fxTest and "Targeting frame test ON: drawing at the center of the screen. Run /acam frametest again to stop."
            or "Targeting frame test off.")
    elseif cmd == "framestyle" then
        db.fxStyle = (db.fxStyle == "halo") and "reticle" or (db.fxStyle == "reticle") and "ring" or (db.fxStyle == "ring") and "solid"
            or (db.fxStyle == "solid") and "outline" or "halo"
        Print("Targeting frame style: " .. db.fxStyle)
    elseif cmd == "padtest" then
        Detect.padTest()
    elseif cmd == "cvars" then
        -- Records every camera / gamepad setting this client has, with its value, into the saved
        -- variables file (WTF\Account\<account>\SavedVariables\TenKsUltimateARPGCamera.lua) after /reload.
        local label = (rest and rest ~= "" and rest) or (Detect.gamepad() and "gamepad" or "mouse")
        local names, seen = {}, {}
        local function want(n)
            local l = n:lower()
            return l:find("camera") or l:find("gamepad") or l:find("actioncam") or l:find("cursor") or l:find("mouselook")
                or l:find("pitch") or l:find("yaw") or l:find("softtarget") or l:find("interact")
        end
        local getAll = (C_Console and C_Console.GetAllCommands) or ConsoleGetAllCommands
        if getAll then
            local ok, all = pcall(getAll)
            if ok and type(all) == "table" then
                for _, c in ipairs(all) do
                    local n = type(c) == "table" and c.command
                    if type(n) == "string" and want(n) and not seen[n] then seen[n] = true; names[#names + 1] = n end
                end
            end
        end
        for _, n in ipairs({ "GamePadEnable", "GamePadCameraYawSpeed", "GamePadCameraPitchSpeed", "GamePadCameraLookMaxYaw",
            "GamePadCameraLookMaxPitch", "GamePadFaceMovementMaxAngle", "GamePadFaceMovementMaxAngleCombat", "GamePadTurnWithCamera",
            "GamePadCursorCentering", "GamePadCursorForTargeting", "GamePadCursorAutoEnable", "cameraSmoothStyle",
            "cameraSmoothTrackingStyle", "cameraFov", "test_cameraOverShoulder", "test_cameraDynamicPitch",
            "test_cameraHeadMovementStrength", "test_cameraTargetFocusEnemyEnable", "test_cameraTargetFocusInteractEnable",
            "cameraDistanceMaxZoomFactor", "CameraKeepCharacterCentered", "CameraReduceUnexpectedMovement" }) do
            if not seen[n] then seen[n] = true; names[#names + 1] = n end
        end
        table.sort(names, function(a, b) return a:lower() < b:lower() end)
        local vals, n = {}, 0
        for _, name in ipairs(names) do
            local ok, v = pcall(getCVar, name)
            if ok and v ~= nil and not issecret(v) then vals[name] = tostring(v); n = n + 1 end
        end
        db.cvarDump = db.cvarDump or {}
        db.cvarDump[label] = { when = date and date("%Y-%m-%d %H:%M:%S") or "", gamepad = Detect.gamepad() and true or false,
            gamepadWhy = select(2, Detect.gamepad()), addonOn = db.enabled and true or false, values = vals }
        Print(string.format("Saved %d camera/gamepad settings as \"%s\". Type /reload, then send the file WTF\\Account\\<account>\\SavedVariables\\%s.lua.", n, label, ADDON))
    elseif cmd == "npcs" then
        local anyOn = false
        for _, k in ipairs(FRIENDLY_FOCUS_KEYS) do if db[k] ~= false then anyOn = true end end
        for _, k in ipairs(FRIENDLY_FOCUS_KEYS) do db[k] = not anyOn end
        Print(anyOn and "Friendly targets (NPCs, players, group, pets, critters) are no longer focused."
            or "Friendly targets (NPCs, players, group, pets, critters) are focused again.")
        Refresh()
    elseif cmd == "combat" then
        db.combatOnly = not db.combatOnly
        Print("Combat-only enemy focus " .. (db.combatOnly and "on." or "off."))
        Refresh()
    elseif cmd == "camtilt" and n then
        db.profiles.world.tilt = math.max(-20, math.min(20, n)); Refresh()
    elseif cmd == "fov" and n then
        db.profiles.world.fov = math.max(50, math.min(90, n)); Refresh()
    elseif cmd == "profile" then
        local parts = {}
        for _, name in ipairs(PROFILES) do
            local pr = db.profiles[name]
            parts[#parts + 1] = string.format("%s%s (fov %.0f, shoulder %.1f, zoom %.1f)", PROFILE_NAMES[name],
                name == "world" and "" or (pr.on and " [on]" or " [off]"), pr.fov, pr.shoulder, pr.zoom)
        end
        Print("active profile: " .. PROFILE_NAMES[activeProfile])
        for _, line in ipairs(parts) do print("  " .. line) end
        print(string.format("  field of view now: set %s, game reports %s", string.format("%.1f", shown.fov or 0), tostring(getCVar(CV.fov))))
    elseif cmd == "shoulder" and n then
        db.profiles.world.shoulder = math.max(-10, math.min(10, n)); Refresh()
    elseif cmd == "shouldercomp" and not n then
        local pr = db.profiles[editProfile]
        pr.shComp = not pr.shComp; ApplyShoulder(true)
        Print(string.format("Shoulder zoom compensation for %s: %s.", PROFILE_NAMES[editProfile], pr.shComp and "on" or "off"))
    elseif cmd == "zoom" and n then
        db.profiles.world.zoom = math.max(1, math.min(3.5, n)); Refresh()
    elseif cmd == "head" and n then
        db.profiles.world.headMove = math.max(0, math.min(1, n)); Refresh()
    elseif cmd == "smooth" and n then
        db.smooth = math.max(0.2, math.min(1, n)); Refresh()
    elseif cmd == "tilt" then
        db.terrainTilt = not db.terrainTilt; Refresh()
    elseif cmd == "bob" then
        db.bobbing = not db.bobbing; Refresh()
    elseif cmd == "follow" then
        if rest == "off" or rest == "" then
            db.followStyle = nil
            Print(L["Camera auto-follow setting left alone (your original value is restored on /acam off)."])
        elseif n then
            db.followStyle = n; Refresh()
            Print("cameraSmoothStyle set to " .. n .. ". Try values and see which follows you the way you like.")
        end
    elseif cmd == "status" then
        print("  " .. TenKsUltimateARPGCamera_EntryReport())
        for label, name in pairs(CV) do
            print(string.format("  %-14s %-46s %s", label, name,
                Has(name) and ("|cff33ff33ok|r (" .. tostring(getCVar(name)) .. ")") or "|cffff5555not available|r"))
        end
        print(string.format("  target nameplate: %s", TargetPlate() and "yes" or "no (target one, with nameplates on)"))
    else
        Help()
        return
    end
    if panel and panel:IsShown() then
        for _, refresh in ipairs(controls) do refresh() end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        TenKsUltimateARPGCameraDB = TenKsUltimateARPGCameraDB or {}
        db = TenKsUltimateARPGCameraDB
        for k, v in pairs(DEFAULTS) do
            if db[k] == nil then db[k] = v end
        end
        ApplyWarningSuppression()
        -- Undo the reverted "keep character in place" update: give back the
        -- personal resource display setting it changed, and drop its data.
        if db.orig and db.orig.nameplateShowSelf ~= nil then
            pcall(setCVar, "nameplateShowSelf", db.orig.nameplateShowSelf)
            db.orig.nameplateShowSelf = nil
        end
        db.holdPosition, db.holdGain = nil, nil
        db.aimY = nil -- removed setting
        if db.orig and db.orig.test_cameraDynamicPitchBaseFovPad ~= nil then -- undo the removed vertical shift
            pcall(setCVar, "test_cameraDynamicPitchBaseFovPad", db.orig.test_cameraDynamicPitchBaseFovPad)
            db.orig.test_cameraDynamicPitchBaseFovPad = nil
        end
        for _, pr in pairs(db.profiles or {}) do pr.vshift = nil end
        if db.orig and db.orig.cameraDistanceMax ~= nil then -- undo the removed zoom workaround
            pcall(setCVar, "cameraDistanceMax", db.orig.cameraDistanceMax)
            db.orig.cameraDistanceMax = nil
        end
        db.pitchZoomBoost = nil -- removed setting
        if MoveViewUpStart then -- make sure no leftover camera nudge is running
            pcall(MoveViewUpStart, 0); pcall(MoveViewDownStart, 0)
        end
        db.orbit, db.maxSpeed, db.yawSign, db.pitchSign = nil, nil, nil, nil -- orbit focus was removed
        -- leftovers from the first version
        db.interact, db.interactYaw, db.interactPitch = nil, nil, nil

        -- Situation profiles. The world profile starts from the plain settings
        -- (so older saves keep their values); combat and indoors start off.
        local freshInstall = db.profiles == nil
        db.profiles = db.profiles or {}
        local P = db.profiles
        local seeds = {
            world   = { tilt = 0, fov = 85, shoulder = db.shoulder, zoom = db.zoom, headMove = db.headMove, yaw = db.yaw, pitch = db.pitch },
            combat  = { on = false, tilt = 0, fov = 80, shoulder = db.shoulder, zoom = math.min(db.zoom, 3.0), headMove = 1.0, yaw = db.yaw, pitch = db.pitch },
            indoors = { on = false, tilt = 0, fov = 85, shoulder = 1, zoom = 2.0, headMove = db.headMove, yaw = db.yaw, pitch = db.pitch },
        }
        for _, name in ipairs(PROFILES) do -- the newer situations start as copies of the exploration values, switched off
            if not seeds[name] then
                seeds[name] = { on = false, tilt = 0, fov = 85, shoulder = db.shoulder, zoom = db.zoom, headMove = db.headMove, yaw = db.yaw, pitch = db.pitch }
            end
        end
        for name, seed in pairs(seeds) do
            P[name] = P[name] or {}
            for k, v in pairs(seed) do
                if P[name][k] == nil then P[name][k] = v end
            end
        end

        for _, name in ipairs(PROFILES) do
            if P[name] then
                if P[name].zoomRemember == nil then P[name].zoomRemember = not P[name].zoomSet end
                if P[name].zoomSet == nil then P[name].zoomSet = false end
                if P[name].zoomDist == nil then P[name].zoomDist = 10 end
            end
            if P[name] and P[name].blend == nil then P[name].blend = db.blendTime or 1.2 end
            if P[name] then -- vignette: off for saves that predate it
                if P[name].vigAlpha == nil then P[name].vigAlpha = 0 end
                if P[name].vigRange == nil then P[name].vigRange = 0.3 end
                if P[name].vigCurve == nil then P[name].vigCurve = 2 end
                if P[name].lbSize == nil then P[name].lbSize = 0 end
                if P[name].fovSpeed == nil then P[name].fovSpeed = 0 end
                if P[name].crowdFov == nil then P[name].crowdFov = 0 end
                if P[name].headStand == nil then P[name].headStand = 0.3 end
                if P[name].headMoving == nil then P[name].headMoving = 0.5 end
                if P[name].headReact == nil then P[name].headReact = 10 end
                if P[name].zoomKind == nil then P[name].zoomKind = 0 end
                if P[name].zoomMin == nil then P[name].zoomMin = 5 end
                if P[name].zoomMax == nil then P[name].zoomMax = 20 end
            end
        end
        -- shoulder compensation is a curve per situation (the old single strength becomes a curve)
        do
            local on, k = db.shoulderCompOn ~= false, tonumber(db.shoulderComp) or 0
            for _, name in ipairs(PROFILES) do
                local pr = P[name]
                if pr then
                    if pr.shComp == nil then
                        pr.shComp = on and k ~= 0
                        pr.shCurve = (pr.shComp and Detect.comp.fromPower(k)) or Detect.comp.FLAT
                    elseif not Detect.comp.valid(pr.shCurve) then
                        pr.shCurve = Detect.comp.FLAT
                    end
                end
            end
            db.shoulderCompOn, db.shoulderComp = nil, nil
            if not Detect.comp.valid(db.shCompCurve) then db.shCompCurve = Detect.comp.FLAT end
            db.shCompShare = db.shCompShare == true
        end
        if freshInstall then
            WriteSnapshot(FactorySnapshot()) -- brand-new installs start from the factory preset
            db.situationsV2 = true
            db.welcomePending = true
        elseif not db.situationsV2 then
            -- first load with the newer situations (swimming, city, talk, dungeon/raid):
            -- give them the values of the preset in use (or the Default), without touching the older situations
            db.situationsV2 = true
            local base = db.activePreset and IsBuiltin(db.activePreset) and BuiltinSnapshot(db.activePreset) or FactorySnapshot()
            local fresh = {}
            for k, v in pairs(base) do
                local prof = k:match("^profiles%.(%a+)%.")
                if prof == "swimming" or prof == "city" or prof == "npc" or prof == "instance" then
                    fresh[k] = v
                end
            end
            WriteSnapshot(fresh)
        end
        if db.profiles then db.profiles.controller = nil end -- the Controller situation became the Controller preset
        db.fxFriendScale = db.fxFriendScale or DEFAULTS.fxFriendScale
        if db.focusAll ~= nil then -- the old "Focus ALL targets" tick became one tick per kind of target
            if db.focusAll == false then
                for _, k in ipairs(FRIENDLY_FOCUS_KEYS) do db[k] = false end
            end
            db.focusAll = nil
        end
        if not freshInstall and db.lastVersion ~= Meta.version then db.updateNote = true end
        db.lastVersion = Meta.version
        if not db.reticleV1 then -- new default look: the layered reticle
            db.reticleV1 = true
            db.fxStyle = "reticle"
        end
        if not db.haloV1 then -- 1.4: the health halo becomes the default look
            db.haloV1 = true
            db.fxStyle = "halo"
        end
        db.pulseOn, db.pulseStrength, db.pulseZoom, db.pulseVignette, db.pulseV2 = nil, nil, nil, nil, nil
        for _, name in ipairs(PROFILES) do
            P[name].fov = math.max(50, math.min(90, P[name].fov))
        end

        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("PLAYER_TARGET_CHANGED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        -- Only the target's flags matter, so ask the game to send just those
        -- (UNIT_FLAGS otherwise fires for every unit around you). Nameplate
        -- events aren't used at all: the targeting frame polls for its own.
        if self.RegisterUnitEvent then
            self:RegisterUnitEvent("UNIT_FLAGS", "target")
        else
            self:RegisterEvent("UNIT_FLAGS")
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if TenKsUltimateARPGCamera_RegisterEntries then TenKsUltimateARPGCamera_RegisterEntries() end
        ApplyWarningSuppression()
        ForgetWrites()
        wipe(hasCache)
        wipe(lastSet)
        Refresh()
        if db.welcomePending then
            db.welcomePending = nil
            if C_Timer and C_Timer.After then C_Timer.After(3, TenKsUltimateARPGCamera_ShowWelcome)
            else TenKsUltimateARPGCamera_ShowWelcome() end
        elseif db.updateNote then
            db.updateNote = nil
            Print("Updated to v" .. Meta.version .. ". Type /acam new to see what changed.")
        end
        local any = false
        for _, name in pairs(CV) do if Has(name) then any = true end end
        if not any then
            Print(L["This client doesn't expose the camera settings the addon needs. Try /acam status."])
        end
    elseif event == "UNIT_FLAGS" then
        if arg1 == "target" then Refresh() end
    else
        Refresh()
    end
end)

---------------------------------------------------------------------------
-- Addon Compartment and the AddOns options page
---------------------------------------------------------------------------

-- The small addon menu next to the minimap lists this addon (the .toc names
-- these functions). Left click opens the settings window; right click turns
-- the camera on or off.
function TenKsUltimateARPGCamera_OnAddonCompartmentClick(_, button)
    if not db then return end
    if button == "RightButton" then
        SetAddonEnabled(not db.enabled)
        Print(db.enabled and "Enabled." or "Disabled; original camera settings restored.")
    else
        TogglePanel()
    end
end

function TenKsUltimateARPGCamera_OnAddonCompartmentEnter(_, frame)
    if not (GameTooltip and frame) then return end
    GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
    GameTooltip:SetText(L["10k's Ultimate ARPG Camera"], 1, 0.82, 0)
    GameTooltip:AddLine(L["Left click: open the settings window"], 1, 1, 1)
    GameTooltip:AddLine(L["Right click: turn the camera on / off"], 1, 1, 1)
    GameTooltip:Show()
end

function TenKsUltimateARPGCamera_OnAddonCompartmentLeave()
    if GameTooltip then GameTooltip:Hide() end
end

-- An entry under Esc > Options > AddOns with a button that opens the same window,
-- and (if the toc fields weren't enough) a manual Compartment registration.
-- Done once the game is up; what happened is kept for /acam status.
local entryReport = "not run yet"
local entriesDone = false
function TenKsUltimateARPGCamera_RegisterEntries()
    if entriesDone then return end
    entriesDone = true
    local report = {}

    -- Addon Compartment
    local comp = _G.AddonCompartmentFrame
    if not comp then
        report[#report + 1] = "Addon Compartment: this client has none"
    elseif comp.RegisterAddon then
        local present = false
        for _, e in ipairs(comp.registeredAddons or {}) do
            if e.text == "10k's Ultimate ARPG Camera" or e.func == TenKsUltimateARPGCamera_OnAddonCompartmentClick then present = true end
        end
        if present then
            report[#report + 1] = "Addon Compartment: registered from the .toc"
        else
            local ok, err = pcall(comp.RegisterAddon, comp, {
                text = "10k's Ultimate ARPG Camera",
                icon = "Interface\\Icons\\INV_Misc_Gear_01",
                notCheckable = true,
                registerForAnyClick = true,
                func = function(_, _, _, _, mouseButton) TenKsUltimateARPGCamera_OnAddonCompartmentClick(nil, mouseButton) end,
                funcOnEnter = function(frame) TenKsUltimateARPGCamera_OnAddonCompartmentEnter(nil, frame) end,
                funcOnLeave = TenKsUltimateARPGCamera_OnAddonCompartmentLeave,
            })
            report[#report + 1] = ok and "Addon Compartment: registered by the addon" or ("Addon Compartment: failed (" .. tostring(err) .. ")")
        end
    else
        report[#report + 1] = "Addon Compartment: frame has no RegisterAddon"
    end

    -- AddOns options page
    local ok, err = pcall(function()
        local page = CreateFrame("Frame")
        page.name = "10k's Ultimate ARPG Camera"
        local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText(L["10k's Ultimate ARPG Camera"])
        local text = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
        text:SetWidth(520)
        text:SetJustifyH("LEFT")
        text:SetText(L["An action-RPG style camera: situations (exploration, combat, indoors, swimming, city, talk, dungeon / raid), a targeting frame, a vignette, letterbox bars and shareable presets.\n\nYou can also type /acam at any time."])
        local btn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        btn:SetSize(200, 26)
        btn:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -16)
        btn:SetText(L["Open the settings window"])
        btn:SetScript("OnClick", function()
            if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then pcall(HideUIPanel, SettingsPanel) end
            if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() and HideUIPanel then pcall(HideUIPanel, InterfaceOptionsFrame) end
            if not panel then BuildPanel() end
            panel:Show()
        end)
        if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
            local category = Settings.RegisterCanvasLayoutCategory(page, page.name)
            Settings.RegisterAddOnCategory(category)
            return "Settings > AddOns page: registered"
        elseif InterfaceOptions_AddCategory then
            InterfaceOptions_AddCategory(page)
            return "Interface Options > AddOns page: registered"
        end
        error("no Settings or InterfaceOptions API")
    end)
    report[#report + 1] = ok and err or ("AddOns page: failed (" .. tostring(err) .. ")")
    entryReport = table.concat(report, "; ")
    if entryReport:find("failed", 1, true) or entryReport:find("none", 1, true) then
        Print(entryReport .. " (use /acam to open the window)")
    end
end

function TenKsUltimateARPGCamera_EntryReport() return entryReport end
