-- Author: Resike
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

local playerName
local conf, pconf
FPerl.RequestConfig(function(new)
	conf = new
	pconf = conf.player
	if (FPerl_Player) then
		FPerl_Player.conf = conf.player
		FPerl.MainFrameStart(FPerl_Player, pconf.enable, PlayerFrame)
	end
end, "$Revision:  $")

local perc1F = "%.1f"..PERCENT_SYMBOL
local percD = "%.0f"..PERCENT_SYMBOL

--[===[@debug@
local function d(...)
	ChatFrame1:AddMessage(format(...))
end
--@end-debug@]===]

-- Upvalues
local floor = floor
local format = format

local CreateFrame = CreateFrame
local GetDifficultyColor = GetDifficultyColor or GetQuestDifficultyColor
local GetLootMethod = GetLootMethod or C_PartyInfo.GetLootMethod
local GetNumGroupMembers = GetNumGroupMembers
local GetPVPTimer = GetPVPTimer
local GetRaidRosterInfo = GetRaidRosterInfo
local GetXPExhaustion = GetXPExhaustion
local IsInRaid = IsInRaid
local IsPVPTimerRunning = IsPVPTimerRunning
local IsResting = IsResting
local UnitAffectingCombat = UnitAffectingCombat
local UnitClass = UnitClass
local UnitFactionGroup = UnitFactionGroup
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitGUID = UnitGUID
local UnitHasIncomingResurrection = UnitHasIncomingResurrection
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid
local UnitIsAFK = UnitIsAFK
local UnitIsDead = UnitIsDead
local UnitIsGhost = UnitIsGhost
local UnitIsGroupAssistant = UnitIsGroupAssistant
local UnitIsGroupLeader = UnitIsGroupLeader
local UnitIsMercenary = UnitIsMercenary
local UnitIsPVP = UnitIsPVP
local UnitIsPVPFreeForAll = UnitIsPVPFreeForAll
local UnitIsUnit = UnitIsUnit
local UnitLevel = UnitLevel
local UnitOnTaxi = UnitOnTaxi
local UnitPowerType = UnitPowerType
local UnitXP = UnitXP
local UnitXPMax = UnitXPMax

local CombatFeedback_Initialize = CombatFeedback_Initialize
local CombatFeedback_OnUpdate = CombatFeedback_OnUpdate

-- secret value helpers from FPerl.lua
local GetPowerPercent = FPerl.GetPowerPercent
local SafeBool = FPerl.SafeBool

local PlayerStatusOnUpdate
local HighlightCallback

--local feignDeath = (C_Spell and C_Spell.GetSpellInfo(5384)) and C_Spell.GetSpellInfo(5384).name or GetSpellInfo(5384)
--local spiritOfRedemption = (C_Spell and C_Spell.GetSpellInfo(27827)) and C_Spell.GetSpellInfo(27827).name or GetSpellInfo(27827)


