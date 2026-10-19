-- F-Perl unit-frame core: the number formatters for health and power text (the plain/secret split
-- lives here and nowhere else), the health and power elements, and the shared event dispatcher of
-- the unit frames. Loads after FPerl.lua; client globals are read at call time.

local conf
FPerl.RequestConfig(function(New)
	conf = New
end, "$Revision: 1 $")

local largeNumTag = FPERL_LOC_LARGENUMTAG
local hugeNumTag = FPERL_LOC_HUGENUMTAG
local veryhugeNumTag = FPERL_LOC_VERYHUGENUMTAG
local percD = "%d%%"
local perc1F = "%.1f%%"

-- FPerl.ShortNumber(v, compact, cap)
-- A readable v becomes an X-Perl ladder string on abs(v), sign kept. The default ladder is the one
-- of the value and deficit texts; compact is the healer-mode deficit in the percent slot. cap, the
-- max printed beside v, limits the bracket (a v above its max prints in the max's bracket, as the
-- old nested ladder did). A secret v goes to AbbreviateNumbers, which accepts one.
function FPerl.ShortNumber(v, compact, cap)
	if (FPerl.IsSecret(v)) then
		return AbbreviateNumbers(v)
	end
	local a = abs(v)
	if (cap and cap < a) then
		a = cap
	end
	if (compact) then
		if (a >= 10000000000) then
			return format("%.0f%s", v / 1000000000, veryhugeNumTag)
		elseif (a >= 1000000000) then
			return format("%.1f%s", v / 1000000000, veryhugeNumTag)
		elseif (a >= 10000000) then
			return format("%.0f%s", v / 1000000, hugeNumTag)
		elseif (a >= 1000000) then
			return format("%.1f%s", v / 1000000, hugeNumTag)
		elseif (a >= 10000) then
			return format("%.0f%s", v / 1000, largeNumTag)
		elseif (a >= 1000) then
			return format("%.1f%s", v / 1000, largeNumTag)
		end
	elseif (a >= 1000000000) then
		return format("%.2f%s", v / 1000000000, veryhugeNumTag)
	elseif (a >= 10000000) then
		return format("%.1f%s", v / 1000000, hugeNumTag)
	elseif (a >= 1000000) then
		return format("%.2f%s", v / 1000000, hugeNumTag)
	elseif (a >= 100000) then
		return format("%.1f%s", v / 1000, largeNumTag)
	end
	return format("%d", v)
end

-- FPerl.ShortPair(v, max): the texts of a value and its max. If either is secret both go to
-- AbbreviateNumbers (a secret can be neither compared nor ladder-cut); otherwise each gets the
-- ladder, v capped at max, and a max of 1e9 or more keeps one decimal beside a v of 1e5-1e6.
function FPerl.ShortPair(v, max)
	if (FPerl.IsSecret(v) or FPerl.IsSecret(max)) then
		return AbbreviateNumbers(v), AbbreviateNumbers(max)
	end
	local a = abs(v)
	if (max >= 1000000000 and a >= 100000 and a < 1000000) then
		return FPerl.ShortNumber(v, nil, max), format("%.1f%s", max / 1000000000, veryhugeNumTag)
	end
	return FPerl.ShortNumber(v, nil, max), FPerl.ShortNumber(max)
end

-- FPerl.SetDeficitPair(fs, missing, max, style)
-- Writes -missing/max to fs: the ladder through FPerl.SetValuedText, or style "full" whole numbers.
function FPerl.SetDeficitPair(fs, missing, max, style)
	if (FPerl.IsSecret(missing)) then
		if (style == "full") then
			fs:SetFormattedText("-%d/%d", missing, max)
		else
			local a, b = FPerl.ShortPair(missing, max)
			fs:SetFormattedText("-%s/%s", a, b)
		end
	elseif (style == "full") then
		fs:SetFormattedText("%d/%d", -missing, max)
	else
		FPerl.SetValuedText(fs, -missing, max)
	end
end

-- FPerl.FormatPercent(fs, pct, precise)
-- pct is 0..100. Readable: one decimal below 10 (always, when precise), else rounded. Secret:
-- truncated by %d (one decimal when precise), because a secret cannot be added to. precise "whole"
-- never prints a decimal (readable: rounded).
function FPerl.FormatPercent(fs, pct, precise)
	if (FPerl.IsSecret(pct)) then
		fs:SetFormattedText((precise and precise ~= "whole") and perc1F or percD, pct)
	elseif (precise == "whole" or (not precise and pct >= 10)) then
		fs:SetFormattedText(percD, pct + 0.5)
	else
		fs:SetFormattedText(perc1F, min(pct + 0.05, 100))
	end
end

