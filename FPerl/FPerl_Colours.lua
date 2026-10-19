-- Author: Resike
-- License: GNU GPL v3, 18 October 2014

-- Health, power and reaction colours, the unit tooltip, the combat flash and the debuff highlight.

local conf

FPerl.RequestConfig(function(New)
	conf = New
end, "$Revision: 1 $")

local max = max
local min = min
local setmetatable = setmetatable
local type = type
local unpack = unpack
local DebuffTypeColor = DebuffTypeColor or {
	none    = { r = 0.80, g = 0.00, b = 0.00 },
	Magic   = { r = 0.20, g = 0.60, b = 1.00 },
	Curse   = { r = 0.60, g = 0.00, b = 1.00 },
	Disease = { r = 0.60, g = 0.40, b = 0.00 },
	Poison  = { r = 0.00, g = 0.60, b = 0.00 },
}
local InCombatLockdown = InCombatLockdown
local IsAltKeyDown = IsAltKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsShiftKeyDown = IsShiftKeyDown
local SecureButton_GetUnit = SecureButton_GetUnit
local SetCursor = SetCursor
local SpellCanTargetUnit = SpellCanTargetUnit
local SpellIsTargeting = SpellIsTargeting
local UnitCanAttack = UnitCanAttack
local UnitClass = UnitClass
local UnitFactionGroup = UnitFactionGroup
local UnitGUID = UnitGUID
local UnitIsEnemy = UnitIsEnemy
local UnitIsFriend = UnitIsFriend
local UnitIsPlayer = UnitIsPlayer
local UnitIsPVP = UnitIsPVP
local UnitIsTapDenied = UnitIsTapDenied
local UnitIsVisible = UnitIsVisible
local UnitPlayerControlled = UnitPlayerControlled
local UnitPowerType = UnitPowerType
local UnitReaction = UnitReaction
local GameTooltip = GameTooltip

local CanAccess = FPerl.CanAccess
local ForeverAPI = FPerl.ForeverAPI
local colourCurves = { }	-- cached Blizzard colour curves and small colour tables
FPerl.colourCurves = colourCurves
local ArcaneExclusions = FPerl.ArcaneExclusions
local playerClass = select(2, UnitClass("player"))

-- FPerl.HealthColourCurve
-- the same gradient as FPerl.SetSmoothBarColor, built as a
-- Blizzard ColorCurve so UnitHealthPercent can evaluate it on a secret percent.
function FPerl.HealthColourCurve()
	if (colourCurves.health or not ForeverAPI.colorCurves) then
		return colourCurves.health
	end
	local curve = C_CurveUtil.CreateColorCurve()
	curve:SetType(Enum.LuaCurveType.Linear)
	if (conf.colour.classic) then
		curve:AddPoint(0, CreateColor(1, 0, 0, 1))
		curve:AddPoint(0.5, CreateColor(1, 1, 0, 1))
		curve:AddPoint(1, CreateColor(0, 1, 0, 1))
	else
		local c = conf.colour.bar
		curve:AddPoint(0, CreateColor(c.healthEmpty.r, c.healthEmpty.g, c.healthEmpty.b, 1))
		curve:AddPoint(1, CreateColor(c.healthFull.r, c.healthFull.g, c.healthFull.b, 1))
	end
	colourCurves.health = curve
	return curve
end

-- FPerl.HealthColour(unit)
-- Colour object for the unit's current health, safe to pass to SetStatusBarColor
function FPerl.HealthColour(unit)
	local curve = FPerl.HealthColourCurve()
	if (curve and unit and ForeverAPI.healthPercent) then
		return UnitHealthPercent(unit, true, curve)
	end
end

---------------------------------
--Smooth Health Bar Color      --
---------------------------------
function FPerl.SetSmoothBarColor(self, partyid)
	if (self) then
		-- Blizzard evaluates the gradient for us
		local color = FPerl.HealthColour(partyid or self.partyid)
		if (not color) then
			return
		end
		local r, g, b = color.r, color.g, color.b

		self:SetStatusBarColor(r, g, b)

		if (self.bg) then
			self.bg:SetVertexColor(r, g, b, 0.25)
		end
	end
end

