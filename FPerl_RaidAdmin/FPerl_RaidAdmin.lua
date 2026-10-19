-- Author: Resike
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

local AddonName, Addon = ...

FPerl.SetModuleRevision("$Revision:  $")

local SavedRoster = nil
local XswapCount = 0
local XmoveCount = 0
local XPendingRosters = 0
local WaitingForRoster
local XFinishedLoad

-- AdminCommands
local function AdminCommands(msg)
	local args = {}
	for value in string.gmatch(msg, "[^ ]+") do
		tinsert(args, string.lower(value))
	end

	if (not args[1]) then
			FPerl_AdminFrame:Show()
	else
		if (not FPerl.RaidAdmin.AdminCommands[args[1]] or not FPerl.RaidAdmin.AdminCommands[args[1]](args[2], args[3], args[4])) then
			FPerl.RaidAdmin.AdminCommands.help()
		end
	end
end

-- DefaultVar
local function DefaultVar(name, value)
	if (FPerlRaidAdminDB[name] == nil or (type(value) ~= type(FPerlRaidAdminDB[name]))) then
		FPerlRaidAdminDB[name] = value
	end
end

-- Defaults
local function Defaults()

	if (not FPerlRaidAdminDB) then
		FPerlRaidAdminDB = {}
	end

	DefaultVar("AutoHideShow",	1)
	DefaultVar("SavedRosters",	{})
	DefaultVar("Transparency",	0.8)

	FPerlRaidAdminDB.Scale_ItemCheck = nil
	FPerlRaidAdminDB.Scale_Admin = nil
end

-- FPerl.RaidAdmin.AdminOnLoad
function FPerl.RaidAdmin.AdminOnLoad(self)
	self:RegisterForDrag("LeftButton")

	FPerlRaidAdminDB = { }

	SlashCmdList["FPERLRAIDADMIN"] = AdminCommands
	SLASH_FPERLRAIDADMIN1 = "/rad"
	SLASH_FPERLRAIDADMIN2 = "/fpadmin"

	--self:RegisterEvent("VARIABLES_LOADED")
	self:RegisterEvent("ADDON_LOADED")
	self:RegisterEvent("GROUP_ROSTER_UPDATE")

	self:OnBackdropLoaded()
	self:SetBackdropColor(0, 0, 0, 1)
	self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

	self.Expand = function()
		FPerl_AdminFrame_Controls:Show()
		FPerl_AdminFrame_TitleBar_LockOpen:Show()
		self:SetWidth(140)
		self:SetHeight(150)
	end

	self.Collapse = function()
		FPerl_AdminFrame_Controls:Hide()
		FPerl_AdminFrame_TitleBar_LockOpen:Hide()
		self:SetWidth(140)
		self:SetHeight(18)
	end
	self:SetScript("OnEvent", FPerl.RaidAdmin.AdminOnEvent)

	FPerl.RaidAdmin.AdminOnLoad = nil
end

-- FPerl.RaidAdmin.AdminStartup
local function AdminStartup(self)
	FPerl.MigrateSavedNames(AddonName)
	Defaults()
	FPerl_AdminFrame_TitleBar_Pin:SetButtonTex()

	FPerl.RaidAdmin.CheckSetup()
	FPerl.RaidAdmin.AdminSetupFrames()

	FPerl.RegisterScalableFrame(self, FPerl_AdminFrameAnchor)
	self.corner:SetParent(FPerl_AdminFrame_Controls)

	self:SetWidth(140)
	self:SetHeight(18)

	AdminStartup = nil
end

-- SetupFrameSimple: local, RaidHelper defines a global of the same name with other defaults
local function SetupFrameSimple(self, alpha)
	self:OnBackdropLoaded()
	self:SetBackdropColor(0, 0, 0, alpha or 1)
	self:SetBackdropBorderColor(0.5, 0.5, 0.5, alpha or 1)
end

-- FPerl.RaidAdmin.AdminSetupFrames()
function FPerl.RaidAdmin.AdminSetupFrames()
	SetupFrameSimple(FPerl_Check)
	SetupFrameSimple(FPerl_CheckListItems)
	SetupFrameSimple(FPerl_CheckListPlayers)

	SetupFrameSimple(FPerl_AdminFrame)

	FPerl_Check:SetAlpha(FPerlRaidAdminDB.Transparency)
	FPerl_AdminFrame:SetAlpha(FPerlRaidAdminDB.Transparency)

	FPerl.RaidAdmin.AdminSetupFrames = nil
