-- Author: Resike
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

local pairs = pairs
local type = type
local GetNumGroupMembers = GetNumGroupMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local GetRaidTargetIndex = GetRaidTargetIndex
local GetTime = GetTime
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local UnitAffectingCombat = UnitAffectingCombat
local UnitCastingInfo = UnitCastingInfo
local UnitExists = UnitExists
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitGUID = UnitGUID
local UnitIsAFK = UnitIsAFK
local UnitIsCharmed = UnitIsCharmed
local UnitIsDead = UnitIsDead
local UnitIsDND = UnitIsDND
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitIsVisible = UnitIsVisible
local UnitName = UnitName
local CheckDebuffs = FPerl.CheckDebuffs
local ColourFriendlyUnit = FPerl.ColourFriendlyUnit
local CanAccess = FPerl.CanAccess
local SafeBool = FPerl.SafeBool

local Shared = FPerl.Raid.Shared
local Events = Shared.Events
local Bus = Shared.Bus
local RaidGroupCounts = Shared.RaidGroupCounts
local FrameArray = Shared.FrameArray
local RaidPositions = Shared.RaidPositions
local UpdateName = Shared.UpdateName
local CheckFlags = Shared.CheckFlags
local ShowFlags = Shared.ShowFlags
local UpdateResurrectionStatus = Shared.UpdateResurrectionStatus
local UpdateHealth = Shared.UpdateHealth
local UpdateMana = Shared.UpdateMana
local rebuildAuras = Shared.rebuildAuras
local RaidUnitName = Shared.RaidUnitName

local conf, rconf, cconf
FPerl.RequestConfig(function(newConf)
	conf = newConf
	rconf = conf.raid
	cconf = conf.custom
end, "$Revision:  $")

local resSpells = {
	[FPerl.SpellName(2006)] = true,			-- Resurrection
	[FPerl.SpellName(2008)] = true,			-- Ancestral Spirit
	[FPerl.SpellName(20484)] = true,			-- Rebirth
	[FPerl.SpellName(7328)] = true,			-- Redemption
}

-- CombatFlash
local function CombatFlash(self, elapsed, argNew, argGreen)
	if (FPerl.CombatFlashSet(self, elapsed, argNew, argGreen)) then
		FPerl.CombatFlashSetFrames(self)
	end
end

-- FPerl.Raid.GetUnitFrameByUnit
function FPerl.Raid.GetUnitFrameByUnit(unit)
	return FrameArray[unit]
end

-- FPerl.Raid.GetFrameArray
function FPerl.Raid.GetFrameArray()
	return FrameArray
end

-- UpdateUnitByName
local function UpdateUnitByName(name, flagsOnly)
	local id = RaidPositions[name]
	if (id) then
		local frame = FrameArray[id]
		if (frame and frame:IsShown()) then
			if (flagsOnly) then
				UpdateHealth(frame)
			else
				FPerl.Raid.UpdateDisplay(frame)
			end
		end
	end
end

-- HighlightCallback(updateName)
local function HighlightCallback(self, guid)
	if not guid then
		return
	end

	local f = FPerl.Raid.GetUnitFrameByGUID(guid)
	if (f) then
		FPerl_Highlight:SetHighlight(f, guid)
	end
end

-- UpdateDebuffHighlight
local function UpdateDebuffHighlight(self)
	local partyid = self.partyid
	if not partyid then
		return
	end

	if (conf.highlightDebuffs.enable) then
		CheckDebuffs(self, partyid)
	end
	ColourFriendlyUnit(self.nameFrame.text, partyid)
end

------------------
-- Buffs stuffs --
------------------

-- UpdateCombat
local function UpdateCombat(self)
	local partyid = self.partyid
	if not partyid then
		return
	end
	if UnitExists(partyid) and UnitAffectingCombat(partyid) then
		self.nameFrame.combatIcon:Show()
	else
		self.nameFrame.combatIcon:Hide()
	end
	-- indirect units can return secret flags; no icon in that case
	if SafeBool(UnitIsVisible(partyid), false) and SafeBool(UnitIsCharmed(partyid), false) and SafeBool(UnitIsPlayer(partyid), false) then
		self.nameFrame.warningIcon:Show()
	else
		self.nameFrame.warningIcon:Hide()
	end