local barColours
function FPerl.ResetBarColourCache()
	colourCurves.health = nil
	barColours = setmetatable({ }, {
		__index = function(self, k)
			local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[k]
			if (c) then
				if (not conf.colour.classbarBright) then
					conf.colour.classbarBright = 1
				end
				self[k] = {
					r = max(0, min(1, c.r * conf.colour.classbarBright)),
					g = max(0, min(1, c.g * conf.colour.classbarBright)),
					b = max(0, min(1, c.b * conf.colour.classbarBright))
				}
				return self[k]
			end
		end
	})
end
FPerl.ResetBarColourCache()

-- FPerl.ColourHealthBar
function FPerl.ColourHealthBar(self, partyid)
	if (not partyid) then
		partyid = self.partyid
	end
	local bar = self.statsFrame.healthBar
	if (conf.colour.classbar) then
		local _, class = UnitClass(partyid)
		if (class and CanAccess(class)) then
			if (UnitIsPlayer(partyid)) then
				local c = barColours[class]
				if (c) then
					bar:SetStatusBarColor(c.r, c.g, c.b)
					if (bar.bg) then
						bar.bg:SetVertexColor(c.r, c.g, c.b, 0.25)
					end
					return
				end
			end
		end
	end

	FPerl.SetSmoothBarColor(bar, partyid)
end
--local FPerl.ColourHealthBar = FPerl.ColourHealthBar

-- FPerl.SetValuedText
function FPerl.SetValuedText(self, unitHealth, unitHealthMax, suffix)
	local hpText, maxText = FPerl.ShortPair(unitHealth, unitHealthMax)
	self:SetFormattedText("%s/%s%s", hpText, maxText, suffix or "")
end

-- FPerl.SetHealthBar(self): the health element reads the unit's values itself; the extra
-- arguments old callers still pass are ignored
function FPerl.SetHealthBar(self)
	FPerl.HealthUpdate(self)
end

---------------------------------
--Class Icon Location Functions--
---------------------------------
--local ClassPos = {
--	WARRIOR	= {0,    0.25,    0,	0.25},
--	MAGE	= {0.25, 0.5,     0,	0.25},
--	ROGUE	= {0.5,  0.75,    0,	0.25},
--	DRUID	= {0.75, 1,       0,	0.25},
--	HUNTER	= {0,    0.25,    0.25,	0.5},
--	SHAMAN	= {0.25, 0.5,     0.25,	0.5},
--	PRIEST	= {0.5,  0.75,    0.25,	0.5},
--	WARLOCK	= {0.75, 1,       0.25,	0.5},
--	PALADIN	= {0,    0.25,    0.5,	0.75},
--	none	= {0.25, 0.5, 0.5, 0.75},
--}
--function FPerl.ClassPos(class)
--	return unpack(ClassPos[class] or ClassPos.none)
--end

local CLASS_ICON_TCOORDS = CLASS_ICON_TCOORDS
function FPerl.ClassPos(unitClass)
	if (not CanAccess(unitClass)) then
		return 0.25, 0.5, 0.5, 0.75
	end
	local b = CLASS_ICON_TCOORDS[unitClass]		-- Now using the Blizzard supplied from FrameXML/WorldStateFrame.lua
	if (b) then
		return unpack(b)
	end
	return 0.25, 0.5, 0.5, 0.75
end


function FPerl.GetDisplayedPowerType(unitID)
	return UnitPowerType(unitID) or 0
end

local ManaColours = {
	[Enum.PowerType.Mana] = "mana",
	[Enum.PowerType.Rage] = "rage",
	[Enum.PowerType.Focus] = "focus",
	[Enum.PowerType.Energy] = "energy",
	[Enum.PowerType.Alternate] = "energy", -- used by some bosses, show it as energy bar
}

-- Forever may expose a usable power token while its numeric power type is
-- restricted or differs from the retail Enum table. Keep the classic X-Perl
-- colours available independently of saved-profile migration.
local PowerTokenColours = {
	MANA = "mana",
	RAGE = "rage",
	FOCUS = "focus",
	ENERGY = "energy",
}
local DefaultPowerColours = {
	mana = {r = 0, g = 0, b = 1},
	rage = {r = 1, g = 0, b = 0},
	focus = {r = 1, g = 0.5, b = 0.25},
	energy = {r = 1, g = 1, b = 0},
}

