-- Frame positions. The active layout's `positions` (FPerl.layout.positions, FPerl.SavePosition) is the only store and
-- FPerl.DefaultPoints (below) the only default; the client's layout cache is not used
-- (SetDontSavePosition), so a frame is where FPerl.PlaceFrame puts it.

-- FPerl.FramePointUI(frame)
-- The frame's top-left times its own scale, and that scale. GetLeft/GetTop and SetPoint offsets are
-- in the frame's own units; these are UIParent units for a frame parented to UIParent. A frame
-- under another parent (the minimap button, the pet target) keeps the units of its saved entries
-- from before they were scaled by the parent. nil if unanchored.
function FPerl.FramePointUI(frame)
	local left, top = frame:GetLeft(), frame:GetTop()
	if (not left or not top) then
		return
	end
	local ratio = frame:GetScale()
	return left * ratio, top * ratio, ratio
end

-- FPerl.SetPointUI(frame, left, top)
-- Anchor the frame's top-left at a point in FPerl.FramePointUI's units (its inverse).
function FPerl.SetPointUI(frame, left, top)
	local ratio = frame:GetScale()
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / ratio, top / ratio)
end

-- FPerl.SetScale(frame, scale)
-- SetScale that keeps the frame's anchor points where they are on screen. SetPoint offsets are in the
-- frame's own units, so a bare SetScale moves the frame toward or away from what it is anchored to.
-- A root frame's position is saved too: its default offsets would place it elsewhere at the new scale.
function FPerl.SetScale(frame, scale)
	local old = frame:GetScale()
	if (math.abs(old - scale) < 1e-6) then
		return
	end
	local points = {}
	for i = 1, frame:GetNumPoints() do
		points[i] = {frame:GetPoint(i)}
	end
	frame:SetScale(scale)
	if (#points == 0) then
		return
	end
	local k = old / scale
	frame:ClearAllPoints()
	for _, p in ipairs(points) do
		frame:SetPoint(p[1], p[2], p[3], (p[4] or 0) * k, (p[5] or 0) * k)
	end
	local name = frame:GetName()
	if (name and FPerl.DefaultPoints[name]) then
		-- not snapped: a slider step would move the frame to the grid
		FPerl.AlignmentGridHold(true)
		FPerl.SavePosition(frame)
		FPerl.AlignmentGridHold(false)
		FPerl.PlaceFrame(frame) -- the same spot, anchored as a load anchors it
	end
end

-- FPerl.AfterPlace[name](frame, pos): run in place of the saved size when a frame of that name gets its saved
-- position; an addon that keeps a frame's size elsewhere sets it.
FPerl.AfterPlace = {}

-- FPerl.PlaceFrame(frame)
-- The saved position, else the default point; sizes of a resizable frame come with the saved one.
-- A protected frame is queued in combat (the unit frames are secure); others are placed at once.
function FPerl.PlaceFrame(frame)
	if (InCombatLockdown() and frame:IsProtected()) then
		FPerl.AfterCombatFor(FPerl.PlaceFrame, frame)
		return
	end
	frame:SetDontSavePosition(true)

	local name = frame:GetName()
	local saved = FPerl.GetSavePositionTable()
	local pos = saved and saved[name]
	if (pos and pos.left and pos.top) then
		FPerl.SetPointUI(frame, pos.left, pos.top)
		if (FPerl.AfterPlace[name]) then
			FPerl.AfterPlace[name](frame, pos)
		elseif (pos.height and pos.width) then
			if (frame:IsResizable()) then
				frame:SetHeight(pos.height)
				frame:SetWidth(pos.width)
			else
				pos.height, pos.width = nil, nil
			end
		end
	elseif (FPerl.DefaultPoints[name]) then
		frame:ClearAllPoints()
		for _, p in ipairs(FPerl.DefaultPoints[name]) do
			frame:SetPoint(unpack(p))
		end
	end
end

-- FPerl.PlaceNewFrames
-- Every default frame that exists and has no anchor yet: each F-Perl addon's ADDON_LOADED. Frames
-- created in Lua place themselves.
function FPerl.PlaceNewFrames()
	for name in pairs(FPerl.DefaultPoints) do
		local frame = _G[name]
		if (frame and frame:GetNumPoints() == 0) then
			FPerl.PlaceFrame(frame)
		end
	end
end

-- Alignment grid and Snap to grid. FPerl.layout.alignmentGrid and FPerl.layout.alignmentSnapToGrid are written by the
-- General > Frames rows. The grid is drawn while it is on and the frames are unlocked or the settings panel is
-- open, and never in combat; Snap runs inside FPerl.SavePosition, which every drag handler ends with.
local GRID_SIZE = 20
local gridFrame
local gridLines = {}
local snapBusy = false

local function gridDB()
	FPerl.layout.alignmentGrid = FPerl.layout.alignmentGrid or false
	FPerl.layout.alignmentSnapToGrid = FPerl.layout.alignmentSnapToGrid or false
	return FPerl.layout
end

function FPerl.AlignmentGridIsShown()
	return gridFrame ~= nil and gridFrame:IsShown()
end

function FPerl.AlignmentGridHide()
	if (gridFrame) then
		gridFrame:Hide()
	end
end

-- One physical pixel in UIParent units; UIParent spans the screen.
local function pixelSize()
	local _, physHeight = GetPhysicalScreenSize()
	return (physHeight and physHeight > 0) and UIParent:GetHeight() / physHeight or 1
end

-- A grid line at v is drawn as the pixel v falls in, from that pixel's low edge, and that edge is its coordinate for snap:
-- a 1-px line with edges between pixels can round to 0 px and not draw.
local function lineAt(v)
	local px = pixelSize()
	return math.floor(v / px + 1e-6) * px
end

local function gridShow()
	if (not gridFrame) then
		gridFrame = CreateFrame("Frame", nil, UIParent)
		gridFrame:SetAllPoints(UIParent)
		gridFrame:SetFrameStrata("LOW")
		gridFrame:EnableMouse(false)
	end
	local width, height = UIParent:GetWidth(), UIParent:GetHeight()
	if (not width or not height) then return end
	local thick = pixelSize()

	-- Textures cannot be destroyed: reuse the lines from earlier shows, create only the shortfall.
	local used = 0
	local function nextLine(major)
		used = used + 1
		local line = gridLines[used]
		if (not line) then
			line = gridFrame:CreateTexture(nil, "BACKGROUND")
			gridLines[used] = line
		end
		line:ClearAllPoints()
		line:SetColorTexture(0.25, 0.75, 1, major and 0.28 or 0.12)
		line:Show()
		return line
	end
	-- k counts from the center line, every 5th is major
	for k = -math.floor(width / 2 / GRID_SIZE), math.floor(width / 2 / GRID_SIZE) do
		local line = nextLine(k % 5 == 0)
		local x = lineAt(width / 2 + k * GRID_SIZE)
		line:SetWidth(thick)
		line:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", x, 0)
		line:SetPoint("BOTTOMLEFT", gridFrame, "BOTTOMLEFT", x, 0)
	end
	for k = -math.floor(height / 2 / GRID_SIZE), math.floor(height / 2 / GRID_SIZE) do
		local line = nextLine(k % 5 == 0)
		local y = lineAt(height / 2 + k * GRID_SIZE)
		line:SetHeight(thick)
		line:SetPoint("BOTTOMLEFT", gridFrame, "BOTTOMLEFT", 0, y)
		line:SetPoint("BOTTOMRIGHT", gridFrame, "BOTTOMRIGHT", 0, y)
	end
	for i = used + 1, #gridLines do
		gridLines[i]:Hide()
	end
	gridFrame:Show()
end

-- Shows or hides the grid for the current state.
function FPerl.AlignmentGridUpdate()
	local editing = FPerl.Locked == 0 or (_G.FPerl_OptionsWindow and _G.FPerl_OptionsWindow:IsShown())
	if (gridDB().alignmentGrid and editing and not InCombatLockdown()) then
		gridShow()
	else
		FPerl.AlignmentGridHide()
	end
end

-- The General > Frames button.
function FPerl.AlignmentGridToggle()
	local db = gridDB()
	db.alignmentGrid = not db.alignmentGrid
	FPerl.AlignmentGridUpdate()
end

-- The frame's visible extent in UIParent units, as offsets from its top-left: {left, right, top, bottom}, left and bottom
-- at most 0, right and top at least 0 (up is positive). It is the union of the rects of the frame and its shown descendant
-- frames and of their visible regions: a texture, or a font string with text, of size above 0 and effective alpha above 0.
-- The saved position stays the frame's top-left. A secret alpha or text counts as shown; a secret size cannot be measured
-- and is left out.
local function extentOf(frame)
	local l, t = FPerl.FramePointUI(frame)
	local uiScale = UIParent:GetEffectiveScale()
	if (not l or not uiScale) then return end
	local minL, minB, maxR, maxT
	local function known(v)
		return v ~= nil and not FPerl.IsSecret(v)
	end
	local function alphaOf(o)
		local a = o:GetAlpha()
		return known(a) and a or 1
	end
	local function add(k, left, bottom, width, height)
		if (not known(left) or not known(bottom) or not known(width) or not known(height)) then return end
		left, bottom, width, height = left * k, bottom * k, width * k, height * k
		minL = minL and math.min(minL, left) or left
		minB = minB and math.min(minB, bottom) or bottom
		maxR = maxR and math.max(maxR, left + width) or left + width
		maxT = maxT and math.max(maxT, bottom + height) or bottom + height
	end
	-- a secret flag counts as set
	local function flag(v)
		return FPerl.IsSecret(v) or v
	end
	local function region(k, r, alpha)
		local w, h = r:GetWidth(), r:GetHeight()
		local text = r.GetText and r:GetText()
		if (flag(r:IsVisible()) and alphaOf(r) * alpha > 0 and known(w) and w > 0 and known(h) and h > 0
			and (r:GetObjectType() == "Texture" or FPerl.IsSecret(text) or (text ~= nil and text ~= ""))) then
			add(k, r:GetRect())
		end
	end
	-- Each frame and region is measured under pcall: the client can return secrets from any getter (GetAlpha and IsShown
	-- do), and one that cannot be read leaves out only its piece.
	local walk
	local function child(c, alpha)
		if (flag(c:IsShown())) then walk(c, alpha) end
	end
	walk = function(f, alpha)
		alpha = alpha * alphaOf(f)
		local k = f:GetEffectiveScale() / uiScale
		add(k, f:GetRect())
		if (alpha > 0) then
			for _, r in ipairs({f:GetRegions()}) do
				pcall(region, k, r, alpha)
			end
		end
		for _, c in ipairs({f:GetChildren()}) do
			pcall(child, c, alpha)
		end
	end
	if (not pcall(walk, frame, 1)) then return end
	if (not minL) then return end
	return {minL - l, maxR - l, maxT - t, minB - t}
end

-- Where a drop would put the frame: the top-left, then the vertical and horizontal grid line its nearer extent edges snap to.
-- nil when Snap does not apply. The drop and the drag indicator both use it; ext (extentOf) is computed when not given.
local function snapTarget(frame, ext)
	-- the tip promises a snap to the visible grid: a save while it is hidden stays where it is
	if (not gridDB().alignmentSnapToGrid or InCombatLockdown() or not FPerl.AlignmentGridIsShown()) then return end
	local name = frame.GetName and frame:GetName()
	if (name == "FPerl_MinimapButton_Frame") then return end
	-- The grid is in UIParent units, centered on UIParent's center (gridShow). Per axis the nearer edge snaps; a tie snaps left/top.
	local l, t = FPerl.FramePointUI(frame)
	local cx, cy = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
	ext = ext or extentOf(frame)
	if (not l or not cx or not ext) then return end
	local function offset(p, c)
		return p - lineAt(c + math.floor((p - c) / GRID_SIZE + 0.5) * GRID_SIZE)
	end
	local edgeX, edgeY = l + ext[1], t + ext[3]
	local dx, dy = offset(edgeX, cx), offset(edgeY, cy)
	if (math.abs(offset(l + ext[2], cx)) < math.abs(dx) - 0.01) then
		edgeX = l + ext[2]
		dx = offset(edgeX, cx)
	end
	if (math.abs(offset(t + ext[4], cy)) < math.abs(dy) - 0.01) then
		edgeY = t + ext[4]
		dy = offset(edgeY, cy)
	end
	return l - dx, t - dy, edgeX - dx, edgeY - dy
end

local function snapFrame(frame)
	local x, y = snapTarget(frame)
	if (not x) then return false end
	return pcall(FPerl.SetPointUI, frame, x, y)
end

-- FPerl.AlignmentGridHold(on): saves while held are not snapped (layouts F-Perl computes itself, e.g. the raid Gap).
function FPerl.AlignmentGridHold(on)
	snapBusy = on and true or false
end

-- Called by FPerl.SavePosition: snap the frame, then save where it landed (the re-entry guard stops the second save snapping again).
function FPerl.AlignmentGridSnapSaved(frame)
	if (snapBusy or not frame) then return end
	snapBusy = true
	-- a failed save must not leave snapBusy set: no later drop would snap
	local ok, err = pcall(function()
		if (snapFrame(frame)) then
			FPerl.SavePosition(frame)
		end
	end)
	snapBusy = false
	FPerl.ArrangeLabelsTick()
	if (not ok) then
		error(err, 0)
	end
end

-- Drag box: a rectangle over the dragged frame's visible extent, the rect snapFrame snaps. Its fill is translucent so art
-- shows through, and its strata puts it on top. The minimap button never snaps and gets none.
local dragBox
local hookedDrag = {}

-- A fill over the whole box and a one-pixel-wide border, in the given {r, g, b, a} colors.
local function boxBorder(box, fillColor, edgeColor)
	local fill = box:CreateTexture(nil, "OVERLAY")
	fill:SetAllPoints()
	fill:SetColorTexture(unpack(fillColor))
	local function edge(p1, p2, horizontal)
		local e = box:CreateTexture(nil, "OVERLAY")
		e:SetColorTexture(unpack(edgeColor))
		e:SetPoint(p1)
		e:SetPoint(p2)
		if (horizontal) then e:SetHeight(1) else e:SetWidth(1) end
	end
	edge("TOPLEFT", "TOPRIGHT", true)
	edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
	edge("TOPLEFT", "BOTTOMLEFT")
	edge("TOPRIGHT", "BOTTOMRIGHT")
end

local function dragBoxHide()
	if (dragBox) then
		dragBox:Hide()
	end
end

-- While Snap applies, two highlight lines mark the grid lines the drop will land on.
local function dragBoxTick(self)
	-- no extent, no snap: the drop does not snap either
	local lineX, lineY
	if (self.ext) then
		_, _, lineX, lineY = snapTarget(self.frame, self.ext)
	end
	if (not lineX) then
		self.vLine:Hide()
		self.hLine:Hide()
		return
	end
	local thick = 2 * pixelSize()
	self.vLine:SetWidth(thick)
	self.vLine:ClearAllPoints()
	self.vLine:SetPoint("TOP", UIParent, "TOPLEFT", lineX, 0)
	self.vLine:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", lineX, 0)
	self.vLine:Show()
	self.hLine:SetHeight(thick)
	self.hLine:ClearAllPoints()
	self.hLine:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 0, lineY)
	self.hLine:SetPoint("RIGHT", UIParent, "BOTTOMRIGHT", 0, lineY)
	self.hLine:Show()