end

-- Help
local function Help()
	FPerl.Message("/rad [save | load name] [auto]")
end

-- FPerl.RaidAdmin.AdminCheckMyRank
function FPerl.RaidAdmin.AdminCheckMyRank()
	if (FPerlRaidAdminDB.AutoHideShow == 1) then
		if (IsInRaid()) then
			local me = UnitName("player")
			for i = 1,GetNumGroupMembers() do
				local name, rank = GetRaidRosterInfo(i)
				if (name == me) then
					if (rank > 0) then
						FPerl_AdminFrame:Show()
					else
						FPerl_AdminFrame:Hide()
					end
					break
				end
			end
		else
			FPerl_AdminFrame:Hide()
		end
	end
end

-- ToggleAuto
local function ToggleAuto()
	if (FPerlRaidAdminDB.AutoHideShow == 1) then
		FPerlRaidAdminDB.AutoHideShow = 0
	else
		FPerlRaidAdminDB.AutoHideShow = 1
	end
	FPerl.RaidAdmin.AdminCheckMyRank()
end

-- FPerl.RaidAdmin.SaveRoster
function FPerl.RaidAdmin.SaveRoster(saveName)

	if (not saveName or saveName == "") then
		local hours, mins = GetGameTime()
		saveName = hours..":"..mins
	end

	local Roster = {}

	for i = 1,GetNumGroupMembers() do
		local name, _, subgroup, _, _, fileName = GetRaidRosterInfo(i)
		Roster[name] = {group = subgroup, class = fileName}
	end

	if (not FPerlRaidAdminDB.SavedRosters) then
		FPerlRaidAdminDB.SavedRosters = {}
	end
	FPerlRaidAdminDB.SavedRosters[saveName] = Roster

	FPerl.Message(format(FPERL_SAVED_ROSTER, saveName))

	return true
end

local function LoadRoster()
	local swapCount = 0
	local moveCount = 0
	local CurrentRoster = {}
	local CurrentGroups = {}
	local FreeFloating = {}

	-- Store the current raid roster, and a list of players in the raid, but not in the saved roster
	for i = 1,GetNumGroupMembers() do
		local name, _, subgroup, _, _, fileName = GetRaidRosterInfo(i)
		CurrentRoster[name] = {index = i, group = subgroup, class = fileName}

		if (not SavedRoster[name]) then
			-- Not in the saved roster, so doesn't matter where
			FreeFloating[name] = {group = subgroup, class = fileName}
		end
	end

	local function Swap(a, b)
	if (CurrentRoster[a] and CurrentRoster[b]) then
		SwapRaidSubgroup(CurrentRoster[a].index, CurrentRoster[b].index)
		local save = CurrentRoster[b].group
		CurrentRoster[b].group = CurrentRoster[a].group
		CurrentRoster[b].moved = true
		CurrentRoster[a].group = save
		CurrentRoster[a].moved = true

		if (FreeFloating[a]) then
			FreeFloating[a].group = CurrentRoster[a].group
		end
		if (FreeFloating[b]) then
			FreeFloating[b].group = CurrentRoster[b].group
		end

		swapCount = swapCount + 1
	end
	end

	local function Move(name, target)
		SetRaidSubgroup(CurrentRoster[name].index, target)
		CurrentRoster[name].group = target
		CurrentRoster[name].moved = true
		if (FreeFloating[name]) then
			FreeFloating[name].group = target
		end

		moveCount = moveCount + 1
	end

	local function GroupCount(grp)
		local count = 0
		for name,entry in pairs(CurrentRoster) do
			if (entry.group == grp) then
				count = count + 1
			end
		end
		return count
	end

	for nameSaved, saved in pairs(SavedRoster) do
	local name = nameSaved
	local group = saved.group

		if (not CurrentRoster[name]) then
		-- Saved player not in raid, so find someone of the same class in the free floater list
		for floaterName,floater in pairs(FreeFloating) do
			if (floater.class == saved.class) then
				name = floaterName
				FreeFloating[name] = nil
				break
			end
		end
	end

		if (CurrentRoster[name] and not CurrentRoster[name].moved) then
			if (CurrentRoster[name].group == group) then
				CurrentRoster[name].moved = true -- They're in right group already
			elseif (not FreeFloating[name]) then
			-- First see if we can directly swap any 2 players
				local swapName
				for name2, saved2 in pairs(SavedRoster) do
					if (name ~= name2) then
						if (CurrentRoster[name] and CurrentRoster[name].group == saved2.group) then
							if (CurrentRoster[name2] and CurrentRoster[name2].group == group) then
								swapName = name2
								break
							end
						end

					end
				end

				if (swapName) then
					Swap(name, swapName)
				--break
				else
				local done
					-- Nothing suitable found to swap, see if target group has space
					if (GroupCount(group) < 5) then
						Move(name, group)
					done = true
						--break
					end

					-- No space in target group, put them anywhere
					if (not done) then
						for i = 1,8 do
							if (CurrentRoster[name].group ~= i and GroupCount(i) < 5) then
								Move(name, i)
							done = true
								break
							end
						end
					end

					if (not done) then
					-- Nothing done yet, see if we can swap a free floater
					local free
					for name2, group in pairs(FreeFloating) do
						if (group ~= CurrentRoster[name2].group) then
							free = name2
							break
						end
					end
						if (free) then
							Swap(CurrentRoster[name].index, CurrentRoster[free].index)
						--break
						else
						-- Couldn't put them anywhere, add them to floater list
							FreeFloating[name] = group
						end
				--else
				--	break
					end
				end
			end
		end

		--if (moveCount > 0) then		-- or swapCount > 0) then
		--	break
		--end
		end

	if (moveCount == 0 and swapCount == 0) then
		--ChatFrame7:AddMessage("Finished!")
		FPerl.RaidAdmin.StopLoad()
	else
		WaitingForRoster = GetTime()
		XswapCount = XswapCount + swapCount
		XmoveCount = XmoveCount + moveCount
		XPendingRosters = XPendingRosters + swapCount
		XPendingRosters = XPendingRosters + moveCount
	end
	--ChatFrame7:AddMessage("Done arranging (swaps: "..swapCount..")  (moves: "..moveCount..")")
