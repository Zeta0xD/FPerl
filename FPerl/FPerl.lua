-- Author: Resike
-- License: GNU GPL v3, 18 October 2014

local conf

FPerl.RequestConfig(function(New)
	conf = New
end, "$Revision: 9c0697ce7ea46b29e24c894c5db60c3d931f5bdd $")
FPerl.SetModuleRevision("$Revision: 9c0697ce7ea46b29e24c894c5db60c3d931f5bdd $")

-- The few helpers used throughout this file
local CanAccess, IsSecret = FPerl.CanAccess, FPerl.IsSecret
local ForeverAPI = FPerl.ForeverAPI
------------------------------------------------------------------------------

-- Upvalues
local _G = _G
local error = error
local format = format
local hooksecurefunc = hooksecurefunc
local pairs = pairs
local select = select
local setmetatable = setmetatable
local strmatch = strmatch
local strupper = strupper
local tinsert = tinsert
local type = type
local CreateFrame = CreateFrame
local SecureButton_GetUnit = SecureButton_GetUnit
local UnitCanAssist = UnitCanAssist
local UnitCanAttack = UnitCanAttack
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid
local UnitInRange = UnitInRange
local UnitIsConnected = UnitIsConnected
local UnitIsDead = UnitIsDead
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsGhost = UnitIsGhost
local UnitIsVisible = UnitIsVisible
local UnregisterUnitWatch = UnregisterUnitWatch
local UIParent = UIParent

local ArcaneExclusions = FPerl.ArcaneExclusions


--[==[@debug@
local function d(...)
	ChatFrame1:AddMessage(format(...))
end
--@end-debug@]==]

-- Compact Raid frame manager
local c = _G.CompactRaidFrameManager
if c then
	c:SetFrameStrata("Medium")
end

------------------------------------------------------------------------------
-- Re-usable tables
local FreeTables = setmetatable({}, {__mode = "k"})

function FPerl.GetReusableTable(...)
	for t in pairs(FreeTables) do
		FreeTables[t] = nil
		for i = 1, select("#", ...) do
			t[i] = select(i, ...)
		end
		return t
	end
	return {...}
end

function FPerl.FreeTable(t, deep)
	if (t) then
		if (type(t) ~= "table") then
			error("Usage: FPerl.FreeTable([table])")
		end
		if (FreeTables[t]) then
			error("FPerl.FreeTable - Table already freed")
		end

		FreeTables[t] = true
		for k, v in pairs(t) do
			if (deep and type(v) == "table") then
				FPerl.FreeTable(v, true)
			end
			t[k] = nil
		end
		--t[''] = 0
		--t[''] = nil
	end
end

--local new, del = FPerl.GetReusableTable, FPerl.FreeTable

-- meta table for string based colours. Allows for other mods changing class colours and things all working
FPerl.ColourTable = setmetatable({ }, {
	__index = function(self, class)
		if not class then
			return
		end
		local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[strupper(class or "")]
		if (c) then
			c = format("|c00%02X%02X%02X", 255 * c.r, 255 * c.g, 255 * c.b)
		else
			c = "|c00808080"
		end
		self[class] = c
		return c
	end
})

--FPerl_Percent = setmetatable({},
--	{__mode = "kv",
--	__index = function(self, i)
--		if (type(i) == "number" and i >= 0) then
--			self[i] = format(percD, i)
--			return self[i]
--		end
--		return ""
--	end
--	})
--local xpPercent = FPerl_Percent


-- We have a dummy do-nothing function here for classes that don't have range checking
-- The do-something function is setup after variables_loaded and we work out spell to use just once
function FPerl.UpdateSpellRange()
	return
end

--local SpiritRealm = (C_Spell and C_Spell.GetSpellInfo(235621)) and C_Spell.GetSpellInfo(235621).name or GetSpellInfo(235621)