end

local function dragBoxShow(frame)
	if (not dragBox) then
		dragBox = CreateFrame("Frame", nil, UIParent)
		dragBox:SetFrameStrata("FULLSCREEN_DIALOG")
		dragBox:EnableMouse(false)
		boxBorder(dragBox, {1, 0.5, 0, 0.25}, {1, 0.5, 0, 1})
		dragBox.vLine = dragBox:CreateTexture(nil, "OVERLAY")
		dragBox.vLine:SetColorTexture(1, 0.5, 0, 1)
		dragBox.hLine = dragBox:CreateTexture(nil, "OVERLAY")
		dragBox.hLine:SetColorTexture(1, 0.5, 0, 1)
	end
	dragBox.frame = frame
	dragBox.vLine:Hide()
	dragBox.hLine:Hide()
	dragBox:SetScript("OnUpdate", dragBoxTick)
	-- the extent is fixed for the drag: the box follows the frame's top-left
	local ext = extentOf(frame)
	dragBox.ext = ext
	if (not ext) then
		-- the frame's own size, in UIParent units
		local k = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
		ext = {0, frame:GetWidth() * k, 0, -frame:GetHeight() * k}
	end
	dragBox:ClearAllPoints()
	dragBox:SetPoint("TOPLEFT", frame, "TOPLEFT", ext[1], ext[3])
	dragBox:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", ext[2], ext[4])
	dragBox:Show()
