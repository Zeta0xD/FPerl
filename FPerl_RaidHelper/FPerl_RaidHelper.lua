-- Author: Resike
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

FPerl.SetModuleRevision("$Revision:  $")

FPerlRaidHelperTanks = {}
local MainTankCount, blizzMTanks, ctraTanks = 0, 0, 0
local MainTanks = {}
local BlizzardMainTanks = {}
local Events = {}
local XUnits = {}
local UpdateTime = 0
local XGaps = 0
local XTitle
local pendingTankListChange -- If in combat when tank list changes, then we'll defer it till next time we're out of combat
local conf

local GetNumGroupMembers = GetNumGroupMembers

--local new, del = FPerl.GetReusableTable, FPerl.FreeTable

-- Dup colours used to show which tanks have the same target
local MTdupColours = {
	{r = "0.8", g = "0.2", b = "0.2"},
	{r = "0.2", g = "0.2", b = "0.8"},
	{r = "0.8", g = "0.2", b = "0.8"},
	{r = "0.2", g = "0.8", b = "0.2"},
	{r = "0.2", g = "0.8", b = "0.8"}
}

local GAP_SPACING = 10
FPERL_UNIT_HEIGHT_MIN = 17
FPERL_UNIT_HEIGHT_MAX = 30
FPERL_UNIT_WIDTH_MIN = 50
FPERL_UNIT_WIDTH_MAX = 125

if (not FPerl.ColourTable) then
	FPerl.ColourTable = setmetatable({},{
		__index = function(self, class)
			local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class] or {r = 0, g = 0, b = 0}
			return format("|c00%02X%02X%02X", 255 * c.r, 255 * c.g, 255 * c.b)
		end
	})
end

-- Although your own "target" is updated immediately, any reference to ourself via our raid id is updated via the server
-- So, to cure the slow response times, we check if anything is 'me'. Only direct targets are updated immedately,
-- so we don't bother with target's target onwards.
local function SpecialCaseUnit(self)
	local id
	if (self.type == "MTT") then
		id = self:GetParent():GetAttribute("unit") -- SecureButton_GetUnit(self:GetParent())
		if (id) then
			if (FPerl.SafeBool(UnitIsUnit("player", id), false)) then
				return "target"
			end
			return id.."target"
		end

	elseif (self.type == "MT") then
		id = self:GetAttribute("unit") -- SecureButton_GetUnit(self)
		if (id and FPerl.SafeBool(UnitIsUnit("player", id), false)) then
			return "player"
		end
		return id
	end

	return SecureButton_GetUnit(self)
end

----------------------------
------- DISPLAY ------------
----------------------------
local function UpdateUnit(self,forcedUpdate)
	if (not self or self.hidden) then
		return
	end

	if (forcedUpdate) then
		local time = GetTime()
		if (self.update and time < self.update + 0.2) then
			-- Since we catch UNIT_HEALTH changes, we don't need to update always
			return
		end
	end

	self.update = GetTime()

	local xunit = SpecialCaseUnit(self)
	if (not xunit) then
		return
	end

	local name = UnitName(xunit)
	local grey
	-- creature names and health are secret inside instances
	local nameReadable = FPerl.CanAccess(name)

	self.healthBar.bg:Show()

	if (name and (not nameReadable or name ~= UNKNOWNOBJECT)) then
		-- Name
		self.text:SetText(name)
		self.text:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, -12)

		if (nameReadable) then
			local remCount = 1
			while ((self.text:GetStringWidth() >= (self:GetWidth() - 2)) and (string.len(name) > remCount)) do
				name = string.sub(name, 1, string.len(name) - remCount)..".."
				remCount = 3
				self.text:SetText(name)
			end
		end

		if (UnitPlayerControlled(xunit)) then
			FPerl.ColourFriendlyUnit(self.text, xunit)
		else
			FPerl.SetUnitNameColor(self.text, xunit)
		end

		-- Health
		local health, healthMax, missing = FPerl.HealthSetBar(self.healthBar, xunit, true)
		if (FPerl.CanAccess(healthMax) and healthMax == 0) then
			grey = true
		end

		if (UnitIsDeadOrGhost(xunit)) then
			self.healthBar.text:SetText(FPERL_LOC_DEAD)
			grey = true
		elseif (not FPerl.SafeBool(UnitIsConnected(xunit), true)) then
			self.healthBar.text:SetText(FPERL_LOC_OFFLINE)
			grey = true
		else
			if (conf.HealerMode == 1 and FPerl.SafeBool(UnitInRaid(xunit), false)) then
				if (conf.HealerModeType == 1 and FPerl.CanAccess(missing)) then
					self.healthBar.text:SetFormattedText("%d/%d", -missing, healthMax)
				else
					FPerl.SetDeficitText(self.healthBar.text, missing, "full")
				end
			else
				FPerl.FormatPercent(self.healthBar.text, UnitHealthPercent(xunit, true, CurveConstants.ScaleTo100), "whole")
			end
		end
		if (conf.UnitHeight < 23) then
			self.healthBar.text:Hide()
		else
			self.healthBar.text:Show()
		end

		if (self.type == "MTT") then
			if (BigWigsTargetMonitor) then
				BigWigsTargetMonitor:TargetCheck(xunit)
			end

			local index = GetRaidTargetIndex(xunit)
			if (FPerl.CanAccess(index)) then
				SetRaidTargetIconTexture(self.raidIcon, index)
				self.raidIcon:Show()
			else
				self.raidIcon:Hide()
			end
		else
			self.raidIcon:Hide()
		end

		if FPerl.SafeBool(UnitAffectingCombat(xunit), false) then
			self.combatIcon:Show()
		else
			self.combatIcon:Hide()
		end

		-- indirect units can return secret flags; no icon in that case
		if FPerl.SafeBool(UnitIsCharmed(xunit), false) and FPerl.SafeBool(UnitIsPlayer(xunit), false) then
			self.warningIcon:Show()
		else
			self.warningIcon:Hide()
		end
	else
		self.text:SetPoint("BOTTOMRIGHT", -2, 1)

		if (self.type == "MTT") then
			local id = SecureButton_GetUnit(self:GetParent())
			name = UnitName(id)

			if (name) then
				FPerl.ColourFriendlyUnit(self.text, id)
				self.text:SetFormattedText(FPERL_XS_TARGET, name)
				self.healthBar.bg:Hide()
			end
		else
			self.text:SetText(FPERL_NO_TARGET)
			self.text:SetTextColor(0.5, 0.5, 0.5, 1)
		end
		self.healthBar:SetMinMaxValues(0, 1)
		self.healthBar:SetValue(0)
		grey = true
		self.healthBar.text:Hide()
		self.raidIcon:Hide()
		self.combatIcon:Hide()
		self.warningIcon:Hide()
	end

	if (FPerl.UpdateSpellRange and FPerl.layout.rangeFinder.enabled) then
		FPerl.UpdateSpellRange(self)
	else
		self:SetAlpha(1)
	end

	if (grey) then
		self.healthBar:SetStatusBarColor(0.5, 0.5, 0.5, 1)
		self.healthBar.bg:SetVertexColor(0.5, 0.5, 0.5, 0.5)
	else
		if (FPerl.layout and FPerl.layout.colour.classbar and UnitIsFriend("player", xunit)) then
			local bar = self.healthBar
			local _, class = UnitClass(xunit)
			if (class and FPerl.CanAccess(class)) then
				local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]

				bar:SetStatusBarColor(c.r, c.g, c.b)
				if (bar.bg) then
					bar.bg:SetVertexColor(c.r, c.g, c.b, 0.25)
				end
				return
			end
		end

		FPerl.SetSmoothBarColor(self.healthBar, xunit)
	end
