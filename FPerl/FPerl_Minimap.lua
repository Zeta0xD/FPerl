-- Author: Resike
-- License: GNU GPL v3, 18 October 2014

-- The minimap button, its menu and its tooltip.

local conf

FPerl.RequestConfig(function(New)
	conf = New
end)

local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local UIParent = UIParent

-- FPerl.MinimapButtonOnClick
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

-- FPerl.MinimapEntries: {text, shown(), func} per extra menu line, added by the raid tools; a line is listed
-- while shown() is true.
FPerl.MinimapEntries = {}

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

	for _, entry in ipairs(FPerl.MinimapEntries) do
		if (entry.shown()) then
			info = MSA_DropDownMenu_CreateInfo()
			info.notCheckable = 1
			info.text = entry.text
			info.func = entry.func
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

-- FPerl.MinimapButtonInit
function FPerl.MinimapButtonInit(self)
	FPerl.MinimapButtonUpdatePosition(self)

	if (conf.minimap.enable) then
		self:Show()
	else
		self:Hide()
	end

	FPerl.MinimapButtonInit = nil
end

-- FPerl.MinimapButtonUpdatePosition
-- Free dragging (FPerl.xml OnDragStart/OnDragStop), not a radius/angle circle:
-- Forever's minimap does not match that circle.
function FPerl.MinimapButtonUpdatePosition(self)
	FPerl.PlaceFrame(self)
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
	tt:Show()
end