end

-- Hooked at unlock: some frames (raid titles) are made after this file loads. The moving calls are hooked, not the
-- scripts: the box then shows only when the frame moves, whichever child starts the drag.
local function hookDragBoxes()
	for name in pairs(FPerl.DefaultPoints) do
		local frame = _G[name]
		if (frame and name ~= "FPerl_MinimapButton_Frame" and not hookedDrag[frame] and frame.StartMoving) then
			hookedDrag[frame] = true
			hooksecurefunc(frame, "StartMoving", dragBoxShow)
			hooksecurefunc(frame, "StopMovingOrSizing", dragBoxHide)
		end
	end
end

-- Labels: while unlocked, out of combat and FPerl.layout.arrangeLabels is on, every shown movable frame named FPerl* gets
-- a box over its visible extent and its name, so small frames can be found. Found by walking UIParent's shown frames, not
-- from FPerl.DefaultPoints. Boxes anchor to the frame's top-left and follow a drag; extents are recomputed on toggle, unlock
-- and after each save.
local labelBoxes = {}
local labelDragging -- the frame a label box is moving
local LABELS = {
	AdminFrameAnchor = "Raid admin", AggroAnchor = "Aggro warning", Assists_FrameAnchor = "Assists",
	CheckAnchor = "Raid check", MTList_Anchor = "Main tank list", MinimapButton_Frame = "Minimap button",
	Party_Anchor = "Party", Player_Pet = "Pet", RaidMonitor_Anchor = "Raid monitor", Raid_TitlePets = "Raid pets",
	RosterTextAnchor = "Roster text", TargetTarget = "Target of target", TargetTargetTarget = "Target of target of target",
}