-- FPerl.SetManaBarType
function FPerl.SetManaBarType(self)
	local m = self.statsFrame.manaBar
	if (m and not self.statsFrame.greyMana) then
		local unit = self.partyid -- SecureButton_GetUnit(self)
		if not unit then
			self.targetmanatype = 0
			return
		end
		if (unit) then
			local p, powerToken = UnitPowerType(unit)
			self.targetmanatype = p
			local colourKey
			if CanAccess(p) then
				colourKey = ManaColours[p]
			end
			if not colourKey and CanAccess(powerToken) then
				colourKey = PowerTokenColours[powerToken]
			end
			local c = colourKey and ((conf.colour.bar and conf.colour.bar[colourKey]) or DefaultPowerColours[colourKey])
			if (c) then
				m:SetStatusBarColor(c.r, c.g, c.b, 1)
				m.bg:SetVertexColor(c.r, c.g, c.b, 0.25)
			end
		end
	end
end

-- FPerl.TooltipModiferPressed
function FPerl.TooltipModiferPressed(buffs)
	local mod, ic
	if (buffs) then
		if (not conf.tooltip.enableBuffs) then
			return
		end
		mod = conf.tooltip.buffModifier
		ic = conf.tooltip.buffHideInCombat
	else
		if (not conf.tooltip.enable) then
			return
		end
		mod = conf.tooltip.modifier
		ic = conf.tooltip.hideInCombat
	end

	if (mod == "alt") then
		mod = IsAltKeyDown()
	elseif (mod == "shift") then
		mod = IsShiftKeyDown()
	elseif (mod == "control") then
		mod = IsControlKeyDown()
	else
		mod = true
	end

	mod = mod and (not ic or not InCombatLockdown())

	return mod
end

-- FPerl.PlayerTip
function FPerl.PlayerTip(self, unitid)
	if (not unitid) then
		unitid = SecureButton_GetUnit(self)
	end

	if (not unitid or FPerl.Locked == 0) then
		return
	end

	if (not FPerl.TooltipModiferPressed()) then
		return
	end

	-- SpellCanTargetUnit is absent on this client; skip the cursor change rather than error.
	if (SpellCanTargetUnit and SpellIsTargeting()) then
		if (SpellCanTargetUnit(unitid)) then
			SetCursor("CAST_CURSOR")
		else
			SetCursor("CAST_ERROR_CURSOR")
		end
	end

	GameTooltip_SetDefaultAnchor(GameTooltip, self)
	GameTooltip:SetUnit(unitid)
	-- SetUnit supplies the tooltip's name color. On restricted clients the
	-- legacy color helper tests secret unit booleans when called by an addon.
	if (not issecretvalue and not canaccessvalue) then
		local r, g, b = GameTooltip_UnitColor(unitid)
		GameTooltipTextLeft1:SetTextColor(r, g, b)
	end
	GameTooltip:Show()

	if (FPerl.Raid.RaidTipExtra) then
		FPerl.Raid.RaidTipExtra(unitid)
	end

	FPerl_Highlight:TooltipInfo(UnitGUID(unitid))
end

-- FPerl.PlayerTipHide
function FPerl.PlayerTipHide()
	if (conf.tooltip.fading) then
		GameTooltip:FadeOut()
	else
		GameTooltip:Hide()
	end
end

-- FPerl.ColourFriendlyUnit
function FPerl.ColourFriendlyUnit(self, partyid)
	local color
	-- FPerl.SafeBool turns a secret boolean into the given default
	if (FPerl.SafeBool(UnitCanAttack("player", partyid), false) and FPerl.SafeBool(UnitIsEnemy("player", partyid), false)) then	-- For dueling
		color = conf.colour.reaction.enemy
	else
		if (conf.colour.class) then
			local _, class = UnitClass(partyid)
			color = FPerl.GetClassColour(class)
		else
			if (FPerl.SafeBool(UnitIsPVP(partyid), false)) then
				color = conf.colour.reaction.friend
			else
				color = conf.colour.reaction.none
			end
		end
	end

	self:SetTextColor(color.r, color.g, color.b, conf.transparency.text)
end

-- FPerl.SameFaction
-- faction names can be secret for creatures inside instances
function FPerl.SameFaction(argUnit)
	local mine, theirs = UnitFactionGroup("player"), UnitFactionGroup(argUnit)
	if (not CanAccess(theirs)) then
		return false
	end
	return mine == theirs
end

