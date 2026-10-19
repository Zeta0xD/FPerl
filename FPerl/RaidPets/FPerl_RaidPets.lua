-- Author: Resike
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

local Events = {} -- unit events, one set per frame (element RaidPets)
local Bus = {} -- events no frame owns (FPerl.On)
local busOn
FPerl.Elements.RaidPets = {events = Events}
local allFrames = {} -- every pet frame, in creation order
local RaidPetFrameArray = {}
local conf, rconf, raidconf
FPerl.RequestConfig(function(New)
	conf = New
	raidconf = New.raid
	rconf = New.raidpet
end, "$Revision:  $")

--local new, del, copy = FPerl.GetReusableTable, FPerl.FreeTable, FPerl.CopyTable

local pairs = pairs

local GetNumGroupMembers = GetNumGroupMembers
local GetRaidTargetIndex = GetRaidTargetIndex
local InCombatLockdown = InCombatLockdown
local SetRaidTargetIconTexture = SetRaidTargetIconTexture
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitHasIncomingResurrection = UnitHasIncomingResurrection
local UnitIsDead = UnitIsDead
local UnitName = UnitName

local SecureButton_GetUnit = SecureButton_GetUnit

-- secret value helpers from FPerl.lua
local CanAccess = FPerl.CanAccess

local LOCALIZED_CLASS_NAMES_MALE = LOCALIZED_CLASS_NAMES_MALE
local CLASS_COUNT = 0
for k, v in pairs(LOCALIZED_CLASS_NAMES_MALE) do
	if k ~= "Adventurer" and k ~= "TRAVELER" then
		CLASS_COUNT = CLASS_COUNT + 1
	end
end

-- UpdateAbsorbPrediction
local function UpdateAbsorbPrediction(self)
	if raidconf.absorbs then
		FPerl.SetExpectedAbsorbs(self)
	else
		self.expectedAbsorbs:Hide()
	end
end

-- UpdateHealPrediction
local function UpdateHealPrediction(self)
	if raidconf.healprediction then
		FPerl.SetExpectedHealth(self)
	else
		self.expectedHealth:Hide()
	end
end

local function UpdateResurrectionStatus(self)
	if (UnitHasIncomingResurrection(self.partyid)) then
		self.resurrect:Show()
	else
		self.resurrect:Hide()
	end
end

local guids = { }
-- RaidPetUpdateGUIDs
local function RaidPetUpdateGUIDs()
	wipe(guids)
	for i = 1, GetNumGroupMembers() do
		local id = "raidpet"..i
		if (UnitExists(id)) then
			-- never key the table with a nil or secret GUID
			local guid = UnitGUID(id)
			if (guid and CanAccess(guid)) then
				guids[guid] = RaidPetFrameArray[id]
			end
		end
	end
end

-- UpdateName
local function UpdateName(self)
	local partyid = SecureButton_GetUnit(self)
	if not partyid then
		self.petGUID = nil
		self.petID = nil
		self.petName = nil
		return
	end
	local name
	if partyid then
		name = UnitName(partyid)
		if name then
			self.text:SetFormattedText("%s", name)
		end
	end

	self.petGUID = UnitGUID(partyid)
	self.petID = partyid
	self.petName = name
	self:SetAlpha(conf.transparency.frame)

	if (self.ownerid) then
		local _, class = UnitClass(self.ownerid)
		local c = FPerl.GetClassColour(class)
		self.text:SetTextColor(c.r, c.g, c.b)
	else
		self.text:SetTextColor(1, 1, 1)
	end
end

-- UpdateHealth
local function UpdateHealth(self)
	local partyid = SecureButton_GetUnit(self)
	if not partyid then
		self.healthBar:SetValue(0)
		return
	end

	FPerl.HealthSetBar(self.healthBar, partyid)
	FPerl.SetSmoothBarColor(self.healthBar, partyid)

	if (FPerl.SafeBool(UnitIsDead(partyid), false)) then
		self.healthBar.text:SetText(FPERL_LOC_DEAD)
		self.healthBar:SetStatusBarColor(0.5, 0.5, 0.5, 1)
		self.healthBar.bg:SetVertexColor(0.5, 0.5, 0.5, 0.5)
	else
		-- direct: one format for plain and secret; FormatPercent truncates a secret and adds a decimal below 10
		self.healthBar.text:SetFormattedText("%.0f%%", UnitHealthPercent(partyid, true, CurveConstants.ScaleTo100))
	end

	UpdateAbsorbPrediction(self)
	UpdateHealPrediction(self)
	UpdateResurrectionStatus(self)
end

