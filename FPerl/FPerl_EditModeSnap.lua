-- Two-way snap: while Edit Mode is open, out of combat, and FPerl.layout.editModeSnapToFPerl is on, Blizzard frames snap
-- to F-Perl's root unit frames (FPerl.DefaultPoints entries with a partyid; party and raid members are not registered).
-- Each gets the methods Edit Mode calls on a magnetic frame and is registered with EditModeMagnetismManager; every other
-- state unregisters it. Blizzard calls these methods in its drag and drop path, which then moves the action bars.

local registered = {}

-- Edit Mode checks HasValidSelectionRect before snapping to a frame, so a frame hidden while Edit Mode is open stops
-- attracting, and one shown later starts, without a new registration.
local function hasRect(self) return self:IsVisible() and self:GetRect() ~= nil end
local function sides(self)
	local left, bottom, width, height = self:GetRect()
	local s = self:GetScale()
	return left * s, (left + width) * s, bottom * s, (bottom + height) * s
end
-- A saved layout anchored to an F-Perl frame name applies tainted at the next login and loses the bar while F-Perl is
-- off. Breaking the snap re-anchors the system to UIParent at the same spot, so the layout never names an F-Perl frame.
local function addSnapped(_, system) if (system and system.BreakFrameSnap) then system:BreakFrameSnap() end end
-- The system still records the F-Perl frame as snappedToFrame and calls this when it clears the snap, also after Edit
-- Mode closes, so the methods stay on the frame after it is unregistered.
local function removeSnapped() end

local function register(frame)
	local mixin = EditModeSystemMixin
	frame.HasValidSelectionRect = hasRect
	frame.GetScaledSelectionSides = sides
	frame.GetScaledSelectionCenter = mixin.GetScaledCenter
	-- Without it Edit Mode compares the frame's unscaled GetCenter with the system's scaled center.
	frame.GetScaledCenter = mixin.GetScaledCenter
	frame.IsToTheLeftOfFrame = mixin.IsToTheLeftOfFrame
	frame.IsAboveFrame = mixin.IsAboveFrame
	frame.AddSnappedFrame = addSnapped
	frame.RemoveSnappedFrame = removeSnapped
	EditModeMagnetismManager:RegisterFrame(frame)
	registered[frame] = true
end

-- FPerl.EditModeSnapUpdate(inCombat): inCombat is true from PLAYER_REGEN_DISABLED, which runs before the lockdown shows.
-- Registration ends in combat because the drop path that runs these addon methods moves protected action bars.
function FPerl.EditModeSnapUpdate(inCombat)
	local mgr = EditModeMagnetismManager
	if (not mgr or not EditModeSystemMixin) then return end
	if (FPerl.InEditMode and FPerl.layout and FPerl.layout.editModeSnapToFPerl and not inCombat and not InCombatLockdown()) then
		for name in pairs(FPerl.DefaultPoints) do
			local f = _G[name]
			if (type(f) == "table" and f.partyid and not registered[f]) then register(f) end
		end
	else
		for f in pairs(registered) do mgr:UnregisterFrame(f) end
		registered = {}
	end
end

FPerl.On("PLAYER_REGEN_DISABLED", function() FPerl.EditModeSnapUpdate(true) end)
FPerl.On("PLAYER_REGEN_ENABLED", function() FPerl.EditModeSnapUpdate() end)
FPerl.RegisterOptionChanger(function() FPerl.EditModeSnapUpdate() end, nil, "editmodesnap")
