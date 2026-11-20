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
-- Hidden while Edit Mode is open: Edit Mode has its own grid (its Show Grid box), and F-Perl's snap follows that one there.
function FPerl.AlignmentGridUpdate()
	local editing = FPerl.Locked == 0 or (_G.FPerl_OptionsWindow and _G.FPerl_OptionsWindow:IsShown())
	if (gridDB().alignmentGrid and editing and not FPerl.InEditMode and not InCombatLockdown()) then
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
-- at most 0, right and top at least 0 (up is positive). In Edit Mode a unit frame (one with partyid; each unit frame's root
-- sets it and is sized to the body) is its own rect: level and class tabs and text that hang past it are left out, so its
-- corners line up with other frames', and its label box covers the same rect. Any other frame is the union of the rects of
-- the frame and its shown descendant frames and of their visible regions: a texture, or a font string with text, of size
-- above 0 and effective alpha above 0. The saved position stays the frame's top-left. A secret alpha or text counts as
-- shown; a secret size cannot be measured and is left out.
local function extentOf(frame)
	local l, t = FPerl.FramePointUI(frame)
	local uiScale = UIParent:GetEffectiveScale()
	if (not l or not uiScale) then return end
	if (frame.partyid and FPerl.InEditMode) then
		local k, w, h = frame:GetEffectiveScale() / uiScale, frame:GetWidth(), frame:GetHeight()
		if (FPerl.IsSecret(w) or FPerl.IsSecret(h)) then return end
		return {0, w * k, 0, -h * k}
	end
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

-- Edit Mode's snap lines in UIParent units: UIParent's edges and center, its grid lines when the grid is on, the sides of
-- each frame it magnetizes to, and the extent sides of each shown F-Perl frame. The Edit Mode fields are internal, not API:
-- read only, type-checked, and a frame whose rect cannot be read is skipped, so a change in them stops the snap without an
-- error. Rebuilt at most every
-- 0.5 s, as the drag indicator asks every frame, and after each drop: other frames stay put during a drag, and the frames
-- that move with the dragged one are skipped (movesWith).
local function known(v) return type(v) == "number" and not FPerl.IsSecret(v) end
local function scaledRect(f)
	local r = f.Selection or f
	local l, b, w, h = r:GetRect()
	local k = r:GetEffectiveScale() / UIParent:GetEffectiveScale()
	if (known(l) and known(b) and known(w) and known(h) and known(k)) then return l * k, b * k, (l + w) * k, (b + h) * k end