local function labelText(name)
	local short = (name:gsub("^FPerl_", ""))
	local n = short:match("^Raid_Title(%d+)$")
	if (n) then return "Raid group " .. n end
	return LABELS[short] or (short:gsub("(%l)(%u)", "%1 %2"):gsub("_", " "))
end

local function labelBox(name)
	local box = labelBoxes[name]
	if (box) then return box end
	box = CreateFrame("Frame", "FPerl_ArrangeLabel_" .. name, UIParent)
	box:SetFrameStrata("FULLSCREEN")
	box:EnableMouse(false)
	boxBorder(box, {1, 1, 1, 0.15}, {1, 1, 1, 0.8})
	box.text = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	box.text:SetTextColor(1, 1, 1)
	box.text:SetJustifyH("LEFT")
	box.text:SetText(labelText(name))
	-- the box of a frame with no drag of its own is its drag handle (mouse set in labelFrame)
	box:RegisterForDrag("LeftButton")
	box:SetScript("OnDragStart", function(self)
		local frame = self.target
		if (frame and not InCombatLockdown()) then
			hookDragBoxes() -- the drag box shows for this frame too
			labelDragging = frame
			frame:StartMoving()
		end
	end)
	box:SetScript("OnDragStop", function(self)
		local frame = labelDragging
		labelDragging = nil
		if (frame) then
			frame:StopMovingOrSizing()
			FPerl.SavePosition(frame)
		end
	end)
	labelBoxes[name] = box
	return box
