-- Author: Resike
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

local conf, tconf, fconf
FPerl.RequestConfig(function(new)
	conf = new
	tconf = conf.target
	fconf = conf.focus
end, "$Revision:  $")

local CanAccess = FPerl.CanAccess
local IsSecret = FPerl.IsSecret
local SetAlphaFromBoolean = FPerl.SetAlphaFromBoolean
local SafeBool = FPerl.SafeBool
local GetLootMethod = GetLootMethod or C_PartyInfo.GetLootMethod
local UnitAffectingCombat = UnitAffectingCombat
local UnitCanAssist = UnitCanAssist
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitInRange = UnitInRange
local UnitIsAFK = UnitIsAFK
local UnitIsConnected = UnitIsConnected
local UnitIsDead = UnitIsDead
local UnitIsGhost = UnitIsGhost
local UnitIsGroupAssistant = UnitIsGroupAssistant
local UnitIsGroupLeader = UnitIsGroupLeader
local UnitIsUnit = UnitIsUnit
local UnitPowerMax = UnitPowerMax
local CombatFeedback_OnUpdate = CombatFeedback_OnUpdate
local percD = "%d"..PERCENT_SYMBOL

-- FPerl.Target.SetManaType
function FPerl.Target.SetManaType(self)
	local unitPowerMax = UnitPowerMax(self.partyid)

	-- a secret maximum cannot be tested, keep the bar shown
	if ((CanAccess(unitPowerMax) and unitPowerMax == 0) or not self.conf.mana) then
		if (self.statsFrame.manaBar:IsShown()) then
			self.statsFrame.manaBar:Hide()

			if (self == FPerl_Target or self == FPerl_Focus or self == FPerl_TargetTarget or self == FPerl_FocusTarget or self == FPerl_PetTarget or self == FPerl_TargetTargetTarget) then
				self.statsFrame:SetHeight(28 + ((conf.bar.fat or 0) * 2))
				FPerl.StatsFrameSetup(self)
			end
		end
		return
	end

	FPerl.SetManaBarType(self)

	if (not self.statsFrame.manaBar:IsShown()) then
		self.statsFrame.manaBar:Show()
		self.statsFrame.manaBar.text:Show()
		if (self == FPerl_Target or self == FPerl_Focus or self == FPerl_TargetTarget or self == FPerl_FocusTarget or self == FPerl_PetTarget or self == FPerl_TargetTargetTarget) then
			self.statsFrame:SetHeight(40)
			FPerl.StatsFrameSetup(self)
		end
	end
end

local powerStyle = {percent = percD, text = "valued"}
function FPerl.Target.SetMana(self)
	if not self.partyid then
		self.targetmana = 0
		self.targetmanamax = 0
		return
	end

	local _, unitPower, unitPowerMax = FPerl.PowerUpdate(self, powerStyle)
	self.targetmana = unitPower
	self.targetmanamax = unitPowerMax
end

-- FPerl.Target.SetManaAndType: the power element's updatePowerType (UNIT_DISPLAYPOWER)
function FPerl.Target.SetManaAndType(self)
	FPerl.Target.SetManaType(self)
	FPerl.Target.SetMana(self)
end

-- UpdateHealPrediction
local function UpdateHealPrediction(self)
	if self == FPerl_Target then
		if tconf.healprediction then
			FPerl.SetExpectedHealth(self)
		else
			self.statsFrame.expectedHealth:Hide()
		end
	elseif self == FPerl_TargetTarget or self == FPerl_TargetTargetTarget then
		if self.conf.healprediction then
			FPerl.SetExpectedHealth(self)
		else
			self.statsFrame.expectedHealth:Hide()
		end
	elseif self == FPerl_Focus then
		if fconf.healprediction then
			FPerl.SetExpectedHealth(self)
		else
			self.statsFrame.expectedHealth:Hide()
		end
	elseif self == FPerl_FocusTarget then
		if conf.focustarget.healprediction then
			FPerl.SetExpectedHealth(self)
		else
			self.statsFrame.expectedHealth:Hide()
		end
	end