end

-- UpdatePlayerFlags(self)
local function UpdatePlayerFlags(self, partyid, ...)
	if (not partyid) then
		partyid = self:GetAttribute("unit")
	end

	local f = FrameArray[partyid]
	if f then
		self = f

		local unitName = RaidUnitName(partyid)
		if (unitName) then
			local unitInfo = FPerlRoster[unitName]
			if (unitInfo) then
				local change
				-- same AFK/DND secrecy risk as above.
				if (SafeBool(UnitIsAFK(partyid), false)) then
					if (not unitInfo.afk) then
						change = true
						unitInfo.afk = GetTime()
						unitInfo.dnd = nil
					end
				elseif (SafeBool(UnitIsDND(partyid), false)) then
					if (not unitInfo.dnd) then
						change = true
						unitInfo.dnd = GetTime()
						unitInfo.afk = nil
					end
				else
					if (unitInfo.afk or unitInfo.dnd) then
						unitInfo.afk, unitInfo.dnd = nil, nil
						change = true
					end
				end

				if (change) then
					local flags = CheckFlags(partyid)
					if (flags) then
						ShowFlags(self, flags)
					else
						UpdateMana(self)
						UpdateHealth(self)
					end
				end
			end
		end
	end
end

-- The roster handling, one video frame after the last GROUP_ROSTER_UPDATE (GROUP_ROSTER_UPDATE below)
function FPerl.Raid.RosterWork()
	if (not Shared.rosterUpdated) then
		return
	end
	Shared.rosterUpdated = nil
	FPerl.AfterCombat(FPerl.Raid.Position, FPerl_Raid_Frame)
	if FPerl_Custom and rconf.enable and FPerl_Custom and cconf and cconf.enable then
		FPerl_Custom:UpdateUnits()
	end
	if (not IsInRaid() or (not IsInGroup() and rconf.inParty)) then
		wipe(Shared.ResArray)
		wipe(FPerlRoster)
		--buffUpdates = { }
	end
end

-- Set one frame after the raid frame's first show (OnShow in FPerl_Raid.xml).
function FPerl.Raid.SetInitialized()
	FPerl.Raid.Initialized = true
end

-- FPerl.Raid.OnUpdate: the combat flash
function FPerl.Raid.OnUpdate(self, elapsed)

	--local updateHighlights, someUpdate
	--local enemyUnitList
	-- Throttling this will fuck up the animations, and create FPS decreases over time
	--self.time = self.time + elapsed
	--if (self.time >= 0.2) then
		--self.time = 0
		--someUpdate = true
		local flashing
		for i, frame in pairs(FrameArray) do
			if (frame:IsShown()) then
				if (conf.combatFlash and frame.PlayerFlash) then
					CombatFlash(frame, elapsed, false)
				end
				if (frame.PlayerFlash) then
					flashing = true
				end
			elseif (frame.PlayerFlash) then
				-- hidden mid-flash: end the flash now, so the frame shows again in its own colour
				CombatFlash(frame, 1000, false)
			end
		end
	-- set by a flash start (UNIT_COMBAT); idle otherwise
	if (not flashing) then
		self:SetScript("OnUpdate", nil)
	end
end

