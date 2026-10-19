-- Author: Resike
-- License: GNU GPL v3, 18 October 2014

-- The minimap button, its menu and its tooltip.

local conf

FPerl.RequestConfig(function(New)
	conf = New
end, "$Revision: 1 $")

local collectgarbage = collectgarbage
local format = format
local max = max
local min = min
local pairs = pairs
local CreateFrame = CreateFrame
local GetAddOnCPUUsage = GetAddOnCPUUsage
local GetAddOnMemoryUsage = GetAddOnMemoryUsage
local IsAltKeyDown = IsAltKeyDown
local IsShiftKeyDown = IsShiftKeyDown
local UpdateAddOnCPUUsage = UpdateAddOnCPUUsage
local UpdateAddOnMemoryUsage = UpdateAddOnMemoryUsage
local GameTooltip = GameTooltip
local UIParent = UIParent

-- Minimap Icon
function FPerl.MinimapButtonOnClick(self, button)
	GameTooltip:Hide()
	if (button == "LeftButton") then
		FPerl.OpenSettings()
	elseif (button == "RightButton") then
		FPerl.MinimapMenu(self)
	end
end

-- FPerl.MinimapMenuOnLoad
function FPerl.MinimapMenuOnLoad(self)
	local dropdown = MSA_DropDownMenu_Create(self:GetName().."_DropDown", self)
	dropdown.displayMode = "MENU"
	dropdown:SetAllPoints(self)
	MSA_DropDownMenu_Initialize(dropdown, FPerl.MinimapMenuInitialize)
end

-- FPerl.MinimapMenuInitialize
function FPerl.MinimapMenuInitialize(self, level)
	local info

	if (level == 2) then
		return
	end

	info = MSA_DropDownMenu_CreateInfo()
	info.isTitle = 1
	info.text = FPerl.ProductName
	MSA_DropDownMenu_AddButton(info)

	info = MSA_DropDownMenu_CreateInfo()
	info.notCheckable = 1
	info.func = FPerl.OpenSettings
	info.text = FPERL_MINIMENU_OPTIONS
	MSA_DropDownMenu_AddButton(info)

	if (C_AddOns.IsAddOnLoaded("FPerl_RaidHelper")) then
		if (FPerl_Assists_Frame and not FPerl_Assists_Frame:IsShown()) then
			info = MSA_DropDownMenu_CreateInfo()
			info.notCheckable = 1
			info.text = FPERL_MINIMENU_ASSIST
			info.func = function()
					FPerlRaidHelperDB.AssistsFrame = 1
					FPerlRaidHelperDB.TargettingFrame = 1
					FPerl.RaidHelper.SetFrameSides()
				end
			MSA_DropDownMenu_AddButton(info)
		end
	end

	if (C_AddOns.IsAddOnLoaded("FPerl_RaidMonitor")) then
		if (FPerl_RaidMonitor_Frame and not FPerl_RaidMonitor_Frame:IsShown()) then
			info = MSA_DropDownMenu_CreateInfo()
			info.notCheckable = 1
			info.text = FPERL_MINIMENU_CASTMON
			info.func = function()
				FPerlRaidMonitorDB.enabled = 1
				FPerl_RaidMonitor_Frame:SetFrameSizes()
			end
			MSA_DropDownMenu_AddButton(info)
		end
	end

	if (C_AddOns.IsAddOnLoaded("FPerl_RaidAdmin")) then
		if (FPerl_AdminFrame and not FPerl_AdminFrame:IsShown()) then
			info = MSA_DropDownMenu_CreateInfo()
			info.notCheckable = 1
			info.text = FPERL_MINIMENU_RAIDAD
			info.func = function() FPerl_AdminFrame:Show() end
			MSA_DropDownMenu_AddButton(info)
		end

		if (FPerl_Check and not FPerl_Check:IsShown()) then
			info = MSA_DropDownMenu_CreateInfo()
			info.notCheckable = 1
			info.text = FPERL_MINIMENU_ITEMCHK
			info.func = function() FPerl_Check:Show() end
			MSA_DropDownMenu_AddButton(info)
		end

		if (FPerl_RosterText and not FPerl_RosterText:IsShown()) then
			info = MSA_DropDownMenu_CreateInfo()
			info.notCheckable = 1
			info.text = FPERL_MINIMENU_ROSTERTEXT
			info.func = function() FPerl_RosterText:Show() end
			MSA_DropDownMenu_AddButton(info)
		end
	end
end

-- FPerl.MinimapMenu
function FPerl.MinimapMenu(self)
	if (not FPerl_Minimap) then
		CreateFrame("Frame", "FPerl_Minimap", nil, BackdropTemplateMixin and "BackdropTemplate")
		FPerl.MinimapMenuOnLoad(FPerl_Minimap)
	end

	MSA_ToggleDropDownMenu(1, nil, FPerl_Minimap_DropDown, "cursor", 0, 0)