-- FPerl.ReactionColour
function FPerl.ReactionColour(argUnit)
	-- every boolean here can be secret for indirect units and
	-- creatures inside instances; FPerl.SafeBool supplies a neutral default
	if (FPerl.SafeBool(UnitPlayerControlled(argUnit), false) or not FPerl.SafeBool(UnitIsVisible(argUnit), true)) then
		if (FPerl.SameFaction(argUnit)) then
			if (FPerl.SafeBool(UnitIsEnemy("player", argUnit), false)) then
				-- Dueling
				return conf.colour.reaction.enemy
			elseif (FPerl.SafeBool(UnitIsPVP(argUnit), false)) then
				return conf.colour.reaction.friend
			end
		else
			if (FPerl.SafeBool(UnitIsPVP(argUnit), false)) then
				if (UnitIsPVP("player")) then
					return conf.colour.reaction.enemy
				else
					return conf.colour.reaction.neutral
				end
			end
		end
	else
		if FPerl.SafeBool(UnitIsTapDenied(argUnit), false) and not FPerl.SafeBool(UnitIsFriend("player", argUnit), true) then
			return conf.colour.reaction.tapped
		else
			local reaction = UnitReaction(argUnit, "player")
			if (reaction and CanAccess(reaction)) then
				if (reaction >= 5) then
					return conf.colour.reaction.friend
				elseif (reaction <= 2) then
					return conf.colour.reaction.enemy
				elseif (reaction == 3) then
					return conf.colour.reaction.unfriendly
				else
					return conf.colour.reaction.neutral
				end
			else
				if (FPerl.SameFaction(argUnit)) then
					return conf.colour.reaction.friend
				elseif (FPerl.SafeBool(UnitIsEnemy("player", argUnit), false)) then
					return conf.colour.reaction.enemy
				else
					return conf.colour.reaction.neutral
				end
			end
		end
	end

	return conf.colour.reaction.none
end

-- FPerl.SetUnitNameColor
function FPerl.SetUnitNameColor(self, unit)
	local color
	if (FPerl.SafeBool(UnitIsPlayer(unit), false) or not FPerl.SafeBool(UnitIsVisible(unit), true)) then -- Changed UnitPlayerControlled to UnitIsPlayer for 2.3.5
		-- 1.8.3 - Changed to override pvp name colours
		if (conf.colour.class) then
			local _, class = UnitClass(unit)
			color = FPerl.GetClassColour(class)
		else
			color = FPerl.ReactionColour(unit)
		end
	else
		if FPerl.SafeBool(UnitIsTapDenied(unit), false) and not FPerl.SafeBool(UnitIsFriend("player", unit), true) then
			color = conf.colour.reaction.tapped
		else
			color = FPerl.ReactionColour(unit)
		end
	end

	self:SetTextColor(color.r, color.g, color.b, conf.transparency.text)
end

-- FPerl.CombatFlashSet
function FPerl.CombatFlashSet(self, elapsed, argNew, argGreen)
	if (not conf.combatFlash) then
		self.PlayerFlash = nil
		return
	end

	if (self) then
		if (argNew) then
			self.PlayerFlash = 1.2 -- Old value: 1.5
			self.PlayerFlashGreen = argGreen
		else
			if (elapsed and self.PlayerFlash) then
				self.PlayerFlash = self.PlayerFlash - elapsed

				if (self.PlayerFlash <= 0) then
					self.PlayerFlash = 0
					self.PlayerFlashGreen = nil
				end
			else
				return
			end
		end

		return true
	end
end

-- FPerl.OnUpdateIdle: the unit frames set OnUpdate when a combat flash or hit text starts (UNIT_COMBAT)
-- and call this at the end of each tick; it clears the script once nothing animates.
function FPerl.OnUpdateIdle(self, feedback)
	if not self.PlayerFlash and not (feedback and self.feedbackText and self.feedbackText:IsShown()) then
		self:SetScript("OnUpdate", nil)
	end
end

-- FPerl.CombatFlashSetFrames
function FPerl.CombatFlashSetFrames(self)
	if (self.PlayerFlash) then
		local baseColour = self.forcedColour or conf.colour.border

		local r, g, b, a
		if (self.PlayerFlash > 0) then
			local flashOffsetColour = min(self.PlayerFlash, 1) / 2
			if (self.PlayerFlashGreen) then
				r = min(1, max(0, baseColour.r - flashOffsetColour))
				g = min(1, max(0, baseColour.g + flashOffsetColour))
			else
				r = min(1, max(0, baseColour.r + flashOffsetColour))
				g = min(1, max(0, baseColour.g - flashOffsetColour))
			end
			b = min(1, max(0, baseColour.b - flashOffsetColour))
			a = min(1, max(0, baseColour.a + flashOffsetColour))
		else
			r, g, b, a = baseColour.r, baseColour.g, baseColour.b, baseColour.a
			self.PlayerFlash = false
		end

		for i = 1, #self.FlashFrames do
			self.FlashFrames[i]:SetBackdropBorderColor(r, g, b, a)
		end
	end
