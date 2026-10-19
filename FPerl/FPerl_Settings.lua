-- The options panel: at login registers the category "F-Perl" in Blizzard's Settings panel, one subcategory per
-- page of FPerl.SettingsList, one proxy setting per entry. List format: the header of
-- FPerl_SettingsList.lua.
--
-- Every getter and setter re-resolves FPerl.layout, which is replaced on a profile switch. A stored nil and false
-- read the same. Section headers are Blizzard's expandable-section template with our own click handler; the
-- entries of a section are stock initializers with a shown predicate on the section's open flag.
--
-- A shared control (list entry with `each`, General's Shown on frames and Auras sections) has no key of its own: its
-- setter calls the store of each ticked frame's own entry (the "Apply to" picker, a bitmask kept in `masks`, session
-- state), its getter reads the first ticked frame's entry, its tooltip names the ticked frames that differ.

local format, floor = string.format, math.floor
-- Pages other addons add: {key, name, create}. build() registers each as a canvas subcategory of "F-Perl" with
-- a frame it keeps in `frame` and `category`; create(frame) runs the first time the frame is shown.
FPerl.SettingsPages = FPerl.SettingsPages or {}

local function norm(v) return v or false end
local byId, settingById = nil, {} -- byId: built on first use, the list file loads after this one
local function rowById(id)
	if not byId then
		byId = {}
		for _, e in ipairs(FPerl.SettingsList) do byId[e.id] = e end
	end
	return byId[id]
end
local refresh -- re-reads every setting into the open panel
local sharedValue, sharedStore, setMask, maskOf -- shared controls, below

-- Parent table and last key of a dotted path (an integer key is its own last key). create: build missing tables.
local function parentOf(root, key, create)
	if type(key) == "number" then return root, key end
	local t, last = root, nil
	for k in string.gmatch(key, "[^%.]+") do
		if last ~= nil then
			local nx = t[last]
			if type(nx) ~= "table" then
				if not create then return nil end
				nx = {}
				t[last] = nx
			end
			t = nx
		end
		last = k
	end
	return t, last
end
local function read(root, path)
	local p, k = parentOf(root, path)
	return p and p[k]
end
local function baseTable(root, e, create)
	if e.base == "" then return root end
	local t = read(root, e.base)
	if type(t) ~= "table" and create then
		local p, k = parentOf(root, e.base, true)
		t = {}
		p[k] = t
	end
	return type(t) == "table" and t or nil
end

------------------------------------------------------------------------------------------------ apply
-- FPerl.Apply (FPerl_Init.lua) runs the entry's appliers and defers itself in combat. A slider or colour calls it on
-- every step; an entry with `throttle` (appliers slower than a frame) at most once per 0.1 s, with a trailing call so
-- the last value always applies.
local lastRun, trailing, latest = 0, false, nil
local collect -- while a shared control writes: the appliers its frames' entries want, name -> true
local function applyNow(names)
	lastRun = GetTime()
	FPerl.Apply(names)
end
local function applyThrottled(names)
	latest = names
	local wait = lastRun + 0.1 - GetTime()
	if wait <= 0 then
		applyNow(names)
	elseif not trailing then
		trailing = true
		C_Timer.After(wait, function()
			trailing = false
			applyNow(latest)
		end)
	end