end

-- FPerl.RaidHelper.RaidHelpShow
function FPerl.RaidHelper.RaidHelpShow()
	conf.RaidHelper = 1
	FPerl_RaidHelperCheck:Show() -- FPerl.RaidHelper.EnableDisable()
	return true
end

-- FPerl.RaidHelper.MTListUnitOnEnter
function FPerl.RaidHelper.MTListUnitOnEnter(self)

	local x = FPerl_RaidHelper_Frame:GetCenter()
	local a1, a2 = "ANCHOR_LEFT", "ANCHOR_TOPLEFT"
	if ( x < (GetScreenWidth() / 2)) then
		a1, a2 = "ANCHOR_RIGHT", "ANCHOR_TOPRIGHT"
	end

	if (conf.Tooltips == 1) then
		local partyid = SecureButton_GetUnit(self)

		if (partyid and UnitName(partyid) and conf.TooltipsWhich == 2) then
			GameTooltip:SetOwner(self, a1)
			GameTooltip:SetUnit(partyid)

			if (self.type == "MTT" and conf.TooltipsWhich == 2) then
				local parentID = SecureButton_GetUnit(self:GetParent())
				if (parentID) then
					FPerl_BottomTip:SetOwner(GameTooltip, a2, 0, 10)
					FPerl_BottomTip:SetUnit(parentID)

					FPerl_BottomTip.NineSlice:SetCenterColor(0.1, 0.4, 0.1, 0.75)
				end
			end
		else
			if (conf.TooltipsWhich == 0) then
				GameTooltip:SetOwner(self, a1)
				GameTooltip:SetUnit(partyid)
			else
				if (self.type == "MTT") then
					partyid = SecureButton_GetUnit(self:GetParent())
				end

				GameTooltip:SetOwner(self, a1)
				GameTooltip:SetUnit(partyid)

				GameTooltip.NineSlice:SetCenterColor(0.1, 0.4, 0.1, 0.75)
			end
		end
	end
end

-- FPerl.RaidHelper.SetupFrameSimple
function FPerl.RaidHelper.SetupFrameSimple(self, alpha)
	if self.backdropInfo then
		self:OnBackdropLoaded()
	end
	self:SetBackdropBorderColor(0.5, 0.5, 0.5, alpha or 0.8)
	self:SetBackdropColor(0, 0, 0, alpha or 0.8)
end

-- FPerl.RaidHelper.HelperBarTextures
if (FPerl.GetBarTexture) then
function FPerl.RaidHelper.HelperBarTextures(tex)
	local function UnitTex(v, tex)
		v.healthBar.tex:SetTexture(tex)
		v.healthBar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
	end

	for k,v in pairs(XUnits) do
		UnitTex(v, tex)
	end
end
end

-- GetRaidIDByName
local function GetRaidIDByName(name)
	for i = 1, GetNumGroupMembers() do
		if (strlower(UnitName("raid"..i)) == strlower(name)) then
			return i
		end
	end
end

