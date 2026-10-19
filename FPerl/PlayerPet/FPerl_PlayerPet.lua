-- Author: Resike
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

local Events = {}
local conf, pconf
FPerl.RequestConfig(function(new)
	conf = new
	pconf = new.pet
	if FPerl_Player_Pet then
		FPerl_Player_Pet.conf = pconf
		FPerl.MainFrameStart(FPerl_Player_Pet, pconf.enable, PetFrame)
	end
end, "$Revision:  $")

-- Upvalues
local _G = _G
local format = format
local max = max
local tonumber = tonumber

local GetPetHappiness = GetPetHappiness
local InCombatLockdown = InCombatLockdown
local RegisterAttributeDriver = RegisterAttributeDriver
local RegisterUnitWatch = RegisterUnitWatch
local UnitAffectingCombat = UnitAffectingCombat
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitHasIncomingResurrection = UnitHasIncomingResurrection
local UnitHasVehicleUI = UnitHasVehicleUI
local UnitIsCharmed = UnitIsCharmed
local UnitIsDead = UnitIsDead
local UnitIsFriend = UnitIsFriend
local UnitName = UnitName
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnregisterUnitWatch = UnregisterUnitWatch

local CombatFeedback_Initialize = CombatFeedback_Initialize
local CombatFeedback_OnCombatEvent = CombatFeedback_OnCombatEvent
local CombatFeedback_OnUpdate = CombatFeedback_OnUpdate

-- secret value helpers from FPerl.lua
local CanAccess = FPerl.CanAccess
local IsSecret = FPerl.IsSecret
local SafeBool = FPerl.SafeBool

local HighlightCallback
local EnableEvents

-- FPerl.PlayerPet.OnLoad
function FPerl.PlayerPet.OnLoad(self)
	FPerl.SetChildMembers(self)
	self.partyid = "pet"

	CombatFeedback_Initialize(self, self.hitIndicator.text, 30)

	--FPerl.SecureUnitButtonOnLoad(self, "pet", nil, PetFrameDropDown, FPerl_ShowGenericMenu)			--PetFrame.menu)
	--FPerl.SecureUnitButtonOnLoad(self.nameFrame, "pet", nil, PetFrameDropDown, FPerl_ShowGenericMenu)	--PetFrame.menu)

	self.nameFrame:SetAttribute("*type1", "target")
	self.nameFrame:SetAttribute("type2", "togglemenu")
	self.nameFrame:SetAttribute("unit", self.partyid)
	self:SetAttribute("*type1", "target")
	self:SetAttribute("type2", "togglemenu")
	self:SetAttribute("unit", self.partyid)

	--RegisterAttributeDriver(self.nameFrame, "unit", "[vehicleui] player; pet")
	RegisterAttributeDriver(self, "unit", "[vehicleui] player; pet")

	FPerl.RegisterClickCastFrame(self.nameFrame)
	FPerl.RegisterClickCastFrame(self)

	--RegisterUnitWatch(self)
	EnableEvents(self)

	self.time = 0

	self:SetScript("OnShow", FPerl.UnitUpdatePortrait)

	if FPerl.ArcaneBar.RegisterFrame then
		FPerl.ArcaneBar.RegisterFrame(self.nameFrame, UnitHasVehicleUI("player") and "player" or "pet")
	end

	FPerl.RegisterHighlight(self.highlight, 2)
	FPerl.RegisterPerlFrames(self, {self.nameFrame, self.statsFrame, self.portraitFrame, self.levelFrame})
	self.FlashFrames = {self.nameFrame, self.levelFrame, self.statsFrame, self.portraitFrame}

	FPerl.RegisterOptionChanger(FPerl.PlayerPet.SetBits, self, "playerpet")

	FPerl_Highlight:Register(HighlightCallback, self)

	if FPerl.layout then
		self.conf = FPerl.layout.pet
	end

	FPerl.PlayerPet.OnLoad = nil
end

-- HighlightCallback
function HighlightCallback(self, updateGUID)
	if updateGUID == UnitGUID("pet") then
		FPerl_Highlight:SetHighlight(self, updateGUID)
	end