end
-- srcX/srcY hold, per line index, the rect {left, bottom, right, top, frame = F-Perl frame} of the frame the line comes
-- from; nil for grid and UIParent lines.
local linesX, linesY, srcX, srcY, linesAt
local function editModeLines()
	local now = GetTime()
	if (linesAt and now - linesAt < 0.5) then return linesX, linesY, srcX, srcY end
	local xs, ys = {0, UIParent:GetWidth() / 2, UIParent:GetWidth()}, {0, UIParent:GetHeight() / 2, UIParent:GetHeight()}
	local sx, sy = {}, {}
	local function add(rect)
		sx[#xs + 1], sx[#xs + 2], sy[#ys + 1], sy[#ys + 2] = rect, rect, rect, rect
		xs[#xs + 1], xs[#xs + 2] = rect[1], rect[3]
		ys[#ys + 1], ys[#ys + 2] = rect[2], rect[4]
	end
	local mm = EditModeMagnetismManager
	local grid = mm and mm.magneticGridLines
	if (type(grid) == "table") then
		-- keyed by line frame, not by index
		for _, v in pairs(grid.vertical or {}) do if (known(v)) then xs[#xs + 1] = v end end
		for _, v in pairs(grid.horizontal or {}) do if (known(v)) then ys[#ys + 1] = v end end
	end
	-- F-Perl frames registered by two-way snap (FPerl_EditModeSnap.lua) are skipped here and added below by their extent.
	for f in pairs(mm and mm.magneticFrames or {}) do
		if (not FPerl.DefaultPoints[f:GetName() or ""]) then
			local ok, l, b, r, t = pcall(scaledRect, f)
			if (ok and l) then add({l, b, r, t}) end
		end
	end
	for name in pairs(FPerl.DefaultPoints) do
		local f = _G[name]
		local shown = f and f:IsVisible()
		-- a secret flag counts as shown, as in extentOf
		if (f and name ~= "FPerl_MinimapButton_Frame" and (FPerl.IsSecret(shown) or shown)) then
			local l, t = FPerl.FramePointUI(f)
			local ext = l and extentOf(f)
			if (ext) then add({l + ext[1], t + ext[4], l + ext[2], t + ext[3], frame = f}) end
		end
	end
	linesX, linesY, srcX, srcY, linesAt = xs, ys, sx, sy, now
	return xs, ys, sx, sy
end

-- True when frame f moves with dragged: f, or a frame along its chain of first anchors, is dragged or a descendant of it
-- (TargetTargetTarget anchors to a child of TargetTarget, for one). The chain is cut at 10 steps.
local function movesWith(f, dragged)
	for _ = 1, 10 do
		if (not f) then return false end
		local p = f
		while (p) do
			if (p == dragged) then return true end
			p = p:GetParent()
		end
		local _, rel = f:GetPoint(1)
		f = rel
	end
	return false
end

-- Edit Mode: per axis, the pair of extent edge (a or b) and line closest together; the edge's move, the line and its
-- index, or nil beyond range. Lines of the dragged frame and of the frames that move with it (src[i].frame) are skipped.
local function nearestLine(a, b, lines, range, src, dragged)
	local best, move, edge, at
	for i, line in ipairs(lines) do
		local da, db = math.huge, math.huge
		if (not (src[i] and src[i].frame and movesWith(src[i].frame, dragged))) then
			da, db = math.abs(line - a), math.abs(line - b)
		end
		if (not best or da < best) then best, move, edge, at = da, line - a, line, i end
		if (db < best) then best, move, edge, at = db, line - b, line, i end
	end
	if (best and best <= range) then return move, edge, at end
end

-- Where a drop would put the frame: the top-left, then the vertical and horizontal line its nearer extent edges snap to.
-- nil when Snap does not apply. The drop and the drag indicator both use it; ext (extentOf) is computed when not given.
-- In Edit Mode it follows Edit Mode's Snap checkbox (not F-Perl's Snap row or grid) and snap lines; an axis with no line
-- in range keeps its position and its line is nil. Then, per axis, the rect of the frame the line comes from.
local function snapTarget(frame, ext)
	local inEM = FPerl.InEditMode
	-- outside Edit Mode the tip promises a snap to the visible grid: a save while it is hidden stays where it is
	if (InCombatLockdown() or (inEM and not (EditModeManagerFrame and EditModeManagerFrame:IsSnapEnabled()))
		or (not inEM and (not gridDB().alignmentSnapToGrid or not FPerl.AlignmentGridIsShown()))) then return end
	local name = frame.GetName and frame:GetName()
	if (name == "FPerl_MinimapButton_Frame") then return end
	local l, t = FPerl.FramePointUI(frame)
	ext = ext or extentOf(frame)
	if (not l or not ext) then return end
	if (inEM) then
		local xs, ys, sx, sy = editModeLines()
		-- Edit Mode measures the range in screen units (distance times UIParent's scale); 8 is its default
		local range = (EditModeMagnetismManager and EditModeMagnetismManager.magnetismRange or 8) / UIParent:GetEffectiveScale()
		local mx, lx, ix = nearestLine(l + ext[1], l + ext[2], xs, range, sx, frame)
		local my, ly, iy = nearestLine(t + ext[3], t + ext[4], ys, range, sy, frame)
		if (not mx and not my) then return end
		return l + (mx or 0), t + (my or 0), lx, ly, ix and sx[ix], iy and sy[iy]
	end
	-- The grid is in UIParent units, centered on UIParent's center (gridShow). Per axis the nearer edge snaps; a tie snaps left/top.
	local cx, cy = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
	if (not cx) then return end
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
	linesAt = nil -- the frame moved: its lines are stale
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

-- A fill over the whole box and a one-pixel-wide border, in the given {r, g, b, a} colors. Returns the textures.
local function boxBorder(box, fillColor, edgeColor)
	local fill = box:CreateTexture(nil, "OVERLAY")
	local textures = {fill}
	fill:SetAllPoints()
	fill:SetColorTexture(unpack(fillColor))
	local function edge(p1, p2, horizontal)
		local e = box:CreateTexture(nil, "OVERLAY")
		e:SetColorTexture(unpack(edgeColor))
		e:SetPoint(p1)
		e:SetPoint(p2)
		if (horizontal) then e:SetHeight(1) else e:SetWidth(1) end
		textures[#textures + 1] = e
	end
	edge("TOPLEFT", "TOPRIGHT", true)
	edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
	edge("TOPLEFT", "BOTTOMLEFT")
	edge("TOPRIGHT", "BOTTOMRIGHT")
	return textures
end

local function dragBoxHide()
	if (dragBox) then
		dragBox:Hide()
	end
end

-- Outline i of the drag box over a rect {left, bottom, right, top} in UIParent units, or hidden for nil.
local function outline(box, i, rect)
	local o = box.outlines[i]
	if (not rect) then
		if (o) then o:Hide() end
		return
	end
	if (not o) then
		o = CreateFrame("Frame", nil, box)
		o.snapOutline = true -- probes find the outlines by it
		boxBorder(o, {1, 0.5, 0, 0.15}, {1, 0.5, 0, 1})
		box.outlines[i] = o
	end
	o:ClearAllPoints()
	o:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", rect[1], rect[2])
	o:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", rect[3], rect[4])
	o:Show()
end

-- While Snap applies, two highlight lines mark the lines the drop will land on, and in Edit Mode an outline marks each
-- frame a line comes from (an Edit Mode frame or another F-Perl frame).
local function dragBoxTick(self)
	-- no extent, no snap: the drop does not snap either
	local lineX, lineY, fromX, fromY
	if (self.ext) then
		_, _, lineX, lineY, fromX, fromY = snapTarget(self.frame, self.ext)
	end
	outline(self, 1, fromX)
	outline(self, 2, fromY ~= fromX and fromY or nil)
	local thick = 2 * pixelSize()
	if (lineX) then
		self.vLine:SetWidth(thick)
		self.vLine:ClearAllPoints()
		self.vLine:SetPoint("TOP", UIParent, "TOPLEFT", lineX, 0)
		self.vLine:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", lineX, 0)
		self.vLine:Show()
	else
		self.vLine:Hide()
	end
	if (lineY) then
		self.hLine:SetHeight(thick)
		self.hLine:ClearAllPoints()
		self.hLine:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 0, lineY)
		self.hLine:SetPoint("RIGHT", UIParent, "BOTTOMRIGHT", 0, lineY)
		self.hLine:Show()
	else
		self.hLine:Hide()
	end
end

local function dragBoxShow(frame)
	if (not dragBox) then
		dragBox = CreateFrame("Frame", nil, UIParent)
		-- HIGH: above the unit frames, below dialogs such as Edit Mode's menus. The level puts it over the frames' own HIGH
		-- children (menu overlays, hit text).
		dragBox:SetFrameStrata("HIGH")
		dragBox:SetFrameLevel(1000)
		dragBox:EnableMouse(false)
		boxBorder(dragBox, {1, 0.5, 0, 0.25}, {1, 0.5, 0, 1})
		dragBox.vLine = dragBox:CreateTexture(nil, "OVERLAY")
		dragBox.vLine:SetColorTexture(1, 0.5, 0, 1)
		dragBox.hLine = dragBox:CreateTexture(nil, "OVERLAY")
		dragBox.hLine:SetColorTexture(1, 0.5, 0, 1)
		dragBox.outlines = {}
	end
	dragBox.frame = frame
	dragBox.vLine:Hide()
	dragBox.hLine:Hide()
	outline(dragBox, 1)
	outline(dragBox, 2)
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
	box:SetFrameStrata("HIGH") -- strata and level as the drag box
	box:SetFrameLevel(1000)
	box:EnableMouse(false)
	box.plain = boxBorder(box, {1, 1, 1, 0.15}, {1, 1, 1, 0.8})
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

-- Edit Mode's selection layout (EditModeSystemTemplates.lua, a local there), for the highlight look.
local EDITMODE_LAYOUT = {
	TopRightCorner = {atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = 8},
	TopLeftCorner = {atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = 8},
	BottomLeftCorner = {atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = -8},
	BottomRightCorner = {atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = -8},
	TopEdge = {atlas = "_%s-NineSlice-EdgeTop"},
	BottomEdge = {atlas = "_%s-NineSlice-EdgeBottom"},
	LeftEdge = {atlas = "!%s-NineSlice-EdgeLeft"},
	RightEdge = {atlas = "!%s-NineSlice-EdgeRight"},
	Center = {atlas = "%s-NineSlice-Center", x = -8, y = 8, x1 = 8, y1 = -8},
}

-- While Edit Mode is open a box wears Edit Mode's highlight, as Blizzard's frames do; otherwise the plain look.
local function boxLook(box)
	local em = FPerl.InEditMode and true or false
	if (box.inEditMode == em) then return end -- runs on the ticker: only a change of look does work
	box.inEditMode = em
	if (em and not box.TopLeftCorner) then NineSliceUtil.ApplyLayout(box, EDITMODE_LAYOUT, "editmode-actionbar-highlight") end
	if (box.TopLeftCorner) then NineSliceUtil.SetLayoutShown(box, em) end
	for _, t in ipairs(box.plain) do t:SetShown(not em) end
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
	boxLook(box)
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
	return FPerl.Locked == 0 and FPerl.layout and (FPerl.layout.arrangeLabels or FPerl.InEditMode) and not InCombatLockdown()
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

-- Finds the frames by walking UIParent's shown frames, then fits their boxes. Run on Labels on, unlock, Edit Mode enter and exit, and roster changes.
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

-- FPerl.UnlockFrames(byEditMode)
function FPerl.UnlockFrames(byEditMode)
	FPerl.Locked = 0
	FPerl.UnlockedByEditMode = byEditMode
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
	if (not byEditMode) then FPerl.Notice("Frames unlocked: /fperl lock, or General > Frames, locks them.") end
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