end

-- True when the frame or a shown descendant takes the mouse or has an OnDragStart: a handle box over it would block
-- those. Flags are read under pcall; a secret or unreadable value counts as set.
local function takesMouse(f)
	local okD, drag = pcall(f.GetScript, f, "OnDragStart")
	local okM, mouse = pcall(f.IsMouseEnabled, f)
	if (not okD or not okM or drag or FPerl.IsSecret(mouse) or mouse) then return true end
	for _, c in ipairs({f:GetChildren()}) do
		local okS, shown = pcall(c.IsShown, c)
		if ((not okS or FPerl.IsSecret(shown) or shown) and takesMouse(c)) then return true end
	end
end

-- Shows a box on the frame, or hides it when the frame has no extent. A box shorter than a line of text puts the text above it.
local function labelFrame(frame, name)
	local ext = extentOf(frame)
	local box = labelBox(name)
	if (not ext) then
		box:EnableMouse(false)
		box:Hide()
		return
	end
	box.target = frame
	box:EnableMouse(not takesMouse(frame))
	box:ClearAllPoints()
	box:SetPoint("TOPLEFT", frame, "TOPLEFT", ext[1], ext[3])
	box:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", ext[2], ext[4])
	box.text:ClearAllPoints()
	if (ext[3] - ext[4] < 16) then
		box.text:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 0, 2)
	else
		box.text:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
	end
	box:Show()
end

local function labelsHide()
	-- a drag in progress ends here: a hidden handle gets no OnDragStop
	local frame = labelDragging
	labelDragging = nil
	if (frame) then
		frame:StopMovingOrSizing()
		FPerl.SavePosition(frame)
	end
	for _, box in pairs(labelBoxes) do
		box:EnableMouse(false)
		box:Hide()
	end
end

local labelled = {} -- {frame, name} of the frames the last walk found

local function labelsOn()
	return FPerl.Locked == 0 and FPerl.layout and FPerl.layout.arrangeLabels and not InCombatLockdown()
end

-- Refits the box of each listed frame, and hides the box of one that is hidden. No walk: it runs on a ticker and after
-- each save. Each frame is read under pcall: a secret flag counts as set, an unreadable frame is skipped.
function FPerl.ArrangeLabelsTick()
	if (not labelsOn()) then return end
	for _, e in ipairs(labelled) do
		local ok, shown = pcall(e[1].IsShown, e[1])
		if (ok and (FPerl.IsSecret(shown) or shown)) then
			pcall(labelFrame, e[1], e[2])
		else
			local box = labelBox(e[2])
			box:EnableMouse(false)
			box:Hide()
		end
	end
end