-- ValidateTankList
-- Check the roster for any tanks that have left the raid
local function ValidateTankList()
	for index,entry in pairs(FPerlRaidHelperTanks) do
		local found
		for i = 1,GetNumGroupMembers() do
			if (strlower(UnitName("raid"..i)) == strlower(entry[2])) then
				found = true
				break
			end
		end

		if (not found) then
			FPerlRaidHelperTanks[index] = nil
		end
	end
end

-- inBattlegrounds
local function inBattlegrounds()
	for i = 1,50 do
		local r = GetBattlefieldStatus(i)
		if (not r) then
			return
		end
		if (r == "active") then
			return true
		end
	end
end

-- FPerl.RaidHelper.MTRosterChanged()
function FPerl.RaidHelper.MTRosterChanged()
	ValidateTankList()

	--del(MainTanks, true)
	MainTanks = {}

	blizzMTanks, ctraTanks = 0, 0

	-- If conf is nothing, just return.
	if (conf == nil) then
		return
	else
		if (conf and conf.UseCTRATargets == 1) then
			for index, entry in pairs(FPerlRaidHelperTanks) do
				local raidid = GetRaidIDByName(entry[2])
				if (raidid) then
					ctraTanks = ctraTanks + 1
					tinsert(MainTanks, {raidid, UnitName("raid"..raidid)})
				end
			end
		end
	end

	-- Blizzard defined main tanks bit. Looks a bit convoluted, but this is all so the order of the tanks is defined
	-- by they order that they were assigned. It's a reasonable assumption that the MT is promoted first. There's no
	-- guarentees of course. This is up to your raid leader, but imo it's better than the default raid ID ordering.
	if (conf and conf.UseBlizzardMTTargets == 1) then
		-- Remember old tanks
		local oldBlizzardNames = { }
		for i, n in ipairs(BlizzardMainTanks) do
			oldBlizzardNames[n] = true
		end

		-- Scan roster, adding any new ones, and removing found ones from old tanks list
		for i = 1, GetNumGroupMembers() do
			local unitid = "raid"..i
			if ((type(UnitGroupRolesAssigned) == "function" and FPerl.SafeBool(UnitGroupRolesAssigned(unitid), nil) == "TANK") or GetPartyAssignment("maintank", unitid)) then
				local name = GetUnitName(unitid, true)
				local name2, realm = UnitName(unitid)
				if (name ~= name2) then
					name = name2.."-"..realm
				end
				if (name ~= UNKNOWN) then
					if (oldBlizzardNames[name]) then
						-- We already had this tank, so leave it where it is
						oldBlizzardNames[name] = nil
					else
						-- New tank defined, add it to the end of the list
						tinsert(BlizzardMainTanks, name)
					end
				end
			end
		end

		-- Remove any that have been demoted
		for name in pairs(oldBlizzardNames) do
			for i = #BlizzardMainTanks,1,-1 do
				if (BlizzardMainTanks[i] == name) then
					tremove(BlizzardMainTanks, i)
					break
				end
			end
		end
		oldBlizzardNames = { }

		for i,name in ipairs(BlizzardMainTanks) do
			local found
			for i,info in ipairs(MainTanks) do
				if (name == info[2]) then
					found = true
				end
			end
			if (not found) then
				tinsert(MainTanks, {i, name})
				blizzMTanks = blizzMTanks + 1
			end
		end
	end

	if (not next(FPerlRaidHelperTanks)) then
		-- If no defined tanks, then make a list from the warriors in raid

		if (blizzMTanks == 0 and conf.NoAutoList == 0 and not inBattlegrounds()) then
			for i = 1,GetNumGroupMembers() do
				local id = "raid"..i
				local _, class = UnitClass(id)
				if (class == "WARRIOR") then
					tinsert(MainTanks, {i, UnitName(id)})
				end
			end
		end
	end

	MainTankCount = #MainTanks

	FPerl.RaidHelper.MakeTankList()
end

-- FPerl.RaidHelper.OnLoad
function FPerl.RaidHelper.OnLoad(self)
	self:OnBackdropLoaded()
	self:RegisterForDrag("LeftButton")
	self:RegisterEvent("VARIABLES_LOADED")
	self:RegisterEvent("GROUP_ROSTER_UPDATE")

	SlashCmdList["FPERLHELPER"] = FPerl.RaidHelper.Slash
	SLASH_FPERLHELPER1 = "/fphelper"

	if (FPerl.RegisterPerlFrames) then
		FPerl.RegisterPerlFrames(self)
	end

	FPerl.RaidHelper.OnLoad = nil
end

-- FPerl.RaidHelper.OnEvent
function FPerl.RaidHelper.OnEvent(self, event, ...)
	Events[event](self, ...)
end

-- GetUnit
local function GetUnit(unit)
	for i,search in pairs(XUnits) do
		if (search.type == "MTT") then
			local partyid = SecureButton_GetUnit(search:GetParent())
			if (partyid == unit) then
				return search
			end
		end
	end
end