end

-- UpdateAbsorbPrediction
local function UpdateAbsorbPrediction(self)
	if self == FPerl_Target then
		if tconf.absorbs then
			FPerl.SetExpectedAbsorbs(self)
		else
			self.statsFrame.expectedAbsorbs:Hide()
		end
	elseif self == FPerl_TargetTarget or self == FPerl_TargetTargetTarget then
		if self.conf.absorbs then
			FPerl.SetExpectedAbsorbs(self)
		else
			self.statsFrame.expectedAbsorbs:Hide()
		end
	elseif self == FPerl_Focus then
		if fconf.absorbs then
			FPerl.SetExpectedAbsorbs(self)
		else
			self.statsFrame.expectedAbsorbs:Hide()
		end
	elseif self == FPerl_FocusTarget then
		if conf.focustarget.absorbs then
			FPerl.SetExpectedAbsorbs(self)
		else
			self.statsFrame.expectedAbsorbs:Hide()
		end
	end
end

function FPerl.Target.UpdateResurrectionStatus(self)
	if (SafeBool(UnitHasIncomingResurrection(self.partyid), false)) then
		if (self == FPerl_Target and tconf.portrait) or (self == FPerl_Focus and fconf.portrait) then
			self.portraitFrame.resurrect:Show()
		else
			self.statsFrame.resurrect:Show()
		end
	else
		if (self == FPerl_Target and tconf.portrait) or (self == FPerl_Focus and fconf.portrait) then
			self.portraitFrame.resurrect:Hide()
		else
			self.statsFrame.resurrect:Hide()
		end
	end
end

-- FPerl.Target.UpdateHealth
function FPerl.Target.UpdateHealth(self)
	local partyid = self.partyid
	if not partyid then
		self.targethp = 0
		self.targetmax = 0
		self.afk = false
		return
	end

	local hp, hpMax = UnitHealth(partyid), UnitHealthMax(partyid)

	self.targethp = hp
	self.targethpmax = hpMax

	-- indirect units (pettarget, targettarget...) can return
	-- secret booleans, which cannot be tested; treat those as "alive and normal"
	local ghost = SafeBool(UnitIsGhost(partyid), false)
	local dead = SafeBool(UnitIsDead(partyid), false)
	local offline = UnitExists(partyid) and not SafeBool(UnitIsConnected(partyid), true)
	local afk = SafeBool(UnitIsAFK(partyid), false)
	self.afk = afk and conf.showAFK == 1

	FPerl.SetHealthBar(self)

	UpdateAbsorbPrediction(self)
	UpdateHealPrediction(self)
	FPerl.Target.UpdateResurrectionStatus(self)

	-- A readable max of 100 means hp is already a percent: print it as one
	if (CanAccess(hpMax) and hpMax == 100 and CanAccess(hp)) then
		FPerl.FormatPercent(self.statsFrame.healthBar.text, (ghost or dead) and 0 or hp, "whole")
	end

	local color
	if (self.conf.percent) then
		if (ghost) then
			self.statsFrame.manaBar.percent:Hide()
			self.statsFrame.healthBar.percent:SetText(FPERL_LOC_GHOST)
		elseif (dead) then
			--self.statsFrame.manaBar.percent:Hide()
			self.statsFrame.healthBar.percent:SetText(FPERL_LOC_DEAD)
		elseif (offline) then
			self.statsFrame.manaBar.percent:Hide()
			self.statsFrame.healthBar.percent:SetText(FPERL_LOC_OFFLINE)
		elseif (afk and conf.showAFK) then
			self.statsFrame.healthBar.percent:SetText(CHAT_MSG_AFK)
		else
			self.statsFrame.manaBar.percent:Show()
			color = true
		end
	else
		if (ghost) then
			self.statsFrame.healthBar.text:SetText(FPERL_LOC_GHOST)
		elseif (dead) then
			self.statsFrame.healthBar.text:SetText(FPERL_LOC_DEAD)
		elseif (offline) then
			self.statsFrame.healthBar.text:SetText(FPERL_LOC_OFFLINE)
		elseif (afk and conf.showAFK) then
			self.statsFrame.healthBar.text:SetText(CHAT_MSG_AFK)
		else
			color = true
		end
	end

	if (color) then
		if (self.statsFrame.greyMana) then
			self.statsFrame.greyMana = nil
			FPerl.Target.SetManaType(self)
		end
	else
		self.statsFrame:SetGrey()
	end