-- Finds the frames by walking UIParent's shown frames, then fits their boxes. Run on Labels on, unlock and roster changes.
function FPerl.ArrangeLabelsUpdate()
	labelsHide()
	wipe(labelled)
	if (not labelsOn()) then return end
	local seen = {}
	local function visit(f)
		for _, c in ipairs({f:GetChildren()}) do
			if (not seen[c]) then
				seen[c] = true
				local ok, shown = pcall(c.IsShown, c)
				if (ok and (FPerl.IsSecret(shown) or shown)) then
					local name = c:GetName()
					if (type(name) == "string" and name:find("^FPerl") and name ~= "FPerl_ArrangeBar"
						and not name:find("^FPerl_ArrangeLabel_")) then
						local okM, movable = pcall(c.IsMovable, c)
						if (okM and (FPerl.IsSecret(movable) or movable)) then labelled[#labelled + 1] = {c, name} end
					end
					visit(c)
				end
			end
		end
	end
	pcall(visit, UIParent)
	FPerl.ArrangeLabelsTick()
end

-- Art that appears after unlock (aura handles) changes extents: refit the listed frames on a ticker.
FPerl.Every(1, FPerl.ArrangeLabelsTick)
FPerl.On("GROUP_ROSTER_UPDATE", function()
	if (labelsOn()) then FPerl.ArrangeLabelsUpdate() end
end)

FPerl.On("PLAYER_REGEN_DISABLED", FPerl.AlignmentGridHide)
FPerl.On("PLAYER_REGEN_DISABLED", dragBoxHide)
FPerl.On("PLAYER_REGEN_DISABLED", labelsHide)
FPerl.On("PLAYER_REGEN_ENABLED", FPerl.AlignmentGridUpdate)
-- the preview ends at combat start (FPerl_Arrange.lua) and comes back before the labels are fitted
FPerl.On("PLAYER_REGEN_ENABLED", function()
	if (FPerl.Locked == 0) then FPerl.UnlockPreview(true) end
end)
FPerl.On("PLAYER_REGEN_ENABLED", FPerl.ArrangeLabelsUpdate)

-- Upvalues for the code below
local _G = _G
local ipairs = ipairs
local max = max
local min = min
local pairs = pairs
local unpack = unpack
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local IsShiftKeyDown = IsShiftKeyDown
local GameTooltip = GameTooltip
local UIParent = UIParent

-- FPerl.UnlockFrames
function FPerl.UnlockFrames()
	FPerl.Locked = 0
	FPerl.UnlockPreview(true)

	if (FPerl.Party.Virtual) then
		FPerl.Party.Virtual(true)
	end

	if (FPerl.Party.Preview) then
		FPerl.Party.Preview(true)
	end

	if (FPerl.PlayerPet.Virtual) then
		FPerl.PlayerPet.Virtual(true)
	end

	if (FPerl_AggroAnchor) then
		FPerl_AggroAnchor:Enable()
	end

	if (FPerl.Raid.RaidTitles) then
		FPerl.Raid.RaidTitles()
		if (FPerl.RaidPets.Titles) then
			FPerl.RaidPets.Titles()
		end
	end
	hookDragBoxes()
	FPerl.AlignmentGridUpdate()
	FPerl.ArrangeLabelsUpdate()
	FPerl.ArrangeBarUpdate()
	FPerl.Notice("Frames unlocked: /fperl lock, or General > Frames, locks them.")
end

-- FPerl.LockFrames
function FPerl.LockFrames()
	FPerl.Locked = 1
	FPerl.UnlockPreview(false)
	dragBoxHide()
	FPerl.AlignmentGridUpdate()
	FPerl.ArrangeLabelsUpdate()
	FPerl.ArrangeBarUpdate()

	if (FPerl.Party.Virtual) then
		FPerl.Party.Virtual()
	end

	if (FPerl.Party.Preview) then
		FPerl.Party.Preview(false)
	end

	if (FPerl.PlayerPet.Virtual) then
		FPerl.PlayerPet.Virtual()
	end

	if (FPerl_AggroAnchor) then
		FPerl_AggroAnchor:Disable()
	end

	if (FPerl.Raid.RaidTitles) then
		FPerl.Raid.RaidTitles()
		if (FPerl.RaidPets.Titles) then
			FPerl.RaidPets.Titles()
		end
	end
end

-- FPerl.GetSavePositionTable(create)
-- The active layout's positions, {[frameName] = {left, top, width, height}}; nil when it has none, unless create.
function FPerl.GetSavePositionTable(create)
	if (not FPerl.layout) then
		return
	end
	if (not FPerl.layout.positions and create) then
		FPerl.layout.positions = {}
	end
	return FPerl.layout.positions
end


-- The only default layout: FPerl.PlaceFrame applies it to a frame with no saved position. The
-- frames have no XML anchors. Entries are {point, relativeTo, relativePoint, x, y}; relativeTo is
-- a frame name.
local function TopLeft(x, y) return {{"TOPLEFT", "UIParent", "TOPLEFT", x, y}} end
FPerl.DefaultPoints = {
	FPerl_Player = TopLeft(35, -16),
	FPerl_Player_Pet = TopLeft(92, -156),
	FPerl_Target = TopLeft(300, -16),
	FPerl_Focus = TopLeft(701, -360),
	FPerl_TargetTarget = TopLeft(593, -16),
	FPerl_Party_Anchor = TopLeft(38, -330),
	FPerl_Raid_TitlePets = TopLeft(680, -500),
	FPerl_MinimapButton_Frame = {{"CENTER", "Minimap", "RIGHT", 0, 0}},
	-- Created in FPerl.TargetTarget.SetBits.
	FPerl_TargetTargetTarget = {{"TOPLEFT", "FPerl_TargetTargetstatsFrame", "TOPRIGHT", 44, 0}},
	FPerl_FocusTarget = {{"TOPLEFT", "FPerl_FocuslevelFrame", "TOPRIGHT", 48, 0}},
	FPerl_PetTarget = {{"TOPLEFT", "FPerl_Player_PetnameFrame", "TOPRIGHT", 57, 0}},
}
for i, x in ipairs({0, 80, 160, 240, 320, 400, 480, 560, 640, 720, 800, 880, 880}) do
	FPerl.DefaultPoints["FPerl_Raid_Title"..i] = TopLeft(x, -715)
end
-- The defaults keep clear of Blizzard's default HUD (minimap, buffs and tracker top right, chat bottom left, bars bottom,
-- widgets top centre): unit frames top left, party down the left side above the chat, Focus below the target of target. Raid groups 1-4 in a row
-- right of the party column, 5-8 under them (a group is 80 x 226); titles 9-13 hold no members and keep the row above.
for i = 1, 8 do
	FPerl.DefaultPoints["FPerl_Raid_Title"..i] = TopLeft(350 + (i - 1) % 4 * 80, i <= 4 and -405 or -635)