-- ScanForMTDups
-- Check MTs all have unique targets
local function ScanForMTDups()
	local dup = 1
	local dups = { }

	for i, unit in pairs(XUnits) do
		FPerl.RaidHelper.SetupFrameSimple(unit, conf.Background_Transparency)
	end

	for i, t1 in pairs(MainTanks) do
		local any = false

		if (UnitExists("raid"..t1[1].."target") and not UnitIsDeadOrGhost("raid"..t1[1])) then
			for j,t2 in pairs(MainTanks) do
				if (j > i and not dups["raid"..t2[1]]) then
					if (FPerl.SafeBool(UnitIsUnit("raid"..t1[1].."target", "raid"..t2[1].."target"), false)) then
						dups["raid"..t2[1]] = 1

						local unit1 = GetUnit("raid"..t1[1])
						local unit2 = GetUnit("raid"..t2[1])

						if (unit1) then
							unit1:OnBackdropLoaded()
							unit1:SetBackdropColor(MTdupColours[dup].r, MTdupColours[dup].g, MTdupColours[dup].b)
							unit1:SetBackdropBorderColor(MTdupColours[dup].r, MTdupColours[dup].g, MTdupColours[dup].b)
						end
						if (unit2) then
							unit2:OnBackdropLoaded()
							unit2:SetBackdropColor(MTdupColours[dup].r, MTdupColours[dup].g, MTdupColours[dup].b)
							unit2:SetBackdropBorderColor(MTdupColours[dup].r, MTdupColours[dup].g, MTdupColours[dup].b)
						end
						any = true
					end
				end
			end

			if (any and dup < 5) then
				dup = dup + 1
			end
		end
	end

	--del(dups)
end

 -- updates when roles are assigned
	--added aug 30, 2012
function Events:PLAYER_ROLES_ASSIGNED()
	--check for tanks for efficiency if possible
	FPerl.RaidHelper.MTRosterChanged()
	FPerl.RaidHelper.EnableDisable()
end

-- MoveArrow
local function MoveArrow(unit)
	FPerl_MyTarget:SetParent(unit)
	FPerl_MyTarget:SetPoint("RIGHT", unit, "LEFT", 2 - (conf.MTLabels * 10), 0)
	FPerl_MyTarget:Show()
end

-- OnUpdate
local function OnUpdate(self, elapsed)
	UpdateTime = UpdateTime + elapsed
	if (UpdateTime > 0.5) then
		-- Forced update here for anything we don't receive events for
		UpdateTime = 0
		for k, unit in pairs(XUnits) do
			if (unit.type == "MTT" or unit.type == "MTTT") then
				UpdateUnit(unit, true)
			end
		end
	end
end

-- CT_RA_IsSendingWithVersion override
-- Override this so that we get the MT list if there's only us in the raid with a CTRA version registered
local old_CT_RA_IsSendingWithVersion

-- VARIABLES_LOADED
function Events:VARIABLES_LOADED()
	self:UnregisterEvent("VARIABLES_LOADED")
	FPerl.MigrateSavedNames("FPerl_RaidHelper")

	if (InCombatLockdown()) then
		pendingTankListChange = true
		return
	end

	if (CT_RA_IsSendingWithVersion) then
		old_CT_RA_IsSendingWithVersion = CT_RA_IsSendingWithVersion
		CT_RA_IsSendingWithVersion = function(version)
			if (version == 1.08) then
				return 1
			end
			return old_CT_RA_IsSendingWithVersion(version)
		end
	end

	if (type(FPerlRaidHelperTanks) ~= "table") then
		FPerlRaidHelperTanks = {}
	end

	FPerl_MTTargets:UnregisterEvent("UNIT_NAME_UPDATE")	-- Fix for WoW 2.1 UNIT_NAME_UPDATE issue
	FPerl_MTTargets:SetAttribute("template", "FPerl_MTList_UnitTemplate")

	FPerl.RaidHelper.Startup()
	conf = FPerlRaidHelperDB
	FPerl_RaidHelperCheck:Show()		-- FPerl.RaidHelper.EnableDisable()

	FPerl.RegisterOptionChanger(FPerl.RaidHelper.SetFrameSizes, nil, "raidsizes")
	FPerl.RaidHelper.SetFrameSizes()

	Events.VARIABLES_LOADED = nil
end

-- Registration
local function Registration()
	local list = {
		FPerl.ForeverAPI.healthEvent,
		"UNIT_MAXHEALTH",
		"UNIT_TARGET",
		"UNIT_FACTION",
		"PLAYER_ENTERING_WORLD",
		"PLAYER_TARGET_CHANGED",
		"PLAYER_REGEN_ENABLED",
		"PLAYER_REGEN_DISABLED",
		"PLAYER_ROLES_ASSIGNED",
		--"CHAT_MSG_ADDON",
	}

	for i, a in pairs(list) do
		if not conf then
			return
		end
		-- never error on an event this client does not have
		if (conf.RaidHelper == 1) then
			FPerl.RegisterEventSafe(FPerl_RaidHelper_Frame, a)
		else
			FPerl.UnregisterEventSafe(FPerl_RaidHelper_Frame, a)
		end
	end
end

-- FPerl.RaidHelper.HelperCheckOnUpdate
function FPerl.RaidHelper.HelperCheckOnUpdate(self)
	self:Hide()
	FPerl.RaidHelper.EnableDisable()
end