----------------------
-- Loading Function --
----------------------
function FPerl.Player.OnLoad(self)
	FPerl.SetChildMembers(self)
	self.partyid = "player"
	self.unit = self.partyid

	CombatFeedback_Initialize(self, self.hitIndicator.text, 30)

	self.portraitFrame:SetAttribute("*type1", "target")
	self.portraitFrame:SetAttribute("type2", "togglemenu")
	self.portraitFrame:SetAttribute("unit", self.partyid)
	self.nameFrame:SetAttribute("*type1", "target")
	self.nameFrame:SetAttribute("type2", "togglemenu")
	self.nameFrame:SetAttribute("unit", self.partyid)
	self.statsFrame:SetAttribute("*type1", "target")
	self.statsFrame:SetAttribute("type2", "togglemenu")
	self.statsFrame:SetAttribute("unit", self.partyid)
	self:SetAttribute("*type1", "target")
	self:SetAttribute("type2", "togglemenu")
	self:SetAttribute("unit", self.partyid)

	--RegisterAttributeDriver(self.nameFrame, "unit", "[vehicleui] vehicle; player")
	RegisterAttributeDriver(self, "unit", "[vehicleui] vehicle; player")

	FPerl.RegisterClickCastFrame(self.portraitFrame)
	FPerl.RegisterClickCastFrame(self.nameFrame)
	FPerl.RegisterClickCastFrame(self.statsFrame)
	FPerl.RegisterClickCastFrame(self)

	FPerl.UnitFrameInit(self, {"player", "vehicle"}, {"PlayerLoad", "PlayerWorld"})

	if (HealBot_Options_EnablePlayerFrame) then
		HealBot_Options_EnablePlayerFrame = function() end
	end

	self:SetScript("OnShow", FPerl.UnitUpdatePortrait)
	self.time = 0

	self.Power = 0
	self.nameFrame.pvp.time = 0

	FPerl.Player.PVPTimerSetup(self.nameFrame.pvptimer)

	local _, playerClass = UnitClass("player")
	if (playerClass == "DRUID") or (playerClass == "SHAMAN") or (playerClass == "PRIEST") then
		FPerl.Player.DruidBarUpdate(self)
	end

	FPerl.RegisterHighlight(self.highlight, 3)

	local perlframes = {self.nameFrame, self.statsFrame, self.levelFrame, self.portraitFrame, self.groupFrame}
	self.FlashFrames = {self.portraitFrame, self.nameFrame,self.levelFrame, self.statsFrame}
	FPerl.RegisterPerlFrames(self, perlframes)

	FPerl.RegisterOptionChanger(FPerl.Player.SetBits, self, "player")
	FPerl_Highlight:Register(HighlightCallback, self)
	--self.IgnoreHighlightStates = {AGGRO = true}

	if (FPerl.layout) then
		self.conf = FPerl.layout.player
	end

	FPerl.Player.OnLoad = nil
end

-- HighlightCallback(updateName)
function HighlightCallback(self, updateGUID)
	if (updateGUID == UnitGUID("player")) then
		FPerl_Highlight:SetHighlight(self, updateGUID)
	end
end

-- UpdateAssignedRoles
local function UpdateAssignedRoles(self)
	local unit = self.partyid
	local icon = self.nameFrame.roleIcon
	local isTank, isHealer, isDamage
	if type(UnitGroupRolesAssigned) == "function" then
		local role = SafeBool(UnitGroupRolesAssigned(unit), nil)
		isTank = false
		isHealer = false
		isDamage = false
		if role == "TANK" then
			isTank = true
		elseif role == "HEALER" then
			isHealer = true
		elseif role == "DAMAGER" then
			isDamage = true
		end
	end

	-- role icons option check by playerlin
	if (conf and conf.oldRoleIcons) then
		if isTank then
			icon:SetTexture("Interface\\GroupFrame\\UI-Group-MainTankIcon")
			icon:Show()
		elseif isHealer then
			icon:SetTexture("Interface\\AddOns\\FPerl\\Images\\FPerl_RoleHealer_old")
			icon:Show()
		elseif isDamage then
			icon:SetTexture("Interface\\GroupFrame\\UI-Group-MainAssistIcon")
			icon:Show()
		else
			icon:Hide()
		end
	else
		if isTank then
			icon:SetTexture("Interface\\AddOns\\FPerl\\Images\\FPerl_RoleTank")
			icon:Show()
		elseif isHealer then
			icon:SetTexture("Interface\\AddOns\\FPerl\\Images\\FPerl_RoleHealer")
			icon:Show()
		elseif isDamage then
			icon:SetTexture("Interface\\AddOns\\FPerl\\Images\\FPerl_RoleDamage")
			icon:Show()
		else
			icon:Hide()
		end
	end
end

-------------------------
-- The Update Function --
-------------------------

local function CombatFlash(self, elapsed, argNew, argGreen)
	if (FPerl.CombatFlashSet(self, elapsed, argNew, argGreen)) then
		FPerl.CombatFlashSetFrames(self)
	end
end

-- UpdateManaType
local function UpdateManaType(self)
	FPerl.SetManaBarType(self)
end

