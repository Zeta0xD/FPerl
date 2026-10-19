-- Author: Resike
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

local Events = FPerl.Elements.Target.events

local conf, tconf, fconf
FPerl.RequestConfig(function(new)
	conf = new
	tconf = conf.target
	fconf = conf.focus
end, "$Revision:  $")

local SafeBool = FPerl.SafeBool
local PlaySound = PlaySound
local UnitCanAttack = UnitCanAttack
local UnitExists = UnitExists
local UnitIsEnemy = UnitIsEnemy
local UnitIsFriend = UnitIsFriend
local UnitIsUnit = UnitIsUnit
local CombatFeedback_OnCombatEvent = CombatFeedback_OnCombatEvent

-------------------
-- Event Handler --
-------------------

function Events:PLAYER_REGEN_ENABLED()
	FPerl.UnitThreatStatus(self, self.partyid == "target" and "player" or nil)
end

function Events:PLAYER_REGEN_DISABLED()
	FPerl.UnitThreatStatus(self, self.partyid == "target" and "player" or nil)
end

-- PLAYER_ENTERING_WORLD
function FPerl.Elements.FocusOnly.events:PLAYER_ENTERING_WORLD()
	if (UnitExists("focus")) then
		--self.feigning = nil
		self.PlayerFlash = 0
		FPerl.CombatFlashSetFrames(self)
		FPerl.Target.UpdateDisplay(self)
	end
end

-- UNIT_COMBAT
function Events:UNIT_COMBAT(unit, action, descriptor, damage, damageType)
	if unit ~= self.partyid then
		return
	end
	-- set first: the flash and hit text animate even when a later line raises on a secret amount
	self:SetScript("OnUpdate", FPerl.Target.OnUpdate)

	FPerl.Target.UpdateCombat(self)

	if (self.conf.hitIndicator and self.conf.portrait) then
		CombatFeedback_OnCombatEvent(self, action, descriptor, damage, damageType)
	end

	if (action == "HEAL") then
		FPerl.Target.CombatFlash(self, 0, true, true)
	elseif (damage and damage > 0) then
		FPerl.Target.CombatFlash(self, 0, true)
	end
end

-- PLAYER_TARGET_CHANGED
-- Full display refresh on purpose: a new target changes every shown field, and the frame is not
-- updated by any other event until the unit's next health, power or aura event.
function FPerl.Elements.TargetOnly.events:PLAYER_TARGET_CHANGED()
	if self ~= FPerl_Target then
		return
	end
	if (self.conf.sound and UnitExists("target")) then
		if (UnitIsEnemy("target", "player")) then
			PlaySound(873)
		elseif (UnitIsFriend("player", "target")) then
			PlaySound(867)
		else
			PlaySound(871)
		end
	end

	self.PlayerFlash = 0
	FPerl.CombatFlashSetFrames(self)
	FPerl.Target.UpdateDisplay(self)

	if (SafeBool(UnitIsUnit("target", "focus"), false)) then
		self.statsFrame.focusTarget:Show()
	else
		self.statsFrame.focusTarget:Hide()
	end

	if (FPerl_Focus and FPerl_Focus:IsShown() and FPerl_FocusTarget) then
		FPerl.TargetTarget.UpdateDisplay(FPerl_FocusTarget)
	end
end

-- PLAYER_FOCUS_CHANGED
function FPerl.Elements.FocusOnly.events:PLAYER_FOCUS_CHANGED()
	if self ~= FPerl_Focus then
		return
	end
	if (self.conf.sound and UnitExists("focus")) then
		if (UnitIsEnemy("focus", "player")) then
			PlaySound(873)
		elseif (UnitIsFriend("player", "focus")) then
			PlaySound(867)
		else
			PlaySound(871)
		end
	end

	self.PlayerFlash = 0
	FPerl.CombatFlashSetFrames(self)
	FPerl.Target.UpdateDisplay(self)

	if (SafeBool(UnitIsUnit("target", "focus"), false)) then
		FPerl_Target.statsFrame.focusTarget:Show()
	else
		FPerl_Target.statsFrame.focusTarget:Hide()
	end

	if (FPerl_FocusTarget) then
		FPerl.TargetTarget.UpdateDisplay(FPerl_FocusTarget)
	end
end