-- DoRangeCheck
local function DoRangeCheck(unit, opt)
	local range
	if opt.PlusHealth then
		local hp, hpMax = UnitHealth(unit), UnitHealthMax(unit)
		-- the health check needs maths, so it is skipped while the
		-- values are secret and the plain range check decides instead.
		if (CanAccess(hp) and CanAccess(hpMax)) then
			if (not ForeverAPI.healthPercent) then
				hp = UnitIsGhost(unit) and 1 or (UnitIsDead(unit) and 0 or hp)
			end
			-- Begin 4.3 divide by 0 work around.
			local percent
			if UnitIsDeadOrGhost(unit) or (hp == 0 and hpMax == 0) then -- Probably dead target
				percent = 0 -- So just automatically set percent to 0 and avoid division of 0/0 all together in this situation.
			elseif hp > 0 and hpMax == 0 then -- We have current HP but max hp failed.
				percent = 1 -- 100% if they are alive with > 0 cur hp, since curhp = maxhp in this hack.
			else
				percent = hp / hpMax -- Everything is dandy, so just do it right way.
			end
			-- End divide by 0 work around
			if (percent > opt.HealthLowPoint) then
				range = 0
			end
		end
	end

	-- UnitAuraByIndex fetches the aura list once per unit, filter and frame time (FPerl_Values.lua) and returns
	-- at once while auras are secret; this runs per frame per range tick only with the PlusDebuff option on
	if opt.PlusDebuff and ((opt.PlusHealth and range == 0) or not opt.PlusHealth) then
		local name = FPerl.UnitAuraByIndex(unit, 1, "HARMFUL|RAID")
		if not name then
			range = 0
		elseif not CanAccess(name) then
			-- A secret name still proves a curable debuff is there
			range = nil
		else
			if ArcaneExclusions[name] then
				-- It's one of the filtered debuffs, so we have to iterate thru all debuffs to see if anything is curable
				for i = 1, 40 do
					local auraName = FPerl.UnitAuraByIndex(unit, i, "HARMFUL|RAID")
					if not auraName then
						range = 0
						break
					elseif not CanAccess(auraName) or not ArcaneExclusions[auraName] then
						range = nil
						break
					end
				end
			else
				range = nil -- Override's the health check, because there's a debuff on unit
			end
		end
	end

	if not range then
		local kind = UnitCanAttack("player", unit) and "harm" or (UnitCanAssist("player", unit) and "help")
		local spell = kind and FPerl.RangeSpells[kind]
		if spell then
			range = C_Spell.IsSpellInRange(spell, unit)
		end
		-- No answer (no spell, or the check is invalid): a group member follows the group range, any other unit is in range.
		if not IsSecret(range) and range == nil then
			if FPerl.SafeBool(UnitInRaid(unit), false) or FPerl.SafeBool(UnitInParty(unit), false) then
				local checkedRange
				range, checkedRange = UnitInRange(unit)
				if not FPerl.SafeBool(checkedRange, true) then
					range = 1
				end
			else
				range = 1
			end
		end
	end

	-- a secret range result is returned as-is; the caller turns
	-- it into an alpha with FPerl.RangeAlpha instead of comparing it here.
	if (IsSecret(range)) then
		return range, true
	end

	if range ~= 1 and range ~= true then
		return opt.FadeAmount
	end
end

-- FPerl.RangeAlpha(result, secret, inAlpha, outAlpha)
-- Converts a DoRangeCheck result into an alpha value without Lua comparisons
-- when the result is secret. inAlpha is used when in range, outAlpha when not.
function FPerl.RangeAlpha(result, secret, inAlpha, outAlpha)
	if (secret) then
		if (ForeverAPI.booleanCurves) then
			return C_CurveUtil.EvaluateColorValueFromBoolean(result, inAlpha, outAlpha)
		end
		return inAlpha
	end
	if (result) then
		return outAlpha
	end
	return inAlpha
end

-- FPerl.UpdateSpellRangeSecure(self, unit, isRaidFrame)
-- Restricted-client version of the range fader. Every alpha is produced by
-- FPerl.RangeAlpha and handed straight to SetAlpha, so nothing here branches
-- on a unit value.
function FPerl.UpdateSpellRangeSecure(self, unit, isRaidFrame)
	local rf = conf.rangeFinder
	local base = conf.transparency.frame
	local mainA, nameA, statsA = base, 1, 1

	if (rf.enabled and (isRaidFrame or not rf.raidOnly)) then
		if (rf.Main.enabled) then
			local result, secret = DoRangeCheck(unit, rf.Main)
			mainA = FPerl.RangeAlpha(result, secret, base, base * rf.Main.FadeAmount)
		else
			if (rf.NameFrame.enabled) then
				local result, secret = DoRangeCheck(unit, rf.NameFrame)
				nameA = FPerl.RangeAlpha(result, secret, 1, rf.NameFrame.FadeAmount)
			end
			if (rf.StatsFrame.enabled) then
				local result, secret = DoRangeCheck(unit, rf.StatsFrame)
				statsA = FPerl.RangeAlpha(result, secret, 1, rf.StatsFrame.FadeAmount)
			end
		end
	end

	local connected = UnitIsConnected(unit)
	if (CanAccess(connected) and not connected) then
		mainA = base * rf.Main.FadeAmount
		nameA, statsA = 1, 1
	end

	self:SetAlpha(mainA)
	if (self.nameFrame) then
		self.nameFrame:SetAlpha(nameA)
	end
	if (self.statsFrame) then
		self.statsFrame:SetAlpha(statsA)
	end
