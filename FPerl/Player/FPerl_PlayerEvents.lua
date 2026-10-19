-- Author: Resike
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

local Events = { }
local conf, pconf
FPerl.RequestConfig(function(new)
	conf = new
	pconf = conf.player
end, "$Revision:  $")

-- Upvalues
local max = max
local InCombatLockdown = InCombatLockdown
local UnitOnTaxi = UnitOnTaxi
local UnitPowerType = UnitPowerType
local CombatFeedback_OnCombatEvent = CombatFeedback_OnCombatEvent

-- Update functions of FPerl_Player.lua
local UpdateAssignedRoles = FPerl.Player.UpdateAssignedRoles
local CombatFlash = FPerl.Player.CombatFlash
local UpdateManaType = FPerl.Player.UpdateManaType
local UpdateLeader = FPerl.Player.UpdateLeader
local UpdateRaidTarget = FPerl.Player.UpdateRaidTarget
local UpdateCombat = FPerl.Player.UpdateCombat
local UpdateName = FPerl.Player.UpdateName
local UpdateClass = FPerl.Player.UpdateClass
local UpdateRep = FPerl.Player.UpdateRep
local UpdateXP = FPerl.Player.UpdateXP
local UpdatePVPTimer = FPerl.Player.UpdatePVPTimer
local UpdatePVP = FPerl.Player.UpdatePVP
local CreateBar = FPerl.Player.CreateBar
local ApplyStatsHeight = FPerl.Player.ApplyStatsHeight
local UpdateMana = FPerl.Player.UpdateMana
local UpdateResurrectionStatus = FPerl.Player.UpdateResurrectionStatus
local UpdateHealth = FPerl.Player.UpdateHealth
local UpdateLevel = FPerl.Player.UpdateLevel
local UpdateBuffs = FPerl.Player.UpdateBuffs
local PlayerStatusOnUpdate = FPerl.Player.PlayerStatusOnUpdate

-- EVENTS AND STUFF

-------------------
-- Event Handler --
-------------------
-- Elements (FPerl_Unit.lua): PlayerLoad and PlayerWorld are on from OnLoad, the rest once the
-- variables are loaded; PlayerXP follows the XP bar option.
FPerl.Elements.PlayerLoad = {events = {}}
FPerl.Elements.PlayerWorld = {events = {}}
FPerl.Elements.PlayerXP = {events = {}}
FPerl.Elements.PlayerHeal = {events = {}}
FPerl.Elements.Player = {
	events = Events,
	units = {UNIT_ENTERED_VEHICLE = {"player"}, UNIT_EXITING_VEHICLE = {"player"}},
}

function FPerl.Elements.PlayerWorld.events:PLAYER_ALIVE()
	FPerl.Player.UpdateDisplay(self)
end


-- SetUnitAttribute: protected
local function SetUnitAttribute(self)
	self:SetAttribute("unit", "player")
end

-- PLAYER_ENTERING_WORLD
function FPerl.Elements.PlayerWorld.events:PLAYER_ENTERING_WORLD()
	self.updateAFK = true

	self.partyid = "player"
	self.unit = self.partyid
	FPerl.AfterCombat(SetUnitAttribute, self)
	if (FPerl.ArcaneBar.SetUnit) then
		FPerl.ArcaneBar.SetUnit(self.nameFrame, "player")
	end

	FPerl.Player.UpdateDisplay(self)

	--C_Timer.After(0.1, function() FPerl.Player.SetBits(self) end)
end

-- UNIT_COMBAT
function Events:UNIT_COMBAT(unit, action, descriptor, damage, damageType)
	if unit ~= self.partyid then
		return
	end
	-- set first: the flash and hit text animate even when a later line raises on a secret amount
	self:SetScript("OnUpdate", FPerl.Player.OnUpdate)

	if (pconf.hitIndicator and pconf.portrait) then
		CombatFeedback_OnCombatEvent(self, action, descriptor, damage, damageType)
	end

	if (action == "HEAL") then
		CombatFlash(self, 0, true, true)
	elseif (damage and damage > 0) then
		CombatFlash(self, 0, true)
	end
end

-- UNIT_PORTRAIT_UPDATE
function Events:UNIT_PORTRAIT_UPDATE()
	FPerl.UnitUpdatePortrait(self, true)
