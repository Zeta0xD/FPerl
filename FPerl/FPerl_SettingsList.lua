-- The settings list: one entry per option of the panel's pages (General, Player, Pet, Target, Focus, Party, Raid), in page
-- and section order. Data only (the Player to Raid pages are in FPerl_SettingsListPages.lua): loads under plain lua5.1, calls no API, makes no frame. Format:
-- Paths are relative to FPerl.layout. A map entry's keys are relative to its base and may be dotted; a stored
-- false and an absent key read as the same value. `percent` marks a slider whose stored fraction shows as a
-- percentage; `default` is the value a slider shows while its key is absent from the profile.
-- General's shared sections (Shown on frames, Auras) start with an entry of type `frames` (the "Apply to" picker: a
-- bitmask over FPerl.SettingsFrames, session state, not in FPerl.layout). A shared control has `each = {frame label =
-- per-frame entry id}` in place of path/base/map (check, slider or dropdown, the type of its per-frame entries). Its
-- setter writes the value through each ticked frame's own entry, so a frame's store, map and appliers are that entry's;
-- its getter shows the first ticked frame's value. A shared dropdown lists the choices of its frames by label (`options`,
-- derived at the end of FPerl_SettingsListPages.lua); `alias = {frame label = {shared label = frame label}}` renames a choice for a
-- frame whose entry words it differently. A frame whose entry has no choice for the label is left alone. `apply` and
-- `throttle` of a shared control are derived from its frames' entries. Entries of these sections without `each` are
-- not per frame: the key they write is read from the profile's top level for every frame.
-- A check may take `with = {path, ...}`: more keys that get the same stored value as `path`.
-- `keys = {path, ...}` names the saved keys of a row with get/set (no path or map), so a layout switch can tell which
-- appliers a changed key needs (FPerl.ReapplyLayout, FPerl_Globals.lua). A saved key no row names runs every applier.
-- Entry fields beyond the format: `get`/`set` (functions) read and write a value outside FPerl.layout:
-- get() returns it, set(value) takes the control's value; `options` as a function returns
-- {{value, label}, ...} when the dropdown opens (the setting then holds that value, not an index);
-- `also = {[path] = value}` writes more keys when the value is set;
-- `confirm` on a button is the text of a confirmation popup shown before `func` runs; `showif` (a function) hides the control while the function returns false; `nocombat` on a button makes it refuse in combat (a get/set check refuses in its own setter).
-- A map entry is {label, writes, reads}. Choosing the label stores `writes` ({key = value}). The stored profile
-- reads as the entry when it matches `reads`: {key = accepted}, where accepted is a value or a list of values,
-- and a key left out does not matter. Without `reads`, `writes` is also what is read. The first entry that
-- matches wins, so the state of a profile the old window could produce reads as an entry, not as nothing.

local list = {}
local R = {list = list} -- shared with FPerl_SettingsListPages.lua: row helpers, constants and the page and section being added
FPerl.SettingsRow = R