end

-- FPerl.SavePosition
-- The saved position is the frame's top-left in UIParent units (FPerl.FramePointUI).
function FPerl.SavePosition(self)
	local name = self:GetName()
	if (name) then
		local l, t = FPerl.FramePointUI(self)
		local h = self:IsResizable() and self:GetHeight()
		local w = self:IsResizable() and self:GetWidth()

		local table = FPerl.GetSavePositionTable(true)
		if (table) then
			if (t and l) then
				if (not table[name]) then
					table[name] = {}
				end
				table[name].top = t
				table[name].left = l
				table[name].height = h
				table[name].width = w
			else
				table[name] = nil
			end
		end
	end
	FPerl.AlignmentGridSnapSaved(self)
end

-- FPerl.RestoreAllPositions
-- Places every default frame and every frame with a saved position.
function FPerl.RestoreAllPositions()
	if (InCombatLockdown()) then
		FPerl.AfterCombat(FPerl.RestoreAllPositions)
		return
	end
	local names = {}
	for name in pairs(FPerl.DefaultPoints) do
		names[name] = true
	end
	local table = FPerl.GetSavePositionTable()
	if (table) then
		for k in pairs(table) do
			if (k == "FPerl_Runes" or k == "FPerl_RaidHelper_Frame" or k == "FPerl_RaidMonitor_Frame" or k == "FPerl_Check" or k == "FPerl_AdminFrame" or k == "FPerl_Assists_Frame") then
				-- An entry under one of these names is stale: these frames are placed through their
				-- anchors (FPerl_MTList_Anchor, FPerl_RaidMonitor_Anchor, FPerl_CheckAnchor,
				-- FPerl_AdminFrameAnchor, FPerl_Assists_FrameAnchor), and F-Perl has no FPerl_Runes frame.
				table[k] = nil
			else
				names[k] = true
			end
		end
	end
	for name in pairs(names) do
		local frame = _G[name]
		if (frame) then
			FPerl.PlaceFrame(frame)
		end
	end
	-- The login alignment ran before this placed the title.
	if (FPerl.RaidPets.Align) then
		FPerl.RaidPets.Align()
	end
end

---------------------------------
-- Scaling frame corner thingy --
---------------------------------
-- Seems a convoluted way of doing things, rather than just anchoring bottomleft, topright.. but
-- doing that introduces a really ugly latency between the anchor moving and the frame scaling because
-- the OnSizeChanged event is fired on the frame after the actual resize took place.

local scaleIndication

local function scaleMouseDown(self)

	GameTooltip:Hide()

	if (self.resizable and IsShiftKeyDown()) then
		self.sizing = true
	elseif (self.scalable) then
		self.scaling = true
	end

	if (not scaleIndication) then
		scaleIndication = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
		scaleIndication:SetWidth(100)
		scaleIndication:SetHeight(18)
		scaleIndication.text = scaleIndication:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		scaleIndication.text:SetAllPoints()
		scaleIndication.text:SetJustifyH("LEFT")
	end

	scaleIndication:Show()
	scaleIndication:ClearAllPoints()
	scaleIndication:SetPoint("LEFT", self, "RIGHT", 4, 0)

	if (self.scaling) then
		scaleIndication.text:SetFormattedText("%.1f%%", self.frame:GetScale() * 100)
	else
		scaleIndication.text:SetFormattedText("%dx%d", self.frame:GetWidth(), self.frame:GetHeight())
	end

	self.anchor:StartSizing(self.resizeTop and "TOPRIGHT")

	self.oldBdBorder = {self.frame:GetBackdropBorderColor()}
	self.frame:SetBackdropBorderColor(1, 1, 0.5, 1)
end

local function scaleMouseUp(self)
	self.anchor:StopMovingOrSizing()

	scaleIndication:Hide()

	FPerl.SavePosition(self.anchor)

	if (self.resizeTop) then
		FPerl.SwitchAnchor(self.anchor, "BOTTOMLEFT")
	end

	if (self.scaling) then
		if (self.onScaleChanged) then
			self:onScaleChanged(self.frame:GetScale())
		end
	end

	if (self.sizing) then
		if (self.onSizeChanged) then
			self:onSizeChanged(self.frame:GetWidth(), self.frame:GetHeight())
		end
	end

	if (self.oldBdBorder) then
		self.frame:SetBackdropBorderColor(unpack(self.oldBdBorder))
		self.oldBdBorder = nil
	end

	self.scaling = nil
	self.sizing = nil