end

-- FPerl.UpdateSpellRange(self)
function FPerl.UpdateSpellRange2(self, overrideUnit, isRaidFrame)
	local unit
	if (overrideUnit) then
		unit = overrideUnit
	else
		unit = self:GetAttribute("unit")
		if (not unit) then
			unit = SecureButton_GetUnit(self)
		end
	end
	if (unit) then
		if (ForeverAPI.booleanCurves) then
			FPerl.UpdateSpellRangeSecure(self, unit, isRaidFrame)
			return
		end

		local rf = conf.rangeFinder
		local mainA, nameA, statsA -- Receives main, name and stats alpha levels

		if (rf.enabled and (isRaidFrame or not conf.rangeFinder.raidOnly)) then
			if (not UnitIsVisible(unit)) then
				if (rf.Main.enabled) then
					mainA = conf.transparency.frame * rf.Main.FadeAmount
				else
					if (rf.NameFrame.enabled) then
						nameA = rf.NameFrame.FadeAmount
					end
					if (rf.StatsFrame.enabled) then
						statsA = rf.StatsFrame.FadeAmount
					end
				end
			else
				if (rf.Main.enabled) then
					mainA = DoRangeCheck(unit, rf.Main)
					if (mainA) then
						mainA = mainA * conf.transparency.frame
					end
				end

				if (rf.NameFrame.enabled) then
					-- check for the same health rule. Saves doing the check multiple times
					if (rf.Main.enabled and (rf.Main.PlusHealth == rf.NameFrame.PlusHealth)) then
						if (mainA) then
							nameA = rf.NameFrame.FadeAmount
						end
					else
						nameA = DoRangeCheck(unit, rf.NameFrame)
						if (not nameA and mainA) then
							-- In range, but 'Whole' frame is out of range, so we need to override the fade for name
							nameA = 1
						end
					end
				end
				if (rf.StatsFrame.enabled) then
					-- check for the same health rule. Saves doing the check multiple times
					if (rf.Main.enabled and (rf.Main.PlusHealth == rf.StatsFrame.PlusHealth)) then
						if (mainA) then
							statsA = rf.StatsFrame.FadeAmount
						end
					else
						statsA = DoRangeCheck(unit, rf.StatsFrame)
						if (not statsA and mainA) then
							-- In range, but 'Whole' frame is out of range, so we need to override the fade for stats
							statsA = 1
						end
					end
				end
			end
		end

		local forcedMainA
		if (not mainA) then
			if (UnitIsConnected(unit)) then
				mainA = conf.transparency.frame
				forcedMainA = true
			else
				mainA = conf.transparency.frame * rf.Main.FadeAmount
				nameA, statsA = mainA
				forcedMainA = true
			end
		end

		self:SetAlpha(mainA)
		if (self.nameFrame) then
			if (nameA or forcedMainA) then
				self.nameFrame:SetAlpha(nameA or mainA)
			else
				self.nameFrame:SetAlpha(1)
			end
		end
		if (self.statsFrame) then
			if (nameA or forcedMainA) then
				self.statsFrame:SetAlpha(statsA or mainA)
			else
				self.statsFrame:SetAlpha(1)
			end
		end
	end
end

-- FPerl.RangeSpells = {help = spellID, harm = spellID}
-- The spells DoRangeCheck asks for a friendly and a hostile unit. Runtime only, never saved.
FPerl.RangeSpells = {}

-- FPerl.PickRangeSpells()
-- Picks from the player's spellbook the helpful and the harmful spell with the longest range. A spell with
-- a minimum range is skipped: it would fade a close enemy. The first spell found wins a tie.
function FPerl.PickRangeSpells()
	local bank, spellType = Enum.SpellBookSpellBank.Player, Enum.SpellBookItemType.Spell
	local help, harm, helpRange, harmRange
	for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
		local line = C_SpellBook.GetSpellBookSkillLineInfo(i)
		if (line and not line.shouldHide and not line.isGuild and not line.offSpecID) then
			for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
				local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
				local id = item and item.itemType == spellType and not item.isPassive and not item.isOffSpec and item.spellID
				if (id and C_Spell.SpellHasRange(id)) then
					local info = C_Spell.GetSpellInfo(id)
					if (info and info.minRange == 0 and info.maxRange) then
						if (C_Spell.IsSpellHelpful(id) and (not helpRange or info.maxRange > helpRange)) then
							help, helpRange = id, info.maxRange
						end
						if (C_Spell.IsSpellHarmful(id) and (not harmRange or info.maxRange > harmRange)) then
							harm, harmRange = id, info.maxRange
						end
					end
				end
			end
		end
	end
	FPerl.RangeSpells.help, FPerl.RangeSpells.harm = help, harm