-- UNIT_FLAGS
function Events:UNIT_FLAGS()
	FPerl.Target.UpdateName(self)
	FPerl.Target.UpdatePVP(self)
	FPerl.Target.UpdateCombat(self)
end

-- RAID_TARGET_UPDATE
function Events:RAID_TARGET_UPDATE()
	FPerl.Target.RaidTargetUpdate(FPerl_Target)
	FPerl.Target.RaidTargetUpdate(FPerl_Focus)
end

-- UNIT_PORTRAIT_UPDATE
function Events:UNIT_PORTRAIT_UPDATE()
	FPerl.UnitUpdatePortrait(self, true)
end

-- UNIT_NAME_UPDATE
function Events:UNIT_NAME_UPDATE()
	FPerl.Target.UpdateName(self)
	FPerl.Target.UpdateHealth(self)
	FPerl.Target.UpdateClassification(self)
end

-- UNIT_LEVEL
function Events:UNIT_LEVEL()
	FPerl.Target.UpdateLevel(self)
	FPerl.Target.UpdateClassification(self)
end

-- UNIT_CLASSIFICATION_CHANGED
function Events:UNIT_CLASSIFICATION_CHANGED()
	FPerl.Target.UpdateClassification(self)
end

-- UNIT_AURA
function Events:UNIT_AURA()
	if not UnitExists(self.partyid) then
		return
	end

	if (self.conf.highlightDebuffs.enable) then
		FPerl.Target.CheckDebuffs(self)
	end
end

-- UNIT_FACTION
function Events:UNIT_FACTION()
	FPerl.Target.UpdatePVP(self)
	-- the containers' order follows hostility
	FPerl.AurasRebuild(self)
	FPerl.AurasUpdate(self)
end

-- PLAYER_FLAGS_CHANGED
function Events:PLAYER_FLAGS_CHANGED()
	FPerl.Target.UpdateCombat(self)
	FPerl.Target.UpdatePVP(self)
	FPerl.Target.UpdateHealth(self)
end

-- UNIT_CONNECTION
function Events:UNIT_CONNECTION(unit, online)
	if (unit == self.partyid) then
		FPerl.Target.UpdateDisplay(self)
	end
end

-- UNIT_PHASE
function Events:UNIT_PHASE(unit)
	if (unit == self.partyid) then
		FPerl.Target.UpdateDisplay(self)
	end
end

-- PARTY_LOOT_METHOD_CHANGED
function Events:PARTY_LOOT_METHOD_CHANGED()
	FPerl.Target.UpdateLeader(self)
end
Events.GROUP_ROSTER_UPDATE = Events.PARTY_LOOT_METHOD_CHANGED
Events.PARTY_LEADER_CHANGED = Events.PARTY_LOOT_METHOD_CHANGED

function Events:UNIT_THREAT_LIST_UPDATE(unit)
	if (UnitCanAttack("player", self.partyid or "target")) then
		FPerl.UnitThreatStatus(self, self.partyid == "target" and "player" or nil)
	else
		FPerl.UnitThreatStatus(self)
	end
end

function FPerl.Elements.TargetHeal.events:UNIT_HEAL_PREDICTION(unit)
	if self == FPerl_Target then
		if (tconf.healprediction and unit == self.partyid) then
			FPerl.SetExpectedHealth(self)
		end
	elseif self == FPerl_Focus then
		if (fconf.healprediction and unit == self.partyid) then
			FPerl.SetExpectedHealth(self)
		end
	end
end

function Events:UNIT_ABSORB_AMOUNT_CHANGED(unit)
	if self == FPerl_Target then
		if (tconf.absorbs and unit == self.partyid) then
			FPerl.SetExpectedAbsorbs(self)
		end
	elseif self == FPerl_TargetTarget or self == FPerl_TargetTargetTarget then
		if (self.conf.absorbs and unit == self.partyid) then
			FPerl.SetExpectedAbsorbs(self)
		end
	elseif self == FPerl_Focus then
		if (fconf.absorbs and unit == self.partyid) then
			FPerl.SetExpectedAbsorbs(self)
		end
	elseif self == FPerl_FocusTarget then
		if (conf.focustarget.absorbs and unit == self.partyid) then
			FPerl.SetExpectedAbsorbs(self)
		end
	end
end

function Events:INCOMING_RESURRECT_CHANGED(unit)
	if (unit == self.partyid) then
		FPerl.Target.UpdateResurrectionStatus(self)
	end
end