end

-- VARIABLES_LOADED
function FPerl.Elements.PlayerLoad.events:VARIABLES_LOADED()
	self.doubleCheckAFK = 2 -- Check during 2nd UPDATE_FACTION, which are the last guarenteed events to come after logging in
	FPerl.UnitFrameDisable(self, "PlayerLoad")

	self.updateHealth = UpdateHealth
	self.updatePower = UpdateMana
	self.updatePowerType = function(frame)
		UpdateManaType(frame)
		UpdateMana(frame)
	end
	FPerl.UnitFrameEnable(self, "Health")
	FPerl.UnitFrameEnable(self, "Power")
	FPerl.UnitFrameEnable(self, "Player")
end

function Events:UPDATE_EXHAUSTION()
	UpdateXP(self)
end

-- PARTY_LOOT_METHOD_CHANGED
function Events:PARTY_LOOT_METHOD_CHANGED()
	UpdateLeader(self)
end

-- PARTY_LEADER_CHANGED
function Events:PARTY_LEADER_CHANGED()
	UpdateLeader(self)
end

-- GROUP_ROSTER_UPDATE
function Events:GROUP_ROSTER_UPDATE()
	UpdateLeader(self)
end

-- PLAYER_DEAD
function Events:PLAYER_DEAD()
	UpdateHealth(self)
end

-- UNIT_NAME_UPDATE
function Events:UNIT_NAME_UPDATE()
	UpdateName(self)
end

-- UNIT_LEVEL
function Events:UNIT_LEVEL()
	UpdateLevel(self)
	UpdateXP(self)
end

-- PLAYER_XP_UPDATE
function FPerl.Elements.PlayerXP.events:PLAYER_XP_UPDATE()
	UpdateXP(self)
end

-- UPDATE_FACTION
function Events:UPDATE_FACTION()
	UpdateRep(self)

	if (self.doubleCheckAFK) then
		if (conf and pconf) then
			self.doubleCheckAFK = self.doubleCheckAFK - 1
			if (self.doubleCheckAFK <= 0) then
				UpdateHealth(self)
				self.doubleCheckAFK = nil
			end
		end
	end
end

-- UNIT_FACTION
function Events:UNIT_FACTION()
	UpdateHealth(self)
	UpdatePVP(self)
	UpdateCombat(self)
end
Events.UNIT_FLAGS = Events.UNIT_FACTION

function Events:PLAYER_FLAGS_CHANGED()
	UpdateHealth(self)
	UpdatePVPTimer(self)
end

-- RAID_TARGET_UPDATE
function Events:RAID_TARGET_UPDATE()
	UpdateRaidTarget(FPerl_Player)
end

-- PLAYER_TALENT_UPDATE
function Events:PLAYER_TALENT_UPDATE()
	UpdateMana(self)
end

-- UPDATE_SHAPESHIFT_FORM
function Events:UPDATE_SHAPESHIFT_FORM()
	if (FPerl.Player.playerClass == "DRUID") or (FPerl.Player.playerClass == "SHAMAN") or (FPerl.Player.playerClass == "PRIEST") then
		FPerl.Player.DruidBarUpdate(self)
	end
end

-- PLAYER_ENTER_COMBAT, PLAYER_LEAVE_COMBAT
function Events:PLAYER_ENTER_COMBAT()
	UpdateCombat(self)
end
Events.PLAYER_LEAVE_COMBAT = Events.PLAYER_ENTER_COMBAT

-- PLAYER_REGEN_ENABLED
-- The unit attribute follows the attribute driver (vehicleui), in and out of combat.
function Events:PLAYER_REGEN_ENABLED()
	UpdateCombat(self)
	UpdateBuffs(self)
end

-- PLAYER_REGEN_DISABLED
function Events:PLAYER_REGEN_DISABLED()
	UpdateCombat(self)
	UpdateBuffs(self)
end

function Events:PLAYER_UPDATE_RESTING()
	UpdateCombat(self)
	UpdateXP(self)
end

function Events:PLAYER_SPECIALIZATION_CHANGED()
	FPerl.Player.SetBits(self)

	if FPerl.PlayerBuffs.Position then
		FPerl.PlayerBuffs.Position(FPerl_Player)
	end
end