end

-- FPerl.Target.UpdateCombat
function FPerl.Target.UpdateCombat(self)
	if (UnitAffectingCombat(self.partyid)) then
		self.nameFrame.combatIcon:Show()
	else
		self.nameFrame.combatIcon:Hide()
	end
end

-- CombatFlash
local function CombatFlash(self, elapsed, argNew, argGreen)
	if (FPerl.CombatFlashSet(self, elapsed, argNew, argGreen)) then
		FPerl.CombatFlashSetFrames(self)
	end
end

-- FPerl.Target.UpdateRange
function FPerl.Target.UpdateRange(self)
	if not self.partyid then
		return
	end
	if not tconf.range30yard then
		self.nameFrame.rangeIcon:Hide()
		return
	end
	local range, checkedRange = UnitInRange(self.partyid)
	if (IsSecret(range) or IsSecret(checkedRange)) then
		-- secret booleans drive the icon's alpha directly
		local icon = self.nameFrame.rangeIcon
		icon:Show()
		icon:SetAlpha(1)
		SetAlphaFromBoolean(icon, checkedRange, 1, 0)
		SetAlphaFromBoolean(icon, range, 0, icon:GetAlpha())
		return
	end
	local inRange = false
	if not checkedRange then
		inRange = true
	end
	if not UnitIsConnected(self.partyid) or inRange then
		self.nameFrame.rangeIcon:Hide()
	else
		self.nameFrame.rangeIcon:Show()
		self.nameFrame.rangeIcon:SetAlpha(1)
	end
end

-- UpdateLeader
local function UpdateLeader(self)
	local partyid = self.partyid

	-- UnitIsGroupLeader/UnitIsGroupAssistant can be secret booleans for a
	-- secret-identity target; crashed on plain click-to-target.
	if (SafeBool(UnitIsGroupLeader(partyid), false)) then
		self.nameFrame.leaderIcon:Show()
		self.nameFrame.assistIcon:Hide()
	else
		self.nameFrame.leaderIcon:Hide()
		if (SafeBool(UnitIsGroupAssistant(partyid), false)) then
			self.nameFrame.assistIcon:Show()
		else
			self.nameFrame.assistIcon:Hide()
		end
	end

	local masterLooter = false
	local method, partyID, raidID = GetLootMethod()

	if FPerl.IsMasterLoot(method) then
		if raidID then
			if SafeBool(UnitIsUnit("raid"..raidID, partyid), false) then
				masterLooter = true
			end
		elseif partyID then
			if SafeBool(UnitIsUnit("party"..partyID, partyid), false) or (partyID == 0 and SafeBool(UnitIsUnit("player", partyid), false)) then
				masterLooter = true
			end
		end
	end

	if masterLooter then
		self.nameFrame.masterIcon:Show()
	else
		self.nameFrame.masterIcon:Hide()
	end
end

-- RaidTargetUpdate
local function RaidTargetUpdate(self)
	local raidIcon = self.nameFrame.raidIcon

	FPerl.UpdateRaidIcon(raidIcon, self.partyid)

	raidIcon:ClearAllPoints()
	if (self.conf.raidIconAlternate) then
		raidIcon:SetHeight(16)
		raidIcon:SetWidth(16)
		raidIcon:SetPoint("CENTER", self.nameFrame, "TOPRIGHT", -5, -4)
	else
		raidIcon:SetHeight(32)
		raidIcon:SetWidth(32)
		raidIcon:SetPoint("CENTER", self.nameFrame, "CENTER", 0, 0)
	end