end

local MagicCureTalentsClassic = {
	["PALADIN"] = 4987, -- Clense
}

local MagicCureTalents = {
	["DRUID"] = 4, -- Resto
	["PALADIN"] = 1, -- Holy
	["SHAMAN"] = 3, -- Resto
}

local function CanClassCureMagic(class)
	if (MagicCureTalents[class]) then
		return MagicCureTalentsClassic[class] and IsSpellKnown(MagicCureTalentsClassic[class])
	end
end

local getShow
function FPerl.DebufHighlightInit()
	-- We also re-set the colours here so that we highlight best colour per class
	if (playerClass == "MAGE") then
		getShow = function(Curses)
			local show
			if (not conf.highlightDebuffs.class) then
				show = Curses.Magic or Curses.Curse or Curses.Poison or Curses.Disease
			end
			return Curses.Curse or show
		end
	elseif (playerClass == "DRUID") then
		getShow = function(Curses)
			local show
			if (not conf.highlightDebuffs.class) then
				show = Curses.Magic or Curses.Curse or Curses.Poison or Curses.Disease
			end
			local magic
			if (CanClassCureMagic(playerClass)) then
				magic = Curses.Magic
			end
			return Curses.Curse or Curses.Poison or magic or show
		end
	elseif (playerClass == "PRIEST") then
		getShow = function(Curses)
			local show
			if (not conf.highlightDebuffs.class) then
				show = Curses.Magic or Curses.Curse or Curses.Poison or Curses.Disease
			end
			return Curses.Magic or Curses.Disease or show
		end
	elseif (playerClass == "WARLOCK") then
		getShow = function(Curses)
			local show
			if (not conf.highlightDebuffs.class) then
				show = Curses.Magic or Curses.Curse or Curses.Poison or Curses.Disease
			end
			return Curses.Magic or show
		end
	elseif (playerClass == "PALADIN") then
		getShow = function(Curses)
			local show
			if (not conf.highlightDebuffs.class) then
				show = Curses.Magic or Curses.Curse or Curses.Poison or Curses.Disease
			end
			local magic
			if (CanClassCureMagic(playerClass)) then
				magic = Curses.Magic
			end
			return Curses.Poison or Curses.Disease or magic or show
		end
	elseif (playerClass == "SHAMAN") then
		getShow = function(Curses)
			local show
			if (not conf.highlightDebuffs.class) then
				show = Curses.Magic or Curses.Curse or Curses.Poison or Curses.Disease
			end
			local magic
			if (CanClassCureMagic(playerClass)) then
				magic = Curses.Magic
			end
			return Curses.Poison or Curses.Disease or magic or show
		end
	elseif (playerClass == "ROGUE") then
		getShow = function(Curses)
			local show
			if (not conf.highlightDebuffs.class) then
				show = Curses.Magic or Curses.Curse or Curses.Poison or Curses.Disease
			end
			return Curses.Poison or show
		end
	else
		getShow = function(Curses)
			return Curses.Magic or Curses.Curse or Curses.Poison or Curses.Disease
		end
	end

	FPerl.DebufHighlightInit = nil
end

local bgDef = {
	bgFile = "Interface\\AddOns\\FPerl\\Images\\FPerl_FrameBack",
	edgeFile = "",
	tile = true,
	tileSize = 32,
	edgeSize = 16,
	insets = {left = 2, right = 2, top = 2, bottom = 2}
}
local normalEdge = "Interface\\Tooltips\\UI-Tooltip-Border"
local curseEdge = "Interface\\AddOns\\FPerl\\Images\\FPerl_Curse"

-- SetBackdrop rebuilds the border and background textures, so it runs only when the edge definition
-- changed since the last call for that frame. Colours are cheap and other code changes them, so
-- they are set on every call.
local function setFlashBackdrop(f)
	local d = bgDef
	local inset = d.insets.left
	if f.xpBdEdge ~= d.edgeFile or f.xpBdSize ~= d.edgeSize or f.xpBdInset ~= inset then
		f.xpBdEdge, f.xpBdSize, f.xpBdInset = d.edgeFile, d.edgeSize, inset
		-- a copy: the frame keeps the table it is given, and bgDef changes on every call
		f:SetBackdrop({bgFile = d.bgFile, edgeFile = d.edgeFile, tile = d.tile, tileSize = d.tileSize,
			edgeSize = d.edgeSize, insets = {left = inset, right = d.insets.right, top = d.insets.top, bottom = d.insets.bottom}})
	end