-- UpdateLeader()
local function UpdateLeader(self)
	local nf = self.nameFrame

	-- Loot Master
	local method, pindex, rindex, ml
	if (UnitInParty("party1") or UnitInRaid("player")) then
		method, pindex, rindex = GetLootMethod()

		if (FPerl.IsMasterLoot(method)) then
			if (rindex ~= nil) then
				ml = SafeBool(UnitIsUnit("raid"..rindex, "player"), false)
			elseif (pindex and (pindex == 0)) then
				ml = true
			end
		end
	end

	if (ml) then
		nf.masterIcon:Show()
	else
		nf.masterIcon:Hide()
	end

	-- Leader
	if (UnitIsGroupLeader("player")) then
		nf.leaderIcon:Show()
	else
		nf.leaderIcon:Hide()
	end

	if (UnitIsGroupAssistant("player")) then
		nf.assistIcon:Show()
	else
		nf.assistIcon:Hide()
	end

	UpdateAssignedRoles(self)

	if (pconf and pconf.partyNumber and IsInRaid()) then
		for i = 1, GetNumGroupMembers() do
			local _, _, subgroup = GetRaidRosterInfo(i)
			if (SafeBool(UnitIsUnit("raid"..i, "player"), false)) then
				if (pconf.withName) then
					nf.group:SetFormattedText(FPERL_RAID_GROUPSHORT, subgroup)
					nf.group:Show()
					self.groupFrame:Hide()
					return
				else
					self.groupFrame.text:SetFormattedText(FPERL_RAID_GROUP, subgroup)
					self.groupFrame:Show()
					nf.group:Hide()
					return
				end
			end
		end
	end

	nf.group:Hide()
	self.groupFrame:Hide()
end

local function UpdateRaidTarget(self)
	FPerl.UpdateRaidIcon(self.nameFrame.raidIcon, self.partyid)
end

-- UpdateCombat
local function UpdateCombat(self)
	local nf = self.nameFrame
	if (UnitAffectingCombat("player")) then
		nf.text:SetTextColor(1, 0, 0)
		nf.combatIcon:SetTexCoord(0.49, 1, 0, 0.49)
		nf.combatIcon:Show()
	else
		if (self.partyid ~= "player") then
			local c = conf.colour.reaction.none
			nf.text:SetTextColor(c.r, c.g, c.b, conf.transparency.text)
		else
			FPerl.ColourFriendlyUnit(nf.text, self.partyid)
		end

		if (IsResting()) then
			nf.combatIcon:SetTexCoord(0, 0.49, 0, 0.49)
			nf.combatIcon:Show()
		else
			nf.combatIcon:Hide()
		end
	end
end

-- UpdateName()
local function UpdateName(self)
	-- full "First Last" (or "First-Realm") display name
	playerName = FPerl.UnitFullName(self.partyid)
	self.nameFrame.text:SetText(playerName)
	UpdateCombat(self)
end

-- UpdateClass
local function UpdateClass(self)
	local _, class = UnitClass(self.partyid)
	FPerl.Player.playerClass = class
	playerName = FPerl.UnitFullName(self.partyid)
	local l, r, t, b = FPerl.ClassPos(FPerl.Player.playerClass)
	self.classFrame.tex:SetTexCoord(l, r, t, b)

	if (pconf.classIcon) then
		self.classFrame:Show()
	else
		self.classFrame:Hide()
	end
end

-- There are two different functions to get faction info, used in retail/classic/era.
-- To maintain compatibility, we fake the original function if it's not there.
local GetWatchedFactionInfo
if _G.GetWatchedFactionInfo then
	GetWatchedFactionInfo = _G.GetWatchedFactionInfo
else
	GetWatchedFactionInfo = function()
		local data = C_Reputation.GetWatchedFactionData()
		if data then
			return data.name, data.reaction, data.currentReactionThreshold, data.nextReactionThreshold, data.currentStanding, data.factionID
		end
		return nil, nil, nil, nil, nil, nil -- documenting that there should be six returns.
	end
end