-- The range poll of the pet frames, on the scheduler, every 0.2 s (no event covers range). Health follows
-- UNIT_HEALTH / UNIT_MAXHEALTH (element Health), the debuff highlight UNIT_AURA, a changed pet or name
-- UNIT_PET / UNIT_NAME_UPDATE (bus below).
local function PollFrames()
	if not conf.rangeFinder.enabled then
		return
	end
	for _, self in ipairs(allFrames) do
		local partyid = self:IsVisible() and (SecureButton_GetUnit(self) or self.partyid)
		if partyid then
			FPerl.UpdateSpellRange(self, partyid, true)
		end
	end
end

FPerl.Every(0.2, PollFrames)

-- FPerl.RaidPets.HighlightCallback
function FPerl.RaidPets.HighlightCallback(self, updateGUID)
	if (not updateGUID or not CanAccess(updateGUID)) then
		return
	end
	local f = guids and guids[updateGUID]
	if (f) then
		FPerl_Highlight:SetHighlight(f, updateGUID)
	end
end


-- FPerl.RaidPets.OnLoad
function FPerl.RaidPets.OnLoad(self)
	self.Array = { }

	--FPerl_Raid_GrpPets:UnregisterEvent("UNIT_NAME_UPDATE") -- Fix for WoW 2.1 UNIT_NAME_UPDATE issue


	FPerl.RegisterOptionChanger(FPerl.RaidPets.OptionActions, nil, "raidpets")

	FPerl_Highlight:Register(FPerl.RaidPets.HighlightCallback, self)

	FPerl.RaidPets.OnLoad = nil
end

-- RaidTargetUpdate
local function RaidTargetUpdate(self)
	local icon = self.raidIcon
	local raidIcon
	if self.partyid then
		raidIcon = GetRaidTargetIndex(self.partyid)
	end

	if (CanAccess(raidIcon)) then
		if (not icon) then
			icon = self:CreateTexture(nil, "OVERLAY")
			self.raidIcon = icon
			icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
			icon:SetPoint("TOPLEFT")
			icon:SetWidth(13)
			icon:SetHeight(13)
		else
			icon:Show()
		end
		SetRaidTargetIconTexture(icon, raidIcon)
	elseif (icon) then
		icon:Hide()
	end
end

-- FPerl.RaidPets.UpdateDisplay
function FPerl.RaidPets.UpdateDisplayAll()
	for k, frame in pairs(RaidPetFrameArray) do
		if (frame:IsShown()) then
			FPerl.RaidPets.UpdateDisplay(frame)
		end
	end
end

-- FPerl.RaidPets.UpdateDisplay
function FPerl.RaidPets.UpdateDisplay(self)
	local partyid = SecureButton_GetUnit(self)
	if not partyid then
		return
	end

	UpdateName(self)
	UpdateHealth(self)
	RaidTargetUpdate(self)

	FPerl_Highlight:SetHighlight(self)
end

-- UNIT_HEAL_PREDICTION
function Events:UNIT_HEAL_PREDICTION(unit)
	if (raidconf.healprediction and unit == self.partyid) then
		FPerl.SetExpectedHealth(self)
	end
end

function Events:UNIT_AURA(unit)
	if conf.highlightDebuffs.enable and unit == self.partyid then
		FPerl.CheckDebuffs(self, unit)
	end
end

function Events:INCOMING_RESURRECT_CHANGED(unit)
	if unit == self.partyid then
		UpdateResurrectionStatus(self)
	end
end

-- VARIABLES_LOADED
function Bus.VARIABLES_LOADED()
	FPerl.Off("VARIABLES_LOADED", Bus.VARIABLES_LOADED)

	FPerl.SetScale(FPerl_Raid_TitlePets, (conf.raid and conf.raid.scale) or 1)

	FPerl.RaidPets.ChangeAttributes()
end

-- PLAYER_ENTERING_WORLD
function Bus.PLAYER_ENTERING_WORLD()
	RaidPetUpdateGUIDs()
	FPerl.RaidPets.UpdateDisplayAll()
end

-- RAID_TARGET_UPDATE
function Bus.RAID_TARGET_UPDATE()
	for i, frame in pairs(RaidPetFrameArray) do
		RaidTargetUpdate(frame)
	end
end

-- UNIT_PET: the owner's pet changed; redraw that owner's frame
function Bus.UNIT_PET(event, unit)
	RaidPetUpdateGUIDs()
	for _, frame in pairs(RaidPetFrameArray) do
		if (frame.ownerid == unit and frame:IsShown()) then
			FPerl.RaidPets.UpdateDisplay(frame)
		end
	end
end

-- UNIT_NAME_UPDATE: a pet's name resolved or changed
function Bus.UNIT_NAME_UPDATE(event, unit)
	local frame = RaidPetFrameArray[unit]
	if (frame and frame:IsShown()) then
		RaidPetUpdateGUIDs()
		UpdateName(frame)
	end