end

-- UpdateName
local function UpdateName(self)
	local partyid = self.partyid
	local petname = UnitName(partyid)

	if CanAccess(petname) and petname == UNKNOWN then
		self.nameFrame.text:SetText("")
	else
		self.nameFrame.text:SetText(petname)
	end

	if partyid == "pet" then
		local c = conf.colour.reaction.none
		self.nameFrame.text:SetTextColor(c.r, c.g, c.b, conf.transparency.text)
	elseif not UnitIsFriend("player", "pet") then		-- Pet or you charmed
		local c = conf.colour.reaction.enemy
		self.nameFrame.text:SetTextColor(c.r, c.g, c.b, conf.transparency.text)
	else
		FPerl.ColourFriendlyUnit(self.nameFrame.text, partyid)
	end
end

-- UpdateLevel
local function UpdateLevel(self)
	FPerl.UnitUpdateLevel(self)
end

-- UpdateAbsorbPrediction
local function UpdateAbsorbPrediction(self)
	if pconf.absorbs then
		FPerl.SetExpectedAbsorbs(self)
	else
		self.statsFrame.expectedAbsorbs:Hide()
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

	FPerl.SetHealthBar(self)

	UpdateAbsorbPrediction(self)
	UpdateHealPrediction(self)
	UpdateResurrectionStatus(self)

	if SafeBool(UnitIsDead(partyid), false) then
		self.statsFrame.healthBar.text:SetText(FPERL_LOC_DEAD)
		self.statsFrame.manaBar.text:Hide()
	end
end

-- UpdateMana()
local powerStyle = {text = "whole"}
local function UpdateMana(self)
	FPerl.PowerUpdate(self, powerStyle)

	if pconf.values then
		self.statsFrame.manaBar.text:Show()
	end
end

-- CombatFlash
local function CombatFlash(self, elapsed, argNew, argGreen)
	if FPerl.CombatFlashSet(self, elapsed, argNew, argGreen) then
		FPerl.CombatFlashSetFrames(self)
	end
end

-- FPerl.PlayerPet.OnUpdate
function FPerl.PlayerPet.OnUpdate(self, elapsed)
	local feedback = pconf.hitIndicator and pconf.portrait
	if feedback then
		CombatFeedback_OnUpdate(self, elapsed)
	end
	if self.PlayerFlash then
		CombatFlash(self, elapsed, false)
	end
	FPerl.OnUpdateIdle(self, feedback)
end

---------------
-- Happiness --
---------------
-- GetPetHappiness is gone, but happiness itself still exists --
-- it is now a power type, Enum.PowerType.Happiness (27). Confirmed on a live
-- hunter pet: 975 of a 1000 maximum while the pet showed as happy. The 1/2/3
-- level comes from three equal bands, the classic model; adjust HAPPY_BANDS
-- alone if a reading at content or unhappy ever contradicts it. damagePercentage
-- and loyaltyRate have no power-type equivalent, so those two tooltip lines are
-- dropped on this path.
local HAPPY_BANDS = 3
local function HappinessFromPower(unit)
	local powerType = Enum and Enum.PowerType and Enum.PowerType.Happiness
	if (not powerType) then
		return
	end
	local cur, max = UnitPower(unit, powerType), UnitPowerMax(unit, powerType)
	-- A pet's power can be secret in combat, and this drives comparisons and
	-- maths below; bail rather than crash.
	if (not cur or not max or IsSecret(cur) or IsSecret(max) or max <= 0) then
		return
	end
	-- Zero is a real reading here (a pet about to run away), not "no happiness":
	-- this only ever runs for hunters, since VARIABLES_LOADED nils the whole
	-- function for every other class. The clamp below turns it into band 1.
	local band = math.ceil((cur / max) * HAPPY_BANDS)
	if (band < 1) then
		band = 1
	elseif (band > HAPPY_BANDS) then
		band = HAPPY_BANDS
	end
	return band
end

