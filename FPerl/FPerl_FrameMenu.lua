-- Frame menu: while the frames are unlocked and out of combat, an insecure overlay covers each listed frame.
-- Left-drag on it runs the frame's own drag scripts; right-click opens a menu of that frame's settings rows.
-- Every item writes through the settings panel's row path (FPerl.SettingsSetRow).

local KEYS = {
	enable = "Enable", scale = "Scale", portrait = "Portrait", buffs = "Buffs", debuffs = "Debuffs",
	onlymybuffs = "Only my buffs", onlymine = "Only my buffs", onlymydebuffs = "Only my debuffs",
	buffside = "Buff side", debuffside = "Debuff side",
}

-- {settings page, menu title, row ids}
local function aura(p, own)
	local t = {p .. "buffs", p .. "debuffs"}
	if own then t[#t + 1] = p .. "onlymybuffs" t[#t + 1] = p .. "onlymydebuffs" end
	t[#t + 1] = p .. "buffside" t[#t + 1] = p .. "debuffside"
	return t
end
local function join(...)
	local t = {}
	for _, l in ipairs({...}) do for _, v in ipairs(l) do t[#t + 1] = v end end
	return t
end
local MENUS = {
	player = {"Player", "Player", join({"player.size.scale", "player.shown.portrait"}, aura("player.auras."))},
	pet = {"Pet", "Pet", join({"pet.size.scale", "pet.shown.portrait"}, aura("pet.auras."))},
	pettarget = {"Pet", "Pet target", {"pet.pettarget.enable", "pet.pettarget.scale", "pet.pettarget.buffs", "pet.pettarget.buffside", "pet.pettarget.debuffside"}},
	target = {"Target", "Target", join({"target.size.scale", "target.shown.portrait"}, aura("target.auras.", true))},
	tot = {"Target", "Target of target", join({"target.tot.enable", "target.tot.scale"}, aura("target.tot.", true))},
	tott = {"Target", "Target's target's target", join({"target.tott.enable", "target.tott.scale"}, aura("target.tott.", true))},
	focus = {"Focus", "Focus", join({"focus.focus.enable", "focus.size.scale", "focus.shown.portrait"}, aura("focus.auras.", true))},
	focustarget = {"Focus", "Focus target", join({"focus.focustarget.enable", "focus.focustarget.scale"}, aura("focus.focustarget.", true))},
	party = {"Party", "Party", {"party.size.scale", "party.shown.portrait", "party.auras.buffs", "party.auras.debuffs", "party.auras.onlymine", "party.auras.buffside", "party.auras.debuffside"}},
	partypet = {"Party", "Party pets", {"party.pets.enable", "party.pets.scale", "party.pets.buffs", "party.pets.buffside", "party.pets.debuffside"}},
	raid = {"Raid", "Raid", {"raid.raid.enable", "raid.size.scale", "raid.auras.buffside", "raid.auras.debuffside"}},
}
local FRAMES = {
	FPerl_Player = "player", FPerl_Player_Pet = "pet", FPerl_PetTarget = "pettarget", FPerl_Target = "target",
	FPerl_TargetTarget = "tot", FPerl_TargetTargetTarget = "tott", FPerl_Focus = "focus", FPerl_FocusTarget = "focustarget",
}
local ORDER = {"FPerl_Player", "FPerl_Player_Pet", "FPerl_PetTarget", "FPerl_Target", "FPerl_TargetTarget", "FPerl_TargetTargetTarget", "FPerl_Focus", "FPerl_FocusTarget"}
for i = 1, 5 do
	FRAMES["FPerl_party" .. i], FRAMES["FPerl_partypet" .. i] = "party", "partypet"
	ORDER[#ORDER + 1] = "FPerl_party" .. i
	ORDER[#ORDER + 1] = "FPerl_partypet" .. i
end
for i = 1, 13 do
	FRAMES["FPerl_Raid_Title" .. i] = "raid"
	ORDER[#ORDER + 1] = "FPerl_Raid_Title" .. i
end

local byId
local function rowOf(id)
	if not byId then
		byId = {}
		for _, e in ipairs(FPerl.SettingsList) do byId[e.id] = e end
	end
	return byId[id]
end

local function percent(v) return format("%d%%", v * 100 + 0.5) end

-- The ordered items of a frame's menu: {id, kind = check|radio|scale|page|lock, label, get(), set(v), options = {{value, label}}}.
function FPerl.FrameMenuItems(frameName)
	local m = MENUS[FRAMES[frameName]]
	if not m then return {} end
	local items = {}
	for _, id in ipairs(m[3]) do
		local e = rowOf(id)
		if e then
			local item = {id = id, label = KEYS[id:match("[^.]+$")] or e.label}
			item.get = function() return FPerl.SettingsGetRow(id) end
			item.set = function(v) FPerl.SettingsSetRow(id, v) end
			if e.type == "check" then
				item.kind = "check"
			elseif e.type == "slider" then
				item.kind = "scale"
				item.options = {}
				local cur, found = item.get()
				for p = 50, 150, 10 do
					item.options[#item.options + 1] = {p / 100, p .. "%"}
					if math.abs(cur - p / 100) < 1e-6 then found = true end
				end
				if not found then
					item.options[#item.options + 1] = {cur, percent(cur)}
					table.sort(item.options, function(a, b) return a[1] < b[1] end)
				end
			else
				item.kind = "radio"
				item.options = {}
				if e.map then
					for i, entry in ipairs(e.map) do item.options[i] = {i, entry[1]} end
				else
					for i, o in ipairs(e.options) do item.options[i] = {i, o[2]} end
				end
			end
			items[#items + 1] = item
		end
	end
	local page = m[1]
	items[#items + 1] = {kind = "page", label = "All " .. m[2] .. " settings...", set = function() FPerl.SettingsOpenPage(page) end}
	items[#items + 1] = {kind = "lock", label = "Lock frames", set = function() FPerl.LockFrames() end}
	return items
end

local function openMenu(owner, frameName)
	if InCombatLockdown() or FPerl.Locked ~= 0 then return end
	local title = MENUS[FRAMES[frameName]][2]
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(title)
		for _, item in ipairs(FPerl.FrameMenuItems(frameName)) do
			if item.kind == "check" then
				root:CreateCheckbox(item.label, item.get, function() item.set(not item.get()) end)
			elseif item.kind == "radio" or item.kind == "scale" then
				local sub = root:CreateButton(item.label)
				for _, o in ipairs(item.options) do
					sub:CreateRadio(o[2], function() return item.get() == o[1] end, function() item.set(o[1]) end)
				end
			else
				if item.kind == "page" then root:CreateDivider() end
				root:CreateButton(item.label, item.set)
			end
		end
	end)
end

local overlays = {}
local function forward(script)
	return function(self)
		local f = self:GetParent()
		local fn = f:GetScript(script)
		if fn then fn(f) end
	end
end
local function make(name)
	local f = _G[name]
	local o = CreateFrame("Button", name .. "_MenuOverlay", f)
	o:SetAllPoints(f)
	o:SetFrameStrata("HIGH")
	o:RegisterForClicks("RightButtonUp")
	o:RegisterForDrag("LeftButton")
	o:SetScript("OnDragStart", forward("OnDragStart"))
	o:SetScript("OnDragStop", forward("OnDragStop"))
	o:SetScript("OnClick", function(self) openMenu(self, name) end)
	o:Hide()
	overlays[name] = o
	return o
end

-- Called by FPerl.ArrangeBarUpdate (unlock, lock, combat end): overlays are shown exactly while unlocked and out of combat.
function FPerl.FrameMenuUpdate()
	if InCombatLockdown() then return end -- the overlays were hidden by PLAYER_REGEN_DISABLED
	local on = FPerl.Locked == 0
	for _, name in ipairs(ORDER) do
		if _G[name] then
			local o = overlays[name]
			if on then
				o = o or make(name)
				o:Show()
			elseif o then
				o:Hide()
			end
		end
	end
end

FPerl.On("PLAYER_REGEN_DISABLED", function()
	for _, o in pairs(overlays) do o:Hide() end
end)