end

-- CheckDebuffs
local function CheckDebuffs(self)
	if (self.conf.highlightDebuffs.enable) then
		if (self.conf.highlightDebuffs.who == 1 or (self.conf.highlightDebuffs.who == 2 and UnitCanAssist("player", self.partyid)) or (self.conf.highlightDebuffs.who == 3 and not UnitCanAssist("player", self.partyid))) then
			FPerl.CheckDebuffs(self, self.partyid)
		else
			FPerl.CheckDebuffs(self, self.partyid, true)
		end
	end

	if (self.conf.reactionHighlight) then
		local c = FPerl.ReactionColour(self.partyid)
		self.nameFrame:SetBackdropColor(c.r, c.g, c.b)
	end
end

-- used by FPerl_TargetEvents.lua
FPerl.Target.CombatFlash = CombatFlash
FPerl.Target.UpdateLeader = UpdateLeader
FPerl.Target.RaidTargetUpdate = RaidTargetUpdate
FPerl.Target.CheckDebuffs = CheckDebuffs

-- FPerl.Target.UpdateDisplay
function FPerl.Target.UpdateDisplay(self)
	local partyid = self.partyid
	if not UnitExists(partyid) then
		return
	end

	FPerl.NoFadeBars(true)

	FPerl.Target.UpdateName(self)
	FPerl.Target.UpdateClassification(self)
	FPerl.Target.UpdateLevel(self)
	FPerl.Target.UpdateType(self)
	FPerl.Target.SetManaType(self)
	FPerl.Target.SetMana(self)
	FPerl.Target.UpdateHealth(self)
	FPerl.Target.UpdateCombat(self)
	UpdateLeader(self)
	FPerl.UnitThreatStatus(self, partyid == "target" and "player" or nil, true)

	RaidTargetUpdate(self)

	if self == FPerl_Target then
		FPerl.Target.UpdateCombo(self)
	end
	FPerl.UnitUpdatePortrait(self)

	FPerl_Highlight:SetHighlight(self, UnitGUID(partyid))

	if tconf.range30yard then
		FPerl.Target.UpdateRange(self)
	else
		self.nameFrame.rangeIcon:Hide()
	end
	FPerl.UpdateSpellRange(self, partyid)

	FPerl.NoFadeBars()

	-- a fresh target is the most common moment the AuraContainer
	-- fallback's friend/enemy half-assignment needs to change; rebuild here (a
	-- no-op on clients without it, deferred while secret) rather than on every
	-- UNIT_AURA.
	FPerl.AurasRebuild(self)
	FPerl.AurasUpdate(self)
	if (self.conf.highlightDebuffs.enable) then
		CheckDebuffs(self)
	end

	FPerl.Target.UpdatePVP(self)
end

-- FPerl.Target.OnUpdate
function FPerl.Target.OnUpdate(self, elapsed)
	local partyid = self.partyid
	if not partyid then
		return
	end

	local feedback = (tconf.hitIndicator and tconf.portrait) or (fconf.hitIndicator and fconf.portrait)
	if feedback then
		CombatFeedback_OnUpdate(self, elapsed)
	end

	if (conf.combatFlash and self.PlayerFlash) then
		CombatFlash(self, elapsed, false)
	end
	FPerl.OnUpdateIdle(self, feedback)
end

-- Range checks every 0.2 s: no event reports a unit's distance
local function PollRangeOne(self)
	do
		local partyid = self and self.partyid
		if (partyid and self:IsVisible()) then
			if tconf.range30yard then
				FPerl.Target.UpdateRange(self)
			end
			if conf.rangeFinder.enabled then
				FPerl.UpdateSpellRange(self, partyid)
			end
		end
	end
end

local function PollRange()
	PollRangeOne(FPerl_Target)
	PollRangeOne(FPerl_Focus)
end
FPerl.Every(0.2, PollRange)