function Events:UNIT_AURA()
	UpdateBuffs(self)
end

-- PLAYER_CONTROL_LOST
function Events:PLAYER_CONTROL_LOST()
	if pconf.fullScreen.enable and not UnitOnTaxi("player") then
		FPerl.Player.isOutOfControl = true
	end
end

-- PLAYER_CONTROL_GAINED
function Events:PLAYER_CONTROL_GAINED()
	FPerl.Player.isOutOfControl = nil
	if (pconf.fullScreen.enable) then
		PlayerStatusOnUpdate(self)
	end
end

-- UNIT_ENTERED_VEHICLE
function Events:UNIT_ENTERED_VEHICLE(unit, showVehicle)
	if showVehicle then
		self.partyid = "vehicle"
		self.unit = self.partyid
		if FPerl.ArcaneBar.SetUnit then
			FPerl.ArcaneBar.SetUnit(self.nameFrame, "vehicle")
		end
		FPerl.Player.UpdateDisplay(self)
		--FPerl.SetUnitNameColor(self.nameFrame.text, self.partyid)
	end
end

-- UNIT_EXITING_VEHICLE
function Events:UNIT_EXITING_VEHICLE()
	if self.partyid ~= "player" then
		self.partyid = "player"
		self.unit = self.partyid
		if FPerl.ArcaneBar.SetUnit then
			FPerl.ArcaneBar.SetUnit(self.nameFrame, "player")
		end
		FPerl.Player.UpdateDisplay(self)
	end
end

-- Element PlayerHeal: on while the option is on (FPerl.RegisterPrediction)
function FPerl.Elements.PlayerHeal.events:UNIT_HEAL_PREDICTION(unit)
	if pconf.healprediction and unit == self.partyid then
		FPerl.SetExpectedHealth(self)
	end
end

function Events:UNIT_ABSORB_AMOUNT_CHANGED(unit)
	if (pconf.absorbs and unit == self.partyid) then
		FPerl.SetExpectedAbsorbs(self)
	end
end

function Events:INCOMING_RESURRECT_CHANGED(unit)
	if unit == self.partyid then
		UpdateResurrectionStatus(self)
	end
end

-- FPerl.Player.SetWidth
function FPerl.Player.SetWidth(self)
	if (InCombatLockdown()) then
		FPerl.AfterCombat(FPerl.Player.SetWidth, self)
		return
	end
	pconf.size.width = max(0, pconf.size.width or 0)
	if (pconf.percent) then
		self.nameFrame:SetWidth(160 + pconf.size.width)
		self.statsFrame:SetWidth(160 + pconf.size.width)
		self.statsFrame.healthBar.percent:Show()
		self.statsFrame.manaBar.percent:Show()

		if (self.statsFrame.xpBar) then
			self.statsFrame.xpBar.percent:Show()
		end
		if (self.statsFrame.repBar) then
			self.statsFrame.repBar.percent:Show()
		end
	else
		self.nameFrame:SetWidth(128 + pconf.size.width)
		self.statsFrame:SetWidth(128 + pconf.size.width)
		self.statsFrame.healthBar.percent:Hide()
		self.statsFrame.manaBar.percent:Hide()
		if (self.statsFrame.xpBar) then
			self.statsFrame.xpBar.percent:Hide()
		end
		if (self.statsFrame.repBar) then
			self.statsFrame.repBar.percent:Hide()
		end
	end

	ApplyStatsHeight(self)

	self:SetWidth(128 + (pconf.portrait and 1 or 0) * 62 + (pconf.percent and 1 or 0) * 32 + pconf.size.width)
	FPerl.SetScale(self, pconf.scale)

	FPerl.StatsFrameSetup(self, {self.statsFrame.druidBar, self.statsFrame.xpBar, self.statsFrame.repBar})
	if (FPerl.PlayerBuffs.Position) then
		FPerl.PlayerBuffs.Position(self)
	end

	UpdateHealth(self)
	UpdateMana(self)
	UpdateXP(self)
end

-- MakeXPBar
local function MakeXPBar(self)
	local f = CreateBar(self, "xpBar")
	local f2 = CreateBar(self, "xpRestBar")

	f2:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	f2:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

	MakeXPBar = nil
end

