-- Author: Resike
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

FPerl.SetModuleRevision("$Revision:  $")

FPerlRaidAdminItems = {}

-- Upvalues
local _G = _G
local floor = floor
local format = format
local ipairs = ipairs
local pairs = pairs
local setmetatable = setmetatable
local sort = sort
local strfind = strfind
local string = string
local strlen = strlen
local strlower = strlower
local strmatch = strmatch
local strsub = strsub
local tinsert = tinsert
local tonumber = tonumber
local tremove = tremove
local type = type
local unpack = unpack

local ChatTypeInfo = ChatTypeInfo
local CheckInteractDistance = CheckInteractDistance
local ClearCursor = ClearCursor
local CursorHasItem = CursorHasItem
local DressUpItemLink = DressUpItemLink
local GetChannelName = GetChannelName
local GetContainerItemLink = GetContainerItemLink or C_Container.GetContainerItemLink
local GetInventoryItemLink = GetInventoryItemLink
local GetItemInfo = GetItemInfo
local GetNumGroupMembers = GetNumGroupMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local GetRealZoneText = GetRealZoneText
local GetTime = GetTime
local IsControlKeyDown = IsControlKeyDown
local IsInRaid = IsInRaid
local IsShiftKeyDown = IsShiftKeyDown
local SecondsToTime = SecondsToTime
local SendChatMessage = SendChatMessage
local UnitClass = UnitClass
local UnitInRaid = UnitInRaid
local UnitIsConnected = UnitIsConnected
local UnitIsGroupAssistant = UnitIsGroupAssistant
local UnitName = UnitName

local C_ChatInfo = C_ChatInfo

local ItemResults = {["type"] = "item"}
local ResistResults = {["type"] = "res", count = 0}
local DurResults = {["type"] = "dur", count = 0}
local RegResults = {["type"] = "reg", count = 0}
local PlayerList = {}
local MsgQueue = {}
local SelectedPlayer
local ActiveScan
local ActiveScanItem
local ActiveScanTotals
local channelList = nil
local outputChannel = "RAID"
local outputChannelIndex = nil
local outputChannelSelection
local outputChannelColour

local ITEMLISTSIZE = 12
local PLAYERLISTSIZE = 10

-- FPerl.RaidAdmin.CheckOnLoad
function FPerl.RaidAdmin.CheckOnLoad(self)
	self:RegisterForDrag("LeftButton")
	self:SetScript("OnEvent", FPerl.RaidAdmin.CheckOnEvent)
	self:SetScript("OnShow", FPerl.RaidAdmin.CheckOnShow)
	self:SetScript("OnHide", FPerl.RaidAdmin.CheckOnHide)
	--self:RegisterEvent("CHAT_MSG_ADDON")

	FPerl_CheckListItemsScrollBar.offset = 0
	FPerl_CheckListPlayersScrollBar.offset = 0

	if (FPerl.RegisterPerlFrames) then
		FPerl.RegisterPerlFrames(self)
	end

	FPerl.RegisterScalableFrame(self, FPerl_CheckAnchor)
	self.corner:SetParent(FPerl_CheckList)

	FPerl_Check:SetWidth(130)
	FPerl_Check:SetHeight(18)

	FPerl.RaidAdmin.CheckOnLoad = nil
end

if (not FPerl.GetClassColour) then
	FPerl.GetClassColour = function(class)
		if (class) then
			local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class] -- Now using the WoW class color table
			if (color) then
				return color
			end
		end
		return {r = 0.5, g = 0.5, b = 1}
	end
end

if (not FPerl.ColourTable) then
	FPerl.ColourTable = setmetatable({},{
		__index = function(self, class)
			local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class] or {r = 0, g = 0, b = 0}
			return format("|c00%02X%02X%02X", 255 * c.r, 255 * c.g, 255 * c.b)
		end
	})
end

if (not FPerl.ClassPos) then
	local ClassPos = CLASS_BUTTONS
	function FPerl.ClassPos(class)
		local b = ClassPos[class] -- Now using the Blizzard supplied from FrameXML/WorldStateFrame.lua
		if (b) then
			return unpack(b)
		end
		return 0.25, 0.5, 0.5, 0.75
	end
end

-- FPerl.RaidAdmin.CheckSetup
function FPerl.RaidAdmin.CheckSetup()
	SlashCmdList["FPERLITEM"] = FPerl.RaidAdmin.ItemCheck
	SLASH_FPERLITEM1 = "/fpitem"
	SLASH_FPERLITEM2 = "/raitem"
	SLASH_FPERLITEM3 = "/radur"
	SLASH_FPERLITEM4 = "/raresist"
	SLASH_FPERLITEM5 = "/raresists"
	SLASH_FPERLITEM6 = "/rareg"

	SlashCmdList["RAITEM"] = nil
	SLASH_RAITEM1 = nil
	SlashCmdList["RADUR"] = nil
	SLASH_RADUR1 = nil
	SlashCmdList["RARST"] = nil
	SLASH_RARST1 = nil
	SlashCmdList["RAREG"] = nil
	SLASH_RAREG1 = nil

	if (not FPerlRaidAdminDB.ResistSort) then
		FPerlRaidAdminDB.ResistSort = "fr"
	end
	for k,v in ipairs(FPerlRaidAdminItems) do
		v.query = nil
	end

	FPerl_CheckTitleBarPin:SetButtonTex()
	FPerl_CheckTitleBarLockOpen:SetButtonTex()

	FPerl_CheckListPlayersTotals:SetHighlightTexture("")
	FPerl_CheckListPlayersTotals:SetScript("OnClick", nil)

	FPerl.RaidAdmin.CheckItemsChanged()
	FPerl.RaidAdmin.CheckUpdatePlayerList()

	FPerl.RaidAdmin.CheckSetup = nil
end

-- FPerl.RaidAdmin.CheckOnShow
function FPerl.RaidAdmin.CheckOnShow(self)
	self:RegisterEvent("GROUP_ROSTER_UPDATE")
end

-- FPerl.RaidAdmin.CheckOnHide
function FPerl.RaidAdmin.CheckOnHide(self)
	self:UnregisterEvent("GROUP_ROSTER_UPDATE")
end

-- FPerl.RaidAdmin.CheckOnEvent
function FPerl.RaidAdmin.CheckOnEvent(self, event, a1)
	if (event == "GROUP_ROSTER_UPDATE") then
		if (not IsInRaid()) then
			ItemResults = {["type"] = "item"}
			ResistResults = {["type"] = "res", count = 0}
			DurResults = {["type"] = "dur", count = 0}
			RegResults = {["type"] = "reg", count = 0}
		end
		FPerl.RaidAdmin.CheckValidateButtons()

	elseif (event == "UNIT_INVENTORY_CHANGED" or event == "UNIT_MODEL_CHANGED") then
		local n = UnitName(a1)
		if (ActiveScan and ActiveScan[n]) then
			ActiveScan[n].changed = true
			ActiveScan[n].offline = nil
			ActiveScan[n].wrongZone = nil
		end
	end
end