end

-- FPerl.RaidAdmin.AdminOnEvent
function FPerl.RaidAdmin.AdminOnEvent(self, event, ...)
	FPerl.RaidAdmin.AdminCheckMyRank()

	if (event == "GROUP_ROSTER_UPDATE") then
		FPerl_AdminFrame_Controls:Details()

		if (WaitingForRoster) then
			if (not XFinishedLoad) then
				XPendingRosters = XPendingRosters - 1
				if (XPendingRosters < 1) then
					LoadRoster()
				end
			end
		end

	elseif (event == "ADDON_LOADED") then
		local addon = ...

		if addon == AddonName then
			AdminStartup(self)

			self:UnregisterEvent(event)
		end
	end
end

-- FPerl.RaidAdmin.AdminOnUpdate
function FPerl.RaidAdmin.AdminOnUpdate(self, elapsed)
	if (WaitingForRoster) then
		if (GetTime() > WaitingForRoster + 5) then
			FPerl.RaidAdmin.StopLoad()
		end
	end
end

-- FPerl.RaidAdmin.LoadRoster
function FPerl.RaidAdmin.LoadRoster(loadName)
	if (not FPerlRaidAdminDB.SavedRosters) then
		return
	end

	SavedRoster = FPerlRaidAdminDB.SavedRosters[loadName]
	if (SavedRoster) then
		FPerl_AdminFrame_Controls_StopLoad:Show()
		FPerl_AdminFrame_Controls_LoadRoster:Hide()

		XFinishedLoad = false
		WaitingForRoster = nil
		XPendingRosters = 0
		LoadRoster()
	else
		if (not loadName) then
			FPerl.Message(FPERL_NO_ROSTER_NAME_GIVEN)
		else
			FPerl.Message(format(FPERL_NO_ROSTER_CALLED, loadName))
		end
	end

	return true
end

-- FPerl.RaidAdmin.StopLoad
function FPerl.RaidAdmin.StopLoad()
	FPerl_AdminFrame_Controls_StopLoad:Hide()
	FPerl_AdminFrame_Controls_LoadRoster:Show()

	XFinishedLoad = true
	WaitingForRoster = nil
	SavedRoster = nil
	XPendingRosters = 0

	FPerl_AdminFrame_Controls:Details()