-- UpdateRep
local function UpdateRep(self)
	if (pconf and pconf.repBar) then
		local rb = self.statsFrame.repBar
		if (rb) then
			local name, reaction, min, max, value, factionID = GetWatchedFactionInfo()
			local color
			local perc

			if max == 43000 then
				max = 42000
			end

			if (factionID == 1733 or factionID == 1736 or factionID == 1737 or factionID == 1738 or factionID == 1739 or factionID == 1740 or factionID == 1741) and min == 20000 and max == 21000 and value == 20000 then
				min = 21000
				value = 21000
			end

			if name then
				color = FACTION_BAR_COLORS[reaction]
				if min > 0 and max > 0 and value > 0 and min ~= max and min ~= value then
					value = value - min
					max = max - min
				end
				min = 0
				if value > 0 and max > 0 then
					perc = (value * 100) / max
				else
					perc = 100
				end
			else
				name = FPERL_LOC_NONEWATCHED
				value = 0
				max = 1
				min = 0
				color = FACTION_BAR_COLORS[4]
				perc = 0
			end

			rb:SetMinMaxValues(min, max)
			rb:SetValue(value)

			rb:SetStatusBarColor(color.r, color.g, color.b, 1)
			rb.bg:SetVertexColor(color.r, color.g, color.b, 0.25)

			if perc < 0 then
				perc = 0
			elseif perc > 100 then
				perc = 100
			end

			rb.tex:SetTexCoord(0, perc / 100, 0, 1)

			if max == 1 then
				rb.text:SetText(name)
			else
				rb.text:SetFormattedText("%d/%d", value, max)
			end

			if perc < 100 then
				rb.percent:SetFormattedText(perc1F, perc)
			else
				rb.percent:SetFormattedText(percD, perc)
			end
		end
	end
end

-- UpdateXP
local function UpdateXP(self)
	if (pconf.xpBar) then
		local xpBar = self.statsFrame.xpBar
		if (xpBar) then
			local restBar = self.statsFrame.xpRestBar
			local playerxp = UnitXP("player")
			local playerxpmax = UnitXPMax("player")
			local playerxprest = GetXPExhaustion() or 0
			xpBar:SetMinMaxValues(0, playerxpmax)
			restBar:SetMinMaxValues(0, playerxpmax)
			xpBar:SetValue(playerxp)

			local color
			local w = xpBar:GetRight() - xpBar:GetLeft()
			for mode = 1, 3 do
				local suffix
				if (playerxprest > 0) then
					if (mode == 1) then
						suffix = format(" +%d", playerxprest)
					elseif (mode == 2) then
						if (playerxprest >= 1000000) then
							suffix = format(" +%.1fM", playerxprest / 1000000)
						else
							suffix = format(" +%.1fk", playerxprest / 1000)
						end
					else
						if (playerxprest >= 1000000) then
							suffix = format(" +%dM", playerxprest / 1000000)
						else
							suffix = format(" +%dk", playerxprest / 1000)
						end
					end

					color = {r = 0.3, g = 0.3, b = 1}
				else
					color = {r = 0.6, g = 0, b = 0.6}
				end

				if (pconf.xpDeficit) then
					FPerl.SetValuedText(xpBar.text, playerxp - playerxpmax, playerxpmax, suffix)
				else
					FPerl.SetValuedText(xpBar.text, playerxp, playerxpmax, suffix)
				end
				if (xpBar.text:GetStringWidth() + 20 <= w) then
					break
				end
			end

			xpBar:SetStatusBarColor(color.r, color.g, color.b, 1)
			xpBar.bg:SetVertexColor(color.r, color.g, color.b, 0.25)
			local x = playerxp / playerxpmax
			if x > 1 then
				x = 1
			end
			xpBar.tex:SetTexCoord(0, x, 0, 1)

			restBar:SetValue(playerxp + playerxprest)
			restBar:SetStatusBarColor(color.r, color.g, color.b, 0.5)
			local y = (playerxp + playerxprest) / playerxpmax
			if y > 1 then
				y = 1
			end
			restBar.tex:SetTexCoord(0, y, 0, 1)
			restBar.bg:SetVertexColor(color.r, color.g, color.b, 0.25)
			xpBar.percent:SetFormattedText(percD, (playerxp * 100) / playerxpmax)
		end
	end
end

-- UpdatePVPTimer
-- the timer text, every 0.5 s on the scheduler while the timer frame is shown (OnShow / OnHide below)
local function PVPTimerTick()
	local timeLeft = GetPVPTimer()

	if timeLeft > 0 then
		local text = FPerl_Player.nameFrame.pvptimer.text
		timeLeft = floor(timeLeft / 1000)
		text:SetFormattedText("%d:%02d", timeLeft / 60, timeLeft % 60)
	end
end