local function SetHappiness(self)
	local happiness, damagePercentage, loyaltyRate
	if (GetPetHappiness) then
		happiness, damagePercentage, loyaltyRate = GetPetHappiness()
	else
		happiness = HappinessFromPower(self.partyid)
	end
	if (not happiness) then
		-- No happiness for this pet (or unreadable): leave the icon alone.
		FPerl.FrameFlashStop(self.happyFrame)
		self.happyFrame:Hide()
		return
	end

	local icon = self.happyFrame.icon
	icon.tex:SetTexCoord(0.5625 - (0.1875 * happiness), 0.75 - (0.1875 * happiness), 0, 0.359375)

	if pconf.happiness.enable and (not pconf.happiness.onlyWhenSad or happiness < 3) then
		self.happyFrame:Show()

		icon.tooltip = _G[("PET_HAPPINESS"..happiness)]
		-- Both of these are nil whenever GetPetHappiness is unavailable, and
		-- the old code compared loyaltyRate without checking it existed.
		icon.tooltipDamage = damagePercentage and format(PET_DAMAGE_PERCENTAGE, damagePercentage) or nil
		if (not loyaltyRate or loyaltyRate == 0) then
			icon.tooltipLoyalty = nil
		elseif (loyaltyRate < 0) then
			icon.tooltipLoyalty = LOSING_LOYALTY
		else
			icon.tooltipLoyalty = GAINING_LOYALTY
		end

		if pconf.happiness.flashWhenSad and happiness < 3 then
			FPerl.FrameFlash(self.happyFrame)
		else
			FPerl.FrameFlashStop(self.happyFrame)
		end
	else
		FPerl.FrameFlashStop(self.happyFrame)
		self.happyFrame:Hide()
	end
end

-- UpdateControl
local function UpdateControl(self)
	-- indirect units can return secret flags; no icon in that case
	if SafeBool(UnitIsCharmed(self.partyid), false) and SafeBool(UnitIsPlayer(self.partyid), false) then
		self.nameFrame.warningIcon:Show()
	else
		self.nameFrame.warningIcon:Hide()
	end
end

-- UpdateCombat
local function UpdateCombat(self)
	local partyid = self.partyid
	if UnitExists(partyid) then
		if (UnitAffectingCombat(partyid)) then
			self.nameFrame.combatIcon:Show()
		else
			self.nameFrame.combatIcon:Hide()
		end
		UpdateControl(self)
	end
end

-- FPerl.PlayerPet.UpdateDisplay
function FPerl.PlayerPet.UpdateDisplay(self)
	local unit = self:GetAttribute("unit")
	if unit ~= self.partyid then
		self.portraitFrame:SetAlpha(0)
		self.nameFrame:SetAlpha(0)
		self.statsFrame:SetAlpha(0)
		self.levelFrame:SetAlpha(0)
	else
		self.portraitFrame:SetAlpha(1)
		self.nameFrame:SetAlpha(1)
		self.statsFrame:SetAlpha(1)
		self.levelFrame:SetAlpha(1)
	end
	FPerl.UnitUpdatePortrait(self)
	UpdateName(self)
	UpdateHealth(self)
	FPerl.SetManaBarType(self)
	if SetHappiness then
		SetHappiness(self)
	end
	UpdateMana(self)
	UpdateLevel(self)
	FPerl.AurasRebuild(self)
	FPerl.AurasUpdate(self)
	if UnitExists(self.partyid) then
		FPerl.CheckDebuffs(self, self.partyid)
	end
	UpdateCombat(self)
end

-------------------
-- Event Handler --
-------------------
-- Elements (FPerl_Unit.lua): PetLoad (VARIABLES_LOADED) leaves after its one run; PetHappiness is on
-- for hunters only; PlayerPet is the Events table. Unit events register for pet and
-- player unless listed.
FPerl.Elements.PetLoad = {events = {}}
FPerl.Elements.PetHeal = {events = {}} -- on while the heal prediction option is on
FPerl.Elements.PetPreview = {events = {}} -- on while the preview shows a pet that does not exist
FPerl.Elements.PetHappiness = {events = {}, units = {UNIT_HAPPINESS = GetPetHappiness and {"pet"} or nil}}
FPerl.Elements.PlayerPet = {
	events = Events,
	units = {UNIT_PET = {"player"}, UNIT_ENTERED_VEHICLE = {"player"}, UNIT_EXITING_VEHICLE = {"player"},
		UNIT_TARGET = {"pet"}},
}