-- FPerl.RaidHelper.EnableDisable
function FPerl.RaidHelper.EnableDisable()
	if (InCombatLockdown()) then
		pendingTankListChange = true
		return
	end

	if (FPerlRaidHelperDB and conf and conf.RaidHelper == 1 and IsInRaid()) then
		if (not FPerl_RaidHelper_Frame:IsShown()) then
			FPerl_RaidHelper_Frame:Show()
			FPerl_RaidHelper_Frame:SetScript("OnUpdate", OnUpdate)
		end

		if (CT_RAMenu_Options and CT_RA_UpdateVisibility) then
			conf.OldCTMTListHide = CT_RAMenu_Options["temp"]["HideMTs"]
			CT_RAMenu_Options["temp"]["HideMTs"] = true
			CT_RA_UpdateVisibility(1)
		end
	else
		if (FPerl_RaidHelper_Frame:IsShown()) then
			FPerl_RaidHelper_Frame:Hide()
			FPerl_RaidHelper_Frame:SetScript("OnUpdate", nil)
		end

		if (FPerlRaidHelperDB and conf and conf.RaidHelper == 0 and CT_RAMenu_Options and CT_RA_UpdateVisibility) then
			if (conf.OldCTMTListHide ~= true) then
				conf.OldCTMTListHide = nil
				CT_RAMenu_Options["temp"]["HideMTs"] = false
				CT_RA_UpdateVisibility(1)
			end
		end
	end

	Registration()
	FPerl.RaidHelper.MTRosterChanged()
end

-- GROUP_ROSTER_UPDATE
function Events:GROUP_ROSTER_UPDATE()
	if (not IsInRaid()) then
		--del(MainTanks, 1)
		MainTanks = { }
		--del(BlizzardMainTanks)
		BlizzardMainTanks = { }
	end
	--FPerl_RaidHelperCheck:show()
end

-- UNIT_HEALTH
function Events:UNIT_HEALTH(unit)
	if not unit then
		return
	end

	if (strfind(unit, "^raid%d")) then
		for k, frame in pairs(XUnits) do
			local partyid = SecureButton_GetUnit(frame)
			if (partyid and FPerl.SafeBool(UnitIsUnit(partyid, unit), false)) then
				UpdateUnit(frame)
			end
		end
	end
end

-- UNIT_MAXHEALTH
function Events:UNIT_MAXHEALTH(unit)
	if not unit then
		return
	end

	if (strfind(unit, "^raid%d")) then
		for k, frame in pairs(XUnits) do
			local partyid = SecureButton_GetUnit(frame)
			if (partyid and FPerl.SafeBool(UnitIsUnit(partyid, unit), false)) then
				UpdateUnit(frame)
			end
		end
	end
end

-- UNIT_FACTION
function Events:UNIT_FACTION(unit)
	if not unit then
		return
	end

	if (strfind(unit, "^raid%d")) then
		for k, frame in pairs(XUnits) do
			if (frame.type == "MT") then
				local partyid = frame:GetAttribute("unit")
				if (partyid and partyid == unit) then
					if (UnitAffectingCombat(partyid)) then
						frame.combatIcon:Show()
					else
						frame.combatIcon:Hide()
					end

					-- indirect units can return secret flags; no icon in that case
					if (FPerl.SafeBool(UnitIsCharmed(partyid), false)) then
						frame.warningIcon:Show()
					else
						frame.warningIcon:Hide()
					end
				end
			end
		end
	end
end

-- CheckArrowPosition
local function CheckArrowPosition()
	local arrowDone
	local arrowType = "MTT"
	local arrowExtra = ""
	if (conf.ShowMT == 1) then
		arrowType = "MT"
		arrowExtra = "target"
	end

	FPerl_MyTarget:Hide()
	FPerl_MainAssist:Hide()
	FPerl_MainTank:Hide()

	local maAssignment, tankAssignment
	if (GetPartyAssignment) then
		maAssignment = GetPartyAssignment("mainassist")
		tankAssignment = GetPartyAssignment("maintank")
	end

	local maDone, mtDone
	for i, unit in pairs(XUnits) do
		local xunit = SpecialCaseUnit(unit)
		if (xunit) then
			if (not arrowDone and unit.type == arrowType and FPerl.SafeBool(UnitIsUnit("target", xunit..arrowExtra), false) and FPerl.SafeBool(UnitExists("target"), false)) then
				MoveArrow(unit)
				arrowDone = true
			end

			if (unit.type == "MTT") then
				xunit = SpecialCaseUnit(unit:GetParent())
			end

			local name = UnitName(xunit)
			if (maAssignment and unit.type == arrowType and not maDone and name == maAssignment) then
				maDone = true
				FPerl_MainAssist:SetParent(unit.healthBar)
				FPerl_MainAssist:ClearAllPoints()

				if (conf.MTLabels == 1) then
					FPerl_MainAssist:SetPoint("BOTTOMRIGHT", unit, "BOTTOMLEFT", 3, 1)
				else
					FPerl_MainAssist:SetPoint("BOTTOMRIGHT", -1, 1)
				end
				FPerl_MainAssist:Show()
			end

			if (tankAssignment and unit.type == arrowType and not mtDone and name == tankAssignment) then
				mtDone = true
				FPerl_MainTank:SetParent(unit.healthBar)
				FPerl_MainTank:ClearAllPoints()

				if (conf.MTLabels == 1) then
					FPerl_MainTank:SetPoint("BOTTOMRIGHT", unit, "BOTTOMLEFT", 3, 1)
				else
					FPerl_MainTank:SetPoint("BOTTOMRIGHT", -1, 1)
				end
				FPerl_MainTank:Show()
			end
		end
	end
end

-- TargetChanged
local function TargetChanged(xunit)
	local unit, i = FPerl_MTTargets:GetAttribute("child1"), 1
	local any
	while (unit) do
		local id = unit:GetAttribute("unit")
		if (id and FPerl.SafeBool(UnitIsUnit(id, xunit), false)) then
			UpdateUnit(unit.target)
			UpdateUnit(unit.targettarget)
			any = true
			break
		end

		i = i + 1
		unit = FPerl_MTTargets:GetAttribute("child"..i)
	end

	if (any) then
		ScanForMTDups()
		CheckArrowPosition()
	end