end

local function scaleMouseChange(self)
	if (self.corner.sizing) then
		self.corner.frame:SetWidth(self:GetWidth() / self.corner.frame:GetScale())
		self.corner.frame:SetHeight(self:GetHeight() / self.corner.frame:GetScale())

		self.corner.startSize.w = self.corner.frame:GetWidth()
		self.corner.startSize.h = self.corner.frame:GetHeight()

		if (scaleIndication and scaleIndication:IsShown()) then
			scaleIndication.text:SetFormattedText("|c00FFFF80%d|c00808080x|c00FFFF80%d", self.corner.frame:GetWidth(), self.corner.frame:GetHeight())
		end

	elseif (self.corner.scaling) then
		local w = self:GetWidth()
		if (w) then
			self.corner.scaling = nil
			local ratio = self.corner.frame:GetWidth() / self.corner.frame:GetHeight()
			local s = min(self.corner.maxScale, max(self.corner.minScale, w / self.corner.startSize.w))	-- New Scale

			w = self.corner.startSize.w * s		-- Set height and width of anchor window to match ratio of actual
			if (self.corner.resizeTop) then
				FPerl.SwitchAnchor(self, "BOTTOMLEFT")
				self:SetWidth(w)
				self:SetHeight(w / ratio)
			else
				self:SetWidth(w)
				self:SetHeight(w / ratio)
			end

			if (scaleIndication and scaleIndication:IsShown()) then
				scaleIndication.text:SetFormattedText("%.1f%%", s * 100)
			end

			self.corner.frame:SetScale(s)
			self.corner.scaling = true
		end
	end
end

-- scaleMouseEnter
local function scaleMouseEnter(self)
	self.tex:SetVertexColor(1, 1, 1, 1)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if (self.scalable) then
		GameTooltip:SetText(FPERL_DRAGHINT1, nil, nil, nil, nil, true)
	end
	if (self.resizable) then
		GameTooltip:AddLine(FPERL_DRAGHINT2, nil, nil, nil, true)
	end
	GameTooltip:Show()
end

-- scaleMouseLeave
local function scaleMouseLeave(self)
	self.tex:SetVertexColor(1, 1, 1, 0.5)
	GameTooltip:Hide()
end

-- FPerl.RegisterScalableFrame
function FPerl.RegisterScalableFrame(self, anchorFrame, minScale, maxScale, resizeTop, resizable, scalable)
	if (scalable == nil) then
		scalable = true
	end

	if (not self.corner) then
		self.corner = CreateFrame("Frame", nil, self)
		self.corner:SetFrameLevel(self:GetFrameLevel() + 3)
		self.corner:EnableMouse(true)
		self.corner:SetScript("OnMouseDown", scaleMouseDown)
		self.corner:SetScript("OnMouseUp", scaleMouseUp)
		self.corner:SetScript("OnEnter", scaleMouseEnter)
		self.corner:SetScript("OnLeave", scaleMouseLeave)
		self.corner:SetHeight(12)
		self.corner:SetWidth(12)

		anchorFrame:SetScript("OnSizeChanged", scaleMouseChange)
		anchorFrame.corner = self.corner

		self.corner.tex = self.corner:CreateTexture(nil, "BORDER")
		self.corner.tex:SetTexture("Interface\\AddOns\\FPerl\\Images\\FPerl_Elements")
		self.corner.tex:SetAllPoints()
		self.corner.tex:SetVertexColor(1, 1, 1, 0.5)

		self.corner.anchor = anchorFrame
		self.corner.frame = self
	end

	if (self.SetResizeBounds) then
		self:SetResizeBounds(10, 10)
	else
		self:SetMinResize(10, 10)
	end

	self.corner.scalable = scalable
	self.corner.resizable = resizable
	self.corner.resizeTop = resizeTop
	self.corner.minScale = minScale or 0.4
	self.corner.maxScale = maxScale or 5
	self.corner.startSize = {w = self:GetWidth(), h = self:GetHeight()}

	local bgDef = self:GetBackdrop()

	self.corner:ClearAllPoints()
	if (resizeTop) then
		self.corner.tex:SetTexCoord(0.78125, 1, 0.5, 0.703125)
		self.corner:SetPoint("TOPRIGHT", -bgDef.insets.right, -bgDef.insets.top)
		self.corner:SetHitRectInsets(0, -6, -6, 0)		-- So the click area extends over the tooltip border
	else
		self.corner.tex:SetTexCoord(0.78125, 1, 0.78125, 1)
		self.corner:SetPoint("BOTTOMRIGHT", -bgDef.insets.right, bgDef.insets.bottom)
		self.corner:SetHitRectInsets(0, -6, 0, -6)		-- So the click area extends over the tooltip border
	end

	self.corner.scaling = true
	scaleMouseChange(anchorFrame)
	self.corner.scaling = nil
end