end

FPerl.On("SPELLS_CHANGED", FPerl.PickRangeSpells)

-- FPerl.StartupSpellRange()
function FPerl.StartupSpellRange()
	local rf = conf.rangeFinder

	local function Setup1(self)
		if (not self.FadeAmount) then
			self.FadeAmount = 0.3
		end
		if (not self.HealthLowPoint) then
			self.HealthLowPoint = 0.7
		end
	end

	Setup1(rf.Main)
	Setup1(rf.NameFrame)
	Setup1(rf.StatsFrame)

	FPerl.Pcall(FPerl.PickRangeSpells)
	-- Put the real work function in place
	FPerl.UpdateSpellRange = FPerl.UpdateSpellRange2
end

FPerl.RegisterOptionChanger(FPerl.StartupSpellRange, nil, "spellrange")

-- StatsFrameSetGrey
local function StatsFrameSetGrey(self, r, g, b)
	if (not r) then
		r, g, b = 0.5, 0.5, 0.5
	end

	self.healthBar:SetStatusBarColor(r, g, b, 1)
	self.healthBar.bg:SetVertexColor(r, g, b, 0.5)
	if (self.manaBar) then
		self.manaBar:SetStatusBarColor(r, g, b, 1)
		self.manaBar.bg:SetVertexColor(r, g, b, 0.5)
	end
	self.greyMana = true
end

-- FPerl.SetChildMembers - Recursive
-- This iterates a frame's child frames and regions and assigns member variables
-- based on the sub-set part of the child's name compared to the parent frame name
function FPerl.SetChildMembers(self)
	local n = self:GetName()
	if (n) then
		local match = "^"..n.."(.+)$"

		local function AddList(list)
			for k, v in pairs(list) do
				local t = v:GetName()
				if (t) then
					local found = strmatch(t, match)
					if (found) then
						--if (self[found] == v) then
						--	break		-- Already done
						--end
						self[found] = v
					end
				end
			end
		end

		AddList({self:GetRegions()})

		local c = {self:GetChildren()}
		AddList(c, true)

		for k, v in pairs(c) do
			if (v:GetName()) then
				FPerl.SetChildMembers(v)
			end
			v:SetScript("OnLoad", nil)
		end

		self:SetScript("OnLoad", nil)
	end
end

do
	local shortlist
	local media

	-- FPerl.RegisterSMBarTextures
	function FPerl.RegisterSMBarTextures()
		if (LibStub) then
			media = LibStub("LibSharedMedia-3.0", true)
		end

		shortlist = {
			{"Perl v2", "Interface\\AddOns\\FPerl\\Images\\FPerl_StatusBar"},
		}
		for i = 1, 9 do
			local name = i == 2 and "BantoBar" or "X-Perl "..i
			tinsert(shortlist, {name, "Interface\\AddOns\\FPerl\\Images\\FPerl_StatusBar"..(i + 1)})
		end

		if (media) then
			for k, v in pairs(shortlist) do
				media:Register("statusbar", v[1], v[2])
			end

			media:Register("border", "X-Perl Thin", "Interface\\AddOns\\FPerl\\Images\\FPerl_ThinEdge")
		end
	end
end

-- FPerl.GetBarTexture
function FPerl.GetBarTexture()
	local texture = conf and conf.bar and conf.bar.texture and conf.bar.texture[2]
	if texture then
		return texture
	end
	return "Interface\\AddOns\\FPerl\\Images\\FPerl_StatusBar"
end

-- FPerl.StatsFrameOnLoad
function FPerl.StatsFrameOnLoad(self)
	self:OnBackdropLoaded()
	FPerl.SetChildMembers(self)
	self.SetGrey = StatsFrameSetGrey
end

-- FPerl.GetClassColour
local defaultColour = {r = 0.5, g = 0.5, b = 1}
function FPerl.GetClassColour(class)
	return (class and CanAccess(class) and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]) or defaultColour
end

local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()
local hideWanted = {}	-- frame -> true while F-Perl keeps it hidden
local ownParent = {}	-- frame -> the parent it goes back to when F-Perl stops hiding it
local hideHooked = {}
local reparenting