end

-- UNIT_ENTERED_VEHICLE
function Bus.UNIT_ENTERED_VEHICLE(event, unit)
	local guid = UnitGUID(unit)
	if (not CanAccess(guid)) then
		return
	end
	for u, frame in pairs(RaidPetFrameArray) do
		local ownerGUID = frame.ownerid and UnitGUID(frame.ownerid)
		if (ownerGUID and CanAccess(ownerGUID) and ownerGUID == guid) then
			UpdateName(frame)
		end
	end
	--TitlesUpdateFrame:Show()
end
-- the vehicle swap the 0.2 s poll used to catch as a changed GUID: not checked in game
Bus.UNIT_EXITED_VEHICLE = Bus.UNIT_ENTERED_VEHICLE

-- GROUP_ROSTER_UPDATE
function Bus.GROUP_ROSTER_UPDATE()
	--TitlesUpdateFrame:Show()
	--FPerl.ProtectedCall(FPerl.RaidPets.Align)
	RaidPetUpdateGUIDs()
end

-- SetFrameArray
local function SetFrameArray(self, value)
	for k, v in pairs(RaidPetFrameArray) do
		if (v == self) then
			RaidPetFrameArray[k] = nil
		end
	end

	self.partyid = value
	FPerl.UnitFrameSetUnit(self, value)

	if (value) then
		RaidPetFrameArray[value] = self
	end
end

-- onAttrChanged
local function onAttrChanged(self, name, value)
	if (name == "unit") then
		if (value) then
			SetFrameArray(self, value)		-- "raidpet"..strmatch(value, "^raid(%d+)"))
			self.ownerid = value:gsub("(%a+)pet(%d+)", "%1%2")

			local guid = UnitGUID(self.partyid)
			if (self.petID ~= value or not CanAccess(guid) or not CanAccess(self.petGUID) or self.petGUID ~= guid) then
				FPerl.RaidPets.UpdateDisplay(self)
			end
		else
			SetFrameArray(self)
			self.petGUID = nil
			self.petID = nil
		end
	end
end

-- Every pet frame runs the Health element and RaidPets while the module is enabled; the unit events
-- follow the frame's unit (FPerl.UnitFrameSetUnit, from SetFrameArray).
local ELEMENTS = {"Health", "RaidPets"}
local function SetElements(self)
	for _, name in ipairs(ELEMENTS) do
		if (rconf and rconf.enable) then
			FPerl.UnitFrameEnable(self, name)
		else
			FPerl.UnitFrameDisable(self, name)
		end
	end
end

-- FPerl.RaidPets.RaidPetSingleOnLoad
function FPerl.RaidPets.RaidPetSingleOnLoad(self)
	self:OnBackdropLoaded()
	self.updateHealth = UpdateHealth
	FPerl.UnitFrameInit(self, nil, {})
	tinsert(allFrames, self)
	SetElements(self)

	FPerl.SetChildMembers(self)

	self.edgeFile = "Interface\\AddOns\\FPerl\\Images\\FPerl_ThinEdge"
	self.edgeSize = 10
	self.edgeInsets = 2

	FPerl.RegisterHighlight(self.highlight, 2)

	FPerl.RegisterPerlFrames(self)
	--self.FlashFrames = {self}

	self:SetScript("OnAttributeChanged", onAttrChanged)
	FPerl.RegisterClickCastFrame(self)

	self:SetScript("OnShow", FPerl.RaidPets.UpdateDisplay)

	self:RegisterForClicks("AnyUp")
	self:SetAttribute("useparent-unit", true)
	self:SetAttribute("*type1", "target")
	self:SetAttribute("type2", "togglemenu")

end

-- initialConfigFunction
--local function initialConfigFunction(self)
	-- This is the only place we're allowed to set attributes whilst in combat
	--self:SetAttribute("unitsuffix", "pet")
	--self:SetAttribute("*type1", "target")
	--self:SetAttribute("initial-height", 30)
	--FPerl.RaidPets.UpdateDisplay(self)
--end