end

-- PLAYER_TARGET_CHANGED
function Events:PLAYER_TARGET_CHANGED()
	if (FPerl_RaidHelper_Frame:IsShown()) then
		TargetChanged("player")
	end
end

-- UNIT_TARGET
function Events:UNIT_TARGET(u)
	if (FPerl_RaidHelper_Frame:IsShown() and strmatch(u, "^raid")) then
		TargetChanged(u)
	end
end

-- DoButtons
local function DoButtons(disable)
	if (disable or InCombatLockdown()) then
		FPerl_RaidHelper_Frame_TitleBar_CloseButton:Disable()
		FPerl_RaidHelper_Frame_TitleBar_ToggleShowMT:Disable()
		FPerl_RaidHelper_Frame_TitleBar_ToggleMTTargets:Disable()
		FPerl_RaidHelper_Frame_TitleBar_ToggleLabels:Disable()
		FPerl_RaidHelper_Frame.corner:EnableMouse(false)
	else
		FPerl_RaidHelper_Frame_TitleBar_CloseButton:Enable()
		FPerl_RaidHelper_Frame_TitleBar_ToggleShowMT:Enable()
		FPerl_RaidHelper_Frame_TitleBar_ToggleMTTargets:Enable()
		FPerl_RaidHelper_Frame_TitleBar_ToggleLabels:Enable()
		FPerl_RaidHelper_Frame.corner:EnableMouse(true)
	end

	FPerl_RaidHelper_Frame_TitleBar_ToggleShowMT:SetButtonTex()
	FPerl_RaidHelper_Frame_TitleBar_ToggleMTTargets:SetButtonTex()
	FPerl_RaidHelper_Frame_TitleBar_ToggleLabels:SetButtonTex()
end

-- PLAYER_REGEN_ENABLED
function Events:PLAYER_REGEN_ENABLED()
	if (pendingTankListChange) then
		FPerl.RaidHelper.MakeTankList()
		FPerl.RaidHelper.MTRosterChanged()
	end
	DoButtons()
	FPerl_RaidHelperCheck:Show() -- FPerl.RaidHelper.EnableDisable()
end
Events.PLAYER_ENTERING_WORLD = Events.PLAYER_REGEN_ENABLED

-- PLAYER_REGEN_DISABLED
function Events:PLAYER_REGEN_DISABLED()
	DoButtons(true)

end

-- The number of 'Other' colums that can be shown
local function DisplayableColumns()
	return 1 + conf.ShowMT + conf.MTTargetTargets
end

-- FPerl.RaidHelper.SetTitle
function FPerl.RaidHelper.SetTitle()
	if (DisplayableColumns() > 1 and conf.UnitWidth >= 70) then
		if (ctraTanks > 0 or blizzMTanks > 0) then
			FPerl_Frame_Title:SetText(FPERL_TITLE_MT_LONG)
		else
			FPerl_Frame_Title:SetText(FPERL_TITLE_WARRIOR_LONG)
		end
	else
		if (ctraTanks > 0 or blizzMTanks > 0) then
			FPerl_Frame_Title:SetText(FPERL_TITLE_MT_SHORT)
		else
			FPerl_Frame_Title:SetText(FPERL_TITLE_WARRIOR_SHORT)
		end
	end
end

local bEdge = {	bgFile = "Interface\\AddOns\\FPerl_RaidHelper\\Images\\FPerl_FrameBack",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 9,
		insets = { left = 3, right = 3, top = 3, bottom = 3 }
	}
local bNoEdge = {bgFile = "Interface\\AddOns\\FPerl_RaidHelper\\Images\\FPerl_FrameBack",
		edgeFile = "", tile = true, tileSize = 16, edgeSize = 9,
		insets = { left = 3, right = 3, top = 3, bottom = 3 }
	}

