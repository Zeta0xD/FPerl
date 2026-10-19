-- F-Perl arrange mode: a small toolbar shown exactly while the frames are unlocked (out of combat).

local bar = CreateFrame("Frame", "FPerl_ArrangeBar", UIParent)
bar:SetSize(280, 52)
bar:SetPoint("TOP", UIParent, "TOP", 0, -40) -- first show only; a drag re-anchors it, kept for the session
bar:SetFrameStrata("DIALOG")
bar:SetClampedToScreen(true)
bar:SetMovable(true)
bar:EnableMouse(true)
bar:RegisterForDrag("LeftButton")
bar:SetScript("OnDragStart", bar.StartMoving)
bar:SetScript("OnDragStop", bar.StopMovingOrSizing)
bar:Hide()

local bg = bar:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0, 0, 0, 0.8)

local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
title:SetPoint("TOPLEFT", 6, -4)
title:SetText("F-Perl")

local function snapText()
	return FPerl.layout and FPerl.layout.alignmentSnapToGrid and "Snap: on" or "Snap: off"
end

local function gridText()
	return FPerl.layout and FPerl.layout.alignmentGrid and "Grid: on" or "Grid: off"
end

local function button(key, label, x, onClick)
	local b = CreateFrame("Button", "FPerl_ArrangeBar_" .. key, bar, "UIPanelButtonTemplate")
	b:SetSize(64, 24)
	b:SetPoint("BOTTOMLEFT", x, 6)
	b:SetText(label)
	b:SetScript("OnClick", onClick)
	return b
end

button("Done", "Done", 6, function()
	if InCombatLockdown() then
		FPerl.Notice("Not available in combat.")
		return
	end
	FPerl.LockFrames()
end)
local grid = button("Grid", gridText(), 74, function(self)
	FPerl.AlignmentGridToggle()
	self:SetText(gridText())
end)
local snap = button("Snap", snapText(), 142, function(self)
	FPerl.layout.alignmentSnapToGrid = not FPerl.layout.alignmentSnapToGrid
	self:SetText(snapText())
end)
button("Settings", "Settings", 210, function() FPerl.OpenSettings() end)

-- Called by FPerl.UnlockFrames, FPerl.LockFrames and the combat events.
function FPerl.ArrangeBarUpdate()
	if FPerl.Locked == 0 and not InCombatLockdown() then
		grid:SetText(gridText())
		snap:SetText(snapText())
		bar:Show()
	else
		bar:Hide()
	end
	FPerl.FrameMenuUpdate()
end

-- Closes the settings window, unlocks the frames and shows the toolbar.
function FPerl.ArrangeMode()
	if InCombatLockdown() then
		FPerl.Notice("Not available in combat.")
		return
	end
	if SettingsPanel and SettingsPanel:IsShown() then
		HideUIPanel(SettingsPanel)
	end
	FPerl.UnlockFrames()
end

FPerl.On("PLAYER_REGEN_DISABLED", function() bar:Hide() end)
FPerl.On("PLAYER_REGEN_ENABLED", FPerl.ArrangeBarUpdate)