function FPerl.Player.PVPTimerSetup(timer)
	timer:SetScript("OnShow", function() FPerl.Every(0.5, PVPTimerTick) end)
	timer:SetScript("OnHide", function() FPerl.Cancel(PVPTimerTick) end)
end

-- UpdatePVPTimer
local function UpdatePVPTimer(self)
	if pconf.pvpIcon and IsPVPTimerRunning() then
		self.nameFrame.pvptimer:Show()
	else
		self.nameFrame.pvptimer:Hide()
		self.nameFrame.pvptimer.text:SetText("")
	end
end

-- UpdatePVP
local function UpdatePVP(self)
	-- PVP Status settings
	--local nf = self.nameFrame
	if (UnitAffectingCombat(self.partyid)) then
		self.nameFrame.text:SetTextColor(1, 0, 0)
	else
		FPerl.ColourFriendlyUnit(self.nameFrame.text, "player")
	end

	local pvpIcon = self.nameFrame.pvp

	local factionGroup = UnitFactionGroup("player")

	if pconf.pvpIcon and UnitIsPVPFreeForAll("player") then
		pvpIcon.icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-FFA")
		pvpIcon:Show()
	elseif pconf.pvpIcon and factionGroup and factionGroup ~= "Neutral" and UnitIsPVP("player") then
		pvpIcon.icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-"..factionGroup)

		if type(UnitIsMercenary) == "function" and UnitIsMercenary("player") then
			if factionGroup == "Horde" then
				pvpIcon.icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance")
			elseif factionGroup == "Alliance" then
				pvpIcon.icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Horde")
			end
		end

		pvpIcon:Show()
	else
		pvpIcon:Hide()
	end

	UpdatePVPTimer(self)
end

-- CreateBar(self, name)
local function CreateBar(self, name)
	local f = CreateFrame("StatusBar", self.statsFrame:GetName()..name, self.statsFrame, "FPerl_StatusBar")
	f:SetPoint("TOPLEFT", self.statsFrame.manaBar, "BOTTOMLEFT", 0, 0)
	f:SetHeight(10)
	self.statsFrame[name] = f
	f:SetWidth(112)
	return f
end

-- MakeDruidBar()
local function MakeDruidBar(self)
	local f = CreateBar(self, "druidBar")
	local c = conf.colour.bar.mana
	f:SetStatusBarColor(c.r, c.g, c.b)
	f.bg:SetVertexColor(c.r, c.g, c.b, 0.25)
	MakeDruidBar = nil
end

-- ApplyStatsHeight: protected; reads the bar state when it runs
local function ApplyStatsHeight(self)
	local druidBar = self.statsFrame.druidBar
	self.statsFrame:SetHeight(40 + ((((druidBar and druidBar:IsShown()) and 1 or 0) + (pconf.repBar and 1 or 0) + (pconf.xpBar and 1 or 0)) * 10))
end

-- FPerl.Player.DruidBarUpdate
local statsBars = {}
function FPerl.Player.DruidBarUpdate(self)
	local druidBar = self.statsFrame.druidBar
	if (pconf.noDruidBar) then
		if (druidBar) then
			druidBar:Hide()
			statsBars[1], statsBars[2], statsBars[3] = nil, self.statsFrame.xpBar, self.statsFrame.repBar
			FPerl.StatsFrameSetup(self, statsBars)
		end
		return
	elseif (not druidBar) then
		if (MakeDruidBar) then
			MakeDruidBar(self)
			druidBar = self.statsFrame.druidBar
		end
	end

	local currMana, _, barMax = FPerl.PowerSetBar(druidBar, "player", 0, true)
	druidBar.text:SetFormattedText("%d/%d", currMana, barMax)
	druidBar.percent:SetFormattedText(percD, GetPowerPercent("player", 0))

	--local druidBarExtra
	if ((FPerl.Player.playerClass == "DRUID" or FPerl.Player.playerClass == "PRIEST") and UnitPowerType(self.partyid) > 0) then -- Shaman's UnitPowerType is buggy
		if (pconf.values) then
			druidBar.text:Show()
		else
			druidBar.text:Hide()
		end
		if (pconf.percent) then
			druidBar.percent:Show()
		else
			druidBar.percent:Hide()
		end
		druidBar:Show()
		--druidBar:SetHeight(10)
		--druidBarExtra = 1
	else
		--druidBar.percent:Hide()
		--druidBar.text:Hide()
		druidBar:Hide()
		--druidBar:SetHeight(1)
		--druidBarExtra = 0
	end

	-- Layout per power event on purpose: the bar's shown state, its text and percent, and the other
	-- bars' visibility all feed the height and anchors, and StatsFrameSetup is their only writer, so a
	-- skip needs a state signature that every other caller of Setup would have to keep current.
	FPerl.AfterCombat(ApplyStatsHeight, self)

	-- one table for every power event; StatsFrameSetup skips the nil entries
	statsBars[1], statsBars[2], statsBars[3] = druidBar, self.statsFrame.xpBar, self.statsFrame.repBar
	FPerl.StatsFrameSetup(self, statsBars)