-- the portrait is taller than the frame: a bottom block starts below it
local function AuraInset(self, side)
	local p = self.portraitFrame
	return (side == "BOTTOM" and p:IsShown()) and max(0, p:GetHeight() - self:GetHeight()) or 0
end

-- EnableEvents: called by OnLoad, with the update functions in reach
EnableEvents = function(self)
	local _, classFileName = UnitClass("player")
	self.updateHealth = UpdateHealth
	self.auraInset = AuraInset
	FPerl.UnitFrameInit(self, {"pet", "player"}, {"PetLoad", "Health", "PlayerPet", "Auras"})
	if classFileName == "HUNTER" then
		FPerl.UnitFrameEnable(self, "PetHappiness")
	end
end

-- VARIABLES_LOADED
function FPerl.Elements.PetLoad.events:VARIABLES_LOADED()
	local _, classFileName = UnitClass("player")
	if classFileName ~= "HUNTER" then
		-- Disable happiness for non-hunters
		SetHappiness = nil
	end

	FPerl.UnitFrameDisable(self, "PetLoad")
end

-- UNIT_AURA
function Events:UNIT_AURA()
	if UnitExists(self.partyid) then
		FPerl.CheckDebuffs(self, self.partyid)
	end
end

-- UNIT_PET
function Events:UNIT_PET()
	if conf then		-- DK can issue very early UNIT_PET, long before PEW. We refresh on entering world regardless
		--self.partyid = UnitHasVehicleUI("player") and "player" or "pet"
		FPerl.PlayerPet.UpdateDisplay(self)
	end
end

-- UNIT_NAME_UPDATE
function Events:UNIT_NAME_UPDATE()
	UpdateName(self)
end

-- UNIT_PORTRAIT_UPDATE
function Events:UNIT_PORTRAIT_UPDATE()
	FPerl.UnitUpdatePortrait(self, true)
end

function Events:UNIT_POWER_FREQUENT()
	UpdateMana(self)
	UpdateCombat(self)
	-- Without GetPetHappiness there is no UNIT_HAPPINESS to ride, and happiness
	-- is itself a power now, so this is where it changes.
	if (not GetPetHappiness and SetHappiness) then
		SetHappiness(self)
	end
end

function Events:UNIT_MAXPOWER()
	UpdateMana(self)
	UpdateCombat(self)
end

-- UNIT_LEVEL
function Events:UNIT_LEVEL()
	UpdateLevel(self)
end

-- UNIT_DISPLAYPOWER
function Events:UNIT_DISPLAYPOWER()
	FPerl.SetManaBarType(self)
end

-- UNIT_HAPPINESS
function FPerl.Elements.PetHappiness.events:UNIT_HAPPINESS()
	SetHappiness(self)
	UpdateCombat(self)
end

-- PET_ATTACK_START
function Events:PET_ATTACK_START()
	UpdateCombat(self)
end

-- UNIT_COMBAT
function Events:UNIT_COMBAT(unit, action, descriptor, damage, damageType)
	if unit ~= self.partyid then
		return
	end
	-- set first: the flash and hit text animate even when a later line raises on a secret amount
	self:SetScript("OnUpdate", FPerl.PlayerPet.OnUpdate)

	if pconf.hitIndicator and pconf.portrait then
		CombatFeedback_OnCombatEvent(self, action, descriptor, damage, damageType)
	end

	if action == "HEAL" then
		CombatFlash(FPerl_Player_Pet, 0, true, true)
	elseif (damage and damage > 0) then
		CombatFlash(FPerl_Player_Pet, 0, true)
	end
end

-- UNIT_FACTION
function Events:UNIT_FACTION()
	UpdateName(self)
	UpdateCombat(self)
end

Events.UNIT_FLAGS = Events.UNIT_FACTION