local function applyBlizzHide(frame)
	reparenting = true
	if (hideWanted[frame]) then
		frame:SetParent(hiddenParent)
	elseif (ownParent[frame]) then
		-- a parent F-Perl hides (the cast bar locked to PlayerFrame) would keep it hidden
		local parent = ownParent[frame]
		frame:SetParent(hideWanted[parent] and UIParent or parent)
		ownParent[frame] = nil
	end
	reparenting = nil
end

local function blizzHideNow(frame)
	-- in combat even an unprotected frame waits: Blizzard's layout code runs on its reparent
	FPerl.AfterCombatFor(applyBlizzHide, frame)
end

-- FPerl.BlizzFrameHide(frame, hide)
-- The one way F-Perl hides a Blizzard frame: parented to a
-- hidden frame, so no Show() of Blizzard's makes it visible, and a SetParent of Blizzard's is undone.
-- hide false gives the frame its parent back. In combat the frame moves at combat end.
function FPerl.BlizzFrameHide(frame, hide)
	if (not frame or not hide == not hideWanted[frame]) then
		return
	end
	if (hide and not ownParent[frame]) then
		ownParent[frame] = frame:GetParent() or UIParent
	end
	hideWanted[frame] = hide and true or nil
	if (hide and not hideHooked[frame]) then
		hideHooked[frame] = true
		hooksecurefunc(frame, "SetParent", function(self, parent)
			if (reparenting or not hideWanted[self]) then
				return
			end
			-- Blizzard moved it: that parent is the one to give back
			ownParent[self] = parent
			blizzHideNow(self)
		end)
	end
	blizzHideNow(frame)
end

---------------------------------
--Loading Function             --
---------------------------------

-- FPerl.BlizzFrameDisable(frame)
-- Hides a Blizzard frame for good: its events (and its bars' events) off, then FPerl.BlizzFrameHide.
function FPerl.BlizzFrameDisable(self)
	if not self then
		return
	end

	UnregisterUnitWatch(self)

	self:UnregisterAllEvents()

	if self == PlayerFrame then
		if AlternatePowerBar then
			AlternatePowerBar:UnregisterAllEvents()
		end
	end

	self:SetMovable(true)
	self:SetUserPlaced(true)
	self:SetDontSavePosition(true)
	self:SetMovable(false)

	FPerl.BlizzFrameHide(self, true)

	local health = self.healthBar or self.healthbar or self.HealthBar
	if health then
		health:UnregisterAllEvents()
	end

	local power = self.manabar or self.ManaBar
	if power then
		power:UnregisterAllEvents()
	end

	local spell = self.castBar or self.spellbar or self.CastingBarFrame
	if spell then
		spell:UnregisterAllEvents()
	end

	local powerBarAlt = self.powerBarAlt or self.PowerBarAlt
	if powerBarAlt then
		powerBarAlt:UnregisterAllEvents()
	end

	local buffFrame = self.BuffFrame
	if buffFrame then
		buffFrame:UnregisterAllEvents()
	end

	local debuffFrame = self.DebuffFrame
	if debuffFrame then
		debuffFrame:UnregisterAllEvents()
	end

	-- The player frame's class power bar also drives the Personal Resource Display's class
	-- resource (e.g. combo points, which other addons can show on the target nameplate).
	local classPowerBar = self.classPowerBar
	if classPowerBar and self ~= PlayerFrame then
		classPowerBar:UnregisterAllEvents()
	end

	local ccRemoverFrame = self.CcRemoverFrame
	if ccRemoverFrame then
		ccRemoverFrame:UnregisterAllEvents()
	end

	local petFrame = self.petFrame or self.PetFrame
	if petFrame then
		petFrame:UnregisterAllEvents()
	end
end

-- FPerl.MainFrameStart(frame, on, blizz)
-- The once-a-session start of the Player, Pet and Target frames, run at the first profile hand-out (the
-- addon's files run before SavedVariables are read); their enable key takes effect after a reload. On:
-- Blizzard's frame is hidden for good. Off: the F-Perl frame is hidden, its unit watch and events are off and
-- frame.off stops its Set_Bits; Blizzard's frame stays as it is.
function FPerl.MainFrameStart(frame, on, blizz)
	if frame.started then
		return
	end
	frame.started = true
	if on then
		FPerl.BlizzFrameDisable(blizz)
		return
	end
	frame.off = true
	UnregisterUnitWatch(frame)
	frame:UnregisterAllEvents()
	FPerl.AfterCombatFor(frame.Hide, frame)
end