end

local xpModList = {"FPerl", "FPerl_RaidHelper", "FPerl_RaidAdmin", "FPerl_RaidMonitor"}
local xpStartupMemory = {}

-- FPerl.MinimapButtonInit
function FPerl.MinimapButtonInit(self)
	--self.time = 0
	collectgarbage()
	UpdateAddOnMemoryUsage()
	for k, v in pairs(xpModList) do
		local usedKB = GetAddOnMemoryUsage(v)
		if ((usedKB or 0) > 0) then
			xpStartupMemory[v] = usedKB
		end
	end

	FPerl.MinimapButtonUpdatePosition(self)

	if (conf.minimap.enable) then
		self:Show()
	else
		self:Hide()
	end

	--self.UpdateTooltip = FPerl.MinimapButtonOnEnter

	FPerl.MinimapButtonInit = nil
end

-- FPerl.MinimapButtonUpdatePosition
-- Free dragging (FPerl.xml OnDragStart/OnDragStop) replaced the old radius/angle
-- circle, which was sized for Era's minimap and misaligned on Forever.
function FPerl.MinimapButtonUpdatePosition(self)
	FPerl.PlaceFrame(self)
end

-- DiffColour(diff, val)
local function DiffColour(val)
	local r, g, b, offset
	offset = max(0, min(0.5, 0.5 * min(1, val)))
	if (val < 0) then
		r = 0.5 + offset
		g = 0.5 - offset
		b = r
	else
		r = 0.5 + offset
		g = 0.5 - offset
		b = g
	end
	return format("|c00%02X%02X%02X", 255 * r, 255 * g, 255 * b)
end

-- FPerl.MinimapButtonOnEnter
function FPerl.MinimapButtonOnEnter(self)
	if (self.dragging) then
		return
	end

	GameTooltip:SetOwner(self or UIParent, "ANCHOR_LEFT")
	FPerl.MinimapButtonDetails(GameTooltip)
end

-- FPerl.MinimapButtonDetails
function FPerl.MinimapButtonDetails(tt, ldb)
	tt:SetText("F-Perl", 1, 1, 1)
	tt:AddLine(FPERL_MINIMAP_HELP1)
	if (not ldb) then
		tt:AddLine(FPERL_MINIMAP_HELP2)
	end
	if UpdateAddOnMemoryUsage then
		if (IsAltKeyDown()) then
			tt:AddLine(FPERL_MINIMAP_HELP6)
		elseif (not IsShiftKeyDown()) then
			tt:AddLine(FPERL_MINIMAP_HELP5)
		end
	end
	if UpdateAddOnMemoryUsage and IsAltKeyDown() then
		local showDiff = IsShiftKeyDown()

		local allAddonsCPU = 0
		for i = 1, C_AddOns.GetNumAddOns() do
			allAddonsCPU = allAddonsCPU + GetAddOnCPUUsage(i)
		end

		-- Show X-Perl memory usage
		UpdateAddOnMemoryUsage()
		UpdateAddOnCPUUsage()
		local totalKB, totalCPU, diffKB, diff = 0, 0, 0
		local cpuText = ""
		for k, v in pairs(xpModList) do
			local usedKB = GetAddOnMemoryUsage(v)
			local usedCPU = GetAddOnCPUUsage(v)
			if ((usedKB or 0) > 0) then
				totalKB = totalKB + usedKB
				totalCPU = totalCPU + usedCPU

				if (allAddonsCPU > 0) then
					cpuText = format(" |c008080FF%.2f%%|r", 100 * (usedCPU / allAddonsCPU))
				end

				if (showDiff) then
					diff = usedKB - xpStartupMemory[v]
					diffKB = diffKB + diff
					tt:AddDoubleLine(format(" %s", v), format("%.1fkB (%s%.1fkB|r)%s", usedKB, DiffColour(diff / 1000), diff, cpuText), 1, 1, 0.5, 1, 1, 1)
				else
					tt:AddDoubleLine(format(" %s", v), format("%.1fkB%s", usedKB, cpuText), 1, 1, 0.5, 1, 1, 1)
				end
			end
		end

		if (showDiff) then
			local color = DiffColour(diffKB / 3000)

			tt:AddDoubleLine("Total", format("%.1fkB (%s%.1fkB|r)", totalKB, color, diffKB), 1, 1, 1, 1, 1, 1)
		else
			tt:AddDoubleLine("Total", format("%.1fkB", totalKB), 1, 1, 1, 1, 1, 1)
		end

		if (totalCPU > 0) then
			tt:AddDoubleLine(" F-Perl CPU Usage Comparison", format("%.2f%%", 100 * (totalCPU / allAddonsCPU)), 0.5, 0.5, 1, 0.5, 0.5, 1)
		end
	end

	tt:Show()
	--tt.updateTooltip = 1
end
