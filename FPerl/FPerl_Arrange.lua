-- F-Perl arrange mode: a small toolbar shown exactly while the frames are unlocked (out of combat), and the preview that shows
-- the player in the empty target and focus frames.

local bar = CreateFrame("Frame", "FPerl_ArrangeBar", UIParent)
bar:SetSize(364, 52)
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

local function labelsText()
	return FPerl.layout and FPerl.layout.arrangeLabels and "Labels: on" or "Labels: off"
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
	if (InCombatLockdown()) then
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
local labels = button("Labels", labelsText(), 210, function(self)
	FPerl.layout.arrangeLabels = not FPerl.layout.arrangeLabels
	self:SetText(labelsText())
	FPerl.ArrangeLabelsUpdate()
end)
labels:SetWidth(80)
button("Settings", "Settings", 294, function() FPerl.OpenSettings() end)

-- the General > Frames Labels row applies through this; FPerl_Positions.lua loads first, so FPerl.ArrangeLabelsUpdate exists
FPerl.RegisterOptionChanger(function() FPerl.ArrangeLabelsUpdate() end, nil, "arrangelabels")

-- Called by FPerl.UnlockFrames, FPerl.LockFrames and at combat end.
function FPerl.ArrangeBarUpdate()
	if (FPerl.Locked == 0 and not InCombatLockdown()) then
		grid:SetText(gridText())
		snap:SetText(snapText())
		labels:SetText(labelsText())
		bar:Show()
	else
		bar:Hide()
	end
	FPerl.FrameMenuUpdate()
end

-- Closes the options window, unlocks the frames and shows the toolbar.
function FPerl.ArrangeMode()
	if (InCombatLockdown()) then
		FPerl.Notice("Not available in combat.")
		return
	end
	if (_G.FPerl_OptionsWindow) then _G.FPerl_OptionsWindow:Hide() end
	FPerl.UnlockFrames()
end

FPerl.On("PLAYER_REGEN_DISABLED", function() bar:Hide() end)
FPerl.On("PLAYER_REGEN_ENABLED", FPerl.ArrangeBarUpdate)

-- Unlocked, the frames that are empty without a unit show the player, so they can be arranged.
-- Only the non-secure side switches (partyid, parentid, the unit events); the secure `unit`
-- attribute stays, so a click does what it always does.
local previewFrames = {"FPerl_Target", "FPerl_TargetTarget", "FPerl_TargetTargetTarget", "FPerl_Focus", "FPerl_FocusTarget", "FPerl_PetTarget"}

local function redraw(f)
	if (f.parentid) then
		FPerl.TargetTarget.UpdateDisplay(f)
	else
		FPerl.Target.UpdateDisplay(f)
	end
end

local function watch(f)
	if (f.conf and f.conf.enable) then
		RegisterUnitWatch(f)
	end
end

-- FPerl.UnlockPreview(on): the real units come back at once; the unit watch waits for the end of combat.
function FPerl.UnlockPreview(on)
	for _, name in ipairs(previewFrames) do
		local f = _G[name]
		if (f and on and not f.previewReal and not f.off and f.conf and f.conf.enable and not InCombatLockdown()) then
			f.previewReal = {f.partyid, f.parentid}
			f.partyid = "player"
			if (f.parentid) then f.parentid = "player" end
			if (not f.parentid) then FPerl.UnitFrameSetUnit(f, "player") end
			UnregisterUnitWatch(f)
			f:Show()
			redraw(f)
		elseif (f and not on and f.previewReal) then
			f.partyid, f.parentid = f.previewReal[1], f.previewReal[2]
			f.previewReal = nil
			if (not f.parentid) then FPerl.UnitFrameSetUnit(f, f.partyid) end
			FPerl.AfterCombatFor(watch, f)
			-- a secret result counts as true
			local exists = UnitExists(f.partyid)
			if (FPerl.IsSecret(exists) or exists) then redraw(f) end
		end
	end
end

FPerl.On("PLAYER_REGEN_DISABLED", function() FPerl.UnlockPreview(false) end)