-- SetVisibility
local function SetVisibility()
	if (InCombatLockdown()) then
		pendingTankListChange = true
		return
	end

	local left = 3 + (conf.MTLabels * 10)
	FPerl_RaidHelper_Frame:ClearAllPoints()
	FPerl_RaidHelper_Frame_TitleBar:ClearAllPoints()
	FPerl_MTTargets:ClearAllPoints()
	if (conf.MTListUpward == 1) then
		FPerl_RaidHelper_Frame:SetPoint("BOTTOMLEFT", FPerl_MTList_Anchor, "BOTTOMLEFT", 0, 0)
		FPerl_RaidHelper_Frame_TitleBar:SetPoint("BOTTOMLEFT", 3, 3)
		FPerl_RaidHelper_Frame_TitleBar:SetPoint("TOPRIGHT", FPerl_RaidHelper_Frame, "BOTTOMRIGHT", -3, 13)
		FPerl_MTTargets:SetAttribute("point", "BOTTOM")
		FPerl_MTTargets:SetPoint("BOTTOMLEFT", left, 13)
	else
		FPerl_RaidHelper_Frame:SetPoint("TOPLEFT", FPerl_MTList_Anchor, "TOPLEFT", 0, 0)
		FPerl_RaidHelper_Frame_TitleBar:SetPoint("TOPLEFT", 3, -3)
		FPerl_RaidHelper_Frame_TitleBar:SetPoint("BOTTOMRIGHT", FPerl_RaidHelper_Frame, "TOPRIGHT", -3, -13)
		FPerl_MTTargets:SetAttribute("point", "TOP")
		FPerl_MTTargets:SetPoint("TOPLEFT", left, -13)
	end

	local v, k = FPerl_MTTargets:GetAttribute("child1"), 1
	while (v) do
		-- We don't actually hide the MT if it's not shown, just make it unclickable and no visible content
		if (conf.ShowMT == 1) then
			if (v.hidden or not v.text:IsShown() or not v.healthBar:IsShown()) then
				v.hidden = false
				v.text:Show()
				v.healthBar:Show()
				v.healthBar.text:Show()
				v:EnableMouse(true)

				v:SetBackdrop(bEdge)

				v.target:SetPoint("TOPLEFT", v, "TOPRIGHT", 0, 0)
			end
		else
			if (not v.hidden or v.text:IsShown() or v.healthBar:IsShown()) then
				v.hidden = true
				v.text:Hide()
				v.healthBar:Hide()
				v.healthBar.text:Hide()
				v.combatIcon:Hide()
				v.warningIcon:Hide()
				v.raidIcon:Hide()
				v:EnableMouse(false)

				v:SetBackdrop(nil)

				v.target:SetPoint("TOPLEFT", v, "TOPLEFT", 0, 0)
			end
		end

		UpdateUnit(v)

		if (conf.MTTargetTargets == 1) then
			v.targettarget:Show()
		else
			v.targettarget:Hide()
		end

		local label = v.label
		if (conf.MTLabels == 1) then
			local u = v:GetAttribute("unit")
			if (u) then
				local lbl
				local name = UnitName(u)
				for i, tank in pairs(MainTanks) do
					if (tank[2] == name) then
						lbl = i
						break
					end
				end

				label:SetText(lbl)
				label:Show()
			end
		else
			label:Hide()
		end

		k = k + 1
		v = FPerl_MTTargets:GetAttribute("child"..k)
	end
end