-- SetBitsLayout: the protected part of FPerl.Player.SetBits
local function SetBitsLayout(self)
	if (pconf.portrait) then
		self.portraitFrame:Show()
		self.portraitFrame:SetWidth(62)
		self.statsFrame.resurrect:Hide()
	else
		self.portraitFrame:Hide()
		self.portraitFrame:SetWidth(3)
	end

	FPerl.Player.SetWidth(self)

	local h1 = self.nameFrame:GetHeight() + self.statsFrame:GetHeight() - 2
	local h2 = self.portraitFrame:GetHeight()
	FPerl.SwitchAnchor(self, "TOPLEFT")
	self:SetHeight(max(h1, h2))

	if (pconf.extendPortrait) then
		local druidBarExtra
		if (UnitPowerType(self.partyid) > 0 and not pconf.noDruidBar) and ((FPerl.Player.playerClass == "DRUID") or (FPerl.Player.playerClass == "PRIEST")) then
			druidBarExtra = 1
		else
			druidBarExtra = 0
		end

		self:SetHeight(62 + druidBarExtra * 10 + (((pconf.xpBar and 1 or 0) + (pconf.repBar and 1 or 0)) * 10))
		self.portraitFrame:SetHeight(62 + druidBarExtra * 10 + (((pconf.xpBar and 1 or 0) + (pconf.repBar and 1 or 0)) * 10))
	else
		self:SetHeight(62)
		self.portraitFrame:SetHeight(62)
	end
end

-- FPerl.Player.SetBits()
function FPerl.Player.SetBits(self)
	if (self.off) then
		return
	end
	if (FPerl.ArcaneBar.RegisterFrame and not self.nameFrame.castBar) then
		FPerl.ArcaneBar.RegisterFrame(self.nameFrame, "player")
	end

	if (pconf.level) then
		self.levelFrame:Show()
	else
		self.levelFrame:Hide()
	end

	UpdateClass(self)

	if (pconf.repBar) then
		if (not self.statsFrame.repBar) then
			CreateBar(self, "repBar")
		end

		self.statsFrame.repBar:Show()
	else
		if (self.statsFrame.repBar) then
			self.statsFrame.repBar:Hide()
		end
	end

	if (pconf.xpBar) then
		if (not self.statsFrame.xpBar) then
			MakeXPBar(self)
		end

		self.statsFrame.xpBar:Show()
		self.statsFrame.xpRestBar:Show()

		FPerl.UnitFrameEnable(self, "PlayerXP")
	else
		if (self.statsFrame.xpBar) then
			self.statsFrame.xpBar:Hide()
			self.statsFrame.xpRestBar:Hide()
		end

		FPerl.UnitFrameDisable(self, "PlayerXP")
	end

	if (pconf.values) then
		self.statsFrame.healthBar.text:Show()
		self.statsFrame.manaBar.text:Show()
		if (self.statsFrame.druidBar) then
			self.statsFrame.druidBar.text:Show()
		end
		if (self.statsFrame.xpBar) then
			self.statsFrame.xpBar.text:Show()
		end
		if (self.statsFrame.repBar) then
			self.statsFrame.repBar.text:Show()
		end
	else
		self.statsFrame.healthBar.text:Hide()
		self.statsFrame.manaBar.text:Hide()
		if (self.statsFrame.druidBar) then
			self.statsFrame.druidBar.text:Hide()
		end
		if (self.statsFrame.xpBar) then
			self.statsFrame.xpBar.text:Hide()
		end
		if (self.statsFrame.repBar) then
			self.statsFrame.repBar.text:Hide()
		end
	end

	FPerl.RegisterPrediction(self, pconf, "PlayerHeal")

	if (FPerl.Player.playerClass == "DRUID") or (FPerl.Player.playerClass == "SHAMAN") or (FPerl.Player.playerClass == "PRIEST") then
		FPerl.Player.DruidBarUpdate(self)
	end

	FPerl.AfterCombat(SetBitsLayout, self)

	self:SetAlpha(conf.transparency.frame)

	FPerl.Player.UpdateDisplay(self)

	if (FPerl.PlayerBuffs.PlayerBuffSetup) then
		if (self.playerBuffsOn) then
			FPerl.PlayerBuffs.PlayerBuffSetup(FPerl_Player)
		end
	end

	UpdateAssignedRoles(self)
end