end

-- UpdateMana
local powerStyle = {percent = percD, text = "valued", rawIfEmpty = true}
local function UpdateMana(self)
	FPerl.PowerUpdate(self, powerStyle)

	if (not self.statsFrame.greyMana) then
		if (pconf.values) then
			self.statsFrame.manaBar.text:Show()
		end
		if (pconf.percent) then
			self.statsFrame.manaBar.percent:Show()
		end
	end

	if (FPerl.Player.playerClass == "DRUID") or (FPerl.Player.playerClass == "SHAMAN") or (FPerl.Player.playerClass == "PRIEST") then
		FPerl.Player.DruidBarUpdate(self)
	end
end

-- UpdateHealPrediction
local function UpdateHealPrediction(self)
	if pconf.healprediction then
		FPerl.SetExpectedHealth(self)
	else
		self.statsFrame.expectedHealth:Hide()
	end
end

-- UpdateAbsorbPrediction
local function UpdateAbsorbPrediction(self)
	if pconf.absorbs then
		FPerl.SetExpectedAbsorbs(self)
	else
		self.statsFrame.expectedAbsorbs:Hide()
	end
end

local function UpdateResurrectionStatus(self)
	if UnitHasIncomingResurrection(self.partyid) then
		if pconf.portrait then
			self.portraitFrame.resurrect:Show()
		else
			self.statsFrame.resurrect:Show()
		end
	else
		if pconf.portrait then
			self.portraitFrame.resurrect:Hide()
		else
			self.statsFrame.resurrect:Hide()
		end
	end
end

-- UpdateHealth
local function UpdateHealth(self)
	local partyid = self.partyid
	local sf = self.statsFrame
	local hb = sf.healthBar

	-- Confirmed that even "player" itself can
	-- return secret booleans from UnitIsAFK/UnitIsDead/UnitIsGhost on this
	-- client; guard all of them, matching the sibling fix already
	-- applied to FPerl.Target.UpdateHealth.
	self.afk = SafeBool(UnitIsAFK(partyid), false) and conf.showAFK == 1

	FPerl.SetHealthBar(self)
	UpdateAbsorbPrediction(self)
	UpdateHealPrediction(self)
	UpdateResurrectionStatus(self)

	local greyMsg
	if (SafeBool(UnitIsDead(partyid), false)) then
		greyMsg = FPERL_LOC_DEAD
	elseif (SafeBool(UnitIsGhost(partyid), false)) then
		greyMsg = FPERL_LOC_GHOST
	elseif (SafeBool(UnitIsAFK("player"), false) and conf.showAFK) then
		greyMsg = CHAT_MSG_AFK
	end

	if (greyMsg) then
		if (pconf.percent) then
			hb.percent:SetText(greyMsg)
			hb.percent:Show()
		else
			hb.text:SetText(greyMsg)
			hb.text:Show()
		end

		sf:SetGrey()
	else
		if (sf.greyMana) then
			if (not pconf.values) then
				hb.text:Hide()
			end

			sf.greyMana = nil
			UpdateManaType(self)
		end
	end

	PlayerStatusOnUpdate(self)
end

-- UpdateLevel
local function UpdateLevel(self)
	local color = GetDifficultyColor(UnitLevel(self.partyid))
	self.levelFrame.text:SetTextColor(color.r, color.g, color.b, conf.transparency.text)

	self.levelFrame.text:SetText(UnitLevel(self.partyid))