-- FPerl.RaidHelper.MakeTankList
function FPerl.RaidHelper.MakeTankList()
	if (InCombatLockdown()) then
		pendingTankListChange = true
		return
	else
		pendingTankListChange = nil
	end

	if (not FPerlRaidHelperDB or (conf and conf.RaidHelper == 0) or not IsInRaid()) then
		FPerl.RaidHelper.SetFrameSizes()
		return
	end

	FPerl.RaidHelper.SetTitle()
	FPerl_MyTarget:Hide()
	XGaps = 0

	local tanks = { }
	for i = 1, 10 do
		if (MainTanks[i]) then
			tinsert(tanks, MainTanks[i][2])
			if (#tanks >= conf.MaxMainTanks) then
				break
			end
		end
	end

	if (#tanks == 0) then
		FPerl_RaidHelper_Frame:Hide()
	else
		FPerl_RaidHelper_Frame:Show()
	end

	FPerl_MTTargets:SetAttribute("nameList", table.concat(tanks, ","))
	FPerl_MTTargets:Show()

	--del(tanks)

	if (FPerl.NoFadeBars) then FPerl.NoFadeBars() end

	FPerl.RaidHelper.SetFrameSizes()
end

-- SetUnitSettings
local function SetUnitSettings(self)
	self:SetWidth(conf.UnitWidth)
	self:SetHeight(conf.UnitHeight)

	if (FPerl.GetBarTexture) then
		local tex = FPerl.GetBarTexture()
		self.healthBar.tex:SetTexture(tex)

		if (not FPerl.layout or FPerl.layout.bar.background) then
			self.healthBar.bg:SetTexture(tex)
		else
			self.healthBar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
		end
	end

	self.healthBar:ClearAllPoints()
	if (conf.UnitHeight > 16) then
		self.healthBar:SetPoint("TOPLEFT", 3, -14)
		self.healthBar:SetPoint("BOTTOMRIGHT", -3, 2)
	else
		self.healthBar:SetPoint("TOPLEFT", 4, -4)
		self.healthBar:SetPoint("BOTTOMRIGHT", -4, 4)
	end

	if (FPerl.RegisterHighlight) then
		FPerl.RegisterHighlight(self, 3)
	else
		local tex = self:GetHighlightTexture()
		tex:SetVertexColor(0.86, 0.82, 0.41)
	end
end

-- onAttrChanged
local function onAttrChanged(self, name, value)
	if (name == "unit") then
		if (value) then
			UpdateUnit(self)
			UpdateUnit(self.target)
			UpdateUnit(self.targettarget)
		end
	end
end

-- FPerl.RaidHelper.MTListChildUnits
function FPerl.RaidHelper.MTListChildUnits(self)
	self.type = "MT"
	self.hidden = false
	self:SetAttribute("*type1", "target")
	FPerl.RegisterClickCastFrame(self)
	SetUnitSettings(self)

	local c1 = CreateFrame("Button", self:GetName().."Target", self, "FPerl_MTList_UnitTemplate")
	c1.type = "MTT"
	c1:SetAttribute("useparent-unit", true)
	c1:SetAttribute("unitsuffix", "target")
	c1:SetAttribute("*type1", "target")
	FPerl.RegisterClickCastFrame(c1)

	c1:SetPoint("TOPLEFT", self, "TOPRIGHT", 0, 0)
	SetUnitSettings(c1)

	local c2 = CreateFrame("Button", self:GetName().."TargetTarget", self, "FPerl_MTList_UnitTemplate")
	c2.type = "MTTT"
	c2:SetAttribute("useparent-unit", true)
	c2:SetAttribute("unitsuffix", "targettarget")
	c2:SetAttribute("*type1", "target")
	FPerl.RegisterClickCastFrame(c2)

	c2:SetPoint("TOPLEFT", c1, "TOPRIGHT", 0, 0)
	SetUnitSettings(c2)

	self.target = c1
	self.targettarget = c2

	self:SetScript("OnShow", UpdateUnit)
	c1:SetScript("OnShow", UpdateUnit)
	c2:SetScript("OnShow", UpdateUnit)

	self:SetScript("OnAttributeChanged", onAttrChanged)

	self:Show()
	c1:Show()
	c2:Show()

	tinsert(XUnits, self)
	tinsert(XUnits, c1)
	tinsert(XUnits, c2)
end

-- FPerl.RaidHelper.SetFrameSizes
function FPerl.RaidHelper.SetFrameSizes()
	if (InCombatLockdown()) then
		FPerl.AfterCombat(FPerl.RaidHelper.SetFrameSizes)
		return
	end
	conf = FPerlRaidHelperDB
	local tanks = MainTankCount

	if (FPerlRaidHelperDB) then
		SetVisibility() -- Change which of MT, MTT and MTTT we can see
		ScanForMTDups()

		if (tanks > conf.MaxMainTanks) then
			tanks = conf.MaxMainTanks
		end

		FPerl.SwitchAnchor(FPerl_MTList_Anchor, (conf.MTListUpward == 1 and "BOTTOMLEFT") or "TOPLEFT")

		if (conf) then
			FPerl_MTTargets:SetHeight((conf.UnitHeight * tanks) + (XGaps * GAP_SPACING))

			local ExtraWidth = (conf.MTLabels * 10)	-- 0 for off, 10 for on
			FPerl_RaidHelper_Frame:SetWidth(DisplayableColumns() * conf.UnitWidth + 6 + ExtraWidth)

			FPerl_RaidHelper_Frame:SetHeight((conf.UnitHeight * tanks) + (XGaps * GAP_SPACING) + 6 + FPerl_RaidHelper_Frame_TitleBar:GetHeight())

			FPerl.RegisterScalableFrame(FPerl_RaidHelper_Frame, FPerl_MTList_Anchor, nil, nil, conf.MTListUpward == 1)
		end
		FPerl_RaidHelper_Frame_TitleBar_Pin:SetButtonTex()

		CheckArrowPosition()
	end
end

-- FPerl.RaidHelper.MTListApplyUnitSizes
function FPerl.RaidHelper.MTListApplyUnitSizes()
	if (InCombatLockdown()) then
		FPerl.AfterCombat(FPerl.RaidHelper.MTListApplyUnitSizes)
		return
	end
	for k,unit in pairs(XUnits) do
		unit:SetWidth(conf.UnitWidth)
		unit:SetHeight(conf.UnitHeight)
		UpdateUnit(unit)
	end
end

-- FPerl.RaidHelper.ToggleUseCTRATargets
function FPerl.RaidHelper.ToggleUseCTRATargets()
	if (conf.UseCTRATargets == 1) then
		conf.UseCTRATargets = 0
	else
		conf.UseCTRATargets = 1
	end

	--FPerl.RaidHelper.MTRosterChanged()
	FPerl_RaidHelperCheck:Show() -- FPerl.RaidHelper.EnableDisable()
	return true
end

-- FPerl.RaidHelper.ToggleMTTargets
function FPerl.RaidHelper.ToggleMTTargets()
	if (conf.MTTargetTargets == 1) then
		conf.MTTargetTargets = 0
	else
		conf.MTTargetTargets = 1
	end

	FPerl.RaidHelper.SetFrameSizes()

	FPerl_RaidHelper_Frame_TitleBar_ToggleMTTargets:SetButtonTex()
	return true
end

-- FPerl.RaidHelper.ToggleLabels
function FPerl.RaidHelper.ToggleLabels()
	if (conf.MTLabels == 1) then
		conf.MTLabels = 0
	else
		conf.MTLabels = 1
	end

	FPerl.RaidHelper.SetFrameSizes()

	FPerl_RaidHelper_Frame_TitleBar_ToggleLabels:SetButtonTex()

	return true
end

-- FPerl.RaidHelper.ToggleShowMT
function FPerl.RaidHelper.ToggleShowMT()
	if (conf.ShowMT == 1) then
		conf.ShowMT = 0
	else
		conf.ShowMT = 1
	end

	FPerl.RaidHelper.SetFrameSizes()

	FPerl_RaidHelper_Frame_TitleBar_ToggleShowMT:SetButtonTex()

	return true
end

-- SmoothBarColor
local function SmoothBarColor(bar, barBG)
	local barmin, barmax = bar:GetMinMaxValues()
	local percentage = (bar:GetValue() / (barmax - barmin))

	local r, g
	if (percentage < 0.5) then
		r = 2 * percentage
		g = 1
	else
		r = 1
		g = 2 * (1 - percentage)
	end

	if ((r >= 0) and (g >= 0) and (r <= 1) and (g <= 1)) then
		bar:SetStatusBarColor(r, g, 0)
		barBG:SetVertexColor(r, g, 0, 0.25)
	end
end