-- The range checks, every 0.2 s on the scheduler (no event reports a unit's distance). The OnUpdate version added every frame's elapsed
-- to one timer, so each pass updated a single frame; this updates every shown frame.
FPerl.Every(0.2, function()
	if (conf and conf.rangeFinder.enabled) then
		for i, frame in pairs(FrameArray) do
			if (frame.partyid and frame:IsVisible()) then
				FPerl.UpdateSpellRange(frame, frame.partyid, true)
			end
		end
	end
end)

-- RaidTargetUpdate
local function RaidTargetUpdate(self)
	local icon = self.nameFrame.raidIcon
	local raidIcon = GetRaidTargetIndex(self.partyid)

	if (CanAccess(raidIcon)) then
		if (not icon) then
			icon = self.nameFrame:CreateTexture(nil, "OVERLAY")
			self.nameFrame.raidIcon = icon
			icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
			icon:SetPoint("LEFT")
			icon:SetWidth(16)
			icon:SetHeight(16)
		else
			icon:Show()
		end
		SetRaidTargetIconTexture(icon, raidIcon)
	elseif (icon) then
		icon:Hide()
	end
end

local function SetRoleIconTexture(texture, role)
	if not rconf.role then
		return false
	end
	if (conf.oldRoleIcons) then
		if role == "TANK" then
			texture:SetTexture("Interface\\GroupFrame\\UI-Group-MainTankIcon")
		elseif role == "HEALER" then
			texture:SetTexture("Interface\\AddOns\\FPerl\\Images\\FPerl_RoleHealer_old")
		elseif role == "DAMAGER" then
			texture:SetTexture("Interface\\GroupFrame\\UI-Group-MainAssistIcon")
		else
			return false
		end
	else
		if role == "TANK" then
			texture:SetTexture("Interface\\AddOns\\FPerl\\Images\\FPerl_RoleTank")
		elseif role == "HEALER" then
			texture:SetTexture("Interface\\AddOns\\FPerl\\Images\\FPerl_RoleHealer")
		elseif role == "DAMAGER" then
			texture:SetTexture("Interface\\AddOns\\FPerl\\Images\\FPerl_RoleDamage")
		else
			return false
		end
	end
	return true
end

-- RoleUpdate
local function RoleUpdate(self, role)
	if not self then
		return
	end
	if (not CanAccess(role)) then
		role = nil
	end
	local icon = self.nameFrame.roleIcon or nil

	if (role) then
		if (not icon) then
			icon = self.nameFrame:CreateTexture(nil, "OVERLAY")
			self.nameFrame.roleIcon = icon
			icon:SetPoint("RIGHT", 7, 7)
			icon:SetWidth(16)
			icon:SetHeight(16)
		end

		if (SetRoleIconTexture(icon, role)) then
			icon:Show()
		else
			icon:Hide()
		end
	end
end

-------------------------
-- The Update Function --
-------------------------
function FPerl.Raid.UpdateDisplayAll()
	for k, frame in pairs(FrameArray) do
		rebuildAuras(frame)
		if (frame:IsShown()) then
			FPerl.Raid.UpdateDisplay(frame)
		end
	end
end

-- FPerl.Raid.UpdateDisplay
function FPerl.Raid.UpdateDisplay(self)
	-- Health must be updated after mana, since ctra flag checks are done here.
	if (rconf.mana) then
		FPerl.Raid.UpdateManaType(self)
		UpdateMana(self)
	end
	if type(UnitGroupRolesAssigned) == "function" then
		RoleUpdate(self, UnitGroupRolesAssigned(self.partyid))
	end
	UpdatePlayerFlags(self)
	UpdateHealth(self)
	UpdateName(self)
	UpdateCombat(self)
	FPerl.UnitUpdateReadyState(self)
	RaidTargetUpdate(self)

	--buffUpdates[self] = true -- UpdateBuffs(self)

	if (not Shared.SkipHighlightUpdate) then
		FPerl_Highlight:SetHighlight(self)
	end
end

-------------------
-- Event Handler --
-------------------

-- Blizzard raid profiles are CVars here; raidOptionIsShown drives the manager's IsShown.
local function HideRaidManagerCVar()
	SetCVar("raidOptionIsShown", "0")
end

local function HideDefaultRaidFrames()
	if not rconf.enable then
		return
	end
	FPerl.AfterCombat(HideRaidManagerCVar)
	FPerl.BlizzFrameDisable(CompactRaidFrameManager)
	FPerl.BlizzFrameDisable(CompactRaidFrameContainer)
end

-- VARIABLES_LOADED
function Bus.VARIABLES_LOADED()
	FPerl.Off("VARIABLES_LOADED", Bus.VARIABLES_LOADED)

	if (not IsInRaid() or (not IsInGroup() and rconf.inParty)) then
		Shared.ResArray = { }
		FPerlRoster = { }
	else
		local myRoster = FPerlRoster[UnitName("player")]
		if (myRoster) then
			myRoster.afk, myRoster.dnd, myRoster.ressed, myRoster.resCount = nil, nil, nil, nil
		end
	end

	FPerl_Highlight:Register(HighlightCallback, FPerl_Raid_Frame)
end

function Events:UNIT_CONNECTION()
	--Update players health when their connection state changes.
	UpdateHealth(self)
end

-- PLAYER_ENTERING_WORLD
function Bus.PLAYER_ENTERING_WORLD()
	--self:UnregisterEvent("PLAYER_ENTERING_WORLD")

	--FPerl.Raid.ChangeAttributes()
	--FPerl.Raid.RaidTitles()

	FPerl.Raid.ChangeAttributes()
	FPerl.Raid.Position()
	FPerl.Raid.SetBits(FPerl_Raid_Frame)

	Shared.raidLoaded = true
	Shared.rosterUpdated = nil

	if (IsInRaid() or (IsInGroup() and rconf.inParty)) then
		FPerl_Raid_Frame:Show()
	end

	FPerl.Raid.UpdateDisplayAll()

	--Events.PLAYER_ENTERING_WORLD = Events.PLAYER_ENTERING_WORLDsmall
	--Events.PLAYER_ENTERING_WORLDsmall = nil
end

local rosterGuids = { }
-- FPerl.Raid.GetUnitFrameByGUID
function FPerl.Raid.GetUnitFrameByGUID(guid)
	if (not guid or not CanAccess(guid)) then
		return
	end
	local unitid = rosterGuids and rosterGuids[guid]
	if (unitid) then
		return FrameArray[unitid]
	end
end

-- Per roster event: one "raid"..i string and one UnitGUID per member (at most 40); no table is built.
-- Lua interns the strings, so a repeat allocates nothing new.
local function BuildGuidMap()
	if (IsInRaid()) then
		wipe(rosterGuids)
		for i = 1, GetNumGroupMembers() do
			local guid = UnitGUID("raid"..i)
			if (guid and CanAccess(guid)) then
				rosterGuids[guid] = "raid"..i
			end
		end
	elseif (IsInGroup()) then
		wipe(rosterGuids)
		local pguid = UnitGUID("player")
		for i = 1, GetNumGroupMembers() do
			if (pguid and CanAccess(pguid)) then
				rosterGuids[pguid] = "player"
			end
			local guid = UnitGUID("party"..i - 1)
			if (guid and CanAccess(guid)) then
				rosterGuids[guid] = "party"..i - 1
			end
		end
	else
		wipe(rosterGuids)
	end
end

-- GROUP_ROSTER_UPDATE
function Bus.GROUP_ROSTER_UPDATE()
	if (not Shared.rosterUpdated) then -- Many roster updates can occur during 1 video frame: one pass after them
		Shared.rosterUpdated = true
		C_Timer.After(0, FPerl.Raid.RosterWork)
	end
	BuildGuidMap()
	if (IsInRaid() or (IsInGroup() and rconf.inParty)) then
		FPerl_Raid_Frame:Show()
		if type(UnitGroupRolesAssigned) == "function" then
			if (rconf.role) then
				for i, frame in pairs(FrameArray) do
					if (frame.partyid) then
						RoleUpdate(frame, UnitGroupRolesAssigned(frame.partyid))
					end
				end
			end
		end
	end
end

-- PLAYER_LOGIN
function Bus.PLAYER_LOGIN()
	BuildGuidMap()
	HideDefaultRaidFrames()
end

-- UNIT_FLAGS
function Events:UNIT_FLAGS(unit, ...)
	UpdateCombat(self)
	UpdatePlayerFlags(self, unit, ...)
end

function Bus.PLAYER_FLAGS_CHANGED(event, unit, ...)
	UpdatePlayerFlags(FPerl_Raid_Frame, unit, ...)
end

-- UNIT_COMBAT
function Events:UNIT_COMBAT(unit, action, descriptor, damage, damageType)
	if unit ~= self.partyid then
		return
	end
	-- set first: the flash and hit text animate even when a later line raises on a secret amount
	FPerl_Raid_Frame:SetScript("OnUpdate", FPerl.Raid.OnUpdate)

	if (action == "HEAL") then
		CombatFlash(self, 0, true, true)
	elseif (damage and damage > 0) then
		CombatFlash(self, 0, true)
	end
end

-- UNIT_NAME_UPDATE
function Events:UNIT_NAME_UPDATE()
	UpdateName(self)
	UpdateHealth(self) -- Added 16th May 2007 - Seems they now fire name update to indicate some change in state.
end

-- UNIT_AURA
function Events:UNIT_AURA()
	if (not conf.highlightDebuffs.enable and not conf.highlight.enable) then
		return
	end
	UpdateDebuffHighlight(self)
end

-- READY_CHECK
function Bus.READY_CHECK()
	for i, frame in pairs(FrameArray) do
		if (frame.partyid) then
			FPerl.UnitUpdateReadyState(frame)
		end
	end
end

function Bus.INCOMING_RESURRECT_CHANGED(event, unit)
	for i, frame in pairs(FrameArray) do
		if (frame.partyid and unit == frame.partyid) then
			UpdateResurrectionStatus(frame)
		end
	end
end


Bus.READY_CHECK_CONFIRM = Bus.READY_CHECK
Bus.READY_CHECK_FINISHED = Bus.READY_CHECK

-- RAID_TARGET_UPDATE
function Bus.RAID_TARGET_UPDATE()
	for i, frame in pairs(FrameArray) do
		if (frame.partyid) then
			RaidTargetUpdate(frame)
		end
	end
end

-- ROLE_CHANGED_INFORM
-- targetUnit is the player whose role is being changed
-- sourceUnit is the player who initiated the change
-- oldRole is a role currently assigned to the player - NONE, TANK, HEALER, DAMAGER
-- newRole is a role being assigned to the player
-- UnitGroupRolesAssigned function will return the oldRole if used in this event
function Bus.ROLE_CHANGED_INFORM(event, targetUnit, sourceUnit, oldRole, newRole)
	local id = RaidPositions[targetUnit]
	if (rconf.role) then
		if (id) then
			RoleUpdate(FrameArray[id], newRole)
		end
	end
end

-- SetRes
local function SetResStatus(resserName, resTargetName, ignoreCounter)
	if (not resserName) then
		return
	end
	local resEnd

	if (resTargetName) then
		Shared.ResArray[resserName] = resTargetName
	else
		resEnd = true

		for i, name in pairs(Shared.ResArray) do
			if (i == resserName) then
				resTargetName = name
				break
			end
		end

		Shared.ResArray[resserName] = nil
	end

	if (resTargetName) then
		local myRoster = FPerlRoster[resTargetName]
		if (myRoster) then
			if (resEnd and not ignoreCounter) then
				myRoster.ressed = 1
				myRoster.resCount = (myRoster.resCount or 0) + 1
			end
			UpdateUnitByName(resTargetName, true)
		end
	end
end

-- UNIT_SPELLCAST_START
function Events:UNIT_SPELLCAST_START(unit, lineGUID, spellID)
	local unitName = RaidUnitName(unit)
	if (Shared.ResArray[unitName]) then
		-- Flagged as ressing, finish their old cast
		SetResStatus(unitName)
	end

	local name = UnitCastingInfo(unit)
	-- spell and target names may be secret in restricted content
	if (name and CanAccess(name) and resSpells[name]) then
		local u = unit.."target"
		local unitTargetName, realm = UnitName(u)
		if (not CanAccess(unitTargetName)) then
			return
		end
		if realm and CanAccess(realm) and realm ~= "" then
			unitTargetName = unitTargetName.."-"..realm
		end
		if (UnitExists(u) and UnitIsDead(u)) then
			SetResStatus(unitName, unitTargetName)
		end
	end
end

-- UNIT_SPELLCAST_STOP
function Events:UNIT_SPELLCAST_STOP(unit)
	if unit then
		local unitName = RaidUnitName(unit)
		SetResStatus(unitName)
	end
end

-- UNIT_SPELLCAST_FAILED
function Events:UNIT_SPELLCAST_FAILED(unit)
	if unit then
		local unitName = RaidUnitName(unit)
		SetResStatus(unitName, nil, true)
	end
end

Events.UNIT_SPELLCAST_INTERRUPTED = Events.UNIT_SPELLCAST_FAILED


-- EnableEvents: called by OnLoad of every raid frame. The unit events follow the frame's unit
-- (FPerl.UnitFrameSetUnit, from SetFrameArray); the Power element follows the mana option.
local function updateHealthAndCombat(self)
	UpdateHealth(self)
	UpdateCombat(self)
end
local function updateManaType(self)
	FPerl.Raid.UpdateManaType(self)
	UpdateMana(self)
end
Shared.EnableEvents = function(self)
	self.updateHealth = updateHealthAndCombat
	self.updatePower = UpdateMana
	self.updatePowerType = updateManaType
	self.conf = rconf
	self.auraNoHandles = true
	-- the raid header leaves no room beside a frame: RIGHT and LEFT overlay the ends of the bars
	self.auraInside = {RIGHT = true, LEFT = true}
	FPerl.UnitFrameInit(self, nil, {"Health", "Raid", "Auras"})
	if (rconf and rconf.mana) then
		FPerl.UnitFrameEnable(self, "Power")
	end
end

function Events:UNIT_HEAL_PREDICTION(unit)
	if rconf.healprediction and unit == self.partyid then
		FPerl.SetExpectedHealth(self)
	end
end

local spareRoster = { }
-- SetRaidRoster
local function SetRaidRoster()
	-- the tables are reused: the roster alternates between two, the others are cleared in place
	local NewRoster = spareRoster
	wipe(NewRoster)
	wipe(RaidPositions)
	for i = 1, #RaidGroupCounts do
		RaidGroupCounts[i] = 0
	end

	Shared.myGroup = nil
	local player
	for i = 1, GetNumGroupMembers() do
		local name, _, group, _, _, fileName = GetRaidRosterInfo(i)

		if (name and (IsInRaid() or (IsInGroup() and rconf.inParty))) then
			local unit
			if IsInRaid() then
				unit = "raid"..i
			else
				if name == UnitName("player") then
					unit = "player"
					player = true
				else
					if player then
						unit = "party"..i - 1
					else
						unit = "party"..i
					end
				end
			end
			RaidPositions[name] = unit

			if (IsInRaid() and SafeBool(UnitIsUnit(unit, "player"), false)) then
				Shared.myGroup = group
			end

			if (rconf.sortByClass) then
				for j = 1, Shared.CLASS_COUNT do
					if (rconf.class[j].name == fileName and rconf.class[j].enable) then
						RaidGroupCounts[j] = RaidGroupCounts[j] + 1
						break
					end
				end
			else
				RaidGroupCounts[group] = RaidGroupCounts[group] + 1
			end

			local r = FPerlRoster[name]
			if (r) then
				NewRoster[name] = r
				FPerlRoster[name] = nil
				-- same AFK/DND secrecy risk as above.
				r.afk = SafeBool(UnitIsAFK(unit), false) and GetTime() or nil
				r.dnd = SafeBool(UnitIsDND(unit), false) and GetTime() or nil
			else
				--NewRoster = new()
				NewRoster[name] = { }
			end
		end
	end

	if (IsInRaid() or (IsInGroup() and rconf.inParty)) then
		FPerl_Raid_Frame:Show()
	else
		FPerl_Raid_Frame:Hide()
	end

	spareRoster = FPerlRoster
	FPerlRoster = NewRoster

	if (FPerl.RaidPets.Align) then
		FPerl.ProtectedCall(FPerl.RaidPets.Align)
	end
end

-- FPerl.Raid.RaidGroupCounts()
function FPerl.Raid.RaidGroupCounts()
	return RaidGroupCounts
end

-- FPerl.Raid.Position
function FPerl.Raid.Position(self)
	SetRaidRoster()
	FPerl.Raid.RaidTitles()
	if (conf.party.smallRaid and FPerl.Raid.Initialized) then
		FPerl.GroupVisibilityUpdate()
	end
end