end


-- PlayerStatusOnUpdate
-- The lost-control flash. F-Perl's low-health flash is gone: health is secret on Forever, and Blizzard flashes its own.
function PlayerStatusOnUpdate(self)
	if (pconf.fullScreen.enable and not UnitOnTaxi("player")) then
		if (FPerl.Player.isOutOfControl and not FPerl_OutOfControlFrame.frameFlash) then
			FPerl.FrameFlash(FPerl_OutOfControlFrame)
		elseif (not FPerl.Player.isOutOfControl and FPerl_OutOfControlFrame.frameFlash) then
			FPerl.FrameFlashStop(FPerl_OutOfControlFrame, "out")
		end
		return
	end

	if (FPerl_OutOfControlFrame.frameFlash) then
		FPerl.FrameFlashStop(FPerl_OutOfControlFrame)
	end
end

-- FPerl.Player.OnUpdate
function FPerl.Player.OnUpdate(self, elapsed)
	local feedback = pconf.hitIndicator and pconf.portrait
	if feedback then
		CombatFeedback_OnUpdate(self, elapsed)
	end

	if (self.PlayerFlash) then
		CombatFlash(self, elapsed, false)
	end
	FPerl.OnUpdateIdle(self, feedback)
end

-- UpdateBuffs: what the player frame does besides drawing the auras (the aura element,
-- enabled by FPerl_PlayerBuffs, does that)
local function UpdateBuffs(self)
	-- TODO: create a highlight handler for the player too
	if (conf.highlightDebuffs.enable) then
		FPerl.CheckDebuffs(self, self.partyid)
	end

	-- Kept per aura event for a druid: UNIT_AURA is the only event here that refreshes the mana bar
	-- text after a shapeshift aura (UPDATE_SHAPESHIFT_FORM reaches the druid bar only). Cost: two
	-- bar writes and one stats layout, no table, no frame. Removal is not verified in game.
	if (FPerl.Player.playerClass == "DRUID") then
		UpdateMana(self)
	end

	if (pconf.fullScreen.enable) then
		if (FPerl.Player.isOutOfControl and not UnitOnTaxi("player")) then
			PlayerStatusOnUpdate(self)
		end
	end
end

-- FPerl.Player.UpdateDisplay
function FPerl.Player.UpdateDisplay(self)
	UpdateXP(self)
	UpdateRep(self)
	UpdateManaType(self)
	UpdateLevel(self)
	UpdateName(self)
	UpdateClass(self)
	UpdatePVP(self)
	UpdateCombat(self)
	UpdateLeader(self)
	UpdateRaidTarget(self)
	UpdateMana(self)
	UpdateHealth(self)
	UpdateBuffs(self)
	if (self.playerBuffsOn) then
		FPerl.AurasUpdate(self)
	end
	FPerl.UnitUpdatePortrait(self)
end

-- Shared with FPerl_PlayerEvents.lua
FPerl.Player.UpdateAssignedRoles = UpdateAssignedRoles
FPerl.Player.CombatFlash = CombatFlash
FPerl.Player.UpdateManaType = UpdateManaType
FPerl.Player.UpdateLeader = UpdateLeader
FPerl.Player.UpdateRaidTarget = UpdateRaidTarget
FPerl.Player.UpdateCombat = UpdateCombat
FPerl.Player.UpdateName = UpdateName
FPerl.Player.UpdateClass = UpdateClass
FPerl.Player.UpdateRep = UpdateRep
FPerl.Player.UpdateXP = UpdateXP
FPerl.Player.UpdatePVPTimer = UpdatePVPTimer
FPerl.Player.UpdatePVP = UpdatePVP
FPerl.Player.CreateBar = CreateBar
FPerl.Player.ApplyStatsHeight = ApplyStatsHeight
FPerl.Player.UpdateMana = UpdateMana
FPerl.Player.UpdateResurrectionStatus = UpdateResurrectionStatus
FPerl.Player.UpdateHealth = UpdateHealth
FPerl.Player.UpdateLevel = UpdateLevel
FPerl.Player.UpdateBuffs = UpdateBuffs
FPerl.Player.PlayerStatusOnUpdate = PlayerStatusOnUpdate