-- SetUnitAttribute: protected; applies the unit chosen at PLAYER_ENTERING_WORLD (the vehicle
-- handlers change partyid later and set no attribute)
local function SetUnitAttribute(self)
	self:SetAttribute("unit", self.attrUnit)
end

-- PLAYER_ENTERING_WORLD
function Events:PLAYER_ENTERING_WORLD()
	self.partyid = UnitHasVehicleUI("player") and "player" or "pet"
	self.unit = self.partyid
	self.attrUnit = self.partyid
	FPerl.AfterCombat(SetUnitAttribute, self)
end

-- UNIT_ENTERED_VEHICLE
function Events:UNIT_ENTERED_VEHICLE(unit, showVehicle)
	if showVehicle then
		self.partyid = "player"
		self.unit = self.partyid
		if FPerl.ArcaneBar.SetUnit then
			FPerl.ArcaneBar.SetUnit(self.nameFrame, "player")
		end
		FPerl.PlayerPet.UpdateDisplay(self)
	end
end

-- UNIT_EXITING_VEHICLE
function Events:UNIT_EXITING_VEHICLE()
	if self.partyid ~= "pet" then
		self.partyid = "pet"
		self.unit = self.partyid
		if (FPerl.ArcaneBar.SetUnit) then
			FPerl.ArcaneBar.SetUnit(self.nameFrame, "pet")
		end
		FPerl.PlayerPet.UpdateDisplay(self)
	end
end

function Events:PLAYER_TARGET_CHANGED()
	FPerl.UnitThreatStatus(self, nil, true)
end
Events.UNIT_TARGET = Events.PLAYER_TARGET_CHANGED

-- PLAYER_REGEN_DISABLED
local virtual
function FPerl.Elements.PetPreview.events:PLAYER_REGEN_DISABLED()
	-- Whether lockdown is already on at this event is unmeasured; if it is, leave preview mode after combat
	if virtual and InCombatLockdown() then
		FPerl.AfterCombat(FPerl.Elements.PetPreview.events.PLAYER_REGEN_DISABLED, self)
		return
	end
	if virtual then
		virtual = nil
		RegisterUnitWatch(FPerl_Player_Pet)
		if UnitExists("pet") then
			FPerl_Player_Pet:Show()
			FPerl.PlayerPet.UpdateDisplay(FPerl_Player_Pet)
		else
			FPerl_Player_Pet:Hide()
		end

		if FPerl_PetTarget then
			RegisterUnitWatch(FPerl_PetTarget)
			if (UnitExists("pettarget")) then
				FPerl_PetTarget:Show()
				FPerl.TargetTarget.UpdateDisplay(FPerl_PetTarget)
			else
				FPerl_PetTarget:Hide()
			end
		end
	end
end

function FPerl.Elements.PetHeal.events:UNIT_HEAL_PREDICTION(unit)
	if pconf.healprediction and unit == self.partyid then
		FPerl.SetExpectedHealth(self)
	end
end

function Events:UNIT_ABSORB_AMOUNT_CHANGED(unit)
	if pconf.absorbs and unit == self.partyid then
		FPerl.SetExpectedAbsorbs(self)
	end
end

function Events:INCOMING_RESURRECT_CHANGED(unit)
	if unit == self.partyid then
		UpdateResurrectionStatus(self)
	end
end

-- FPerl.PlayerPet.SetWidth
function FPerl.PlayerPet.SetWidth(self)
	if (InCombatLockdown()) then
		FPerl.AfterCombat(FPerl.PlayerPet.SetWidth, self)
		return
	end
	pconf.size.width = max(0, pconf.size.width or 0)
	self.statsFrame:SetWidth(80 + pconf.size.width)
	self.nameFrame:SetWidth(80 + pconf.size.width)
	FPerl.SetScale(self, pconf.scale)
	FPerl.StatsFrameSetup(self, nil, 2)
end