-- CheckOnUpdate
-- Only active after a query, and only for 10 seconds
local function CheckOnUpdate(self, elapsed)
	-- TODO Total Progress indication
	if (#MsgQueue > 0) then
		local Time = GetTime()
		local send
		if (not self.lastMsgsent) then
			send = true
		elseif (Time > self.lastMsgsent + 1) then
			send = true
		end

		if (send) then
			self.lastMsgsent = Time

			local count = 0
			local msg = ""

			while (#MsgQueue > 0 and count < 4) do
				local sub = MsgQueue[1]

				if (strlen(msg..sub) > 220) and UnitInRaid("player") then
					C_ChatInfo.SendAddonMessage("CTRA", msg, "RAID")
					break
				else
					count = count + 1
					tremove(MsgQueue, 1)
					if (msg == "") then
						msg = sub
					else
						msg = msg.."#"..sub
					end
				end
			end

			if (msg ~= "") and UnitInRaid("player") then
				C_ChatInfo.SendAddonMessage("CTRA", msg, "RAID")
			end
		end

	elseif (ActiveScanItem) then
		FPerl.RaidAdmin.CheckActiveScan()
	else
		if (self.queryStart and GetTime() > self.queryStart + 5) then
			self:SetScript("OnUpdate", nil)
			self.queryStart, self.lastMsgsent = nil, nil

			FPerl.RaidAdmin.CheckValidateButtons()
		end
	end
end

-- GetVLinkName
local function GetVLinkName(v)
	local linkName
	if (strsub(v.link, 1, 1) == "|") then
		linkName = strmatch(v.link, "%[(.+)%]")
	else
		linkName = v.link
	end
	return linkName
end

-- ClearSelectedItem
local function ClearSelectedItem()
	for k,v in ipairs(FPerlRaidAdminItems) do
		v.selected = nil
	end
end

-- TickItemByName
local function TickItemByName(itemName)
	for k,v in ipairs(FPerlRaidAdminItems) do
		local name = GetVLinkName(v)

		if (name == itemName) then
			if (not v.fixed) then
				v.ticked = true
			end
			v.selected = true
			break
		end
	end
end

-- GotItem
local function GotItem(link)
	local findItem = strmatch(link, "item:(%d+):")
	for k,v in pairs(FPerlRaidAdminItems) do
		local item = strmatch(v.link, "item:(%d+):")
		if (item == findItem) then
			return true
		end
	end
end

-- GotItem
local function GotItemName(itemName)
	for k,v in pairs(FPerlRaidAdminItems) do
		local linkName = strmatch(v.link, "%[(.+)%]")
		if (linkName == itemName) then
			return true
		end
	end
end

-- InsertItemLink
local function InsertItemLink(itemLink)
	ClearSelectedItem()

	if (strsub(itemLink, 1, 1) == "|") then
		if (not GotItem(itemLink)) then
			tinsert(FPerlRaidAdminItems, {link = itemLink, ticked = true, selected = true})
		else
			local linkName = strmatch(itemLink, "%[(.+)%]")
			TickItemByName(linkName)
		end
	else
		if (not GotItemName(itemLink)) then
			tinsert(FPerlRaidAdminItems, {link = itemLink, ticked = true, selected = true})
		else
			local linkName = strmatch(itemLink, "%[(.+)%]")
			TickItemByName(linkName)
		end
	end
end

-- FPerl.RaidAdmin.CheckExpand()
function FPerl.RaidAdmin.CheckExpand(forced)
	FPerl_Check:SetWidth(500)
		FPerl_Check:SetHeight(240)
		FPerl_CheckList:Show()
		FPerl_CheckButton:Show()
	FPerl_Check.forcedOpen = forced
	FPerl_CheckTitleBarLockOpen:Show()
end

-- FPerl.RaidAdmin.ItemCheck
function FPerl.RaidAdmin.ItemCheck(itemName)
	local cmd = "/raitem"
	if (DEFAULT_CHAT_FRAME.editBox) then
		local command = DEFAULT_CHAT_FRAME.editBox:GetText()
		if (strlower(strsub(command, 1, 6)) == "/radur") then
			cmd = "/radur"
		elseif (strlower(strsub(command, 1, 9)) == "/raresist") then
			cmd = "/raresist"
		elseif (strlower(strsub(command, 1, 6)) == "/rareg") then
			cmd = "/rareg"
		end
	end

	FPerl_Check:Show()
	FPerl.RaidAdmin.CheckExpand(true)

	if (cmd == "/raitem") then
		if (not itemName or itemName == "") then
			return
		end

		if (strsub(itemName, 1, 1) == "|") then
			-- TODO search for item in inventory (and LootLink) and use the link
		end

		InsertItemLink(itemName)
	elseif (cmd == "/radur") then
		ClearSelectedItem()
		TickItemByName("dur")

	elseif (cmd == "/rareg") then
		ClearSelectedItem()
		TickItemByName("reg")

	elseif (cmd == "/raresist") then
		ClearSelectedItem()
		TickItemByName("res")
	end

	FPerl.RaidAdmin.CheckQuery()
end

-- FPerl_PickupContainerItem
local PickupBag, PickupSlot
if C_Container then
	hooksecurefunc(C_Container, "PickupContainerItem", function(bagID, slot)
		PickupBag, PickupSlot = bagID, slot
	end)
elseif PickupContainerItem then
	hooksecurefunc("PickupContainerItem", function(bagID, slot)
		PickupBag, PickupSlot = bagID, slot
	end)
end

-- sortItems
-- Fixed entries at top, followed by last current queried, followed by rest. Alphabetical within this.
local function sortItems(i1, i2)
	local itemName1 = GetVLinkName(i1)
	local itemName2 = GetVLinkName(i2)

	local t1, t2, f1, f2, q1, q2
	if (i1.fixed) then f1 = "0" else f1 = "1" end
	if (i2.fixed) then f2 = "0" else f2 = "1" end
	if (i1.ticked) then t1 = "0" else t1 = "1" end
	if (i2.ticked) then t2 = "0" else t2 = "1" end
	if (i1.query) then q1 = "0" else q1 = "1" end
	if (i2.query) then q2 = "0" else q2 = "1" end

	return f1..q1..t1..itemName1 < f2..q2..t2..itemName2
end

-- ItemsChanged
function FPerl.RaidAdmin.CheckItemsChanged()
	-- Validate. Make sure we have our fixed entries
	local dur, reg, res
	for k,v in ipairs(FPerlRaidAdminItems) do
		if (v.link == "res") then
			res = true
		elseif (v.link == "dur") then
			dur = true
		elseif (v.link == "reg") then
			reg = true
		end
	end
	if (not dur) then
		tinsert(FPerlRaidAdminItems, {fixed = true, link = "dur"})
	end
	if (not res) then
		tinsert(FPerlRaidAdminItems, {fixed = true, link = "res"})
	end
	if (not reg) then
		tinsert(FPerlRaidAdminItems, {fixed = true, link = "reg"})
	end

	sort(FPerlRaidAdminItems, sortItems)

	FPerl.RaidAdmin.CheckUpdateItemList()
	FPerl.RaidAdmin.CheckValidateButtons()
end

-- GetSelectedResults
local function GetSelectedItem()
	for k,v in ipairs(FPerlRaidAdminItems) do
		if (v.selected) then
			if (v.fixed) then
				if (v.link == "res") then
					return ResistResults, "res"
				elseif (v.link == "dur") then
					return DurResults, "dur"
				elseif (v.link == "reg") then
					return RegResults, "reg"
				end
			else
				local linkName = GetVLinkName(v)
				if (linkName) then
					return ItemResults[linkName], "item"
				end
				break
			end
		end
	end
end

-- GetSelectedItemLink
local function GetSelectedItemLink()
	local link
	for k,v in ipairs(FPerlRaidAdminItems) do
		if (v.selected) then
			return v.link
		end
	end
end

-- GetCursorItem
local function GetCursorItemLink(self)
	local id = self:GetID() + FPerl_CheckListItemsScrollBar.offset
	local item = FPerlRaidAdminItems[id]
	if (item and not item.fixed) then
		return item.link
	end
	return ""
end

-- SelectClickedTickItem
local function SelectClickedTickItem(self)
	local oldSelection
	for k, v in ipairs(FPerlRaidAdminItems) do
		if (v.selected) then
			oldSelection = v
			v.selected = nil
		end
	end

	local id
	if ((self.GetFrameType or self.GetObjectType)(self) == "CheckButton") then
		id = self:GetParent():GetID()
	else
		id = self:GetID()
	end

	if (id and id > 0) then
		id = id + FPerl_CheckListItemsScrollBar.offset

		local item = FPerlRaidAdminItems[id]
		if (item) then
			item.selected = true
		end

		if (oldSelection ~= item) then
			FPerl.RaidAdmin.CheckStopActiveScan()
			ActiveScan = nil
			ActiveScanTotals = nil
		end

		FPerl.RaidAdmin.CheckUpdateItemList()
		FPerl.RaidAdmin.CheckMakePlayerList()
		FPerl.RaidAdmin.CheckShowInfo()
	end
end

-- FPerl.RaidAdmin.CheckTickAll
function FPerl.RaidAdmin.CheckTickAll(all)
	for k, v in ipairs(FPerlRaidAdminItems) do
		if (not v.fixed) then
			v.ticked = all
		end
	end
	FPerl.RaidAdmin.CheckItemsChanged()
end

-- FPerl.RaidAdmin.CheckTickLastResults
function FPerl.RaidAdmin.CheckTickLastResults()
	for k, v in ipairs(FPerlRaidAdminItems) do
		if (not v.fixed) then
			v.ticked = nil

			local linkName = GetVLinkName(v)
			if (linkName) then
				if (ItemResults[linkName]) then
					v.ticked = true
				end
			end
		end
	end

	FPerl.RaidAdmin.CheckItemsChanged()
end

-- FPerl.RaidAdmin.CheckOnClickItem
function FPerl.RaidAdmin.CheckOnClickItem(button)
	if (button == "LeftButton") then
		if (IsShiftKeyDown()) then
			local activeWindow = ChatEdit_GetActiveWindow()
			if ( activeWindow ) then
				activeWindow:Insert(GetCursorItemLink(button))
			end

		elseif (IsControlKeyDown()) then
			DressUpItemLink(GetCursorItemLink(button))

		else
			if (CursorHasItem()) then
				ClearCursor()

				if (PickupBag and PickupSlot) then
					local itemLink = GetContainerItemLink(PickupBag, PickupSlot)

					if (itemLink) then
						InsertItemLink(itemLink)
						FPerl.RaidAdmin.CheckItemsChanged()
					end
				end
			end

			FPerl_CheckListPlayersScrollBarScrollBar:SetValue(0)
			FPerl_CheckButtonPlayerPortrait:SetTexture("")	-- SetPortraitTexture(FPerl_CheckButtonPlayerPortrait, "raidx")
			SelectedPlayer = nil
			SelectClickedTickItem(button)
			FPerl.RaidAdmin.CheckValidateButtons()
		end
	end
end

local reagentClasses = {
	PRIEST = true,
	MAGE = true,
	DRUID = true,
	WARLOCK = true,
	PALADIN = true,
	SHAMAN = true
}

-- GetOnlineMembers
local function GetOnlineMembers()
	local count = 0
	local reagentCount = 0
	for i = 1,GetNumGroupMembers() do
		if (UnitIsConnected("raid"..i)) then
			local _, class = UnitClass("raid"..i)
			if (reagentClasses[class]) then
				reagentCount = reagentCount + 1
			end

			if (FPerlRoster) then
				local stats = FPerlRoster[UnitName("raid"..i)]
				if (stats) then
					if (stats.version) then
						count = count + 1
					end
				end
			else
				count = count + 1
			end
		end
	end
	return count, reagentCount
end

-- SmoothColour
local function SmoothColour(percentage)
	local r, g
	if (percentage < 0.5) then
		g = 2 * percentage
		r = 1
	else
		g = 1
		r = 2 * (1 - percentage)
	end
	if (r < 0) then r = 0 elseif (r > 1) then r = 1 end
	if (g < 0) then g = 0 elseif (g > 1) then g = 1 end
	return r, g, 0
end

-- SmoothBarColor
local function SmoothGuageColor(bar, percentage)
	local r, g, b = SmoothColour(percentage)
	bar:SetVertexColor(r, g, b, 0.75)
end

-- FPerl.RaidAdmin.CheckUpdateItemList
function FPerl.RaidAdmin.CheckUpdateItemList()
	local onlineCount, reagentCount = GetOnlineMembers()
	local index = 1
	local i = 0
	for k,v in ipairs(FPerlRaidAdminItems) do
		if (index > ITEMLISTSIZE) then
			break
		end
		if (i >= FPerl_CheckListItemsScrollBar.offset) then
			local frame = _G["FPerl_CheckListItems"..index]
			local nameFrame = _G["FPerl_CheckListItems"..index.."Name"]
			local countFrame = _G["FPerl_CheckListItems"..index.."Count"]
			local iconFrame = _G["FPerl_CheckListItems"..index.."Icon"]
			local gaugeFrame = _G["FPerl_CheckListItems"..index.."Gauge"]
			local tickFrame = _G["FPerl_CheckListItems"..index.."Tick"]

			frame:Show()
			if (v.selected) then
				frame:LockHighlight()
			else
				frame:UnlockHighlight()
			end

			if (v.fixed) then
				tickFrame:Hide()
				iconFrame:Hide()

				local div
				if (v.link == "res") then
					nameFrame:SetText(RESISTANCE_LABEL)
					countFrame:SetText(ResistResults.count)
					if onlineCount == 0 then
						div = 1
					else
						div = ResistResults.count / onlineCount
					end

				elseif (v.link == "dur") then
					local dur,c = string.gsub(DURABILITY_TEMPLATE, " %%d / %%d", "")
					if (not dur or c ~= 1) then
						dur = "Durability"
					end
					nameFrame:SetText(dur)
					countFrame:SetText(DurResults.count)
					if onlineCount == 0 then
						div = 1
					else
						div = DurResults.count / onlineCount
					end

				elseif (v.link == "reg") then
					nameFrame:SetText(FPERL_CHECK_REAGENTS)
					countFrame:SetText(RegResults.count)
					if reagentCount == 0 then
						div = 1
					else
						div = RegResults.count / reagentCount
					end
				end
				nameFrame:SetTextColor(1, 1, 0.7)

				if (div > 0) then
					if (div > 1) then div = 1 end
					gaugeFrame:SetWidth((countFrame:GetLeft() - nameFrame:GetLeft()) * div)
					gaugeFrame:Show()
					SmoothGuageColor(gaugeFrame, div)
				else
					gaugeFrame:Hide()
				end
			else
				tickFrame:Show()
				tickFrame:SetChecked(v.ticked)

				nameFrame:SetText(v.link)

				local itemId = strmatch(v.link, "item:(%d+):")
				if (itemId) then
					local itemName, itemString, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemId)
					iconFrame:SetTexture(itemTexture)
					iconFrame:Show()
				else
					iconFrame:Hide()
				end

				local linkName = GetVLinkName(v)
				if (linkName) then
					local count = ""
					local result = ItemResults[linkName]
					if (result) then
						count = #result

						for k,v in pairs(result) do
							if (v == -1) then
								-- Don't count Blocked ones, it's misleading
								count = count - 1
							end
						end

						local div = count / onlineCount

						if (v.query and div > 0) then
							if (div > 1) then div = 1 end
							gaugeFrame:SetWidth((countFrame:GetLeft() - nameFrame:GetLeft()) * div)
							gaugeFrame:Show()
							SmoothGuageColor(gaugeFrame, div)
						else
							gaugeFrame:Hide()
						end
					else
						gaugeFrame:Hide()
					end
					countFrame:SetText(count)
				else
					gaugeFrame:Hide()
				end
			end

			index = index + 1
		end
		i = i + 1
	end

	for i = index,ITEMLISTSIZE do
			_G["FPerl_CheckListItems"..i]:Hide()
	end

	if (FauxScrollFrame_Update(FPerl_CheckListItemsScrollBar, #FPerlRaidAdminItems, ITEMLISTSIZE, 1)) then
		FPerl_CheckListItemsScrollBar:Show()
	else
		FPerl_CheckListItemsScrollBar:Hide()
	end
end

-- SortPlayersByCount
local function SortPlayersByCount(p1, p2)
	local c1, c2
	if (p1.broken) then
		if (p1.connected and not p1.noCTRA) then	c1 = p1.broken + (1 - (p1.dur / 100))	else	c1 = -1	end
		if (p2.connected and not p2.noCTRA) then	c2 = p2.broken + (1 - (p2.dur / 100))	else	c2 = -1	end
	else
		if (p1.connected and not p1.noCTRA) then	c1 = p1.count	else	c1 = -1	end
		if (p2.connected and not p2.noCTRA) then	c2 = p2.count	else	c2 = -1	end
	end
	return c1 > c2
end

-- SortPlayersByName
local function SortPlayersByName(p1, p2)
	return p1.name < p2.name
end

-- SortPlayersByClass
local function SortPlayersByClass(p1, p2)
	return p1.class..p1.name < p2.class..p2.name
end

-- ScanOrder
local function ScanOrder(p)
	local s = ActiveScan[p.name]
	if (s) then
		if (s.notequipped) then
			return 1
		elseif (s.equipped) then
			if (s.changed) then
				return 2
			else
				return 3
			end
		elseif (s.notinzone) then
			return 4
		elseif (s.offline) then
			return 5
		end
	end
	return 0
end

-- SortPlayersByDur
local function SortPlayersByDur(p1, p2)
	if (p1.dur) then
		local o1, o2 = 0,0
		if (not p1.connected or p1.noCTRA) then o1 = 1000 end
		if (not p2.connected or p2.noCTRA) then o2 = 1000 end
		return p1.dur + o1 < p2.dur + o2
	else
		if (ActiveScan) then
			return ScanOrder(p1)..p1.class..p1.name < ScanOrder(p2)..p2.class..p2.name
		else
			return SortPlayersByCount(p1, p2)
		end
	end
end

-- SortPlayersByResist
local function SortPlayersByResist(p1, p2)
	local o1, o2 = 0,0
	if (not p1.connected or p1.noCTRA) then o1 = 1000 end
	if (not p2.connected or p2.noCTRA) then o2 = 1000 end
	return p1[FPerlRaidAdminDB.ResistSort] - o1 > p2[FPerlRaidAdminDB.ResistSort] - o2
end

-- FPerl.RaidAdmin.CheckMakePlayerList
function FPerl.RaidAdmin.CheckMakePlayerList()

	FauxScrollFrame_SetOffset(FPerl_CheckListPlayersScrollBar, 0)

	local function ShowResists(show)
		local r = {"FR", "FRR", "NR", "SR", "AR"}
		for k,v in pairs(r) do
			local title = _G["FPerl_CheckListPlayersTitle"..v]
			local total = _G["FPerl_CheckListPlayersTotals"..v]
			if (show) then
				title:Show()
				total:Show()
			else
				title:Hide()
				total:Hide()
			end
		end
	end

	local function ShowCount(show)
		if (show) then
			FPerl_CheckListPlayersTitleCount:Show()
			FPerl_CheckListPlayersTotalsCount:Show()
		else
			FPerl_CheckListPlayersTitleCount:Hide()
			FPerl_CheckListPlayersTotalsCount:Hide()
		end
	end

	local function ShowDur(show)
		if (show) then
			FPerl_CheckListPlayersTitleDur:Show()
			FPerl_CheckListPlayersTotalsNR:Show()
		else
			FPerl_CheckListPlayersTitleDur:Hide()
			FPerl_CheckListPlayersTotalsNR:Hide()
		end
	end

	PlayerList = {}

	local results, resType = GetSelectedItem()
	if (results and results.last) then
		FPerl_CheckListPlayersTitleClass:Show()
		FPerl_CheckListPlayersTitleName:Show()
		FPerl_CheckListPlayersTotalsName:Show()

		if (resType == "item" or resType == "reg") then
			FPerl_CheckListPlayersTotalsName:SetText(FPERL_CHECK_TOTALS)
			FPerl_CheckListPlayersTitleCount:SetText("#")

			ShowCount(true)
			ShowResists(false)
			ShowDur(ActiveScan)

			if (ActiveScan) then
				FPerl_CheckListPlayersTitleDur:SetText(FPERL_CHECK_EQUIPED)
			end

		elseif (resType == "dur") then
			FPerl_CheckListPlayersTotalsName:SetText(FPERL_CHECK_AVERAGE)

			ShowResists(false)
			ShowCount(true)
			ShowDur(true)

			FPerl_CheckListPlayersTitleCount:SetText(FPERL_CHECK_BROKEN)
			FPerl_CheckListPlayersTitleDur:SetText("%")

		elseif (resType == "res") then
			FPerl_CheckListPlayersTotalsName:SetText(FPERL_CHECK_AVERAGE)

			ShowCount(false)
			ShowDur(false)
			ShowResists(true)
		end

		for i = 1, GetNumGroupMembers() do
			local name = UnitName("raid"..i)
			local _, class = UnitClass("raid"..i)
			local count = 0
			local noCTRA

			if (FPerlRoster) then
				local stats = FPerlRoster[name]
				if (stats) then
					if (not stats.version) then
						noCTRA = true
					end
				end
			end

			if (resType == "item") then
				for k,v in ipairs(results) do
					if (v.name == name) then	-- type(v) == "table" and
						count = v.count
						if (count > 0) then
							noCTRA = nil
						end
						break
					end
				end

				tinsert(PlayerList, {["name"] = name, unit = "raid"..i, ["count"] = count, ["class"] = class, connected = (UnitIsConnected("raid"..i) == 1), ["noCTRA"] = noCTRA})

			elseif (resType == "reg") then
				if (reagentClasses[class] or results[name]) then
					local p = results[name]
					local reg = 0
					if (p) then
						reg = p.count
						if (reg > 0) then
							noCTRA = nil
						end
					end

					tinsert(PlayerList, {["name"] = name, unit = "raid"..i, ["count"] = reg, ["class"] = class, connected = (UnitIsConnected("raid"..i) == 1), ["noCTRA"] = noCTRA})
				end

			elseif (resType == "res") then
				local p = results[name]
				local fr, frr, nr, sr, ar = 0, 0, 0, 0, 0
				if (p) then
					fr, frr, nr, sr, ar = p.fr, p.frr, p.nr, p.sr, p.ar
					if (fr + frr + nr + sr + ar > 0) then
						noCTRA = nil
					end
				end

				tinsert(PlayerList, {["name"] = name, unit = "raid"..i, ["fr"] = fr, ["frr"] = frr, ["nr"] = nr, ["sr"] = sr, ["ar"] = ar, ["class"] = class, connected = (UnitIsConnected("raid"..i) == 1), ["noCTRA"] = noCTRA})

			elseif (resType == "dur") then
				local p = results[name]
				local dur, broken = 0, 0
				if (p) then
					dur, broken = p.dur, p.broken
					if (dur + broken > 0) then
						noCTRA = nil
					end
				end

				tinsert(PlayerList, {["name"] = name, unit = "raid"..i, ["dur"] = dur, ["broken"] = broken, ["class"] = class, connected = (UnitIsConnected("raid"..i) == 1), ["noCTRA"] = noCTRA})
			end
		end

		if (resType == "item" or resType == "reg") then
			sort(PlayerList, SortPlayersByCount)
		elseif (resType == "dur") then
			sort(PlayerList, SortPlayersByDur)
		elseif (resType == "res") then
			sort(PlayerList, SortPlayersByResist)
		end
	else
		FPerl_CheckListPlayersTitleClass:Hide()
		FPerl_CheckListPlayersTitleName:Hide()
		FPerl_CheckListPlayersTotalsName:Hide()
		ShowCount(false)
		ShowDur(false)
		ShowResists(false)
	end

	FPerl.RaidAdmin.CheckUpdatePlayerList()
end

-- FPerl.RaidAdmin.CheckUpdatePlayerList
function FPerl.RaidAdmin.CheckUpdatePlayerList()
	local onlineCount, tFR, tFRR, tNR, tSR, tAR, tDur, tBroken, tCount = 0, 0, 0, 0, 0, 0, 0, 0, 0

	local results, resType = GetSelectedItem()
	local index = 1

	for i = 1,#PlayerList do
		--    + FPerl_CheckListPlayersScrollBar.offset, PLAYERLISTSIZE + FPerl_CheckListPlayersScrollBar.offset do
		local v = PlayerList[i]
		if (not v) then
			break
		end

		if (v.fr) then
			tFR = tFR + v.fr
			tFRR = tFRR + v.frr
			tNR = tNR + v.nr
			tSR = tSR + v.sr
			tAR = tAR + v.ar
		elseif (v.dur) then
			tDur = tDur + v.dur
			tBroken = tBroken + v.broken
		else
			if (v.count > 0) then
				tCount = tCount + v.count
			end
		end

		if (v.connected) then
			onlineCount = onlineCount + 1
		end

		if (i >= FPerl_CheckListPlayersScrollBar.offset + 1 and index <= PLAYERLISTSIZE) then
			local frame = _G["FPerl_CheckListPlayers"..index]
			local iconFrame = _G["FPerl_CheckListPlayers"..index.."Icon"]
			local nameFrame = _G["FPerl_CheckListPlayers"..index.."Name"]
			local countFrame = _G["FPerl_CheckListPlayers"..index.."Count"]
			local resFrameFR = _G["FPerl_CheckListPlayers"..index.."FR"]
			local resFrameFRR = _G["FPerl_CheckListPlayers"..index.."FRR"]
			local resFrameNR = _G["FPerl_CheckListPlayers"..index.."NR"]
			local resFrameSR = _G["FPerl_CheckListPlayers"..index.."SR"]
			local resFrameAR = _G["FPerl_CheckListPlayers"..index.."AR"]
			local resFrameEquiped = _G["FPerl_CheckListPlayers"..index.."Equiped"]

			if (v.name == SelectedPlayer) then
				frame:LockHighlight()
			else
				frame:UnlockHighlight()
			end

			nameFrame:SetText(v.name)
			local color = FPerl.GetClassColour(v.class)
			nameFrame:SetTextColor(color.r, color.g, color.b)

			if (v.class) then
				local r, l, t, b = FPerl.ClassPos(v.class)
				iconFrame:SetTexCoord(r, l, t, b)
				iconFrame:Show()
			else
				iconFrame:Hide()
			end

			_G["FPerl_CheckListPlayers"..index]:Show()

			local function ShowScanIcon()
				if (ActiveScan) then
					local z = ActiveScan[v.name]
					if (z) then
						resFrameEquiped:Show()
						if (z.equipped) then
							if (z.changed) then
								resFrameEquiped:SetTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
							else
								resFrameEquiped:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
							end
							resFrameEquiped:SetTexCoord(0, 1, 0, 1)
						elseif (z.offline) then
							resFrameEquiped:SetTexture("Interface\\CharacterFrame\\Disconnect-Icon")
							resFrameEquiped:SetTexCoord(0.2, 0.8, 0.2, 0.8)
						elseif (z.notequipped) then
							resFrameEquiped:SetTexture("Interface\\AddOns\\FPerl_RaidAdmin\\Images\\FPerl_Check")
							if (z.changed) then
								resFrameEquiped:SetTexCoord(0.75, 0.875, 0.25, 0.5)
							else
								resFrameEquiped:SetTexCoord(0.625, 0.75, 0.25, 0.5)
							end
						elseif (z.notinzone) then
							resFrameEquiped:SetTexture("Interface\\GossipFrame\\TaxiGossipIcon")
							resFrameEquiped:SetTexCoord(0, 1, 0, 1)
						else
							resFrameEquiped:Hide()
						end
					else
						resFrameEquiped:Hide()
					end
				else
					resFrameEquiped:Hide()
				end
			end

			if (not v.connected or v.noCTRA) then
				if (not v.connected) then
					countFrame:SetText(FPERL_LOC_OFFLINE)
				end
				countFrame:SetTextColor(0.5, 0.5, 0.5)
				countFrame:Show()

				ShowScanIcon()

				resFrameFR:Hide()
				resFrameFRR:Hide()
				resFrameNR:Hide()
				resFrameSR:Hide()
				resFrameAR:Hide()
			else
				if (v.fr) then
					if (v.fr == -1) then
						countFrame:SetText("Blocked")
						countFrame:SetTextColor(0.5, 0.5, 0.5)
						countFrame:Show()

						resFrameFR:Hide()
						resFrameFRR:Hide()
						resFrameNR:Hide()
						resFrameSR:Hide()
						resFrameAR:Hide()
						resFrameEquiped:Hide()
					else
						resFrameFR:SetText(v.fr)
						resFrameFRR:SetText(v.frr)
						resFrameNR:SetText(v.nr)
						resFrameNR:SetTextColor(0, 1, 0)
						resFrameSR:SetText(v.sr)
						resFrameAR:SetText(v.ar)

						resFrameFR:Show()
						resFrameFRR:Show()
						resFrameNR:Show()
						resFrameSR:Show()
						resFrameAR:Show()
						countFrame:Hide()
						resFrameEquiped:Hide()
					end

				elseif (v.dur) then
					resFrameNR:SetText(v.dur)
					countFrame:SetText(v.broken)

					local r, g, b = SmoothColour(v.dur)
					resFrameNR:SetTextColor(r, g, b)

					countFrame:Show()
					resFrameNR:Show()

					if (v.broken > 0) then
						countFrame:SetTextColor(1, 0, 0)
					else
						countFrame:SetTextColor(0, 1, 0)
					end

					resFrameFR:Hide()
					resFrameFRR:Hide()
					resFrameSR:Hide()
					resFrameAR:Hide()
					resFrameEquiped:Hide()
				else
					if (v.count == -1) then
						countFrame:SetText("Blocked")
						countFrame:SetTextColor(0.5, 0.5, 0.5)
					else
						countFrame:SetText(v.count)
						if (v.count == 0) then
							countFrame:SetTextColor(1, 0, 0)
						else
							countFrame:SetTextColor(0, 1, 0)
						end
					end

					countFrame:Show()

					ShowScanIcon()

					resFrameFR:Hide()
					resFrameFRR:Hide()
					resFrameNR:Hide()
					resFrameSR:Hide()
					resFrameAR:Hide()
				end
			end

			index = index + 1
		end
	end

	for i = index,PLAYERLISTSIZE do
		_G["FPerl_CheckListPlayers"..i]:Hide()
	end

	if (resType == "dur") then
		FPerl_CheckListPlayersTotalsNR:SetText(floor(tDur / onlineCount))
		FPerl_CheckListPlayersTotalsNR:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		FPerl_CheckListPlayersTotalsCount:SetText(tBroken)

		local r, g, b = SmoothColour((tDur / onlineCount) / 100)
		FPerl_CheckListPlayersTotalsNR:SetTextColor(r, g, b)

		if (tBroken > 0) then
			FPerl_CheckListPlayersTotalsCount:SetTextColor(1, 0, 0)
		else
			FPerl_CheckListPlayersTotalsCount:SetTextColor(0, 1, 0)
		end

	elseif (resType == "res") then
		FPerl_CheckListPlayersTotalsFR:SetText(floor(tFR / onlineCount))
		FPerl_CheckListPlayersTotalsNR:SetText(floor(tNR / onlineCount))
		FPerl_CheckListPlayersTotalsNR:SetTextColor(0, 1, 0)
		FPerl_CheckListPlayersTotalsFRR:SetText(floor(tFRR / onlineCount))
		FPerl_CheckListPlayersTotalsSR:SetText(floor(tSR / onlineCount))
		FPerl_CheckListPlayersTotalsAR:SetText(floor(tAR / onlineCount))
	else
		FPerl_CheckListPlayersTotalsCount:SetText(tCount)

		if (tCount == 0) then
			FPerl_CheckListPlayersTotalsNR:SetTextColor(1, 0, 0)
		else
			FPerl_CheckListPlayersTotalsNR:SetTextColor(0, 1, 0)
		end
	end

	if (FauxScrollFrame_Update(FPerl_CheckListPlayersScrollBar, #PlayerList, PLAYERLISTSIZE, 1)) then
		FPerl_CheckListPlayersScrollBar:Show()
	else
		FPerl_CheckListPlayersScrollBar:Hide()
	end
end

-- FPerl.RaidAdmin.CheckShowInfo
function FPerl.RaidAdmin.CheckShowInfo()
	if (ActiveScanTotals) then
		if (ActiveScanTotals.missing > 0) then
			FPerl_CheckButtonInfo:SetFormattedText(FPERL_CHECK_SCAN_MISSING, ActiveScanTotals.missing)
		else
			FPerl_CheckButtonInfo:SetText("")
		end
	else
		local results = GetSelectedItem()

		local t
		if (results and results.last and results.last > 0) then
			t = SecondsToTime(GetTime() - results.last)
		else
			t = ""
		end
		if (t ~= "") then
			FPerl_CheckButtonInfo:SetFormattedText(FPERL_CHECK_LASTINFO, t)
		else
			FPerl_CheckButtonInfo:SetText("")
		end
	end
end

-- FPerl.RaidAdmin.CheckOnEnter
function FPerl.RaidAdmin.CheckOnEnter(self)
	local f, anc
	if ((self.GetFrameType or self.GetObjectType)(self) == "CheckButton") then
		f = _G[self:GetParent():GetName().."Name"]
		anc = self:GetParent()
	else
		f = _G[self:GetName().."Name"]
		anc = self
	end
	if (f) then
		local link = f:GetText()
		if (link and strsub(link, 1, 1) == "|") then
			-- Have to strip excess information for the SetHyperlink call
			local itemId = strmatch(link, "item:(%d+):")
			if (itemId) then
				local newLink = format("item:%d:0:0:0", itemId)

				GameTooltip:SetOwner(anc, "ANCHOR_LEFT")
				GameTooltip:SetHyperlink(newLink)
				return
			end
		end
	end

	GameTooltip:SetOwner(FPerl_CheckListItems1, "ANCHOR_LEFT")
	GameTooltip:SetText(FPERL_CHECK_DROPITEMTIP1, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	GameTooltip:AddLine(FPERL_CHECK_DROPITEMTIP2, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1)
	GameTooltip:Show()
end

-- FPerl_Check_OnClickStart
function FPerl.RaidAdmin.CheckOnClickTick(self)
	local id = self:GetParent():GetID() + FPerl_CheckListItemsScrollBar.offset
	if (FPerlRaidAdminItems[id]) then
		FPerlRaidAdminItems[id].ticked = self:GetChecked()
	end
	FPerl.RaidAdmin.CheckValidateButtons()
end

-- FPerl.RaidAdmin.CheckDeleteSelectedItems
function FPerl.RaidAdmin.CheckDeleteSelectedItems()
	local newList = {}

	for k, v in ipairs(FPerlRaidAdminItems) do
		if (v.fixed or not v.ticked) then
			tinsert(newList, v)
		else
			local linkName = GetVLinkName(v)
			if (linkName) then
				ItemResults[linkName] = nil
			end
		end
	end

	FPerlRaidAdminItems = newList

	FPerl.RaidAdmin.CheckItemsChanged()
end

-- FPerl.RaidAdmin.CheckQuery
function FPerl.RaidAdmin.CheckQuery()
	local oldResults = ItemResults
	ItemResults = {["type"] = "item"}

	FPerl_CheckListItemsScrollBarScrollBar:SetValue(0)

	tinsert(MsgQueue, "DURC")
	tinsert(MsgQueue, "RSTC")
	tinsert(MsgQueue, "REAC")
	ResistResults.count = 0
	DurResults.count = 0
	RegResults.count = 0

	local msg
	for k, v in ipairs(FPerlRaidAdminItems) do
		if (v.ticked) then
			v.query = true
			v.ticked = nil

			if (not v.fixed) then
				local linkName = GetVLinkName(v)

				if (linkName) then
					ItemResults[linkName] = {last = 0}
					oldResults[linkName] = nil
					tinsert(MsgQueue, "ITMC "..linkName)
				end
			end
		else
			v.query = nil
		end
	end

	for k, v in pairs(oldResults) do
		if (type(v) == "table") then
			if (not v.fixed) then
				ItemResults[k] = v
			end
		end
	end

	FPerl_Check.queryStart = GetTime()
	FPerl_Check.lastMsgsent = nil
	FPerl_Check:SetScript("OnUpdate", CheckOnUpdate)

	FPerl.RaidAdmin.CheckItemsChanged()		-- Re-sort and re-show list with ticked items at top
	FPerl.RaidAdmin.CheckValidateButtons()
end

-- GetActiveScanItem
local function GetActiveScanItem()
	local item = GetSelectedItemLink()
	local itemId
	if (item and strsub(item, 1, 1) == "|") then
		itemId = strmatch(item, "item:(%d+):")
		if (not itemId) then
			return
		end
	else
		return
	end

	local itemName, itemString, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemId)

	if (not itemEquipLoc or not itemType) then
		return
	end

	if (not (itemType == "Armor" or itemType == "Weapon")) then
		return
	end

	local slots = {	INVTYPE_HEAD = 1,
			INVTYPE_NECK = 2,
			INVTYPE_SHOULDER = 3,
			INVTYPE_BODY = 4,
			INVTYPE_CHEST = 5,
			INVTYPE_ROBE = 5,
			INVTYPE_WAIST = 6,
			INVTYPE_LEGS = 7,
			INVTYPE_FEET = 8,
			INVTYPE_WRIST = 9,
			INVTYPE_HAND = 10,
			INVTYPE_FINGER = {11, 12},
			INVTYPE_TRINKET = {13, 14},
			INVTYPE_CLOAK = 15,
			INVTYPE_2HWEAPON = 16,
			INVTYPE_WEAPONMAINHAND = 16,
			INVTYPE_WEAPON = {16, 17},
			INVTYPE_WEAPONOFFHAND = 17,
			INVTYPE_HOLDABLE = 17,
			INVTYPE_SHIELD = 17,
			INVTYPE_RANGED = 18,
			INVTYPE_RELIC = 18,
			INVTYPE_TABARD = 19}

	local slot = slots[itemEquipLoc]
	if (slot) then
		return tonumber(itemId), slot
	end
end

-- GetSelectedPlayer
local function GetSelectedPlayer()
	if (SelectedPlayer) then
		for k,v in pairs(PlayerList) do
			if (v.name == SelectedPlayer) then
				return v
			end
		end
	end
end

-- FPerl.RaidAdmin.CheckValidateButtons
function FPerl.RaidAdmin.CheckValidateButtons()
	local fixedSelected, regSelected
	local anyTicked
	for k,v in ipairs(FPerlRaidAdminItems) do
		if (v.selected) then
			if (v.fixed) then
				fixedSelected = true
			end
			if (v.link == "reg") then
				regSelected = true
			end
		end
		if (not v.fixed and v.ticked) then
			anyTicked = true
		end
	end

	local results, resType = GetSelectedItem()

	if (anyTicked and not FPerl_Check.queryStart) then
		FPerl_CheckButtonDelete:Enable()
	else
		FPerl_CheckButtonDelete:Disable()
	end

	if (not FPerl_Check.queryStart and UnitIsGroupAssistant("player")) then
		FPerl_CheckButtonQuery:Enable()
	else
		FPerl_CheckButtonQuery:Disable()
	end

	if (((results and results.last) or ActiveScan) and IsInRaid()) then
		FPerl_CheckButtonReport:Enable()
	else
		FPerl_CheckButtonReport:Disable()
	end

	if (results and results.last and not (fixedSelected and not regSelected) and IsInRaid()) then
		FPerl_CheckButtonReportWith:Enable()
		FPerl_CheckButtonReportWithout:Enable()
	else
		FPerl_CheckButtonReportWith:Disable()
		FPerl_CheckButtonReportWithout:Disable()
	end

	if (ActiveScanItem) then
		local tex = FPerl_CheckButtonEquiped:GetNormalTexture()
		tex:SetTexCoord(0.75, 0.875, 0.5, 0.75)
		tex = FPerl_CheckButtonEquiped:GetPushedTexture()
		tex:SetTexCoord(0.875, 1, 0.5, 0.75)

				FPerl_CheckButtonEquiped.tooltipText = "FPERL_CHECK_SCANSTOP_DESC"
	else
		local tex = FPerl_CheckButtonEquiped:GetNormalTexture()
		tex:SetTexCoord(0.375, 0.5, 0.5, 0.75)
		tex = FPerl_CheckButtonEquiped:GetPushedTexture()
		tex:SetTexCoord(0.5, 0.625, 0.5, 0.75)

				FPerl_CheckButtonEquiped.tooltipText = "FPERL_CHECK_SCAN_DESC"
	end

	local myPlayer = GetSelectedPlayer()
	if (((results and results.last) or (ActiveScan and ActiveScan[SelectedPlayer])) and myPlayer and myPlayer.connected) then
		FPerl_CheckButtonPlayer:Enable()
	else
		FPerl_CheckButtonPlayer:Disable()
	end

	FPerl_CheckButtonEquiped:Hide()
	FPerl_CheckButtonEquiped:Show()

	if (results and not fixedSelected and GetActiveScanItem()) then
		FPerl_CheckButtonEquiped:Enable()
	else
		FPerl_CheckButtonEquiped:Disable()
	end
end

-- FPerl.RaidAdmin.CheckPlayersSort
function FPerl.RaidAdmin.CheckPlayersSort(sortType)
	if (sortType == "class") then
		sort(PlayerList, SortPlayersByClass)
	elseif (sortType == "name") then
		sort(PlayerList, SortPlayersByName)
	elseif (sortType == "count") then
		sort(PlayerList, SortPlayersByCount)
	elseif (sortType == "dur") then
		sort(PlayerList, SortPlayersByDur)
	elseif (strfind("frrsrnrar", sortType)) then
		FPerlRaidAdminDB.ResistSort = sortType
		sort(PlayerList, SortPlayersByResist)
	end

	FPerl.RaidAdmin.CheckUpdatePlayerList()
end

-- FPerl.RaidAdmin.CheckReport
function FPerl.RaidAdmin.CheckReport(showNames)
	local function ReportOutput(msg)
		if (msg) then
			SendChatMessage("<F-Perl> "..msg, outputChannel, nil, outputChannelIndex)
		end
	end

	local link = GetSelectedItemLink()
	local msg
	if (link) then
		local myPlayer = GetSelectedPlayer()

		if (link == "res") then
			if (ResistResults.last) then
				if (showNames == "player") then
					if (SelectedPlayer) then
						if (myPlayer.connected) then
							msg = format(FPERL_CHECK_REPORT_PRESISTS, SelectedPlayer, myPlayer.fr, myPlayer.nr, myPlayer.frr, myPlayer.sr, myPlayer.ar)
						end
					end
				else
					local fr, frr, nr, sr, ar, count = 0, 0, 0, 0, 0, 0

					for k,v in ipairs(PlayerList) do
						if (v.connected) then
							count = count + 1

							fr = fr + v.fr
							frr = frr + v.frr
							nr = nr + v.nr
							sr = sr + v.sr
							ar = ar + v.ar
						end
					end

					fr = fr / count
					frr = frr / count
					nr = nr / count
					sr = sr / count
					ar = ar / count

					msg = format(FPERL_CHECK_REPORT_RESISTS, fr, nr, frr, sr, ar)
				end
				ReportOutput(msg)
			end

		elseif (link == "dur") then
			if (DurResults.last) then
				if (showNames == "player") then
					if (SelectedPlayer) then
						if (myPlayer.connected) then
							msg = format(FPERL_CHECK_REPORT_PDURABILITY, SelectedPlayer, myPlayer.dur, myPlayer.broken)
						end
					end
				else
					local dur, broken, brokenPeople, count = 0, 0, 0, 0

					for k,v in ipairs(PlayerList) do
						if (v.connected) then
							count = count + 1
							dur = dur + v.dur

							if (v.broken > 0) then
								brokenPeople = brokenPeople + 1
								broken = broken + v.broken
							end
						end
					end

					dur = dur / count

					msg = format(FPERL_CHECK_REPORT_DURABILITY, dur, brokenPeople, broken)
				end
				ReportOutput(msg)
			end
		else
			if (showNames == "player") then
				if (SelectedPlayer) then
					if (myPlayer.connected) then
						if (link == "reg") then
							if (RegResults.last) then
								msg = format(FPERL_CHECK_REPORT_PITEM, SelectedPlayer, myPlayer.count, FPERL_REAGENTS[myPlayer.class])
							end
						else
							if (ActiveScan and ActiveScan[SelectedPlayer]) then
								if (ActiveScan[SelectedPlayer].equipped) then
									msg = format(FPERL_CHECK_REPORT_PEQUIPED, SelectedPlayer, link)
								elseif (ActiveScan[SelectedPlayer].notequipped) then
									msg = format(FPERL_CHECK_REPORT_PNOTEQUIPED, SelectedPlayer, link)
								end
							else
								msg = format(FPERL_CHECK_REPORT_PITEM, SelectedPlayer, myPlayer.count, link)
							end
						end
						ReportOutput(msg)
					end
				end
			else
				local equipable = ""
				if (strsub(link, 1, 1) == "|") then
					local itemId = strmatch(link, "item:(%d+):")
					local itemName, itemString, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemId)
					if (itemEquipLoc and itemType) then
						if (itemType == "Armor" or itemType == "Weapon") then
							equipable = "_EQ"
						end
					end
				end

				local with = {}
				local without = {}
				local offline = {}
				local totalItems = 0

				for k, v in ipairs(PlayerList) do
					if (ActiveScanTotals and ActiveScanTotals.missing == 0) then
						local scan = ActiveScan[v.name]
						if (scan.equipped) then
							tinsert(with, v)
						elseif (scan.notequipped) then
							tinsert(without, v)
						elseif (scan.offline) then
							tinsert(offline, v)
						end
					else
						if (v.connected) then
							if (v.count > 0) then
								tinsert(with, v)
								totalItems = totalItems + v.count
							elseif (not v.noCTRA) then
								tinsert(without, v)
							end
						else
							tinsert(offline, v)
						end
					end
				end

				if (ActiveScanTotals and ActiveScanTotals.missing == 0 and ActiveScanTotals.wrongZone == 0 and ActiveScanTotals.notequipped == 0) then
					if (ActiveScanTotals.offline == 0) then
						ReportOutput(format(FPERL_CHECK_REPORT_ALLEQUIPED, link))
					else
						ReportOutput(format(FPERL_CHECK_REPORT_ALLEQUIPEDOFF, link, ActiveScanTotals.offline))
					end
				else
					if (showNames) then
						if (link == "reg") then
							local c
							link, c = string.gsub(SPELL_REAGENTS, ": ", "")
							if (not link or c ~= 1) then
								link = "Reagents"
							end
						end

						local showList
						local showTitle
						if (showNames == "with") then
							if (ActiveScanTotals and ActiveScanTotals.missing == 0) then
								showTitle = link..FPERL_CHECK_REPORT_EQUIPED
							else
								showTitle = link.._G["FPERL_CHECK_REPORT_WITH"..equipable]
							end
							if (#with > 0) then
								showList = with
							end
						elseif (showNames == "without") then
							if (ActiveScanTotals and ActiveScanTotals.missing == 0) then
								showTitle = link..FPERL_CHECK_REPORT_NOTEQUIPED
							else
								showTitle = link.._G["FPERL_CHECK_REPORT_WITHOUT"..equipable]
							end
							if (#without > 0) then
								showList = without
							end
						end

						if (showList) then
							msg = showTitle
							local msgLocal = showTitle
							local first = true

							for k,v in ipairs(showList) do
								local name = FPerl.ColourTable[v.class]..v.name.."|r"

								if (strlen(msg) + strlen(name) > 240) then
									ReportOutput(msg.."...")
									DEFAULT_CHAT_FRAME:AddMessage("<F-Perl> "..msgLocal)
									msg = "  ... "..v.name
									msgLocal = "  ... "..name
								else
									if (first) then
										msg = msg..v.name
										msgLocal = msgLocal..name
										first = nil
									else
										msg = msg..", "..v.name
										msgLocal = msgLocal..", "..name
									end
								end
							end

							if (msg) then
								ReportOutput(msg)
							end
							if (msgLocal) then
								DEFAULT_CHAT_FRAME:AddMessage("<F-Perl> "..msgLocal)
							end
						elseif (showTitle) then
							DEFAULT_CHAT_FRAME:AddMessage("<F-Perl> "..showTitle..NONE)
						end
					else
						msg = link.." "

						local function Out(txt, num)
							if (num > 0) then
								msg = msg..format(txt, num)
							end
						end

						if (ActiveScanTotals) then	-- and ActiveScanTotals.missing == 0) then
							Out(FPERL_CHECK_REPORT_EQUIPEDSHORT, ActiveScanTotals.equipped)
							Out(FPERL_CHECK_REPORT_NOTEQUIPEDSHORT, ActiveScanTotals.notequipped)
							Out(FPERL_CHECK_REPORT_OFFLINE, ActiveScanTotals.offline)
							Out(FPERL_CHECK_REPORT_NOTSCANNED, ActiveScanTotals.missing + ActiveScanTotals.wrongZone)
						else
							Out(FPERL_CHECK_REPORT_WITHSHORT, #with)
							Out(FPERL_CHECK_REPORT_WITHOUTSHORT, #without)
							Out(" : %d "..FPERL_LOC_OFFLINE, #offline)
						end

						if (link ~= "reg") then
							Out(FPERL_CHECK_REPORT_TOTAL, totalItems)
						end

						ReportOutput(msg)
					end
				end
			end
		end
	end
end

-- FPerl.RaidAdmin.CheckPlayerOnClick
function FPerl.RaidAdmin.CheckPlayerOnClick(button)
	local index = button:GetID() + FPerl_CheckListPlayersScrollBar.offset

	if (index < 1 or index > #PlayerList) then
		return
	end

	if (SelectedPlayer == PlayerList[index].name) then
		SelectedPlayer = nil
	else
		SelectedPlayer = PlayerList[index].name
	end

	FPerl.RaidAdmin.CheckUpdatePlayerList()

	SetPortraitTexture(FPerl_CheckButtonPlayerPortrait, PlayerList[index].unit)

	FPerl.RaidAdmin.CheckValidateButtons()
end

-- FPerl.RaidAdmin.CheckStopActiveScan
function FPerl.RaidAdmin.CheckStopActiveScan()
	FPerl_Check:UnregisterEvent("UNIT_INVENTORY_CHANGED")
	FPerl_Check:UnregisterEvent("UNIT_MODEL_CHANGED")
	ActiveScanItem = nil
end

-- FPerl.RaidAdmin.CheckStartActiveScan
function FPerl.RaidAdmin.CheckStartActiveScan()
	if (ActiveScanItem) then
		FPerl.RaidAdmin.CheckStopActiveScan()
	else
		local itemId, itemSlot = GetActiveScanItem()
		if (itemId) then
			ActiveScan = {}

			ActiveScanItem = {id = itemId, slot = itemSlot, missing = GetNumGroupMembers()}
			ActiveScanTotals = {missing = 0, equipped = 0, notequipped = 0, offline = 0, wrongZone = 0}

			FPerl_Check:SetScript("OnUpdate", CheckOnUpdate)
			FPerl_Check:RegisterEvent("UNIT_INVENTORY_CHANGED")
			FPerl_Check:RegisterEvent("UNIT_MODEL_CHANGED")

			FPerl_CheckListPlayersTitleDur:SetText(FPERL_CHECK_EQUIPED)
			FPerl_CheckListPlayersTitleDur:Show()
		end
	end

	FPerl.RaidAdmin.CheckValidateButtons()
end

-- FPerl.RaidAdmin.CheckActiveScan
function FPerl.RaidAdmin.CheckActiveScan()
	local function CheckSlot(unit, slot)
		local link = GetInventoryItemLink(unit, slot)
		local eq
		local name = UnitName(unit)

		if (link) then
			local itemId = strmatch(link, "item:(%d+):")
			if (itemId) then
				itemId = tonumber(itemId)

				if (itemId == ActiveScanItem.id) then
					if (not ActiveScan[name]) then
						ActiveScan[name] = {}
					end

					ActiveScan[name].notequipped = nil
					ActiveScan[name].equipped = 1
					return true
				end
			end
		end

		if (not ActiveScan[name]) then
			ActiveScan[name] = {}
		end
		ActiveScan[name].equipped = nil
		ActiveScan[name].notequipped = 1
	end

	local myZone = GetRealZoneText()

	local any
	local update
	ActiveScanTotals = {missing = 0, equipped = 0, notequipped = 0, offline = 0, wrongZone = 0}

	for i = 1, GetNumGroupMembers() do
		local name, _, _, _, _, _, zone = GetRaidRosterInfo(i)
		local unit = "raid"..i
		local new
		local myScan = ActiveScan[name]

		if (not myScan or myScan.changed) then
			if (myScan) then
				myScan.changed = nil
			end
			any = true
			if (not InCombatLockdown() and CheckInteractDistance(unit, 1)) then		-- Checks to see if in inspect range
				local eq
				if (type(ActiveScanItem.slot) == "table") then
					for k,v in pairs(ActiveScanItem.slot) do
						if (CheckSlot(unit, v)) then
							eq = true
							break
						end
					end
				else
					eq = CheckSlot(unit, ActiveScanItem.slot)
				end

				if (eq) then
					ActiveScanTotals.equipped = ActiveScanTotals.equipped + 1
				else
					ActiveScanTotals.notequipped = ActiveScanTotals.notequipped + 1
				end
				update = true

			elseif (not UnitIsConnected(unit)) then
				if (not ActiveScan[name]) then
					ActiveScan[name] = {}
				end

				ActiveScan[name].offline = 1
				ActiveScanTotals.offline = ActiveScanTotals.offline + 1
				update = true

			elseif (zone ~= myZone) then
				if (not ActiveScan[name]) then
					ActiveScan[name] = {}
				end

				ActiveScan[name].notinzone = 1
				ActiveScanTotals.wrongZone = ActiveScanTotals.wrongZone + 1
				update = true

			else
				ActiveScanTotals.missing = ActiveScanTotals.missing + 1
			end
		else
			ActiveScanTotals.missing	= ActiveScanTotals.missing	+ (myScan.missing	or 0)
			ActiveScanTotals.equipped	= ActiveScanTotals.equipped	+ (myScan.equipped	or 0)
			ActiveScanTotals.notequipped	= ActiveScanTotals.notequipped	+ (myScan.notequipped	or 0)
			ActiveScanTotals.offline	= ActiveScanTotals.offline	+ (myScan.offline	or 0)
			ActiveScanTotals.wrongZone	= ActiveScanTotals.wrongZone	+ (myScan.notinzone	or 0)
		end
	end

	FPerl.RaidAdmin.CheckShowInfo()

	if (update) then
		sort(PlayerList, SortPlayersByDur)		-- It's actually by equipped, that's sorted out in sort func
		FPerl.RaidAdmin.CheckUpdatePlayerList()
		FPerl.RaidAdmin.CheckValidateButtons()
	end
end

-- FPerl.RaidAdmin.GetChannelList
if (not FPerl.RaidAdmin.GetChannelList) then
local function GetChatColour(name)
	local info = ChatTypeInfo[name]
	local clr = {r = 0.5, g = 0.5, b = 0.5}
	if (info) then
		clr.r = (info.r or 0.5)
		clr.g = (info.g or 0.5)
		clr.b = (info.b or 0.5)
	end
	return clr
end
function FPerl.RaidAdmin.GetChannelList()
	local cList = {}
	local l = {"RAID", "OFFICER", "GUILD", "PARTY", "SAY"}
	for k,v in pairs(l) do
		tinsert(cList, {display = _G["CHAT_MSG_"..v], channel = v, colour = GetChatColour(v)})
	end

	for i = 1, 10 do
		local c, name = GetChannelName(i)
		if (name and c ~= 0) then
			tinsert(cList, {display = name, channel = "CHANNEL", index = c, colour = GetChatColour("CHANNEL"..c)})
		end
	end

	return cList
end
end

-- FPerl.RaidAdmin.CheckChannelsOnLoad
function FPerl.RaidAdmin.CheckChannelsOnLoad(self)
	if (not outputChannelSelection) then
		outputChannelSelection = 1
	end

	local dropdown = MSA_DropDownMenu_Create(self:GetName().."_DropDown", self)
	dropdown:SetAllPoints(self)
	MSA_DropDownMenu_Initialize(dropdown, FPerl.RaidAdmin.CheckChannelsInitialize)
	MSA_DropDownMenu_SetWidth(dropdown, 100)
	MSA_DropDownMenu_SetSelectedID(dropdown, outputChannelSelection)
	_G[dropdown:GetName().."Text"]:SetTextColor(unpack(outputChannelColour))
end

-- ChannelOnClick
local function ChannelOnClick(self)
	local v = self.value
	outputChannel = v.channel
	outputChannelIndex = v.index
	outputChannelSelection = self:GetID()
	MSA_DropDownMenu_SetSelectedID(FPerl_CheckButtonChannel, outputChannelSelection)

	FPerl_CheckButtonChannelText:SetTextColor(v.red, v.green, v.blue)
end

-- FPerl.RaidAdmin.CheckChannelsInitialize
function FPerl.RaidAdmin.CheckChannelsInitialize()
	channelList = FPerl.RaidAdmin.GetChannelList()

	for i,entry in pairs(channelList) do
		local r, g, b = entry.colour.r, entry.colour.g, entry.colour.b
		if (entry.channel == outputChannel) then
			if (outputChannel ~= "CHANNEL" or entry.index == outputChannelIndex) then
				outputChannelSelection = i
				outputChannelColour = {r, g, b}
			end
		end

		local info = MSA_DropDownMenu_CreateInfo()
		info.text = entry.display
		info.func = ChannelOnClick
		info.value = {channel = entry.channel, index = entry.index, red = r, green = g, blue = b}
		info.colorCode = format("|cFF%02X%02X%02X", r * 255, g * 255, b * 255)
		MSA_DropDownMenu_AddButton(info)
	end
end