end

-- FPerl.CheckDebuffs
--local Curses = setmetatable({ }, {__mode = "k"})	-- 2.2.6 - Now re-using static table to save garbage memory creation
local Curses = { }
function FPerl.CheckDebuffs(self, unit, resetBorders)
	if not self.FlashFrames then
		return
	end

	local high = conf.highlightDebuffs.enable or (self == FPerl_Target and conf.target.highlightDebuffs.enable) or (self == FPerl_Focus and conf.focus.highlightDebuffs.enable)

	if resetBorders or not high or not getShow then
		-- Reset the frame edges back to normal in case they changed options while debuffed.
		self.forcedColour = nil
		bgDef.edgeFile = self.edgeFile or normalEdge
		bgDef.edgeSize = self.edgeSize or 16
		bgDef.insets.left = self.edgeInsets or 3
		bgDef.insets.top = self.edgeInsets or 3
		bgDef.insets.right = self.edgeInsets or 3
		bgDef.insets.bottom = self.edgeInsets or 3
		--for i, f in pairs(self.FlashFrames) do
		for i = 1, #self.FlashFrames do
			local f = self.FlashFrames[i]
			setFlashBackdrop(f)
			f:SetBackdropColor(conf.colour.frame.r, conf.colour.frame.g, conf.colour.frame.b, conf.colour.frame.a)
			f:SetBackdropBorderColor(conf.colour.border.r, conf.colour.border.g, conf.colour.border.b, conf.colour.border.a)
		end
		return
	end

	if not unit then
		unit = self:GetAttribute("unit")
		if not unit then
			return
		end
	end

	Curses.Magic, Curses.Curse, Curses.Poison, Curses.Disease = nil, nil, nil, nil

	local show
	local debuffCount = 0
	local _, unitClass = UnitClass(unit)
	if (not CanAccess(unitClass)) then
		unitClass = nil
	end

	for i = 1, 40 do
		local name, dispelName
		local _
		name, _, _, dispelName = FPerl.UnitAuraByIndex(unit, i, "HARMFUL")
		if not name then
			break
		end

		-- secret aura names/types cannot be looked up, skip them
		if dispelName and CanAccess(dispelName) and CanAccess(name) then
			local exclude = ArcaneExclusions[name]
			if not exclude or (type(exclude) == "table" and not exclude[unitClass]) then
				Curses[dispelName] = dispelName
				debuffCount = debuffCount + 1
			end
		end
	end

	if debuffCount > 0 then
		-- 2.2.6 - Very (very very) slight speed optimazation by having a function per class which is set at startup
		show = getShow(Curses)
	end

	local colour, borderColour
	if show then
		colour = DebuffTypeColor[show]
		colour.a = 1

		if conf.highlightDebuffs.border then
			borderColour = colour
		else
			borderColour = conf.colour.border
		end
	else
		colour = conf.colour.frame
		borderColour = conf.colour.border
	end

	if show and conf.highlightDebuffs.frame then
		self.forcedColour = borderColour
		bgDef.edgeFile = curseEdge
	else
		self.forcedColour = nil
		--bgDef.edgeFile = normalEdge

		bgDef.edgeFile = self.edgeFile or normalEdge
		bgDef.edgeSize = self.edgeSize or 16
		bgDef.insets.left = self.edgeInsets or 3
		bgDef.insets.top = self.edgeInsets or 3
		bgDef.insets.right = self.edgeInsets or 3
		bgDef.insets.bottom = self.edgeInsets or 3
	end

	--for i, f in pairs(self.FlashFrames) do
	for i = 1, #self.FlashFrames do
		local f = self.FlashFrames[i]
		if not conf.highlightDebuffs.frame then
			colour = conf.colour.frame
		end
		setFlashBackdrop(f)
		f:SetBackdropColor(colour.r, colour.g, colour.b, colour.a)
		f:SetBackdropBorderColor(borderColour.r, borderColour.g, borderColour.b, borderColour.a)
	end
end
