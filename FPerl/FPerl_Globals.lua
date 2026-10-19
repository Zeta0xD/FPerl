-- Author: Resike
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

FPerl.Locked = 1
local conf
local ConfigRequesters = {}
local playerName
local maxRevision

local LOCALIZED_CLASS_NAMES_MALE = LOCALIZED_CLASS_NAMES_MALE
local CLASS_COUNT = 0
for k, v in pairs(LOCALIZED_CLASS_NAMES_MALE) do
	if k ~= "Adventurer" and k ~= "TRAVELER" then
		CLASS_COUNT = CLASS_COUNT + 1
	end
end

FPerl.TooltipEdge9 = {
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	edgeSize = 9,
	title = true
}

FPerl_Frame_Backdrop_32_16_3333 = {
	bgFile = "Interface\\AddOns\\FPerl\\Images\\FPerl_FrameBack",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 16,
	insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

FPerl_Frame_Backdrop_32_16_4444 = {
	bgFile = "Interface\\AddOns\\FPerl\\Images\\FPerl_FrameBack",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 }
}

FPerl_Frame_Backdrop_16_16_4444 = {
	bgFile = "Interface\\AddOns\\FPerl\\Images\\FPerl_FrameBack",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 }
}

FPerl_Frame_Backdrop_8_16_3333 = {
	bgFile = "Interface\\AddOns\\FPerl\\Images\\FPerl_FrameBack",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 8,
	edgeSize = 16,
	insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

FPerl_Icon_Backdrop_8_16_3333 = {
	bgFile = "",
	edgeFile = "",
	tile = true,
	tileSize = 32,
	edgeSize = 16,
	insets = { left = 3, right = 4, top = 3, bottom = 3 }
}

FPerl_Frame_Backdrop_256_10_1211 = {
	bgFile = "Interface\\AddOns\\FPerl\\Images\\FPerl_FrameBack",
	edgeFile = "Interface\\AddOns\\FPerl\\Images\\FPerl_ThinEdge",
	tile = true,
	tileSize = 256,
	edgeSize = 10,
	insets = { left = 1, right = 2, top = 1, bottom = 1 }
}

FPerl_Raid_Backdrop_16_9_3333 = {
	bgFile = "Interface\\AddOns\\FPerl_RaidHelper\\Images\\FPerl_FrameBack",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 9,
	insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

FPerl_Raid_Backdrop_32_16_3333 = {
	bgFile = "Interface\\AddOns\\FPerl_RaidHelper\\Images\\FPerl_FrameBack",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 16,
	insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

FPerl_Options_Backdrop_256_16_5555 = {
	bgFile = "Interface\\AddOns\\FPerl\\Images\\FPerl_FancyBack",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 256,
	edgeSize = 16,
	insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

FPerl_Frame_Backdrop_32_16_2222 = {
	bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
	edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
	tile = true,
	tileSize = 8,
	edgeSize = 8,
	insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

FPerl_BackdropTemplateMixin = CreateFromMixins(BackdropTemplateMixin)

function FPerl.SetModuleRevision(rev)
	if (rev) then
		rev = strmatch(rev, "Revision: (%d+)")
		if (rev) then
			rev = tonumber(rev)
			if (not maxRevision or rev > maxRevision) then
				maxRevision = rev
			end
		end
	end
end
local AddRevision = FPerl.SetModuleRevision

FPerl.SetModuleRevision("$Revision:  $")

function FPerl.Notice(...)
	if (DEFAULT_CHAT_FRAME) then
		DEFAULT_CHAT_FRAME:AddMessage(FPerl.ProductName.." - |c00FFFF80"..format(...))
	end
end

-- FPerl.RequestConfig
-- Setup a callback to give config around to local variables
function FPerl.RequestConfig(getConfig, rev)
	tinsert(ConfigRequesters, getConfig)
	if (FPerl.layout) then
		getConfig(FPerl.layout)
	end
	AddRevision(rev)
end

-- CurrentConfig()
-- The active layout of this character (FPerlDB.active["Realm / Name"]), created from the defaults when
-- absent, else backfilled. A character with no active layout starts on the one the schema 5 migration made
-- for it (FPerlDB.migrated; a stale per-character profile gives way to Default's settings, positions
-- kept), else on Default. A layout another character deleted gives a notice and Default.
local function CurrentConfig()
	local s = FPerlDB
	s.layouts = s.layouts or {}
	s.active = s.active or {}
	local layouts, me = s.layouts, GetRealmName() .. " / " .. playerName

	local defaults = {}
	FPerl.Defaults(defaults)
	if (type(layouts.Default) ~= "table") then
		layouts.Default = FPerl.CopyTable(defaults)
	end

	local name = s.active[me]
	if (name == nil) then
		local m = s.migrated and s.migrated[me]
		if (m and type(layouts[m]) == "table") then
			name = m
			local shared = false
			for _, n in pairs(s.active) do
				if (n == m) then
					shared = true
				end
			end
			if (not FPerlPerCharacter and not shared) then
				local positions = layouts[m].positions
				layouts[m] = FPerl.CopyTable(layouts.Default)
				layouts[m].positions = positions
			end
		else
			if (m) then
				FPerl.Notice("Layout %s no longer exists, using Default.", tostring(m))
			end
			name = "Default"
		end
		if (s.migrated) then
			s.migrated[me] = nil
		end
	elseif (type(layouts[name]) ~= "table") then
		FPerl.Notice("Layout %s no longer exists, using Default.", tostring(name))
		name = "Default"
	end
	s.active[me] = name

	local report = FPerl.Backfill(layouts[name], defaults)
	if (report[1]) then
		FPerl.Notice("Settings kept as stored, wrong type: %s", table.concat(report, ", ", 1, math.min(#report, 5)))
	end

	return layouts[name]
end

-- GiveConfig
local function GiveConfig()
	conf = CurrentConfig()
	FPerl.layout = conf

	for k, v in pairs(ConfigRequesters) do
		v(conf)
	end
end

FPerl.GiveConfig = GiveConfig

-- FPerl.AfterConfig(fn, ...)
-- fn(...) at once when the profile is handed out, else when the first hand-out has finished (the addon's
-- files run before SavedVariables are read). For an XML OnLoad that builds a frame from the profile.
local afterConfig = {}
function FPerl.AfterConfig(fn, ...)
	if (FPerl.layout) then
		return fn(...)
	end
	local args = {...}
	tinsert(afterConfig, function() fn(unpack(args)) end)
end

-- FPerl.ResetDefaults
-- Resets the active layout: its settings and its frame positions.
function FPerl.ResetDefaults()
	local conf = {}

	FPerl.Defaults(conf)

	FPerlDB.layouts[FPerl.ActiveLayout()] = conf

	FPerl.ReapplyLayout()

	FPerl.ResetFramePositions()
	print("F-Perl: settings and frame positions reset to defaults.")
end

-- FPerl.ResetFramePositions
-- Forget this character's saved positions and move every frame to its default anchor now.
-- Also the "Default" entry in the layout list.
function FPerl.ResetFramePositions()
	if (InCombatLockdown()) then
		FPerl.AfterCombat(FPerl.ResetFramePositions)
	else
		local positions = FPerl.GetSavePositionTable()
		if (positions) then
			wipe(positions)
		end
		for name in pairs(FPerl.DefaultPoints) do
			local frame = _G[name]
			if (frame) then
				FPerl.Pcall(FPerl.PlaceFrame, frame)
			end
		end
	end
end

-- CopyTable
function FPerl.CopyTable(old)
	if (not old) then
		return
	end

	--local new = FPerl.GetReusableTable()
	local new = { }

	for k, v in pairs(old) do
		if (type(v) == "table") then
			new[k] = FPerl.CopyTable(v)
		else
			new[k] = v
		end
	end

	return new
end

-- FPerl.RegisterLDB
local function RegisterLDB()
	local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
	if (LDB) then
		local ldbSource = LDB:NewDataObject("F-Perl", {
			type = "launcher",
			text = FPerl.ShortProductName,
			icon = FPerl.ModMenuIcon,
		})

		if (ldbSource) then
			function ldbSource:Update()
				self.text = FPerl.Version
			end
			ldbSource.OnClick = FPerl.MinimapButtonOnClick
			ldbSource.OnTooltipShow = function(tooltip) FPerl.MinimapButtonDetails(tooltip, true) end
		end
	end
	RegisterLDB = nil
end


local function settingspart1()
	playerName = UnitName("player")

	if (not FPerlDB) then
		FPerlDB = {}
	end

	FPerl.MigrateConfig()
	FPerl.MigrateLayouts()
	FPerl.MigrateDeadKeys()
	FPerl.MigrateEngineNames()
	GiveConfig()

	-- Informational only: settings migrations key on FPerlDB.schema (FPerl.MigrateConfig)
	FPerlDB.ConfigVersion = FPerl.VersionNumber

	FPerl.Pcall(FPerl.ValidateSettings)

	FPerl.RegisterSMBarTextures()
end

local function startupCheckSettings()
	FPerl.Pcall(FPerl.Init)
	RegisterLDB()
end

-- The three login events of this file, on the FPerl.On bus. ADDON_LOADED filters by addon name; the
-- login pair run once.
local function onAddonLoaded(_, addon)
	-- 0.x saved-variable names to the new ones, before settingspart1 and before AuraBlacklist's own ADDON_LOADED
	FPerl.Pcall(FPerl.MigrateSavedNames, addon)
	if (addon == "FPerl") then
		settingspart1()
		for _, run in ipairs(afterConfig) do
			FPerl.Pcall(run)
		end
	end
	-- An addon's frames exist, unanchored, when its ADDON_LOADED fires; its own handler
	-- may measure them.
	if (strsub(addon, 1, 5) == "FPerl") then
		FPerl.PlaceNewFrames()
	end
end

local function onLogin()
	FPerl.Off("ADDON_LOADED", onAddonLoaded)
	FPerl.Off("PLAYER_LOGIN", onLogin)
	startupCheckSettings()
	FPerl.MinimapButtonInit(FPerl_MinimapButton_Frame)
end

local function onEnteringWorld()
	FPerl.Off("PLAYER_ENTERING_WORLD", onEnteringWorld)
	-- Restore the layout's saved positions (a first install has none: PlaceNewFrames placed the defaults).
	if (FPerl.GetSavePositionTable()) then
		FPerl.RestoreAllPositions()
	end
end

FPerl.On("ADDON_LOADED", onAddonLoaded)
FPerl.On("PLAYER_LOGIN", onLogin)
FPerl.On("PLAYER_ENTERING_WORLD", onEnteringWorld)

-- FPerl.LayoutKey(): this character's key in FPerlDB.active and .migrated.
function FPerl.LayoutKey()
	return GetRealmName() .. " / " .. UnitName("player")
end

-- FPerl.ActiveLayout(): the name of this character's layout.
function FPerl.ActiveLayout()
	return FPerlDB.active[FPerl.LayoutKey()]
end

-- FPerl.LayoutNames(): all layout names, Default first, the rest sorted ignoring case.
function FPerl.LayoutNames()
	local names = {}
	for name in pairs(FPerlDB.layouts) do
		if (name ~= "Default") then
			names[#names + 1] = name
		end
	end
	table.sort(names, function(a, b)
		local la, lb = a:lower(), b:lower()
		if (la ~= lb) then
			return la < lb
		end
		return a < b
	end)
	table.insert(names, 1, "Default")
	return names
end

-- FPerl.CleanLayoutName(name, except)
-- The trimmed name, or nil and a reason: empty, or taken by a layout other than `except`, ignoring case.
function FPerl.CleanLayoutName(name, except)
	name = tostring(name or ""):match("^%s*(.-)%s*$")
	if (name == "") then
		return nil, "A layout needs a name."
	end
	for other in pairs(FPerlDB.layouts) do
		if (other ~= except and other:lower() == name:lower()) then
			return nil, string.format("A layout named %s exists.", other)
		end
	end
	return name
end

-- The layout functions refuse with a notice and return nil; on success they return true.
function FPerl.LayoutRefuse(reason)
	FPerl.Notice("%s", reason)
end
function FPerl.LayoutInCombat()
	if (InCombatLockdown()) then
		FPerl.LayoutRefuse("Not available in combat.")
		return true
	end
end

-- FPerl.SelectLayout(name)
-- The one switch, for the panel and the slash command. Prunes the layout in use, makes `name` this
-- character's, and re-applies everything (FPerl.ReapplyLayout). The Player, Pet and Target
-- enable keys and raid.enable need a reload.
function FPerl.SelectLayout(name)
	if (FPerl.LayoutInCombat()) then
		return
	end
	if (type(FPerlDB.layouts[name]) ~= "table") then
		FPerl.LayoutRefuse(string.format("No layout named %s.", tostring(name)))
		return
	end
	local before = FPerl.layout and FPerl.CopyTable(FPerl.layout) -- the outgoing layout as the frames show it, before the prune
	FPerl.PruneConfig()
	FPerlDB.active[FPerl.LayoutKey()] = name
	FPerl.ReapplyLayout(before)
	return true
end

-- FPerl.LayoutAppliers(a, b)
-- The appliers needed by the keys that differ between the settings tables a and b, as a set; nil when a differing key has
-- no settings row (then everything runs). Positions are not settings. Keys map to appliers through FPerl.SettingsList:
-- the union over the rows that save the key: `path`, `with`, `also`, the keys of a `map`, and `keys` (a row with
-- get/set). A colour row saves a table: its keys r, g, b, a belong to the row.
-- FPerl.LayoutApplyStats counts both outcomes, and holds the keys without a row of the last full run.
FPerl.LayoutApplyStats = {scoped = 0, full = 0, unmatched = {}}
function FPerl.LayoutAppliers(a, b)
	local index = {}
	local function add(key, apply)
		local set = index[key]
		if (not set) then
			set = {}
			index[key] = set
		end
		for _, n in ipairs(apply) do
			set[n] = true
		end
	end
	for _, e in ipairs(FPerl.SettingsList or {}) do
		local apply = e.apply or {"full"}
		if (e.path) then
			add(e.path, apply)
		end
		for _, k in ipairs(e.with or {}) do
			add(k, apply)
		end
		for k in pairs(e.also or {}) do
			add(k, apply)
		end
		for _, k in ipairs(e.keys or {}) do
			add(k, apply)
		end
		for _, m in ipairs(e.map or {}) do
			for _, part in ipairs({m[2] or {}, m[3] or {}}) do
				for k in pairs(part) do
					add((e.base and e.base ~= "" and (e.base .. ".") or "") .. tostring(k), apply)
				end
			end
		end
	end
	local need, unmatched = {}, {}
	local function note(path)
		local key = path
		while (key and not index[key]) do
			key = key:match("^(.*)%.[^.]*$")
		end
		if (not key) then
			unmatched[#unmatched + 1] = path
			return
		end
		for n in pairs(index[key]) do
			need[n] = true
		end
	end
	local function walk(x, y, prefix)
		for k, v in pairs(x) do
			local w, path = y[k], prefix .. tostring(k)
			if (type(v) == "table" and type(w) == "table") then
				walk(v, w, path .. ".")
			elseif (v ~= w) then
				note(path)
			end
		end
		for k in pairs(y) do
			if (x[k] == nil) then
				note(prefix .. tostring(k))
			end
		end
	end
	for k, v in pairs(a) do
		if (k ~= "positions") then
			if (type(v) == "table" and type(b[k]) == "table") then
				walk(v, b[k], k .. ".")
			elseif (v ~= b[k]) then
				note(k)
			end
		end
	end
	for k in pairs(b) do
		if (k ~= "positions" and a[k] == nil) then
			note(k)
		end
	end
	local stats = FPerl.LayoutApplyStats
	if (unmatched[1]) then
		stats.full = stats.full + 1
		stats.unmatched = unmatched
		return nil
	end
	stats.scoped = stats.scoped + 1
	return need
end

-- FPerl.ReapplyLayout(before)
-- Applies the active layout everywhere: config consumers, positions (before the scale appliers, which
-- save the position of a frame with no entry), spell range, class list, option changers, the raid
-- header appliers the option changers do not run. Shared by the layout switch and Reset to defaults.
-- before: the settings of the layout just left (a copy). With it only the appliers of the settings
-- that differ run (FPerl.Apply); without it, or with a differing key no settings row covers, every
-- option changer runs.
function FPerl.ReapplyLayout(before)
	FPerl.GiveConfig()
	FPerl.RestoreAllPositions()
	FPerl.StartupSpellRange()
	ValidateClassNames(FPerl.layout.raid)
	local need = before and FPerl.LayoutAppliers(before, FPerl.layout)
	if (need and not need.full) then
		-- these follow the layout or the restored positions whether or not a key differs: the raid headers and widths,
		-- and the raid helper, which anchors its frame after the restore
		need.raidheaders, need.raidwidth, need.raidsizes = true, true, true
		local names = {}
		for n in pairs(need) do
			if (FPerl.HasApplier(n)) then
				names[#names + 1] = n
			end
		end
		FPerl.Apply(names)
	else
		FPerl.OptionActions()
		for _, applier in ipairs({"raidheaders", "raidwidth"}) do
			if (FPerl.HasApplier(applier)) then
				FPerl.Apply({applier})
			end
		end
	end
	if (FPerl.SettingsRefresh) then
		FPerl.SettingsRefresh()
	end
end

-- FPerl.NewLayout(name): a layout of the defaults, selected.
function FPerl.NewLayout(name)
	if (FPerl.LayoutInCombat()) then
		return
	end
	local clean, reason = FPerl.CleanLayoutName(name)
	if (not clean) then
		FPerl.LayoutRefuse(reason)
		return
	end
	local d = {}
	FPerl.Defaults(d)
	FPerlDB.layouts[clean] = d
	return FPerl.SelectLayout(clean)
end

-- FPerl.CopyLayout(name): a copy of the active layout, positions included, selected.
function FPerl.CopyLayout(name)
	if (FPerl.LayoutInCombat()) then
		return
	end
	local clean, reason = FPerl.CleanLayoutName(name)
	if (not clean) then
		FPerl.LayoutRefuse(reason)
		return
	end
	FPerl.PruneConfig()
	FPerlDB.layouts[clean] = FPerl.CopyTable(FPerlDB.layouts[FPerl.ActiveLayout()])
	return FPerl.SelectLayout(clean)
end

-- FPerl.RenameLayout(old, new): not Default; every character on it follows.
function FPerl.RenameLayout(old, new)
	if (FPerl.LayoutInCombat()) then
		return
	end
	local s = FPerlDB
	if (old == "Default") then
		FPerl.LayoutRefuse("The Default layout cannot be renamed.")
		return
	end
	if (type(s.layouts[old]) ~= "table") then
		FPerl.LayoutRefuse(string.format("No layout named %s.", tostring(old)))
		return
	end
	local clean, reason = FPerl.CleanLayoutName(new, old)
	if (not clean) then
		FPerl.LayoutRefuse(reason)
		return
	end
	if (clean == old) then
		return true
	end
	local layout = s.layouts[old]
	s.layouts[old] = nil
	s.layouts[clean] = layout
	for _, map in ipairs({s.active, s.migrated or {}}) do
		for key, name in pairs(map) do
			if (name == old) then
				map[key] = clean
			end
		end
	end
	if (FPerl.SettingsRefresh) then
		FPerl.SettingsRefresh()
	end
	return true
end

-- FPerl.DeleteLayout(name): not Default, not this character's own layout. A character on it goes back to
-- Default at its next login.
function FPerl.DeleteLayout(name)
	if (FPerl.LayoutInCombat()) then
		return
	end
	local s = FPerlDB
	if (name == "Default") then
		FPerl.LayoutRefuse("The Default layout cannot be deleted.")
		return
	end
	if (type(s.layouts[name]) ~= "table") then
		FPerl.LayoutRefuse(string.format("No layout named %s.", tostring(name)))
		return
	end
	if (FPerl.ActiveLayout() == name) then
		FPerl.LayoutRefuse("The layout in use cannot be deleted.")
		return
	end
	s.layouts[name] = nil
	if (FPerl.SettingsRefresh) then
		FPerl.SettingsRefresh()
	end
	return true
end

-- FPerl.Backfill(profile, defaults)
-- Copies every key absent from profile out of defaults, recursively (at login, after FPerl.MigrateConfig:
-- run before it, an unticked option stored as nil would come back ticked). A stored value is never
-- replaced. A list (a table with an array part: raid.class, raid.group) is a leaf: a stored list is not
-- merged with the default one. Where one side is a table and the other is not, the stored value stays.
-- Returns the paths of those mismatches. Keys the defaults lack (savedPositions) are not touched.
function FPerl.Backfill(profile, defaults, report, path)
	report = report or {}
	for k, d in pairs(defaults) do
		local v = profile[k]
		local name = (path and path .. "." or "") .. tostring(k)
		if (v == nil) then
			profile[k] = (type(d) == "table") and FPerl.CopyTable(d) or d
		elseif ((type(v) == "table") ~= (type(d) == "table")) then
			report[#report + 1] = name
		elseif (type(d) == "table" and d[1] == nil and v[1] == nil) then
			FPerl.Backfill(v, d, report, name)
		end
	end
	return report
end

-- FPerl.Prune(profile, defaults)
-- The inverse of FPerl.Backfill, run at PLAYER_LOGOUT: deletes every key whose stored value equals the
-- default, so a default changed later reaches a key the profile never changed (the backfill at the next
-- login restores the pruned keys). Walks the defaults only: keys they lack (savedPositions, extra keys)
-- stay. A list is a leaf, compared element by element. A table left empty is deleted because the defaults
-- hold it, and the backfill recreates it.
function FPerl.Prune(profile, defaults)
	local function same(a, b)
		if (type(a) ~= "table" or type(b) ~= "table") then
			return a == b
		end
		for k, v in pairs(a) do
			if (not same(v, b[k])) then
				return false
			end
		end
		for k in pairs(b) do
			if (a[k] == nil) then
				return false
			end
		end
		return true
	end

	for k, d in pairs(defaults) do
		local v = profile[k]
		if (type(d) == "table" and type(v) == "table" and d[1] == nil and v[1] == nil) then
			FPerl.Prune(v, d)
			if (next(v) == nil) then
				profile[k] = nil
			end
		elseif (v ~= nil and same(v, d)) then
			profile[k] = nil
		end
	end
end

-- FPerl.PruneConfig()
-- Prunes the active profile (FPerl.layout, set by every GiveConfig: login, profile switch, Reset Defaults,
-- Copy Settings) against freshly built defaults. Only that profile: the defaults hold the logged-in
-- character's class (target.hitIndicator), so another character's profile is not pruned with them.
-- A ConfigDefault function that raises leaves partial defaults, which delete fewer keys, never more.
function FPerl.PruneConfig()
	if (type(FPerl.layout) == "table") then
		local defaults = {}
		FPerl.Pcall(FPerl.Defaults, defaults)
		-- Defaults by class: a profile shared by characters of different classes keeps the stored value
		if (defaults.target) then
			defaults.target.highlightDebuffs = nil
		end
		FPerl.Prune(FPerl.layout, defaults)
	end
end

FPerl.On("PLAYER_LOGOUT", FPerl.PruneConfig)


-- FPerl.Defaults()
function FPerl.Defaults(new)
	FPerl.OptionsDefaults(new)
end

-- DefaultRaidClasses
-- Must have one entry per class the client knows about (FPerl_Raid.lua's
-- CLASS_COUNT counts LOCALIZED_CLASS_NAMES_MALE), or its repair path rebuilds
-- this, still comes up short for the newer classes, and crashes again on the
-- very next lookup -- which aborts raid frame setup entirely.
function DefaultRaidClasses()
	return {
		{enable = true, name = "WARRIOR"},
		{enable = true, name = "ROGUE"},
		{enable = true, name = "HUNTER"},
		{enable = true, name = "MAGE"},
		{enable = true, name = "WARLOCK"},
		{enable = true, name = "PRIEST"},
		{enable = true, name = "DRUID"},
		{enable = true, name = "SHAMAN"},
		{enable = true, name = "PALADIN"},
		{enable = true, name = "DEATHKNIGHT"},
		{enable = true, name = "MONK"},
		{enable = true, name = "DEMONHUNTER"},
		{enable = true, name = "EVOKER"},
	}
end

-- ValidateClassNames
function ValidateClassNames(part)
	if not part then
		return
	end
	-- This should never happen, but I'm sure someone will find a way to break it

	local list = {WARRIOR = false, MAGE = false, ROGUE = false, DRUID = false, HUNTER = false, SHAMAN = false, PRIEST = false, WARLOCK = false, PALADIN = false}
	local valid
	if (part.class) then
		local classCount = 0
		for i, info in pairs(part.class) do
			if (type(info) == "table" and info.name) then
				classCount = classCount + 1
			end
		end
		if (classCount == CLASS_COUNT) then
			valid = true
		end

		if (valid) then
			for i = 1, CLASS_COUNT do
				if (part.class[i]) then
					list[part.class[i].name] = true
				end
			end
		end
	end

	if (valid) then
		for k, v in pairs(list) do
			if (not v) then
				valid = nil
			end
		end
	end

	if (not valid) then
		part.class = DefaultRaidClasses(true)
	end
end

-- FPerl.ValidateSettings()
function FPerl.ValidateSettings()
	ValidateClassNames(FPerl.layout.raid)

	FPerl.ValidateSettings = nil
end