end
-- A name whose module has no applier (a raid tool not loaded) is skipped, not raised.
local function loaded(names)
	local out = {}
	for _, n in ipairs(names) do
		if n == "full" or FPerl.Appliers[n] then out[#out + 1] = n end
	end
	return out
end
local function apply(e, names)
	names = names or e.apply
	if collect then
		for _, n in ipairs(names) do collect[n] = true end
		return
	end
	names = loaded(names)
	if #names == 0 then return end
	if e.throttle then applyThrottled(names) else applyNow(names) end
end

------------------------------------------------------------------------------------------------ values
local function hexOf(c)
	if type(c) ~= "table" then return "FFFFFFFF" end
	local function b(x) return floor((x or 1) * 255 + 0.5) end
	return format("%02X%02X%02X%02X", b(c.a), b(c.r), b(c.g), b(c.b))
end

-- A stored check value: X-Perl readers test `== 1` or truthiness, and the defaults store 0 for off.
local function on(v) return v ~= nil and v ~= false and v ~= 0 end

-- The setting's value for an entry, read from root (FPerl.layout, or a default profile).
local function valueOf(e, root)
	local t = e.type
	if e.each then
		return sharedValue(e, root)
	elseif t == "frames" then
		return maskOf(e.section)
	elseif e.get then
		local v = e.get()
		if t == "check" then return on(v) end
		return v == nil and "" or v
	elseif t == "check" then
		return on(read(root, e.path))
	elseif t == "slider" then
		local v = tonumber(read(root, e.path))
		if v == nil then v = e.default end
		if v == nil then v = e.min end
		return v
	elseif t == "colour" then
		return hexOf(read(root, e.path))
	elseif type(e.options) == "function" then
		return ""
	elseif e.map then
		local base = baseTable(root, e)
		if base then
			for i, entry in ipairs(e.map) do
				local ok = true
				for k, want in pairs(entry[3] or entry[2]) do
					local p, last = parentOf(base, k)
					local good = false
					if p then
						if type(want) == "table" then
							for _, w in ipairs(want) do good = good or norm(p[last]) == norm(w) end
						else
							good = norm(p[last]) == norm(want)
						end
					end
					if not good then
						ok = false
						break
					end
				end
				if ok then return i end
			end
		end
		return 0
	else
		local v = norm(read(root, e.path))
		for i, o in ipairs(e.options) do
			if norm(o[1]) == v then return i end
		end
		return 0
	end
end

local function write(path, v)
	local p, k = parentOf(FPerl.layout, path, true)
	p[k] = v
end

-- Store the setting's value v for an entry.
local function store(e, v)
	local t = e.type
	if e.each then
		return sharedStore(e, v)
	elseif t == "frames" then
		return setMask(e.section, v)
	elseif e.set then
		e.set(v)
	elseif t == "check" then
		write(e.path, v and e.on or e.off)
		if e.with then for _, w in ipairs(e.with) do write(w, v and e.on or e.off) end end
	elseif t == "slider" then
		v = e.min + floor((v - e.min) / e.step + 0.5) * e.step
		write(e.path, tonumber(format("%.6f", v)))
	elseif t == "colour" then
		local a, r, g, b = string.match(v, "^(%x%x)(%x%x)(%x%x)(%x%x)$")
		if not a then return end
		local p, k = parentOf(FPerl.layout, e.path, true)
		local c = p[k]
		if type(c) ~= "table" then
			c = {}
			p[k] = c
		end
		-- the swatch has no opacity: the stored alpha stays
		c.r, c.g, c.b = tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
	elseif e.map then
		local entry = e.map[v]
		if not entry then return end
		local base = baseTable(FPerl.layout, e, true)
		for k, want in pairs(entry[2]) do
			local p, last = parentOf(base, k, true)
			p[last] = want
		end
	else
		local o = e.options[v]
		if o then write(e.path, o[1]) end
	end
	-- Blizzard's Defaults button sets every setting to its default in no fixed order: the side effect would undo one
	-- refresh only on a change: a colour drag stores every step, and refreshing the whole panel each step lags the game
	if e.also and not (SettingsPanel and SettingsPanel:CheckIsSettingDefaults()) then
		local changed
		for path, v in pairs(e.also) do
			if norm(read(FPerl.layout, path)) ~= norm(v) then
				write(path, v)
				changed = true
			end
		end
		if changed then refresh() end
	end
	apply(e)
end

------------------------------------------------------------------------------------------------ shared
-- FPerl.SettingsFrames is set by the list file, which loads after this one: read it at run time
local function full() return 2 ^ #FPerl.SettingsFrames - 1 end
local masks = {} -- section -> bitmask of the ticked frames; session state, not saved
local function ticked(mask, i) return bit.band(mask, bit.lshift(1, i - 1)) ~= 0 end
function maskOf(section) return masks[section] or full() end

-- A choice of a per-frame dropdown entry by index or label; a shared dropdown's labels are the frames' labels, renamed
-- for a frame by the entry's `alias`.
local function choiceOf(fe, i)
	local c = fe.map and fe.map[i] and fe.map[i][1] or (type(fe.options) == "table" and fe.options[i] and fe.options[i][2])
	return c or nil
end
local function indexOfChoice(fe, label)
	for i = 1, fe.map and #fe.map or #fe.options do
		if choiceOf(fe, i) == label then return i end
	end
end
local function toShared(e, fl, label)
	for s, f in pairs(e.alias and e.alias[fl] or {}) do
		if f == label then return s end
	end
	return label
end
local function toFrame(e, fl, label)
	local a = e.alias and e.alias[fl]
	return a and a[label] or label
end
local function sameValue(a, b)
	if type(a) == "number" and type(b) == "number" then return math.abs(a - b) < 1e-6 end
	return a == b
end

-- The value of a frame's entry in the shared control's terms: a boolean, a number, or a choice label.
local function frameForm(e, fl, root)
	local v = valueOf(rowById(e.each[fl]), root)
	if e.type == "dropdown" then
		local c = choiceOf(rowById(e.each[fl]), v)
		return c and toShared(e, fl, c) or nil
	end
	return v
end
-- The first ticked frame that has an entry (any frame of the profile `root` when it is not the live one: the defaults).
local function firstFrame(e, anyFrame)
	local mask = anyFrame and full() or maskOf(e.section)
	for i, fl in ipairs(FPerl.SettingsFrames) do
		if e.each[fl] and ticked(mask, i) then return fl end
	end
end
function sharedValue(e, root)
	local fl = firstFrame(e, root ~= FPerl.layout)
	if not fl then return e.type == "check" and false or (e.type == "slider" and e.min or 0) end
	local v = frameForm(e, fl, root)
	if e.type == "dropdown" then
		for i, o in ipairs(e.options) do
			if o[2] == v then return i end
		end
		return 0
	elseif e.type == "slider" then
		return math.max(e.min, math.min(e.max, v))
	end
	return v
end

-- Write v through the entry of each ticked frame (overwriting its value), then run the appliers they want once. The Defaults
-- button would push one frame's default into all of them: it leaves shared controls alone.
function sharedStore(e, v)
	if SettingsPanel and SettingsPanel:CheckIsSettingDefaults() then return end
	local mask = maskOf(e.section)
	collect = {}
	local ok, err = pcall(function()
		for i, fl in ipairs(FPerl.SettingsFrames) do
			local id = e.each[fl]
			if id and ticked(mask, i) then
				local fe, fv = (rowById(id))
				if e.type == "dropdown" then
					local o = e.options[v]
					fv = o and indexOfChoice(fe, toFrame(e, fl, o[2]))
				elseif e.type == "slider" then
					fv = math.max(fe.min, math.min(fe.max, v))
				else
					fv = v
				end
				if fv ~= nil and not sameValue(valueOf(fe, FPerl.layout), fv) then store(fe, fv) end
			end
		end
	end)
	local names = {}
	for n in pairs(collect) do names[#names + 1] = n end
	collect = nil
	if not ok then error(err, 0) end
	apply(e, names)
end

-- The picker's setter: the shared controls of the section show the first ticked frame's value.
function setMask(section, v)
	masks[section] = v
	if SettingsPanel and SettingsPanel:CheckIsSettingDefaults() then return end
	for _, x in ipairs(FPerl.SettingsList) do
		if x.each and x.section == section and settingById[x.id] then settingById[x.id]:NotifyUpdate() end
	end
end

-- The tooltip: the entry's text, the ticked frames whose value differs from the shown one, and, for a dropdown, the ticked
-- frames that have no choice for the shown value (they are left alone when it is picked).
local function sharedTip(e)
	return function()
		local first = firstFrame(e)
		if not first then return e.tip .. "\nNo frame with this setting is ticked in Apply to." end
		local mask, shown = maskOf(e.section), frameForm(e, first, FPerl.layout)
		local differ, skipped = {}, {}
		for i, fl in ipairs(FPerl.SettingsFrames) do
			if e.each[fl] and ticked(mask, i) then
				if fl ~= first and not sameValue(frameForm(e, fl, FPerl.layout), shown) then differ[#differ + 1] = fl end
				if e.type == "dropdown" and shown and not indexOfChoice(rowById(e.each[fl]), toFrame(e, fl, shown)) then skipped[#skipped + 1] = fl end
			end
		end
		local text = e.tip
		if #differ > 0 then text = text .. "\nDiffers: " .. table.concat(differ, ", ") end
		if #skipped > 0 then text = text .. "\nNot changed: " .. table.concat(skipped, ", ") end
		return text
	end
end

local function framesOptions()
	local c = Settings.CreateControlTextContainer()
	for i, fl in ipairs(FPerl.SettingsFrames) do c:AddCheckbox(i, fl) end
	return c:GetData()
end
local function framesText(selections)
	if #selections == 0 then return "None" end
	if #selections == #FPerl.SettingsFrames then return "All frames" end
end

------------------------------------------------------------------------------------------------ popup
StaticPopupDialogs["FPERL_SETTINGS_CONFIRM"] = {
	text = "%s",
	button1 = ACCEPT,
	button2 = CANCEL,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	OnAccept = function(self, data) data() end,
}
local function confirm(text, fn)
	StaticPopup_Show("FPERL_SETTINGS_CONFIRM", text, nil, fn)
end

------------------------------------------------------------------------------------------------ core functions
-- Reset to defaults and the layout rows change the whole profile; the old window disabled them in combat.
local function refuseInCombat()
	if InCombatLockdown() then
		FPerl.Notice("Not available in combat.")
		return true
	end
end

-- The layout rows act through FPerl.SelectLayout, FPerl.NewLayout, FPerl.CopyLayout, FPerl.RenameLayout and
-- FPerl.DeleteLayout (FPerl_Globals.lua), which refuse in combat and on bad names with a notice.
function FPerl.SettingsLayoutList()
	local ret = {}
	for _, name in ipairs(FPerl.LayoutNames()) do ret[#ret + 1] = {name, name} end
	return ret
end
function FPerl.SettingsDeleteList()
	local ret = {{"", "Select a layout"}}
	local active = FPerl.ActiveLayout()
	for _, name in ipairs(FPerl.LayoutNames()) do
		if name ~= "Default" and name ~= active then ret[#ret + 1] = {name, name} end
	end
	return ret
end
function FPerl.SettingsGetLayout() return FPerl.ActiveLayout() or "Default" end

function FPerl.SettingsSelectLayout(name)
	if SettingsPanel and SettingsPanel:CheckIsSettingDefaults() then return end
	if name ~= FPerl.ActiveLayout() then FPerl.SelectLayout(name) end
	refresh()
end

-- Name entry: Blizzard's generic input box; its callback gets the typed text.
local function askName(text, arg, callback)
	StaticPopup_ShowCustomGenericInputBox({text = text, text_arg1 = arg, callback = callback, maxLetters = 32})
end
function FPerl.SettingsNewLayout()
	askName("Name of the new layout (default settings):", nil, FPerl.NewLayout)
end
function FPerl.SettingsCopyLayout()
	askName("Name of the copy of layout %s:", FPerl.ActiveLayout(), FPerl.CopyLayout)
end
function FPerl.SettingsRenameLayout()
	local old = FPerl.ActiveLayout()
	if old == "Default" then
		FPerl.Notice("The Default layout cannot be renamed.")
		return
	end
	askName("New name of layout %s:", old, function(name) FPerl.RenameLayout(old, name) end)
end

function FPerl.SettingsDeleteLayout(name)
	if name == "" or refuseInCombat() then return end
	confirm(format("Delete layout %s?", name), function()
		FPerl.DeleteLayout(name)
		refresh()
	end)
end

-- Aura blacklist...: the blacklist editor is a settings page AuraBlacklist/ adds through FPerl.SettingsPages.
function FPerl.SettingsOpenBlacklist()
	for _, p in ipairs(FPerl.SettingsPages) do
		if p.key == "AuraBlacklist" and p.category then
			Settings.OpenToCategory(p.category:GetID())
			return
		end
	end
	FPerl.Notice("The aura blacklist page is missing.")
end

-- Reset colours: every colour default, the frame backdrop and border, and the transparency.
function FPerl.ResetColours()
	FPerl.DefaultFrameAppearance()
	FPerl.layout.colour.gradient = FPerl.DefaultGradientColours()
	FPerl.layout.colour.reaction = FPerl.DefaultReactionColours()
	FPerl.layout.colour.bar = FPerl.DefaultBarColours()
	FPerl.OptionActions()
end

-- Reset position of a frame's aura blocks (key: the frame's profile table): the four offsets back to 0.
function FPerl.SettingsResetAuraPos(key)
	for _, kind in ipairs({"buffs", "debuffs"}) do
		write(key .. "." .. kind .. ".x", 0)
		write(key .. "." .. kind .. ".y", 0)
	end
end

-- Raid page. While the switch is on Blizzard's raid frames are hidden (read when the raid frames load, so it takes effect after
-- a reload). Each group box is a numeric key of raid.group, which a dotted path cannot name.
-- Unlock frames: session state (FPerl.Locked), not a profile key.
function FPerl.SettingsGetUnlock() return FPerl.Locked == 0 end
function FPerl.SettingsSetUnlock(v)
	if refuseInCombat() then refresh() return end
	if v then FPerl.UnlockFrames() else FPerl.LockFrames() end
end
function FPerl.SettingsGetRaid() return FPerl.layout.raid.enable and true or false end
function FPerl.SettingsSetRaid(v)
	FPerl.layout.raid.enable = v and 1 or false
end
local function groupGet(i) return function() return FPerl.layout.raid.group[i] and true or false end end
local function groupSet(i) return function(v) FPerl.layout.raid.group[i] = v and 1 or false end end
FPerl.SettingsGetRaidGroup1 = groupGet(1)
FPerl.SettingsSetRaidGroup1 = groupSet(1)
FPerl.SettingsGetRaidGroup2 = groupGet(2)
FPerl.SettingsSetRaidGroup2 = groupSet(2)
FPerl.SettingsGetRaidGroup3 = groupGet(3)
FPerl.SettingsSetRaidGroup3 = groupSet(3)
FPerl.SettingsGetRaidGroup4 = groupGet(4)
FPerl.SettingsSetRaidGroup4 = groupSet(4)
FPerl.SettingsGetRaidGroup5 = groupGet(5)
FPerl.SettingsSetRaidGroup5 = groupSet(5)
FPerl.SettingsGetRaidGroup6 = groupGet(6)
FPerl.SettingsSetRaidGroup6 = groupSet(6)
FPerl.SettingsGetRaidGroup7 = groupGet(7)
FPerl.SettingsSetRaidGroup7 = groupSet(7)
FPerl.SettingsGetRaidGroup8 = groupGet(8)
FPerl.SettingsSetRaidGroup8 = groupSet(8)
-- All and None set every group and class box, as the old window's buttons did (a class box shows a class column of Sort by Class).
local function raidGroupsAll(on)
	local r = FPerl.layout.raid
	for i = 1, #r.group do r.group[i] = on and 1 or false end
	for _, c in ipairs(r.class) do c.enable = on and 1 or nil end
	FPerl.Apply({"raidheaders", "raid"})
end
function FPerl.SettingsRaidGroupsAll() raidGroupsAll(true) end
function FPerl.SettingsRaidGroupsNone() raidGroupsAll(false) end

------------------------------------------------------------------------------------------------ builder
local function header(name, state)
	local init = CreateFromMixins(SettingsExpandableSectionInitializer)
	init:Init("SettingsExpandableSectionTemplate")
	init.data = {name = name}
	function init:GetExtent() return 25 end
	function init:InitFrame(frame)
		frame:Init(self)
		local function arrow()
			frame.Button.Right:SetAtlas(state.open and "Options_ListExpand_Right_Expanded" or "Options_ListExpand_Right", true)
		end
		arrow()
		frame.Button:SetScript("OnClick", function()
			state.open = not state.open
			arrow()
			SettingsInbound.RepairDisplay()
		end)
	end
	return init
end

local function optionsFn(e)
	return function()
		local c = Settings.CreateControlTextContainer()
		if e.map then
			for i, m in ipairs(e.map) do c:Add(i, m[1]) end
		elseif type(e.options) == "table" then
			for i, o in ipairs(e.options) do c:Add(i, o[2]) end
		else
			for _, o in ipairs(e.options()) do c:Add(o[1], o[2]) end
		end
		return c:GetData()
	end
end

local function sliderOptions(e)
	local o = Settings.CreateSliderOptions(e.min, e.max, e.step)
	o.steps = floor((e.max - e.min) / e.step + 0.5)
	local label
	if e.percent then
		label = function(v) return format("%d%%", floor(v * 100 + 0.5)) end
	elseif e.step >= 1 then
		label = function(v) return e.zero and v < 0.5 and e.zero or format("%d", floor(v + 0.5)) end
	else
		label = function(v) return (format("%.2f", v):gsub("(%.%d-)0+$", "%1"):gsub("%.$", "")) end
	end
	o:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, label)
	return o
end

local function click(e)
	if e.nocombat and refuseInCombat() then return end
	local function run()
		if e.nocombat and refuseInCombat() then return end
		local f = e.func
		if f then f(e.arg) end
		if e.arg then apply(e) end -- a button with an arg re-runs its appliers
		refresh()
	end
	if e.confirm then confirm((e.confirm:gsub("{layout}", function() return FPerl.ActiveLayout() or "Default" end)), run) else run() end
end

local settingObjects = {}
-- seen[id]: the value the panel last showed for a plain setting. Entries read through a function, shared
-- controls, the frame picker and dropdowns whose choices come from a function have no cached value: always notified.
local seen, settingEntry = {}, {}
local function plain(e) return not (e.get or e.each or e.type == "frames" or type(e.options) == "function") end
function refresh(changedOnly)
	for i, s in ipairs(settingObjects) do
		local e = settingEntry[i]
		if plain(e) then
			local v = valueOf(e, FPerl.layout)
			if changedOnly and seen[e.id] == v then s = nil else seen[e.id] = v end
		end
		if s then s:NotifyUpdate() end
	end

end

-- The panel row's own write path, for other callers (the frame menu): the value write, then the row's appliers.
function FPerl.SettingsSetRow(id, v)
	seen[id] = nil
	store(rowById(id), v)
end
function FPerl.SettingsGetRow(id) return valueOf(rowById(id), FPerl.layout) end
local pageCategory = {}
function FPerl.SettingsOpenPage(name)
	local cat = pageCategory[name]
	if cat then FPerl.AfterCombat(function() Settings.OpenToCategory(cat:GetID()) end) end
end

function FPerl.SettingsRefresh() refresh(true) end -- the layout and profile changes: only settings whose value changed

local rootCategory

-- Opens Esc > Options > AddOns > F-Perl. Opening it in combat is a blocked action (seen in game), so in
-- combat it opens when combat ends.
local function openNow() Settings.OpenToCategory(rootCategory:GetID()) end
function FPerl.OpenSettings()
	if not rootCategory then
		FPerl.Notice("The settings are not ready yet.")
		return
	end
	if InCombatLockdown() then
		FPerl.Notice("The settings open when combat ends.")
	end
	FPerl.AfterCombat(openNow)
end

local function build()
	local defaults = {}
	FPerl.Defaults(defaults)
	local root, rootLayout = Settings.RegisterVerticalLayoutCategory("F-Perl")
	rootCategory = root
	local pages = {}
	for _, e in ipairs(FPerl.SettingsList) do
		local page = pages[e.page]
		if not page then
			page = {}
			if e.page == "General" then
				page.cat, page.layout = root, rootLayout -- General is the F-Perl page itself
			else
				page.cat, page.layout = Settings.RegisterVerticalLayoutSubcategory(root, e.page)
			end
			pages[e.page] = page
			pageCategory[e.page] = page.cat
		end
		if page.section ~= e.section then
			page.section = e.section
			page.state = {open = false}
			page.layout:AddInitializer(header(e.section, page.state))
		end
		local state = page.state
		local init
		local tip = e.each and sharedTip(e) or function() return e.tip end
		if e.type == "button" then
			init = CreateSettingsButtonInitializer(e.label, e.label, function() click(e) end, e.tip, true)
			page.layout:AddInitializer(init)
		else
			local vtype, default = Settings.VarType.Number
			if e.type == "check" then
				vtype = Settings.VarType.Boolean
			elseif e.type == "colour" or type(e.options) == "function" then
				vtype = Settings.VarType.String
			end
			if e.type == "frames" then
				default = full()
			elseif e.get or type(e.options) == "function" then
				default = valueOf(e)
			else
				default = valueOf(e, defaults)
			end
			local setting = Settings.RegisterProxySetting(page.cat, "FPerl_" .. e.id, vtype, e.label, default,
				function() return valueOf(e, FPerl.layout) end,
				function(v) FPerl.SettingsSetRow(e.id, v) end)
			settingObjects[#settingObjects + 1] = setting
			settingEntry[#settingObjects] = e
			settingById[e.id] = setting
			if e.type == "check" then
				init = Settings.CreateCheckbox(page.cat, setting, tip)
			elseif e.type == "slider" then
				init = Settings.CreateSlider(page.cat, setting, sliderOptions(e), tip)
			elseif e.type == "colour" then
				init = Settings.CreateColorSwatch(page.cat, setting, tip)
			elseif e.type == "frames" then
				init = Settings.CreateDropdown(page.cat, setting, framesOptions, tip)
				init.getSelectionTextFunc = framesText
			else
				init = Settings.CreateDropdown(page.cat, setting, optionsFn(e), tip)
			end
		end
		-- a closed section still shows its settings while the panel lists search results, or search finds none of them
		init:AddShownPredicate(function()
			if e.showif and not e.showif() then return false end
			return state.open or (SettingsPanel and SettingsPanel.SearchBox and SettingsPanel.SearchBox:GetText() ~= "")
		end)
	end
	for _, p in ipairs(FPerl.SettingsPages) do
		local frame = CreateFrame("Frame")
		frame:Hide() -- the panel shows it; a frame created shown never gets the OnShow that builds the page
		frame:SetScript("OnShow", function(self)
			self:SetScript("OnShow", nil)
			xpcall(function() p.create(self) end, geterrorhandler())
		end)
		p.frame = frame
		p.category = Settings.RegisterCanvasLayoutSubcategory(root, frame, p.name)
	end
	Settings.RegisterAddOnCategory(root)
end

local function onLogin()
	FPerl.Off("PLAYER_LOGIN", onLogin)
	build()
end
FPerl.On("PLAYER_LOGIN", onLogin)