-- FPerl.PlayerPet.Virtual
function FPerl.PlayerPet.Virtual(show)
	if FPerl_Player_Pet.off then
		return
	end
	if InCombatLockdown() then
		FPerl.AfterCombat(FPerl.PlayerPet.Virtual, show and true or false)
		return
	end
	if show then
		if not virtual then
			virtual = true
			if not UnitExists("pet") then
				FPerl.UnitFrameEnable(FPerl_Player_Pet, "PetPreview")
				UnregisterUnitWatch(FPerl_Player_Pet)
				FPerl_Player_Pet:Show()
				FPerl_Player_Pet.nameFrame.text:SetText(PET)
				FPerl_Player_Pet.statsFrame.healthBar.text:SetText("")
				FPerl_Player_Pet.statsFrame.manaBar.text:SetText("")
				FPerl_Player_Pet:SetAlpha(0.5)
			end

			if FPerl_PetTarget and not UnitExists("pettarget") then
				FPerl_PetTarget.virtual = true
				UnregisterUnitWatch(FPerl_PetTarget)
				FPerl_PetTarget:Show()
				FPerl_PetTarget.nameFrame.text:SetText(PET.." "..TARGET)
				FPerl_PetTarget.statsFrame.healthBar.text:SetText("")
				FPerl_PetTarget.statsFrame.manaBar.text:SetText("")
				FPerl_PetTarget.statsFrame.healthBar.percent:SetText("")
				FPerl_PetTarget.statsFrame.manaBar.percent:SetText("")
				FPerl_PetTarget:SetAlpha(0.5)
			end
		end
	else
		if virtual then
			virtual = nil
			RegisterUnitWatch(FPerl_Player_Pet)
			if FPerl_PetTarget then
				FPerl_PetTarget.virtual = nil
				if (FPerl_PetTarget.conf and FPerl_PetTarget.conf.enable) then
					RegisterUnitWatch(FPerl_PetTarget)
					FPerl_PetTarget:Hide()
				end
			end
			FPerl.UnitFrameDisable(FPerl_Player_Pet, "PetPreview")
		end
	end
end

-- ApplyLayout: the protected part of Set_Bits; reads the config when it runs
local function ApplyLayout(self)
	if not virtual then
		RegisterUnitWatch(self)
	end

	if pconf.portrait then
		self.portraitFrame:Show()
		self.portraitFrame:SetWidth(50)
		self.statsFrame.resurrect:Hide()
	else
		self.portraitFrame:Hide()
		self.portraitFrame:SetWidth(3)
	end

	if pconf.name then
		self.nameFrame:Show()
		self.nameFrame:SetHeight(24)
	else
		self.nameFrame:Hide()
		self.nameFrame:SetHeight(2)
	end

	self.portraitFrame:SetHeight(56 + (pconf.extendPortrait and 1 or 0) * 10)
end

-- FPerl.PlayerPet.SetBits
function FPerl.PlayerPet.SetBits(self)
	if self.off then
		return
	end
	FPerl.AfterCombat(ApplyLayout, self)

	if pconf.name or pconf.portrait then
		if pconf.level then
			self.levelFrame:SetPoint("TOPRIGHT", self.portraitFrame, "TOPLEFT", 2, 0)
		end
	else
		if pconf.level then
			self.levelFrame:SetPoint("TOPRIGHT", self.statsFrame, "TOPLEFT", 2, 0)
		end
	end

	if pconf.level then
		self.levelFrame:Show()
	else
		self.levelFrame:Hide()
	end

	if pconf.values then
		self.statsFrame.healthBar.text:Show()
		self.statsFrame.manaBar.text:Show()
	else
		self.statsFrame.healthBar.text:Hide()
		self.statsFrame.manaBar.text:Hide()
	end

	self.highlight:ClearAllPoints()
	if pconf.portrait or pconf.name then
		self.highlight:SetPoint("BOTTOMLEFT", self.portraitFrame)
	else
		self.highlight:SetPoint("BOTTOMLEFT", self.statsFrame)
	end
	self.highlight:SetPoint("TOPRIGHT", self.nameFrame)

	pconf.buffs.size = tonumber(pconf.buffs.size) or 20

	FPerl.RegisterPrediction(self, pconf, "PetHeal")

	FPerl.PlayerPet.SetWidth(self)

	if self:IsShown() then
		FPerl.PlayerPet.UpdateDisplay(self)
	end
end