-- FPerl.SetDeficitText(fs, missing, style)
-- Writes -missing to fs. A secret cannot be concatenated, so the FontString is written here, as
-- "-%d". Readable: the X-Perl ladder, its compact form (style true) or the whole number (style
-- "full", for the frames that never abbreviated).
function FPerl.SetDeficitText(fs, missing, style)
	if (FPerl.IsSecret(missing)) then
		fs:SetFormattedText("-%d", missing)
	elseif (style == "full") then
		fs:SetFormattedText("%d", -missing)
	else
		fs:SetText(FPerl.ShortNumber(-missing, style))
	end
end

-- FPerl.HealthSetBar(bar, unit, ignoreInverse): fills a health bar from the unit (the "inverse" bar
-- option applies unless ignoreInverse, for the frames that never honoured it); returns hp, hpMax and missing
-- for the text. The readable arithmetic only picks the deficit when both values can be read: it
-- keeps the ladder text of the plain path; a secret deficit comes from UnitHealthMissing. Every
-- health call passes usePredicted = true (the API's default, what the old code showed), so the bar,
-- the texts and the colour read the same health.
function FPerl.HealthSetBar(bar, u, ignoreInverse)
	local hp, hpMax = UnitHealth(u, true), UnitHealthMax(u)
	local missing
	if (FPerl.CanAccess(hp) and FPerl.CanAccess(hpMax)) then
		if (hp > hpMax) then
			hp = hpMax
		end
		missing = hpMax - hp
	else
		missing = UnitHealthMissing(u, true)
	end

	bar:SetMinMaxValues(0, hpMax)
	bar:SetValue(conf.bar.inverse and not ignoreInverse and missing or hp)
	return hp, hpMax, missing
end

-- FPerl.HealthUpdateBar(frame): the bar of the health element of a unit frame (frame.partyid is
-- the unit, frame.statsFrame.healthBar the bar).
function FPerl.HealthUpdateBar(frame)
	return FPerl.HealthSetBar(frame.statsFrame.healthBar, frame.partyid)
end

-- FPerl.HealthUpdate(frame): the health element for the unit frames whose bar carries a separate
-- .percent and .text: bar, colour, then percent, value and healer-mode deficit text. The raid
-- frames, whose one text shows either, call the pieces themselves.
function FPerl.HealthUpdate(frame)
	local u = frame.partyid
	local bar = frame.statsFrame.healthBar
	local hp, hpMax, missing = FPerl.HealthUpdateBar(frame)
	FPerl.ColourHealthBar(frame, u)

	local healer = frame.conf.healerMode
	if (bar.percent) then
		if (healer and healer.enable and healer.type == 2) then
			FPerl.SetDeficitText(bar.percent, missing, true)
		else
			FPerl.FormatPercent(bar.percent, UnitHealthPercent(u, true, CurveConstants.ScaleTo100))
		end
	end

	if (bar.text) then
		if (healer.enable and healer.type ~= 2) then
			if (healer.type == 1) then
				FPerl.SetDeficitPair(bar.text, missing, hpMax)
			else
				FPerl.SetDeficitText(bar.text, missing)
			end
		else
			FPerl.SetValuedText(bar.text, hp, hpMax)
		end
	end
end

-- FPerl.PowerSetBar(bar, unit, powerType, clampMax): fills a power bar from the unit; returns the
-- value, the max and the max the bar got. clampMax raises a readable max of 0 or less to 1 for the
-- bar (the pet frames), so an empty bar does not get a 0..0 range.
function FPerl.PowerSetBar(bar, u, powerType, clampMax)
	local cur, max = UnitPower(u, powerType), UnitPowerMax(u, powerType)
	local barMax = max
	if (clampMax and FPerl.CanAccess(max) and max <= 0) then
		barMax = 1
	end
	bar:SetMinMaxValues(0, barMax)
	bar:SetValue(cur)
	return cur, max, barMax
end

-- FPerl.PowerUpdate(frame, style): the power element of a unit frame (frame.partyid is the unit,
-- frame.statsFrame.manaBar the bar). style is a constant table of the module:
--   percent    format of the percent text ("%d%%" truncates, "%.0f%%" rounds); nil prints none
--   inText     the percent goes to the bar's .text (the pet frames) instead of its .percent
--   rawIfEmpty a readable max below 1 prints the value in the percent slot (as a type >= 1 power does)
--   text       value text in .text: "valued" (FPerl.SetValuedText) or "whole" ("%d/%d")
--   clampMax   see FPerl.PowerSetBar
-- Returns the power type, value and max. A power type of 1 or more (rage, energy, ...) prints the
-- value where the percent would be; the percent is FPerl.GetPowerPercent's, plain or secret.
function FPerl.PowerUpdate(frame, style)
	local u = frame.partyid
	local bar = frame.statsFrame.manaBar
	local powerType = FPerl.GetDisplayedPowerType(u)
	local cur, max = FPerl.PowerSetBar(bar, u, powerType, style.clampMax)

	if (style.percent) then
		local fs = style.inText and bar.text or bar.percent
		if (powerType >= 1 or (style.rawIfEmpty and FPerl.CanAccess(max) and max < 1)) then
			fs:SetText(cur)
		else
			fs:SetFormattedText(style.percent, FPerl.GetPowerPercent(u, powerType))
		end
	end

	if (style.text == "valued") then
		FPerl.SetValuedText(bar.text, cur, max)
	elseif (style.text == "whole") then
		bar.text:SetFormattedText("%d/%d", cur, max)
	end
	return powerType, cur, max
end

-- Elements and the shared dispatcher.
-- An element is FPerl.Elements[name] = {events = {EVENT = fn(frame, ...)}, units = {EVENT = {unit, ...}}}.
-- A frame turns it on with FPerl.UnitFrameEnable; the element's events are then registered on the
-- frame and FPerl.UnitFrameOnEvent calls fn(frame, ...) with the payload the client sent (the unit
-- first for a unit event). Events named UNIT_* or INCOMING_* are unit events: registered with
-- RegisterUnitEvent for units[EVENT], else for the frame's __units list, so the client filters by
-- unit and no handler checks it; units[EVENT] = false registers the event for every unit. An event
-- the client does not know is skipped. An event nobody handles is not registered.
FPerl.Elements = {}

local function register(frame, event, el)
	local units = el.units and el.units[event]
	if (units == nil) then
		units = frame.__units
	end
	local isUnitEvent = strfind(event, "^UNIT_") or strfind(event, "^INCOMING_")
	if (isUnitEvent and units == nil and frame.__units == nil) then
		-- the frame has no unit yet: FPerl.UnitFrameSetUnit registers the event when it gets one
		frame.__unitEvents[event] = true
	elseif (units and isUnitEvent) then
		if (el.units == nil or el.units[event] == nil) then
			frame.__unitEvents[event] = true -- follows the frame's unit (FPerl.UnitFrameSetUnit)
		end
		FPerl.RegisterUnitEventSafe(frame, event, unpack(units))
	else
		FPerl.RegisterEventSafe(frame, event)
	end
end

-- FPerl.UnitFrameInit(frame, units, names): sets the frame's default unit list for unit events,
-- its OnEvent script, and enables the named elements.
function FPerl.UnitFrameInit(frame, units, names)
	frame.__units = units
	frame.__handlers = frame.__handlers or {}
	frame.__elements = frame.__elements or {}
	frame.__unitEvents = frame.__unitEvents or {}
	frame:SetScript("OnEvent", FPerl.UnitFrameOnEvent)
	for i = 1, #names do
		FPerl.UnitFrameEnable(frame, names[i])
	end
end

-- FPerl.UnitFrameEnable(frame, name): handlers join frame.__handlers[event] in the order enabled.
function FPerl.UnitFrameEnable(frame, name)
	local el = FPerl.Elements[name]
	if (not el) then
		error("F-Perl: no element " .. tostring(name), 2)
	end
	if (frame.__elements[name]) then
		return
	end
	frame.__elements[name] = true
	for event, fn in pairs(el.events) do
		if (type(fn) ~= "function") then
			error("F-Perl: element " .. name .. " has no handler for " .. event, 2)
		end
		local list = frame.__handlers[event]
		if (not list) then
			list = {}
			frame.__handlers[event] = list
			register(frame, event, el)
		end
		list[#list + 1] = fn
	end
end

-- FPerl.UnitFrameDisable(frame, name): the inverse; an event nobody on the frame handles is unregistered.
function FPerl.UnitFrameDisable(frame, name)
	local el = FPerl.Elements[name]
	if (not frame.__elements[name]) then
		return
	end
	frame.__elements[name] = nil
	for event, fn in pairs(el.events) do
		-- a new list, so a dispatch loop running over the old one is not shifted
		local old, list, removed = frame.__handlers[event], {}, false
		for i = 1, #old do
			if (not removed and old[i] == fn) then
				removed = true
			else
				list[#list + 1] = old[i]
			end
		end
		frame.__handlers[event] = list
		if (#list == 0) then
			frame.__handlers[event] = nil
			frame.__unitEvents[event] = nil
			FPerl.UnregisterEventSafe(frame, event)
		end
	end
end

-- FPerl.UnitFrameSetUnit(frame, unit): points the unit events that follow the frame's unit (the
-- header children, whose unit changes with the group) at the new unit; nil stops them.
function FPerl.UnitFrameSetUnit(frame, unit)
	frame.__units = unit and {unit} or nil
	for event in pairs(frame.__unitEvents) do
		FPerl.UnregisterEventSafe(frame, event)
		if (unit) then
			FPerl.RegisterUnitEventSafe(frame, event, unit)
		end
	end
end

function FPerl.UnitFrameOnEvent(self, event, ...)
	local list = self.__handlers[event]
	if (list) then
		for i = 1, #list do
			list[i](self, ...)
		end
	end
end

-- The health and power elements: the module sets frame.updateHealth, frame.updatePower and
-- frame.updatePowerType (what its frame does on a display power change) and enables them.
local function updateHealth(frame)
	frame.updateHealth(frame)
end
local function updatePower(frame)
	frame.updatePower(frame)
end
local function updatePowerType(frame)
	frame.updatePowerType(frame)
end
FPerl.Elements.Health = {events = {[FPerl.ForeverAPI.healthEvent] = updateHealth, UNIT_MAXHEALTH = updateHealth}}
FPerl.Elements.Power = {events = {UNIT_POWER_FREQUENT = updatePower, UNIT_MAXPOWER = updatePower, UNIT_DISPLAYPOWER = updatePowerType}}

-- The aura element. A frame with a frame.conf section with buffs and
-- debuffs turns it on with FPerl.UnitFrameEnable(frame, "Auras") and sets what differs:
--   auraLineSize      function(frame, kind): the line width of the "buffs" or "debuffs" container
--                     (default FPerl.AurasLineSize)
--   auraAnchor        region the blocks are placed against (default the frame)
--   auraInset         function(frame, side): extra distance from the anchor on that side
--   auraDebuffsNeedBuffs  debuffs show only while buffs are on
--   auraNoHandles     no drag handles
--   auraInside        set of sides ({RIGHT = true}) whose block next to the frame sits inside the anchor's
--                     edge on that side, icons filling inward from it
-- Update shows Blizzard's AuraContainer on every UNIT_AURA and combat change.
-- Without a container (no container API) it shows nothing. Rebuild reconfigures the
-- containers; the module calls it when the unit or an option changes. A rebuild that arrives while
-- auras are secret is left pending and applied by the next Update.

-- The line of a kind at full size that fits its anchor: perLine icons when set, else the anchor's
-- width (rowEdge, when the frame's strip is wider than the anchor).
local function fitLine(frame, kind, rowEdge)
	local o = frame.conf[kind]
	if ((o.perLine or 0) > 0 and o.size) then
		return o.perLine * (o.size + 3) - 3
	end
	local a = frame.auraAnchor or frame
	local edge = rowEdge or a:GetWidth()
	return (edge and edge > 0) and edge or 2000
end

-- FPerl.AurasLineSize(frame, kind, rowEdge): the line width of the "buffs" or "debuffs" container.
-- Debuffs with halfSize: the fitting line at full size, whatever Wrap says, so the half-size icons
-- fill the same length. Otherwise one line (2000) with buffs.wrap off, and on Left and Right with no
-- perLine; else perLine icons, or the anchor's width. A frame's auraLineSize hook passes the rowEdge
-- that differs from the anchor's width.
function FPerl.AurasLineSize(frame, kind, rowEdge)
	local c = frame.conf
	local o = c[kind]
	if (kind == "debuffs" and o.halfSize) then
		return fitLine(frame, kind, rowEdge)
	end
	local line = fitLine(frame, kind, rowEdge)
	if (not c.buffs.wrap) then
		line = 2000
	elseif ((o.side == "LEFT" or o.side == "RIGHT") and (o.perLine or 0) == 0) then
		line = 2000
	end
	-- both kinds inside the anchor at its two ends: a line holds what fits in half the anchor's width
	local b, d, inside = c.buffs, c.debuffs, frame.auraInside
	if (inside and b.enable and d.enable and b.side ~= d.side and inside[b.side] and inside[d.side] and o.size) then
		local half = (frame.auraAnchor or frame):GetWidth() / 2
		line = min(line, max(1, floor((half + 3) / (o.size + 3))) * (o.size + 3) - 3)
	end
	return line
end

local AXIS = AnchorUtil and AnchorUtil.FlowLayoutAxis or {Horizontal = 0, Vertical = 1}

-- the corner a block's first icon sits at (point), the corner of the anchor (or of the near block) it
-- hangs from (rel), and the direction away from the frame (ax, ay). Every block is rows: TOP and BOTTOM
-- fill rightward (reverse: leftward) and stack away from the frame; LEFT and RIGHT fill away from the frame
-- and stack downward (reverse: upward).
local OPPOSITE = {TOP = "BOTTOM", BOTTOM = "TOP", LEFT = "RIGHT", RIGHT = "LEFT"}
local function blockCorners(side, reverse)
	local rows = side == "TOP" or side == "BOTTOM"
	local h, v
	if (rows) then
		h, v = reverse and -1 or 1, side == "TOP" and 1 or -1
	else
		h, v = side == "LEFT" and -1 or 1, reverse and 1 or -1
	end
	local point = (v > 0 and "BOTTOM" or "TOP")..(h > 0 and "LEFT" or "RIGHT")
	local rel
	if (rows) then
		rel = side..(h > 0 and "LEFT" or "RIGHT")
	else
		rel = (v < 0 and "TOP" or "BOTTOM")..side
	end
	local ax = side == "LEFT" and -1 or side == "RIGHT" and 1 or 0
	local ay = side == "TOP" and 1 or side == "BOTTOM" and -1 or 0
	return point, rel, h, v, rows, ax, ay
end

-- Drag handles: while frames are unlocked and out of combat each aura block shows a handle over its
-- container (Blizzard's buttons are not scriptable, so F-Perl's own frame takes the mouse). Drag stop adds
-- the handle's displacement to the kind's x / y and places the frame again. FPerl.Locked is assigned in
-- many places, so a 0.2 s ticker follows it; combat is followed by event.
local handled, handlesOn, inCombat = {}, false, InCombatLockdown()
local HANDLE_LABEL = {buffs = "Buffs", debuffs = "Debuffs"}

local function coverHandle(frame, kind)
	local h = frame[kind == "buffs" and "buffHandle" or "debuffHandle"]
	local container = frame[kind == "buffs" and "buffContainer" or "debuffContainer"]
	local point = frame.auraHandlePoint and frame.auraHandlePoint[kind]
	if (not h or not container or not point) then
		return
	end
	-- the client refuses to anchor an addon frame to the container or its holder (their template forbids
	-- untrusted layout scripts), so the handle goes to the unit frame at the container's measured rect
	-- only while the handles show: while auras are secret the container's rect is secret too, and
	-- arithmetic on it raises
	if (not handlesOn) then
		return
	end
	local cl, cb, fl, fb = container:GetLeft(), container:GetBottom(), frame:GetLeft(), frame:GetBottom()
	if (not (cl and cb and fl and fb) or not (FPerl.CanAccess(cl) and FPerl.CanAccess(cb))) then
		return
	end
	h:ClearAllPoints()
	h:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", cl - fl, cb - fb)
	h:SetFrameLevel(container:GetFrameLevel() + 20)
	local size = frame.conf[kind].size or 25
	local w, ht = container:GetWidth() or 0, container:GetHeight() or 0
	if (not (FPerl.CanAccess(w) and FPerl.CanAccess(ht))) then
		w, ht = 0, 0
	end
	h:SetSize(max(w, size), max(ht, size))
end

local function stopDrag(h)
	if (h.dragFrom) then
		h:StopMovingOrSizing()
		h:SetUserPlaced(false)
		h.dragFrom = nil
	end
end

local function dragStop(h)
	local from = h.dragFrom
	if (not from) then
		return
	end
	stopDrag(h)
	local frame, kind = h.auraFrame, h.auraKind
	local l, b = h:GetLeft(), h:GetBottom()
	local o = frame.conf[kind]
	if (l and b) then
		-- the Settings sliders' range
		o.x = max(-300, min(300, (o.x or 0) + floor(l - from[1] + 0.5)))
		o.y = max(-300, min(300, (o.y or 0) + floor(b - from[2] + 0.5)))
	end
	-- frames share a conf (party members, party pets): every one of them moves
	for _, other in ipairs(handled) do
		if (other.conf and other.conf[kind] == o) then
			FPerl.AurasPlace(other)
			coverHandle(other, kind)
		end
	end
	if (FPerl.SettingsRefresh) then
		FPerl.SettingsRefresh()
	end
end

local function makeHandle(frame, kind)
	local h = CreateFrame("Frame", nil, frame)
	h.auraFrame, h.auraKind = frame, kind
	local tex = h:CreateTexture(nil, "OVERLAY")
	tex:SetAllPoints()
	tex:SetColorTexture(0.2, 0.6, 1, 0.35)
	local label = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("CENTER")
	label:SetText(HANDLE_LABEL[kind])
	h:EnableMouse(true)
	h:SetMovable(true)
	h:RegisterForDrag("LeftButton")
	h:SetScript("OnDragStart", function(self)
		if (inCombat or FPerl.Locked ~= 0 or FPerl.AurasSecret()) then
			return
		end
		self.dragFrom = {self:GetLeft() or 0, self:GetBottom() or 0}
		self:StartMoving()
	end)
	h:SetScript("OnDragStop", dragStop)
	-- the container moves and resizes with its auras, and the handle is not anchored to it:
	-- FPerl.AurasSyncHandles re-fits it on the 0.2 s ticker
	h:Hide()
	return h
end

local function refitHandle(frame, h)
	if (h:IsShown() and not h.dragFrom) then
		coverHandle(frame, h.auraKind)
	end
end

-- the ticker's handler; the harness's clock never fires timers in a probe run, so probes call it
function FPerl.AurasSyncHandles()
	local on = FPerl.Locked == 0 and not inCombat
	if (on == handlesOn) then
		if (on) then -- the containers move and resize with their auras: re-fit the shown handles
			for _, frame in ipairs(handled) do
				refitHandle(frame, frame.buffHandle)
				refitHandle(frame, frame.debuffHandle)
			end
		end
		return
	end
	handlesOn = on -- before the loop: coverHandle reads the container only while handles are on
	for _, frame in ipairs(handled) do
		for _, kind in ipairs({"buffs", "debuffs"}) do
			local h = frame[kind == "buffs" and "buffHandle" or "debuffHandle"]
			if (h) then
				if (on) then
					if (frame.conf[kind].enable) then
						coverHandle(frame, kind)
						h:Show()
					end
				else
					stopDrag(h)
					h:Hide()
				end
			end
		end
	end
end

local function ensureHandles(frame)
	if (frame.auraNoHandles) then
		return
	end
	if (not frame.buffHandle) then
		frame.buffHandle, frame.debuffHandle = makeHandle(frame, "buffs"), makeHandle(frame, "debuffs")
		handled[#handled + 1] = frame
	end
	for _, kind in ipairs({"buffs", "debuffs"}) do
		coverHandle(frame, kind)
		local h = frame[kind == "buffs" and "buffHandle" or "debuffHandle"]
		if (handlesOn and frame.conf[kind].enable) then
			h:Show()
		elseif (not frame.conf[kind].enable) then
			stopDrag(h)
			h:Hide()
		end
	end
end

do
	local function onRegen(event)
		inCombat = event == "PLAYER_REGEN_DISABLED"
		FPerl.AurasSyncHandles()
	end
	FPerl.On("PLAYER_REGEN_DISABLED", onRegen)
	FPerl.On("PLAYER_REGEN_ENABLED", onRegen)
	FPerl.Every(0.2, FPerl.AurasSyncHandles)
end

-- FPerl.AurasPlace(frame): sets the flow of the frame's two containers and anchors their holders. Each
-- kind (buffs.side / debuffs.side) goes to its side of the aura anchor (frame.auraAnchor, default the
-- frame), lines along the side and growing away from it, icons filling from the anchor's left / top edge
-- (right / bottom with reverse), moved by the kind's x, y. Two kinds on one side: the nearer by
-- frame.conf.auraOrder ("buffs", "debuffs", "reaction": debuffs on a unit the player can attack), the
-- other beyond it. Room for duration text (FPerl.AuraGap) sits between the frame and a TOP block and
-- between the two blocks. frame.auraInset(frame, side) is extra distance from the anchor.
function FPerl.AurasPlace(frame, fresh)
	local buffContainer, debuffContainer = frame.buffContainer, frame.debuffContainer
	-- a container built just now may be configured while auras are secret; a live one waits
	if (not buffContainer or not debuffContainer or (not fresh and not FPerl.AuraContainerGate(frame))) then
		return
	end
	local c = frame.conf
	local anchor = frame.auraAnchor or frame
	local gap = FPerl.AuraGap(c)
	local kinds = {
		buffs = {c.buffs, buffContainer, frame.buffHalfFrame},
		debuffs = {c.debuffs, debuffContainer, frame.debuffHalfFrame},
	}
	local order = c.auraOrder
	if (order == "reaction") then
		order = FPerl.SafeBool(UnitCanAttack("player", frame.partyid), false) and "debuffs" or "buffs"
	end
	local first, second = "buffs", "debuffs"
	if (order == "debuffs") then
		first, second = second, first
	end
	local near
	for _, kind in ipairs({first, second}) do
		local o, container, holder = unpack(kinds[kind])
		local side = o.side or "BOTTOM"
		local inside = not (near and near.side == side) and frame.auraInside and frame.auraInside[side]
		-- inside: the opposite side's flow, pinned to the same corner of the anchor
		local point, rel, h, v, rows, ax, ay = blockCorners(inside and OPPOSITE[side] or side, o.reverse)
		if (inside) then
			rel = point
		end
		container:SetFlowLayoutAxis(AXIS.Horizontal)
		container:SetFlowLayoutAnchorPoint(point)
		container:SetFlowLayoutGrowthDirection(h, v)
		container:ClearAllPoints()
		container:SetPoint(point, holder, point, 0, 0)
		holder:ClearAllPoints()
		holder:SetSize(1, 1)
		local away
		local target = anchor
		if (near and near.side == side) then
			-- beyond the nearer block, which is placed already: no overlap however many lines it wraps
			target, away = near.container, (rows and gap > 0) and gap or 3
		elseif (inside) then
			away = 0
		else
			away = (side == "TOP" and gap or 0) + (frame.auraInset and frame.auraInset(frame, side) or 0)
		end
		holder:SetPoint(point, target, rel, (o.x or 0) + ax * away, (o.y or 0) + ay * away)
		-- a disabled kind draws nothing, so it does not push the other one away
		if (o.enable) then
			near = near or {side = side, container = container}
		end
		frame.auraHandlePoint = frame.auraHandlePoint or {}
		frame.auraHandlePoint[kind] = point
	end
	ensureHandles(frame)
end

-- FPerl.AurasGroups(c, kind[, exclude]): the aura groups of a frame's buff or debuff container, from
-- the frame's options c and kind "buffs" or "debuffs"; a list of {key, filter, candidateFilters, size,
-- maxFrameCount, layoutIndex, cooldown, countdown}. exclude is a set of spell IDs the groups drop.
-- Reads no unit state and no aura data, so the filters apply whatever the unit's reaction.
-- One group, "other", unless an option asks for more. castable / curable (ticked = 1) add the RAID
-- token; onlyMine keeps the player's and the player's pets' auras. big splits "mine" (the player's and
-- pets', double size, first) from "other"; buffs.bigStealable adds "steal" (stealable buffs, double
-- size) and keeps them out of "other". buffs.bigpet is not read: the owner filter includes the pet.
-- lineSize (the container's line width) and buffs.rows set each group's maxFrameCount to rows x icons per
-- line, floor((lineSize + 3) / (size + 3)); without either it is math.huge, the container's own
-- default (no cap). half halves the sizes.
-- The global buffs.cooldown / countdown say whether a group's buttons draw the swipe / the duration text;
-- cooldownAny / countdownAny off limit them to the player's auras, which splits a "mine" group off
-- (at the normal size when Big is off) unless the group is all mine already.
function FPerl.AurasGroups(c, kind, exclude, lineSize, half)
	local o = c[kind]
	local rows = c.buffs.rows
	local filter = kind == "buffs" and "HELPFUL" or "HARMFUL"
	if (o[kind == "buffs" and "castable" or "curable"] == 1) then
		filter = filter.."|RAID"
	end
	local b = conf.buffs
	local split = (b.cooldown and not b.cooldownAny) or (b.countdown and not b.countdownAny and c.auraText ~= false)
	local textOff = c.auraText == false
	local gap = FPerl.AuraGap(c)
	local function group(key, size, owner, stealable)
		local cand
		if (exclude or owner ~= nil or stealable ~= nil) then
			cand = {excludeSpellIDs = exclude, isFromPlayerOrPlayerPet = owner, isStealable = stealable}
		end
		return {
			key = key,
			filter = filter,
			candidateFilters = cand,
			size = size,
			maxFrameCount = (lineSize and rows and size) and rows * max(1, floor((lineSize + 3) / (size + 3))) or math.huge,
			layoutIndex = 1,
			-- the swipe and the text are one global for buffs and debuffs
			cooldown = b.cooldown and (b.cooldownAny or owner == true) and true or false,
			countdown = not textOff and b.countdown and (b.countdownAny or owner == true) and true or false,
			gap = gap,
		}
	end
	local size = o.size
	if (half and size) then
		size = size / 2
	end
	local big = o.big and size and size * 2
	if (o.onlyMine) then
		return {group(big and "mine" or "other", big or size, true)}
	end
	local mineSize = big or (split and size)
	local steal = kind == "buffs" and o.bigStealable
	-- false when the sibling groups take the other side of the split, else nil (no constraint)
	local notMine, notSteal
	if (mineSize) then
		notMine = false
	end
	if (steal) then
		notSteal = false
	end
	local list = {}
	if (mineSize) then
		list[#list + 1] = group("mine", mineSize, true)
	end
	if (steal) then
		list[#list + 1] = group("steal", size and size * 2, notMine, true)
	end
	list[#list + 1] = group("other", size, notMine, notSteal)
	for n, g in ipairs(list) do
		g.layoutIndex = n
	end
	return list
end

-- the container's line width for kind "buffs" or "debuffs"
local function lineSizeOf(frame, kind)
	return frame.auraLineSize(frame, kind)
end

-- FPerl.AurasRebuild(frame): builds the containers, or, once built and while auras are readable,
-- tears them down and builds them again from the current options and unit.
function FPerl.AurasRebuild(frame)
	local c = frame.conf
	frame.auraLineSize = frame.auraLineSize or FPerl.AurasLineSize
	if (not c or not frame.partyid or not FPerl.HasAuraContainerNow()) then
		return
	end
	if (not UnitExists(frame.partyid)) then
		-- the unit is back later: Update applies the request then
		if (frame.buffContainer) then
			frame.auraContainerPending = true
		end
		return
	end
	local fresh = not frame.buffContainer
	if (not fresh) then
		if (not FPerl.AuraContainerGate(frame)) then
			return
		end
		frame.buffContainer:Hide()
		frame.debuffContainer:Hide()
		frame.buffContainer, frame.debuffContainer = nil, nil
	end

	-- debuffs.halfSize (party): half-size debuffs while Update found more than fit the line
	local half = c.debuffs.halfSize and frame.auraHalf or false
	frame.auraHalf = half
	frame.auraContainerPending = nil
	local exclude = FPerl.AuraBlacklist.Set and FPerl.AuraBlacklist.Set(frame)
	local buffLine, debuffLine = lineSizeOf(frame, "buffs"), lineSizeOf(frame, "debuffs")
	local buffContainer = FPerl.AuraContainerCreate(frame, "buffHalfFrame",
		frame:GetName().."AuraBuffs", FPerl.AurasGroups(c, "buffs", exclude, buffLine), buffLine)
	local debuffContainer = FPerl.AuraContainerCreate(frame, "debuffHalfFrame",
		frame:GetName().."AuraDebuffs", FPerl.AurasGroups(c, "debuffs", nil, debuffLine, half), debuffLine)
	frame.buffContainer, frame.debuffContainer = buffContainer, debuffContainer
	if (frame.auraContainerPending) then
		-- Create left a live container as it was (auras secret): placing it would reconfigure it
		return
	end
	FPerl.AurasPlace(frame, fresh)
end

-- the container's own auto-refresh event list does not include UNIT_AURA: refresh on every show
-- a SetUnit that raises (a live container, auras secret) leaves the rebuild pending, which sets the unit
local function showContainer(frame, container, unit, enabled)
	-- while secret a pending frame waits for the rebuild instead of retrying (and reporting) each event
	if (container:GetUnit() ~= unit) then
		-- the container still tracks the old unit: hidden until the rebuild applies
		if (not FPerl.AuraContainerGate(frame) or not FPerl.Pcall(container.SetUnit, container, unit)) then
			frame.auraContainerPending = true
			if (container:IsShown()) then
				container:Hide()
			end
			return
		end
	end
	if (enabled) then
		if (not container:IsShown()) then
			container:Show()
		end
		if (container.UpdateAllAuras) then
			container:UpdateAllAuras()
		end
	elseif (container:IsShown()) then
		container:Hide()
	end
end

-- debuffs.halfSize (party): while auras are readable, half the
-- debuff size when more debuffs than fit the line, full size when they fit; a change rebuilds. While
-- secret the size stays.
local halfFilters = {}
local function checkHalfSize(frame, c, unit)
	local d = c.debuffs
	if (not d.halfSize or not d.enable or not d.size or not frame.debuffContainer or FPerl.AurasSecret()) then
		return
	end
	local key = (d.curable == 1 and 2 or 0) + (d.onlyMine and 1 or 0)
	local filter = halfFilters[key]
	if (not filter) then
		filter = "HARMFUL"..(d.curable == 1 and "|RAID" or "")..(d.onlyMine and "|PLAYER" or "")
		halfFilters[key] = filter
	end
	-- the id list is the only way to count the debuffs against the line; it is the API's table, one per
	-- UNIT_AURA of a party frame with halfSize on
	local ids = C_UnitAuras.GetUnitAuraInstanceIDs(unit, filter)
	local fit = max(1, floor((lineSizeOf(frame, "debuffs") + 3) / (d.size + 3)))
	local half = ids ~= nil and #ids > fit
	if (half ~= (frame.auraHalf or false)) then
		frame.auraHalf = half
		FPerl.AurasRebuild(frame)
	end
end

-- FPerl.AurasUpdate(frame): shows the display that owns the auras now and refreshes it.
function FPerl.AurasUpdate(frame)
	local c = frame.conf
	local unit = frame.partyid
	if (not c or not unit or not UnitExists(unit)) then
		return
	end
	if (frame.auraContainerPending or not frame.buffContainer) then
		FPerl.AurasRebuild(frame)
	end
	local buffContainer, debuffContainer = frame.buffContainer, frame.debuffContainer
	if (not buffContainer) then
		return
	end
	checkHalfSize(frame, c, unit)

	local buffs, debuffs = c.buffs.enable, c.debuffs.enable
	if (frame.auraDebuffsNeedBuffs) then
		debuffs = buffs and debuffs
	end
	showContainer(frame, buffContainer, unit, buffs)
	showContainer(frame, debuffContainer, unit, debuffs)
end

-- Aura secrecy can flip after the combat event has been dispatched: run again one tick later.
local function updateAurasInCombatChange(frame)
	FPerl.AurasUpdate(frame)
	C_Timer.After(0, function()
		FPerl.AurasUpdate(frame)
	end)
end
local function updateAuras(frame, unit)
	if (unit == frame.partyid) then
		FPerl.AurasUpdate(frame)
	end
end
FPerl.Elements.Auras = {events = {
	UNIT_AURA = updateAuras,
	PLAYER_REGEN_DISABLED = updateAurasInCombatChange,
	PLAYER_REGEN_ENABLED = updateAurasInCombatChange,
}}