-- SetMainHeaderAttributes
local function SetMainHeaderAttributes(self)
	self:Hide()

	local petsPerColumn
	if conf.raid.mana then
		petsPerColumn = 7
	else
		petsPerColumn = 6
	end

	self:SetAttribute("showParty", raidconf.inParty)

	self:SetAttribute("filterOnPet", true)
	self:SetAttribute("unitsPerColumn", petsPerColumn) -- Don't grow taller than a standard raid group
	self:SetAttribute("maxColumns", 8)
	self:SetAttribute("columnAnchorPoint", "LEFT")

	self:SetAttribute("point", conf.raid.anchor)
	self:SetAttribute("minWidth", 80)
	self:SetAttribute("minHeight", 30.5)
	local titleFrame = self:GetParent()
	self:ClearAllPoints()
	if (conf.raid.anchor == "TOP") then
		self:SetPoint("TOPLEFT", titleFrame, "BOTTOMLEFT", 0, 0)
		self:SetAttribute("xOffset", 0)
		self:SetAttribute("yOffset", -conf.raid.spacing)
	elseif (conf.raid.anchor == "LEFT") then
		self:SetPoint("TOPLEFT", titleFrame, "BOTTOMLEFT", 0, 0)
		self:SetAttribute("xOffset", conf.raid.spacing)
		self:SetAttribute("yOffset", 0)
	elseif (conf.raid.anchor == "BOTTOM") then
		self:SetPoint("BOTTOMLEFT", titleFrame, "TOPLEFT", 0, 0)
		self:SetAttribute("xOffset", 0)
		self:SetAttribute("yOffset", conf.raid.spacing)
	elseif (conf.raid.anchor == "RIGHT") then
		self:SetPoint("TOPRIGHT", titleFrame, "BOTTOMRIGHT", 0, 0)
		self:SetAttribute("xOffset", -conf.raid.spacing)
		self:SetAttribute("yOffset", 0)
	end
	--self:SetAttribute("template", "FPerl_RaidPet_FrameTemplate")
	--self:SetAttribute("templateType", "Button")

	-- Fix Secure Header taint in combat
	local maxColumns = self:GetAttribute("maxColumns") or 1
	local unitsPerColumn = self:GetAttribute("unitsPerColumn") or petsPerColumn
	local startingIndex = self:GetAttribute("startingIndex")
	local maxUnits = maxColumns * unitsPerColumn

	self:Show()
	self:SetAttribute("startingIndex", - maxUnits + 1)
	self:SetAttribute("startingIndex", startingIndex)

	-- the header makes buttons for what its attributes allow, so the decider waits for them
	FPerl.RaidPets.Ready = true

	--self.initialConfigFunction = initialConfigFunction
end

-- FPerl.RaidPets.ChangeAttributes
function FPerl.RaidPets.ChangeAttributes()
	FPerl.ProtectedCall(SetMainHeaderAttributes, FPerl_Raid_GrpPets)
end

-- FPerl.RaidPets.Align()
function FPerl.RaidPets.Align()
	if (rconf.enable and rconf.alignToRaid) then
		local counts = FPerl.Raid.RaidGroupCounts()
		local lastUsed = 0
		if (counts) then
			for i = 1, CLASS_COUNT do
				if (counts[i] > 0) then
					lastUsed = i
				end
			end
		end

		if (lastUsed > 0) then
			local relative = _G["FPerl_Raid_Title"..lastUsed]
			if (relative) then
				FPerl_Raid_TitlePets:ClearAllPoints()
				FPerl_Raid_TitlePets:SetPoint("TOPLEFT", relative, "TOPRIGHT", raidconf.spacing, 0)
			end
		end

		FPerl_Raid_TitlePets:EnableMouse(false)
	else
		FPerl_Raid_TitlePets:EnableMouse(true)
	end
end

-- FPerl.RaidPets.Titles
function FPerl.RaidPets.Titles()
	FPerl_Raid_TitlePets.text:SetFormattedText("%s", PETS)

	FPerl.GroupVisibilityUpdate()

	FPerl.ProtectedCall(FPerl.RaidPets.Align)

	local show = FPerl_Raid_GrpPetsUnitButton1 and FPerl_Raid_GrpPetsUnitButton1:IsShown()
	if (FPerl.Locked == 0 or (rconf.enable and show and conf.raid.titles)) then
		FPerl_Raid_TitlePets.text:Show()
	else
		FPerl_Raid_TitlePets.text:Hide()
	end
end

-- FPerl.RaidPets.OptionActions
function FPerl.RaidPets.OptionActions()
	if (InCombatLockdown()) then
		FPerl.AfterCombat(FPerl.RaidPets.OptionActions)
		return
	end

	SetMainHeaderAttributes(FPerl_Raid_GrpPets)

	for i, frame in ipairs(allFrames) do
		SetElements(frame)
	end

	-- the events no frame owns follow the enable option
	if ((rconf.enable and true) ~= busOn) then
		busOn = rconf.enable and true
		for event, fn in pairs(Bus) do
			if (busOn) then
				FPerl.On(event, fn)
			else
				FPerl.Off(event, fn)
			end
		end
	end

	FPerl.RaidPets.Titles()
	FPerl.SetScale(FPerl_Raid_TitlePets, (conf.raid and conf.raid.scale) or 1)

	if (rconf.enable) then
		FPerl_Raid_TitlePets:Show()
	else
		FPerl_Raid_TitlePets:Hide()
	end
end