-- Appliers per entry (names: FPerl.Appliers in FPerl_Init.lua). An entry not listed here applies with "full".
-- Entry field `throttle` is derived in add(). {} = the setting is read when it is used (a range tick, a tooltip, an event), nothing to refresh.
local UF = {"party", "partypet", "player", "playerpet", "raid", "raidpets", "target", "targettarget"}
local function join(...)
	local out = {}
	for _, t in ipairs({...}) do
		for _, n in ipairs(t) do out[#out + 1] = n end
	end
	return out
end
local PAINT = join(UF) -- every module that repaints its bars and names on a display update
local BARS = {"party", "partypet", "player", "playerpet", "raid", "raidpets", "target"} -- modules with absorb and heal prediction bars
local RANGE = {"party", "partypet", "raid", "raidpets", "target"} -- modules that re-run the range fade on a display update
local BACKDROP = {"skin", "party", "partypet", "player", "playerpet", "raid", "raidhelper", "target"}
local APPLY = {
	["general.frames.pettarget"] = {"targettarget", "playerpet"},
	["general.frames.targettarget"] = {"targettarget"},
	["general.frames.targettargettarget"] = {"targettarget"},
	["general.frames.focustarget"] = {"targettarget"},
	["general.frames.focus"] = {"target"},
	["general.frames.party"] = {"party"},
	["general.frames.partypet"] = {"partypet"},
	["general.frames.raid"] = {"raid"},
	["general.frames.raidpet"] = {"raidpets", "raid"},
	["general.frames.snap"] = {},
	["general.look.bartexture"] = {"bartextures"},
	["general.look.bgbartex"] = {"bartextures"},
	["general.look.fat"] = {"party", "partypet", "player", "playerpet", "target", "targettarget"},
	["general.look.inverse"] = PAINT,
	["general.look.fading"] = {},
	["general.look.fadetime"] = {},
	["general.look.transparency"] = {"framealpha", "party", "partypet", "player", "raid", "raidpets", "target"},
	["general.look.texttransparency"] = {"texttransparency", "player", "playerpet", "target", "raidhelper"},
	["general.look.background"] = BACKDROP,
	["general.look.background.alpha"] = BACKDROP,
	["general.look.border"] = BACKDROP,
	["general.look.border.alpha"] = BACKDROP,
	["general.look.gradient"] = BACKDROP,
	["general.look.gradientstart"] = BACKDROP,
	["general.look.gradientstart.alpha"] = BACKDROP,
	["general.look.gradientend"] = BACKDROP,
	["general.look.gradientend.alpha"] = BACKDROP,
	["general.colours.health"] = join({"barcolours"}, PAINT),
	["general.colours.healthempty"] = join({"barcolours"}, PAINT),
	["general.colours.healthfull"] = join({"barcolours"}, PAINT),
	["general.colours.brightness"] = join({"barcolours"}, PAINT),
	["general.colours.classbars"] = join(PAINT, {"raidhelper"}),
	["general.colours.classnames"] = join(PAINT, {"raidhelper"}),
	["general.colours.friend"] = PAINT,
	["general.colours.neutral"] = PAINT,
	["general.colours.unfriendly"] = PAINT,
	["general.colours.enemy"] = PAINT,
	["general.colours.none"] = PAINT,
	["general.colours.tapped"] = PAINT,
	["general.colours.mana"] = PAINT,
	["general.colours.rage"] = PAINT,
	["general.colours.energy"] = PAINT,
	["general.colours.focus"] = PAINT,
	["general.colours.absorb"] = BARS,
	["general.colours.absorb.alpha"] = BARS,
	["general.colours.healprediction"] = BARS,
	["general.colours.healprediction.alpha"] = BARS,
	["general.highlights.enable"] = {"highlight"},
	["general.highlights.debuff"] = join({"skin"}, BARS, {"highlight"}),
	["general.highlights.curable"] = BARS,
	["general.highlights.aggro"] = {"highlight"},
	["general.highlights.target"] = {"highlighttex"},
	["general.highlights.heal"] = {"highlight"},
	["general.highlights.hots"] = {"highlight"},
	["general.highlights.shields"] = {"highlight"},
	["general.highlights.hotcount"] = {"highlight"},
	["general.highlights.sparkles"] = {"highlight"},
	["general.range.enable"] = join(RANGE, {"raidsizes"}),
	["general.range.raidonly"] = RANGE,
	["general.tooltips.unit"] = {},
	["general.tooltips.modifier"] = {},
	["general.tooltips.hideincombat"] = {},
	["general.tooltips.fading"] = {},
	["general.lowhealth.enable"] = {"player"},
	["general.misc.minimap"] = {"minimap"},
	["general.misc.oldroleicons"] = {"party", "player", "raid"},
	["player.shown.castbar"] = {"arcanebar"},
	["player.shown.casttime"] = {"arcanebar"},
	["player.auras.buffs"] = {"playerbuffs"},
	["player.auras.debuffs"] = {"playerbuffs"},
	["player.auras.buffsize"] = {"playerbuffs"},
	["player.auras.debuffsize"] = {"playerbuffs"},
	["player.auras.wrap"] = {"playerbuffs"},
	["player.auras.bigbuffs"] = {"playerbuffs"},
	["player.player.precast"] = {},
	["player.player.originalcastbar"] = {"arcanebar"},
	["player.player.hideblizzbuffs"] = {"playerbuffs"},
}
for _, part in ipairs({"main", "name", "bars"}) do
	for _, k in ipairs({"enable", "health", "debuff"}) do APPLY["general.range." .. part .. "." .. k] = RANGE end
	-- the range polls (0.2 s) read the sliders; running RANGE on every drag step lagged the game
	for _, k in ipairs({"fade", "marker"}) do APPLY["general.range." .. part .. "." .. k] = {} end
end
for _, k in ipairs({"scale", "width"}) do APPLY["player.size." .. k] = {"player"} end
for _, k in ipairs({"portrait", "level", "classicon", "pvp", "hit", "healthtext", "absorbs", "healprediction"}) do APPLY["player.shown." .. k] = {"player"} end
for _, k in ipairs({"xp", "xpdeficit", "rep", "partynumber", "withname", "extend", "nodruidbar"}) do APPLY["player.player." .. k] = {"player"} end
for _, k in ipairs({"scale", "width"}) do APPLY["pet.size." .. k] = {"playerpet"} end
-- the pet frame's own changer (Set_Bits) lays the frame out and redraws it; hit indicators and threat are read when
-- the next combat or threat event arrives, and the old controls refreshed nothing
for _, k in ipairs({"portrait", "level", "healthtext", "absorbs", "healprediction"}) do APPLY["pet.shown." .. k] = {"playerpet"} end
APPLY["pet.shown.hit"] = {}
APPLY["pet.shown.castbar"] = {"arcanebar"} -- the cast bar changer reads each registered frame's castBar.enable
for _, k in ipairs({"buffs", "debuffs", "buffsize", "debuffsize", "wrap", "rows", "castable", "curable", "bigbuffs", "bigdebuffs"}) do APPLY["pet.auras." .. k] = {"playerpet"} end
for _, k in ipairs({"name", "happiness", "onlysad", "flashsad", "extend"}) do APPLY["pet.pet." .. k] = {"playerpet"} end
APPLY["pet.pet.threat"] = {}
-- the pet's target is a frame of the target-of-target module; that module's changer covers all four of its frames
APPLY["pet.pettarget.enable"] = {"targettarget", "playerpet"}
for _, k in ipairs({"scale", "mana", "buffs", "bigbuffs", "bigdebuffs", "level", "healthtext"}) do APPLY["pet.pettarget." .. k] = {"targettarget"} end

-- Party page. Readers of each key: the party module (Set_Bits1, UpdateDisplay), plus the party pet module for what it reads
-- from party.* (flip, showPlayer, absorbs, healprediction, healerMode), the arcane bar for castBar.enable, the group
-- visibility decision (run by the party changer) for showPlayer, inRaid and smallRaid, the raid changer and raid pet
-- changer for smallRaid (group titles) and raid.inParty (header attributes).
local PARTY = {"party"}
local PARTYPETS = {"party", "partypet"}
for _, k in ipairs({"scale", "width"}) do APPLY["party.size." .. k] = PARTY end
for _, k in ipairs({"portrait", "level", "classicon", "pvp", "hit"}) do APPLY["party.shown." .. k] = PARTY end
for _, k in ipairs({"healthtext", "absorbs", "healprediction"}) do APPLY["party.shown." .. k] = PARTYPETS end
APPLY["party.shown.castbar"] = {"arcanebar"}
for _, k in ipairs({"buffs", "debuffs", "buffsize", "debuffsize", "wrap", "castable", "curable", "onlymine", "big", "rows", "halfsize"}) do APPLY["party.auras." .. k] = PARTY end
for _, k in ipairs({"names", "targets", "targetsize", "targetlarge", "range", "threat"}) do APPLY["party.party." .. k] = PARTY end
APPLY["party.party.showplayer"] = PARTYPETS
APPLY["party.layout.anchor"] = PARTY
APPLY["party.layout.spacing"] = PARTY
APPLY["party.layout.flip"] = PARTYPETS
for _, k in ipairs({"scale", "name", "level", "mana", "buffs", "buffsize", "debuffsize"}) do APPLY["party.pets." .. k] = {"partypet"} end
APPLY["party.pets.enable"] = {"partypet"}
APPLY["party.visibility.inparty"] = {"raidheaders", "raid", "raidpets"}
APPLY["party.visibility.insmallraid"] = {"party", "raid"}
-- Raid. Readers: the "raid" changer (FPerl.Raid.RaidTitles, FPerl.Raid.SetBits with the group visibility, scale, width and power bars,
-- FPerl.Raid.UpdateDisplayAll for texts, icons and auras), "raidheaders" (FPerl.Raid.ChangeAttributes: group filter, sort, anchor, spacing)
-- and "raidpets" (FPerl.RaidPets.OptionActions: reads raid.absorbs, healprediction, mana, anchor, spacing, scale, titles).
local RAID, RAIDPETS = {"raid"}, {"raid", "raidpets"}
local RAIDHEADERS = {"raidheaders", "raid"}
APPLY["raid.size.scale"] = RAIDPETS
APPLY["raid.size.width"] = {"raidwidth", "raid"}
for _, k in ipairs({"absorbs", "healprediction", "mana"}) do APPLY["raid.shown." .. k] = RAIDPETS end
for _, k in ipairs({"healthtext", "role", "manapercent", "precision", "manaprecision"}) do APPLY["raid.shown." .. k] = RAID end
for _, k in ipairs({"show", "castable", "text"}) do APPLY["raid.auras." .. k] = RAID end
APPLY["raid.raid.enable"] = RAID
APPLY["raid.raid.titles"] = RAIDPETS
APPLY["raid.raid.notinbg"] = RAID
for i = 1, 8 do APPLY["raid.groups." .. i] = RAIDHEADERS end
APPLY["raid.groups.sort"] = {"raidheaders", "bartextures", "raid"} -- Class shows headers 10-13, whose new buttons need the bar texture
APPLY["raid.groups.alpha"] = RAIDHEADERS
APPLY["raid.layout.anchor"] = join(RAIDHEADERS, {"raidpets"})
APPLY["raid.layout.gap"] = {"raidgap"}
APPLY["raid.layout.spacing"] = join(RAIDHEADERS, {"raidpets"})
APPLY["raid.pets.enable"] = {"raidpets", "raid"}
APPLY["raid.pets.align"] = {"raidpets"}
APPLY["raid.helper.enable"] = {}
APPLY["raid.helper.sort"] = {}
APPLY["raid.helper.visible"] = {}
for _, k in ipairs({"enable", "alpha", "blend"}) do APPLY["raid.custom." .. k] = {"custom"} end
APPLY["raid.custom.enable"] = {"custom", "raid"}
APPLY["raid.visibility.party"] = APPLY["party.visibility.inparty"]
APPLY["raid.visibility.onegroup"] = APPLY["party.visibility.insmallraid"]
APPLY["general.shown.afk"] = {"party", "player", "target", "targettarget", "raid"}
APPLY["general.shown.readycheck"] = {"party", "raid"} -- the modules that call FPerl.UnitUpdateReadyState
local AURAS = {"playerbuffs", "playerpet", "target", "targettarget", "party", "partypet", "raid"} -- modules that style aura buttons
for _, k in ipairs({"cooldown", "cooldownany", "countdown", "countdownany", "blizzardnumbers"}) do APPLY["general.auras." .. k] = AURAS end

local function throttleOf(apply)
	local has = {}
	for _, n in ipairs(apply) do has[n] = true end
	return (has.party and (has.raid or has.raidpets or has.skin)) or has.full or nil
end
local function add(kind, id, label, tip, e)
	e.id, e.page, e.section, e.type, e.label, e.tip = id, R.page, R.section, kind, label, tip
	e.apply = e.apply or APPLY[id] or {"full"}
	-- a slider or colour whose appliers can take a frame (measured 12-16 ms): the party changer (5.6 ms) with
	-- raid, raidpets or skin; the panel runs them at most every 0.1 s while the control moves
	if (kind == "slider" or kind == "colour") and not e.throttle then e.throttle = throttleOf(e.apply) end
	list[#list + 1] = e
end
-- an unticked box was stored false, a ticked one 1
local function check(id, label, tip, e)
	e.on = e.on == nil and 1 or e.on
	if e.off == nil then e.off = false end
	add("check", id, label, tip, e)
end
local function slider(id, label, tip, e) add("slider", id, label, tip, e) end
local function dropdown(id, label, tip, e) add("dropdown", id, label, tip, e) end
local function colour(id, label, tip, e) add("colour", id, label, tip, e) end
local function button(id, label, tip, e)
	e.apply = e.apply or {}
	add("button", id, label, tip, e)
end

-- Party and Raid Visibility, "In a one-group raid use". FPerl.GroupVisibilityUpdate shows the party frames in a raid when
-- the raid has one group and smallRaid is on, or when inRaid is on and smallRaid off (then in every raid).
local VIS_ONEGROUP = {
	{"Party frames", {smallRaid = 1}},
	{"Raid frames", {smallRaid = false, inRaid = false}},
	{"Party and raid frames (every raid)", {smallRaid = false, inRaid = 1}},
}

-- Healer types (healerMode.type, set by the old window's radios; read by FPerl.HealthUpdate): 0 Deficit = the missing health
-- alone, 1 Deficit/Max = -missing/max, 2 Cur/Max/Deficit = current/max with the missing health in place of the percent.
-- The healer entries read on the switch and the type alone, so a profile the old window left with any Percent or Current
-- tick reads as the entry of its type.
local function healer(type) return {["healerMode.enable"] = 1, ["healerMode.type"] = type} end
local function healerWrites(type) return {percent = 1, values = 1, ["healerMode.enable"] = 1, ["healerMode.type"] = type} end
local HEALTHTEXT = {
	{"Percent", {percent = 1, values = false, ["healerMode.enable"] = false}},
	{"Current", {percent = false, values = 1, ["healerMode.enable"] = false}},
	{"Current and percent", {percent = 1, values = 1, ["healerMode.enable"] = false}},
	{"Missing (healer)", healerWrites(0), healer(0)},
	{"Missing and maximum", healerWrites(1), healer(1)},
	{"Current, maximum and missing", healerWrites(2), healer(2)},
	{"None", {percent = false, values = false, ["healerMode.enable"] = false}, {percent = false, values = false}},
}

-- The frames of General's "Apply to" pickers, in the order of the picker. Shared controls name the frames they reach
-- by these labels; the id prefixes are those of the frames' own entries in their Shown and Auras sections.
local FRAMES = {"Player", "Pet", "Pet's target", "Target", "Target of target", "Target of target of target", "Focus", "Focus target", "Party", "Party pets", "Raid"}
FPerl.SettingsFrames = FRAMES
local PLAYER, PET, PETTARGET, TARGET, TOT, TOTT, FOCUS, FOCUSTARGET, PARTY, PARTYPETS, RAID = unpack(FRAMES)
local SHOWN_ID = {[PLAYER] = "player.shown.", [PET] = "pet.shown.", [PETTARGET] = "pet.pettarget.", [TARGET] = "target.shown.", [TOT] = "target.tot.",
	[TOTT] = "target.tott.", [FOCUS] = "focus.shown.", [FOCUSTARGET] = "focus.focustarget.", [PARTY] = "party.shown.", [PARTYPETS] = "party.pets.", [RAID] = "raid.shown."}
local AURA_ID = {[PLAYER] = "player.auras.", [PET] = "pet.auras.", [PETTARGET] = "pet.pettarget.", [TARGET] = "target.auras.", [TOT] = "target.tot.",
	[TOTT] = "target.tott.", [FOCUS] = "focus.auras.", [FOCUSTARGET] = "focus.focustarget.", [PARTY] = "party.auras.", [PARTYPETS] = "party.pets.", [RAID] = "raid.auras."}
-- {frame label = prefix .. suffix} for the frames listed; `more` adds frames whose entry has another suffix
local function of(prefix, suffix, frames, more)
	local t = {}
	for _, f in ipairs(frames) do t[f] = prefix[f] .. suffix end
	for f, id in pairs(more or {}) do t[f] = id end
	return t
end
local MAIN = {PLAYER, TARGET, FOCUS, PARTY} -- the frames with a class icon and a PvP flag
local function framesPicker(id, label, tip) add("frames", id, label, tip, {apply = {}}) end
local function shared(kind, id, label, tip, e)
	e.apply = {} -- derived at the end of FPerl_SettingsListPages.lua
	add(kind, id, label, tip, e)
end

-- Aura layout controls: sides, order, icons per line, fill direction, offsets and Reset for
-- the frame whose entries are `pre` .. suffix, profile table k, appliers ap. The same suffixes feed General's shared controls.
local SIDES = {{"TOP", "Top"}, {"BOTTOM", "Bottom"}, {"LEFT", "Left"}, {"RIGHT", "Right"}}
local function auraLayout(pre, k, ap)
	for _, kind in ipairs({"buff", "debuff"}) do
		local K, key, Name = kind, kind .. "s", kind == "buff" and "Buff" or "Debuff"
		dropdown(pre .. K .. "side", Name .. " side", "The side of the frame the " .. K .. "s sit on.", {path = k .. "." .. key .. ".side", options = SIDES, apply = ap})
		slider(pre .. K .. "perline", Name .. " icons per line", "The most " .. K .. " icons in a line before it wraps. Applies while Wrap is on. Auto: as many as fit the frame width on Top and Bottom, one line on Left and Right.", {path = k .. "." .. key .. ".perLine", min = 0, max = 20, step = 1, zero = "Auto", apply = ap})
		check(pre .. K .. "reverse", Name .. " reverse fill", "Fill from the right (rows) or the bottom (columns).", {path = k .. "." .. key .. ".reverse", apply = ap})
	end
	dropdown(pre .. "order", "Order", "Which kind sits next to the frame when both share a side. By reaction puts debuffs next to the frame on a unit you can attack.", {
		path = k .. ".auraOrder", apply = ap,
		options = {{"buffs", "Buffs first"}, {"debuffs", "Debuffs first"}, {"reaction", "By reaction"}},
	})
	for _, kind in ipairs({"buff", "debuff"}) do
		for _, ax in ipairs({"x", "y"}) do
			slider(pre .. kind .. ax, (kind == "buff" and "Buff " or "Debuff ") .. string.upper(ax), "Move the " .. kind .. "s sideways (X) or up (Y), in pixels.", {path = k .. "." .. kind .. "s." .. ax, min = -300, max = 300, step = 1, apply = ap})
		end
	end
	button(pre .. "resetpos", "Reset position", "Set the buff and debuff offsets of this frame back to 0.", {func = FPerl.SettingsResetAuraPos, arg = k, apply = ap})
end

R.throttleOf, R.check, R.slider, R.dropdown, R.button = throttleOf, check, slider, dropdown, button
R.VIS_ONEGROUP, R.HEALTHTEXT, R.FRAMES, R.auraLayout = VIS_ONEGROUP, HEALTHTEXT, FRAMES, auraLayout

------------------------------------------------------------------------------------------------ General
R.page = "General"

R.section = "Frames"
button("general.frames.arrange", "Unlock frames and hide menu", "Closes this window, unlocks the frames and shows a small toolbar.", {func = FPerl.ArrangeMode, nocombat = true})
check("general.frames.player", "Player", "Show the player frame. Takes effect after a reload.", {path = "player.enable", apply = {}})
check("general.frames.pet", "Pet", "Show the pet frame. Takes effect after a reload.", {path = "pet.enable", apply = {}})
check("general.frames.pettarget", "Pet target", "Show the pet's target frame.", {path = "pettarget.enable"})
check("general.frames.target", "Target", "Show the target frame. Takes effect after a reload.", {path = "target.enable", apply = {}})
check("general.frames.targettarget", "Target of target", "Show the frame of your target's target.", {path = "targettarget.enable"})
check("general.frames.targettargettarget", "Target of target of target", "Show the frame of your target's target's target.", {path = "targettargettarget.enable"})
check("general.frames.focus", "Focus", "Show the focus frame.", {path = "focus.enable"})
check("general.frames.focustarget", "Focus target", "Show the frame of your focus's target.", {path = "focustarget.enable"})
check("general.frames.party", "Party", "Show the party frames.", {path = "party.enable"})
check("general.frames.partypet", "Party pets", "Show the party members' pet frames.", {path = "partypet.enable"})
check("general.frames.raid", "Raid", "Show the raid frames.", {get = FPerl.SettingsGetRaid, set = FPerl.SettingsSetRaid})
check("general.frames.raidpet", "Raid pets", "Show the raid members' pet frames.", {path = "raidpet.enable"})
button("general.frames.reload", "Reload UI", "Reload the interface. The Player, Pet and Target switches take effect after a reload.", {func = ReloadUI})
button("general.frames.grid", "Alignment grid", "Show or hide the alignment grid.", {func = FPerl.AlignmentGridToggle})
check("general.frames.unlock", "Unlock frames", "Show the move handles and the party placeholder frames so frames can be dragged. Not saved: frames are locked after a reload. Closing this window does not lock them.", {get = FPerl.SettingsGetUnlock, set = FPerl.SettingsSetUnlock, nocombat = true, apply = {}})
check("general.frames.snap", "Snap to grid", "Snap moved F-Perl frames to the visible grid.", {path = "alignmentSnapToGrid", on = true})

R.section = "Layouts"
dropdown("general.layouts.active", "Layout", "Switch to a layout: its settings and frame positions. Layouts belong to the account, not to a character.", {options = FPerl.SettingsLayoutList, get = FPerl.SettingsGetLayout, set = FPerl.SettingsSelectLayout, nocombat = true, apply = {}})
button("general.layouts.new", "New layout…", "Make a layout of the default settings and switch to it. Asks for a name.", {func = FPerl.SettingsNewLayout, nocombat = true})
button("general.layouts.copy", "Copy layout…", "Make a copy of the layout in use, positions included, and switch to it. Asks for a name.", {func = FPerl.SettingsCopyLayout, nocombat = true})
button("general.layouts.rename", "Rename layout…", "Rename the layout in use, for every character on it. Default cannot be renamed. Asks for a name.", {func = FPerl.SettingsRenameLayout, nocombat = true})
dropdown("general.layouts.delete", "Delete layout", "Delete a layout, after a confirmation. The layout in use and Default cannot be deleted.", {options = FPerl.SettingsDeleteList, set = FPerl.SettingsDeleteLayout, nocombat = true, apply = {}})
button("general.profiles.reset", "Reset to defaults", "Reset all options to their default values.", {func = FPerl.ResetDefaults, nocombat = true, confirm = "Reset layout {layout} to its defaults, settings and frame positions? Every character on this layout is reset, and the frames move at once."})

R.section = "Look"
dropdown("general.look.bartexture", "Bar texture", "The texture of all bars.", {
	base = "bar.texture",
	map = {
		{"Perl v2", {[1] = "Perl v2", [2] = "Interface\\AddOns\\FPerl\\Images\\FPerl_StatusBar"}},
		{"X-Perl 1", {[1] = "X-Perl 1", [2] = "Interface\\AddOns\\FPerl\\Images\\FPerl_StatusBar2"}},
		{"BantoBar", {[1] = "BantoBar", [2] = "Interface\\AddOns\\FPerl\\Images\\FPerl_StatusBar3"}},
		{"X-Perl 3", {[1] = "X-Perl 3", [2] = "Interface\\AddOns\\FPerl\\Images\\FPerl_StatusBar4"}},
		{"X-Perl 4", {[1] = "X-Perl 4", [2] = "Interface\\AddOns\\FPerl\\Images\\FPerl_StatusBar5"}},
		{"X-Perl 5", {[1] = "X-Perl 5", [2] = "Interface\\AddOns\\FPerl\\Images\\FPerl_StatusBar6"}},
		{"X-Perl 6", {[1] = "X-Perl 6", [2] = "Interface\\AddOns\\FPerl\\Images\\FPerl_StatusBar7"}},
		{"X-Perl 7", {[1] = "X-Perl 7", [2] = "Interface\\AddOns\\FPerl\\Images\\FPerl_StatusBar8"}},
		{"X-Perl 8", {[1] = "X-Perl 8", [2] = "Interface\\AddOns\\FPerl\\Images\\FPerl_StatusBar9"}},
		{"X-Perl 9", {[1] = "X-Perl 9", [2] = "Interface\\AddOns\\FPerl\\Images\\FPerl_StatusBar10"}},
	},
})
check("general.look.bgbartex", "Background bar textures", "Status bar backgrounds use the same texture as the foreground.", {path = "bar.background"})
check("general.look.fat", "Fat health bars", "Draw the health bars fat.", {path = "bar.fat"})
check("general.look.inverse", "Inverse bars", "Bars fill upwards from empty as units get damaged, instead of emptying from full.", {path = "bar.inverse"})
check("general.look.fading", "Fading bars", "Health and mana bars fade away the portion of lost health and mana.", {path = "bar.fading"})
slider("general.look.fadetime", "Fade time", "The speed of the fading bars.", {path = "bar.fadeTime", min = 0.2, max = 2, step = 0.1})
slider("general.look.transparency", "Frame transparency", "The transparency of the frames.", {path = "transparency.frame", min = 0, max = 1, step = 0.01, percent = true})
slider("general.look.texttransparency", "Text transparency", "The transparency of the text.", {path = "transparency.text", min = 0, max = 1, step = 0.01, percent = true})
colour("general.look.background", "Background colour", "The colour and transparency of all frame backgrounds.", {path = "colour.frame"})
slider("general.look.background.alpha", "Background opacity", "The opacity of all frame backgrounds.", {path = "colour.frame.a", min = 0, max = 1, step = 0.01, percent = true})
colour("general.look.border", "Border colour", "The colour and transparency of all frame borders.", {path = "colour.border"})
slider("general.look.border.alpha", "Border opacity", "The opacity of all frame borders.", {path = "colour.border.a", min = 0, max = 1, step = 0.01, percent = true})
dropdown("general.look.gradient", "Gradient", "Give all frames a gradient effect.", {
	base = "colour.gradient",
	map = {
		{"Off", {enable = false}},
		{"Vertical", {enable = 1, horizontal = false}},
		{"Horizontal", {enable = 1, horizontal = 1}},
	},
})
colour("general.look.gradientstart", "Gradient start", "The colour the gradient starts with.", {path = "colour.gradient.s"})
slider("general.look.gradientstart.alpha", "Gradient start opacity", "The opacity the gradient starts with.", {path = "colour.gradient.s.a", min = 0, max = 1, step = 0.01, percent = true})
colour("general.look.gradientend", "Gradient end", "The colour the gradient ends with.", {path = "colour.gradient.e"})
slider("general.look.gradientend.alpha", "Gradient end opacity", "The opacity the gradient ends with.", {path = "colour.gradient.e.a", min = 0, max = 1, step = 0.01, percent = true})

R.section = "Colours"
dropdown("general.colours.health", "Health colours", "Colour the health bars with the original gradient, or between your Empty and Full colours.", {
	path = "colour.classic",
	options = {{1, "Classic gradient"}, {false, "Empty and full colours"}},
})
colour("general.colours.healthempty", "Health bar empty", "The colour of an empty health bar.", {path = "colour.bar.healthEmpty", also = {["colour.classic"] = false}})
colour("general.colours.healthfull", "Health bar full", "The colour of a full health bar.", {path = "colour.bar.healthFull", also = {["colour.classic"] = false}})
check("general.colours.classbars", "Class coloured bars", "Colour health bars according to class colour.", {path = "colour.classbar"})
slider("general.colours.brightness", "Brightness", "The brightness of the class coloured health bars.", {path = "colour.classbarBright", min = 0, max = 2, step = 0.01, default = 1})
check("general.colours.classnames", "Class coloured names", "Colour the names of players to match their class.", {path = "colour.class"})
colour("general.colours.friend", "Friendly units", "The colour of friendly units. Class coloured names override it for players.", {path = "colour.reaction.friend"})
colour("general.colours.neutral", "Neutral units", "The colour of neutral units. Class coloured names override it for players.", {path = "colour.reaction.neutral"})
colour("general.colours.unfriendly", "Unfriendly units", "The colour of unfriendly units. Class coloured names override it for players.", {path = "colour.reaction.unfriendly"})
colour("general.colours.enemy", "Enemy units", "The colour of enemy units. Class coloured names override it for players.", {path = "colour.reaction.enemy"})
colour("general.colours.none", "No reaction", "The colour of non-PvP flagged units. Class coloured names override it for players.", {path = "colour.reaction.none"})
colour("general.colours.tapped", "Tapped units", "The colour of tapped units.", {path = "colour.reaction.tapped"})
colour("general.colours.mana", "Mana", "The colour of mana bars.", {path = "colour.bar.mana"})
colour("general.colours.rage", "Rage", "The colour of rage bars.", {path = "colour.bar.rage"})
colour("general.colours.energy", "Energy", "The colour of energy bars.", {path = "colour.bar.energy"})
colour("general.colours.focus", "Focus", "The colour of focus bars.", {path = "colour.bar.focus"})
colour("general.colours.absorb", "Absorb bar", "The colour of absorb bars.", {path = "colour.bar.absorb"})
slider("general.colours.absorb.alpha", "Absorb bar opacity", "The opacity of absorb bars.", {path = "colour.bar.absorb.a", min = 0, max = 1, step = 0.01, percent = true})
colour("general.colours.healprediction", "Heal prediction bar", "The colour of heal prediction bars.", {path = "colour.bar.healprediction"})
slider("general.colours.healprediction.alpha", "Heal prediction bar opacity", "The opacity of heal prediction bars.", {path = "colour.bar.healprediction.a", min = 0, max = 1, step = 0.01, percent = true})
button("general.colours.reset", "Reset colours", "Reset the frame, bar, gradient and unit reaction colours and the transparency to their defaults.", {func = FPerl.ResetColours})

R.section = "Shown on frames"
framesPicker("general.shown.frames", "Apply to", "The frames the controls of this section write to. A control shows the value of the first ticked frame; its tooltip lists the ticked frames that differ. Changing a control overwrites the value of every ticked frame. The ticks are not saved.")
shared("dropdown", "general.shown.portrait", "Portrait", "The portrait of the ticked frames: none, flat, 3D, or the class icon (not on the pet).", {each = of(SHOWN_ID, "portrait", {PLAYER, PET, TARGET, FOCUS, PARTY})})
shared("check", "general.shown.level", "Level", "Show the unit's level.", {each = of(SHOWN_ID, "level", {PLAYER, PET, PETTARGET, TARGET, TOT, TOTT, FOCUS, FOCUSTARGET, PARTY, PARTYPETS})})
shared("check", "general.shown.classicon", "Class icon", "Show the unit's class icon.", {each = of(SHOWN_ID, "classicon", MAIN)})
shared("check", "general.shown.pvp", "PvP flag", "Show the unit's PvP status.", {each = of(SHOWN_ID, "pvp", MAIN)})
shared("check", "general.shown.hit", "Hit indicators", "Show combat hit indicators over the portrait.", {each = of(SHOWN_ID, "hit", {PLAYER, PET, TARGET, FOCUS, PARTY})})
shared("dropdown", "general.shown.healthtext", "Health text", "How health is written on the bars. The pet has its own health and mana text switch on its page. The raid frames have no Current, no Missing and maximum and no Current, maximum and missing.", {
	each = of(SHOWN_ID, "healthtext", {PLAYER, PETTARGET, TARGET, TOT, TOTT, FOCUS, FOCUSTARGET, PARTY, RAID}),
	alias = {[RAID] = {["Current and percent"] = "Current and maximum", ["Missing (healer)"] = "Missing (healer mode)"}},
})
shared("check", "general.shown.absorbs", "Absorbs", "Show the absorb bar.", {each = of(SHOWN_ID, "absorbs", {PLAYER, PET, TARGET, TOT, TOTT, FOCUS, FOCUSTARGET, PARTY, RAID})})
shared("check", "general.shown.healprediction", "Heal prediction", "Show the heal prediction bar.", {each = of(SHOWN_ID, "healprediction", {PLAYER, PET, TARGET, TOT, TOTT, FOCUS, FOCUSTARGET, PARTY, RAID})})
shared("check", "general.shown.castbar", "Cast bar", "Show a cast bar on the frame.", {each = of(SHOWN_ID, "castbar", {PLAYER, PET, TARGET, FOCUS, PARTY})})
shared("dropdown", "general.shown.casttime", "Cast time text", "Show the casting time beside the cast bar or inside it. Every cast bar reads the Player frame's value, so this changes only while Player is ticked.", {each = of(SHOWN_ID, "casttime", {PLAYER})})
check("general.shown.combatflash", "Combat flashing", "Flash the frame borders on combat damage or healing. Applies to all frames.", {path = "combatFlash", apply = {}})
check("general.shown.afk", "AFK flag", "Show the AFK status of players. Applies to all frames.", {path = "showAFK"})
check("general.shown.readycheck", "Ready check", "Show the ready check state on the frames of group members. Applies to all frames.", {path = "showReadyCheck"})

R.section = "Auras"
framesPicker("general.auras.frames", "Apply to", "The frames the controls of this section write to. A control shows the value of the first ticked frame; its tooltip lists the ticked frames that differ. Changing a control overwrites the value of every ticked frame. The ticks are not saved.")
shared("check", "general.auras.buffs", "Buffs", "Show the unit's buffs. The pet's target and the party pets switch their debuffs with it.", {each = of(AURA_ID, "buffs", {PLAYER, PET, PETTARGET, TARGET, TOT, TOTT, FOCUS, FOCUSTARGET, PARTY, PARTYPETS})})
shared("check", "general.auras.debuffs", "Debuffs", "Show the unit's debuffs.", {each = of(AURA_ID, "debuffs", {PLAYER, PET, TARGET, TOT, TOTT, FOCUS, FOCUSTARGET, PARTY})})
shared("slider", "general.auras.buffsize", "Buff size", "The size of the buff icons. Each frame keeps to its own range.", {each = of(AURA_ID, "buffsize", {PLAYER, PET, TARGET, TOT, TOTT, FOCUS, FOCUSTARGET, PARTY, PARTYPETS})})
shared("slider", "general.auras.debuffsize", "Debuff size", "The size of the debuff icons. Each frame keeps to its own range.", {each = of(AURA_ID, "debuffsize", {PLAYER, PET, TARGET, TOT, TOTT, FOCUS, FOCUSTARGET, PARTY, PARTYPETS})})
check("general.auras.tooltips", "Aura tooltips", "Show a tooltip over the aura icons. Applies to all frames.", {path = "tooltip.enableBuffs", apply = {"playerbuffs", "playerpet", "target", "targettarget", "party", "partypet"}})
button("general.auras.blacklist", "Aura blacklist...", "Open the aura blacklist editor, to hide chosen auras by spell ID or name.", {func = FPerl.SettingsOpenBlacklist, nocombat = true})
shared("check", "general.auras.wrap", "Wrap", "Wrap aura icons that exceed the width of the frame.", {each = of(AURA_ID, "wrap", {PLAYER, PET, TARGET, TOT, TOTT, FOCUS, FOCUSTARGET, PARTY})})
shared("slider", "general.auras.rows", "Rows", "The most rows of wrapped aura icons.", {each = of(AURA_ID, "rows", {PET, TARGET, TOT, TOTT, FOCUS, FOCUSTARGET, PARTY})})
shared("check", "general.auras.castable", "Castable buffs only", "Show only the buffs you can cast.", {each = of(AURA_ID, "castable", {PET, TARGET, TOT, TOTT, FOCUS, FOCUSTARGET, PARTY})})
shared("check", "general.auras.curable", "Curable debuffs only", "Show only the debuffs you can cure.", {each = of(AURA_ID, "curable", {PET, TARGET, TOT, TOTT, FOCUS, FOCUSTARGET, PARTY})})
shared("check", "general.auras.onlymybuffs", "Only my buffs", "Show only the buffs you cast.", {each = of(AURA_ID, "onlymybuffs", {TARGET, TOT, TOTT, FOCUS, FOCUSTARGET}, {[PARTY] = "party.auras.onlymine"})})
shared("check", "general.auras.onlymydebuffs", "Only my debuffs", "Show only the debuffs you cast.", {each = of(AURA_ID, "onlymydebuffs", {TARGET, TOT, TOTT, FOCUS, FOCUSTARGET})})
shared("check", "general.auras.bigbuffs", "Big buffs", "Show your own buffs larger.", {each = of(AURA_ID, "bigbuffs", {PLAYER, PET, PETTARGET, TARGET, TOT, TOTT, FOCUS, FOCUSTARGET}, {[PARTY] = "party.auras.big"})})
shared("check", "general.auras.bigdebuffs", "Big debuffs", "Show your own debuffs larger. The target and focus frames have Big stealable buffs in its place.", {each = of(AURA_ID, "bigdebuffs", {PET, PETTARGET, TOT, TOTT, FOCUSTARGET})})
shared("check", "general.auras.bigstealable", "Big stealable buffs", "Show the buffs you can steal larger.", {each = of(AURA_ID, "bigstealable", {TARGET, FOCUS})})
local LAYOUT = {PLAYER, PET, PETTARGET, TARGET, TOT, TOTT, FOCUS, FOCUSTARGET, PARTY, PARTYPETS}
for _, e in ipairs({
	{"dropdown", "buffside", "Buff side", "The side of the frame the buffs sit on."},
	{"dropdown", "debuffside", "Debuff side", "The side of the frame the debuffs sit on."},
	{"dropdown", "order", "Order", "Which kind sits next to the frame when both share a side. By reaction puts debuffs next to the frame on a unit you can attack."},
	{"slider", "buffperline", "Buff icons per line", "The most buff icons in a line before it wraps. Applies while Wrap is on. Auto: as many as fit the frame width on Top and Bottom, one line on Left and Right."},
	{"slider", "debuffperline", "Debuff icons per line", "The most debuff icons in a line before it wraps. Applies while Wrap is on. Auto: as many as fit the frame width on Top and Bottom, one line on Left and Right."},
	{"check", "buffreverse", "Buff reverse fill", "Fill from the right (rows) or the bottom (columns)."},
	{"check", "debuffreverse", "Debuff reverse fill", "Fill from the right (rows) or the bottom (columns)."},
	{"slider", "buffx", "Buff X", "Move the buffs sideways, in pixels."},
	{"slider", "buffy", "Buff Y", "Move the buffs up, in pixels."},
	{"slider", "debuffx", "Debuff X", "Move the debuffs sideways, in pixels."},
	{"slider", "debuffy", "Debuff Y", "Move the debuffs up, in pixels."},
}) do
	shared(e[1], "general.auras." .. e[2], e[3], e[4], {each = of(AURA_ID, e[2], LAYOUT)})
end
check("general.auras.cooldown", "Cooldown sweep", "Show the cooldown sweep on aura icons. Applies to all frames.", {path = "buffs.cooldown"})
check("general.auras.cooldownany", "Sweep on all auras", "Show the cooldown sweep on every aura, not only your own. Acts in the X-Perl aura style.", {path = "buffs.cooldownAny"})
check("general.auras.countdown", "Countdown numbers", "Show the time left as a number on aura icons.", {path = "buffs.countdown"})
check("general.auras.countdownany", "Numbers on all auras", "Show the countdown on every aura, not only your own.", {path = "buffs.countdownAny"})
check("general.auras.blizzardnumbers", "Big countdown numbers", "Show Blizzard's large countdown numbers over the aura icons.", {path = "buffs.blizzard"})

R.section = "Highlights"
check("general.highlights.enable", "Status highlighting", "Highlight units with the glows below.", {path = "highlight.enable"})
dropdown("general.highlights.debuff", "Debuff highlight", "Highlight units that are debuffed: the background, the border, or both.", {
	base = "highlightDebuffs",
	map = {
		{"Off", {enable = false}},
		{"Background", {enable = 1, border = false, frame = 1}},
		{"Border", {enable = 1, border = 1, frame = false}},
		{"Both", {enable = 1, border = 1, frame = 1}},
	},
})
check("general.highlights.curable", "Only curable", "Only highlight debuffs when it is something you can cure.", {path = "highlightDebuffs.class"})
check("general.highlights.aggro", "Aggro glow", "Highlight units with a red border if they have aggro. Requires Raid Helper's Target Counter to be loaded and enabled.", {path = "highlight.AGGRO"})
check("general.highlights.target", "Target glow", "Indicate your target on the frames.", {path = "highlightSelection"})
check("general.highlights.heal", "Incoming heal glow", "Highlight units that are being healed in green.", {path = "highlight.HEAL"})
check("general.highlights.hots", "HoTs", "Highlight units with a blue border that have your heal over time spells.", {path = "highlight.HOT"})
check("general.highlights.shields", "Shields", "Highlight units with a purple border that have your short term beneficial shield buffs.", {path = "highlight.SHIELD"})
check("general.highlights.hotcount", "HoT counter", "Indicate on a unit how many active heal over time effects it has from any class.", {path = "highlight.HOTCOUNT"})
check("general.highlights.sparkles", "Sparkles", "Use sparkles for a more apparent look of the glows. Off: the old style border colours.", {path = "highlight.sparkles"})

R.section = "Range"
check("general.range.enable", "Dim out-of-range units", "Fade any unit frame that is out of range.", {path = "rangeFinder.enabled", on = true})
check("general.range.raidonly", "Raid frames only", "Only fade raid frames.", {path = "rangeFinder.raidOnly"})

local function rangePart(sectionName, key, idPart, first)
	R.section = sectionName
	check("general.range." .. idPart .. ".enable", "Enable", "Fade this part of the frame when out of range.", {path = "rangeFinder." .. key .. ".enabled", on = true})
	slider("general.range." .. idPart .. ".fade", "Fade amount", "How much to fade from the normal transparency when out of range.", {path = "rangeFinder." .. key .. ".FadeAmount", min = 0.1, max = 0.8, step = 0.1, percent = true})
	check("general.range." .. idPart .. ".health", "Health check", "Only units that need healing and are in range are clear.", {path = "rangeFinder." .. key .. ".PlusHealth", on = true})
	slider("general.range." .. idPart .. ".marker", "Health marker", "The low health point for the health check.", {path = "rangeFinder." .. key .. ".HealthLowPoint", min = 0.1, max = 0.95, step = 0.05, percent = true})
	check("general.range." .. idPart .. ".debuff", "Debuff check", "Only units that need curing and are in range are clear.", {path = "rangeFinder." .. key .. ".PlusDebuff", on = true})
end
rangePart("Range: Whole frame", "Main", "main", true)
rangePart("Range: Name", "NameFrame", "name", false)
rangePart("Range: Bars", "StatsFrame", "bars", false)

R.section = "Tooltips"
check("general.tooltips.unit", "Unit tooltips", "Show tooltips for unit frames.", {path = "tooltip.enable"})
dropdown("general.tooltips.modifier", "Modifier key", "The key to hold for the unit tooltip.", {
	path = "tooltip.modifier",
	options = {{"all", "Always"}, {"alt", "Alt"}, {"shift", "Shift"}, {"ctrl", "Ctrl"}},
})
check("general.tooltips.hideincombat", "Hide in combat", "Do not show unit tooltips in combat.", {path = "tooltip.hideInCombat"})
check("general.tooltips.fading", "Fading tooltips", "Tooltips fade out.", {path = "tooltip.fading"})

R.section = "Lost control"
check("general.lowhealth.enable", "Lost-control flash", "Flash the screen edges while you have lost control of your character (fear, mind control).", {path = "player.fullScreen.enable"})

R.section = "Misc"
check("general.misc.minimap", "Minimap button", "Show the minimap button.", {path = "minimap.enable"})
check("general.misc.oldroleicons", "Old role icons", "Show the original X-Perl group role icons.", {path = "oldRoleIcons"})