end

function FPerl.Message(...)
	DEFAULT_CHAT_FRAME:AddMessage(FPERL_MSG_PREFIX.."- "..format(...))
end

FPerl.RaidAdmin.AdminCommands = {
	save = FPerl.RaidAdmin.SaveRoster,
	load = FPerl.RaidAdmin.LoadRoster,
	auto = ToggleAuto,
	help = Help
}

-- FPerl.RaidAdmin.AdminCountDifferences
function FPerl.RaidAdmin.AdminCountDifferences(rosterName)
	if (not FPerlRaidAdminDB.SavedRosters) then
		return
	end

	local count = 0

	SavedRoster = FPerlRaidAdminDB.SavedRosters[rosterName]
	if (SavedRoster) then
		for i = 1,GetNumGroupMembers() do
			local name, _, subgroup = GetRaidRosterInfo(i)
			if (SavedRoster[name]) then
				if (SavedRoster[name].group ~= subgroup) then
					count = count + 1
				end
			else
				count = count + 1
			end
		end

		return count
	end
end

function FPerl.RaidAdmin.AdminControlsOnLoad(self)
	self.Details = function(self)
		local name = FPerl_AdminFrame_Controls_Edit:GetText()
		local diff
		if (name) then
			diff = FPerl.RaidAdmin.AdminCountDifferences(name)
		end

		if (diff) then
			FPerl_AdminFrame_Controls_DetailsText:SetFormattedText(FPERL_ADMIN_DIFFERENCES, diff)
			FPerl_AdminFrame_Controls_Details:Show()
		else
			FPerl_AdminFrame_Controls_Details:Hide()
		end
	end

	self.MakeList = function(self)
		local index = 1
		local line = 1
		local find = FPerl_AdminFrame_Controls_Edit:GetText()

		local Offset = FPerl_AdminFrame_Controls_RosterScrollBarScrollBar:GetValue() + 1
		for name,roster in pairs(FPerlRaidAdminDB.SavedRosters) do
			if (index >= Offset) then
				local f = _G["FPerl_AdminFrame_Controls_Roster"..line]
				if (f) then
					if (name == find) then
						f:LockHighlight()
					else
						f:UnlockHighlight()
					end
					f:SetText(name)
					f:Show()
				end
				line = line + 1
			end
			index = index + 1
		end
		for i = line,5 do
			local f = _G["FPerl_AdminFrame_Controls_Roster"..i]
			if (f) then
				f:SetText("")
				f:UnlockHighlight()
				f:Hide()
			end
		end

		local offset = FPerl_AdminFrame_Controls_RosterScrollBarScrollBar:GetValue()
		if (FauxScrollFrame_Update(FPerl_AdminFrame_Controls_RosterScrollBar, index - 1, 5, 1)) then
			FPerl_AdminFrame_Controls_RosterScrollBar:Show()
		else
			FPerl_AdminFrame_Controls_RosterScrollBar:Hide()
		end

		FPerl_AdminFrame_Controls:Details()
	end

	self.Validate = function(self)
		FPerl_AdminFrame.Valid = false
		FPerl_AdminFrame_Controls_LoadRoster:Disable()
		FPerl_AdminFrame_Controls_DeleteRoster:Disable()

		local index = 1
		local line = 1
		local find = FPerl_AdminFrame_Controls_Edit:GetText()
		local Offset = FPerl_AdminFrame_Controls_RosterScrollBarScrollBar:GetValue()
			for name,roster in pairs(FPerlRaidAdminDB.SavedRosters) do
				if (index - 1 >= Offset) then
					local f = _G["FPerl_AdminFrame_Controls_Roster"..line]
					if (not f) then
						break
					end
					if (name == find) then
						f:LockHighlight()
						FPerl_AdminFrame.Valid = true
						if (UnitIsGroupAssistant("player") or UnitIsGroupLeader("player")) then
							FPerl_AdminFrame_Controls_LoadRoster:Enable()
						end
						FPerl_AdminFrame_Controls_DeleteRoster:Enable()
					else
						f:UnlockHighlight()
					end
				line = line + 1
			end
		   index = index + 1
		end
	end
end
