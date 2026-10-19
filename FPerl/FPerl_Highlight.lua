-- Author: Resike
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

local playerClass
local conf
FPerl.RequestConfig(function(new)
	conf = new
end, "$Revision:  $")

local _G = _G

local cos = cos
local format = format
local min = min
local pairs = pairs
local random = random
local sin = sin
local strfind = strfind
local tinsert = tinsert
local type = type

local CreateFrame = CreateFrame
local GetTime = GetTime
local UnitCastingInfo = UnitCastingInfo
local UnitClass = UnitClass
local UnitGetIncomingHeals = UnitGetIncomingHeals
local UnitGUID = UnitGUID
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsUnit = UnitIsUnit
local UnitPlayerOrPetInParty = UnitPlayerOrPetInParty
local UnitPlayerOrPetInRaid = UnitPlayerOrPetInRaid

local SecureButton_GetUnit = SecureButton_GetUnit

local new = FPerl.GetReusableTable

local hotSpells  = FPERL_HIGHLIGHT_SPELLS.hotSpells
local shieldSpells = FPERL_HIGHLIGHT_SPELLS.shieldSpells

-- secret value helpers from FPerl.lua
local CanAccess = FPerl.CanAccess
local UnitAuraByIndex = FPerl.UnitAuraByIndex
local colours = {
	HOT = {r = 0.2, g = 0.4, b = 0.8, canFlash = true},
	SHIELD = {r = 0.6, g = 0.1, b = 0.6, canFlash = true},
	AGGRO = {r = 0.8, g = 0, b = 0},
	HEAL = {r = 0.2, g = 0.8, b = 0.2},
	SEL = {r = 0.86, g = 0.82, b = 0.41},
	TARGET = {r = 0.7167, g = 0.6833, b = 0.31467} -- Coloured so that colour * 1.2 == SEL colour
}

local xpHigh = FPerl_Highlight or CreateFrame("Frame", "FPerl_Highlight", nil, BackdropTemplateMixin and "BackdropTemplate")
-- the two colours of a two-highlight gradient, refilled per call (SetGradient copies the values)
local gradFrom, gradTo = CreateColor(0, 0, 0, 1), CreateColor(0, 0, 0, 1)
xpHigh.list = {}
xpHigh.callbacks = {}
xpHigh.flashers = {}

-- rotate
-- Positive angle is clockwise rotation
local function rotate(angle)
	local hcos = 0.5 * cos(angle)
	local mhcos = -hcos
	local hsin = 0.5 * sin(angle)
	local mhsin = -hsin
	local ULx, ULy, LLx, LLy = hcos - mhsin, mhsin + hcos, hcos - hsin, mhsin + mhcos
	local URx, URy, LRx, LRy = mhcos - mhsin, hsin + hcos, mhcos - hsin, hsin + mhcos
	return ULx + 0.5, ULy + 0.5, LLx + 0.5, LLy + 0.5, URx + 0.5, URy + 0.5, LRx + 0.5, LRy + 0.5
end

-- FPerl_Highlight:Add
function xpHigh:Add(guid, highlightType, duration, source)
	if (not guid or not CanAccess(guid)) then
		return
	end
	if (not strfind(guid, "-")) then
		guid = self.lookup and self.lookup[guid]
	end

	local a = self.list[guid]
	if (not a) then
		a = new()
		self.list[guid] = a
	end

	if (not duration) then
		a[highlightType] = nil
		self:Send(guid)
	else
		if (duration == 0) then
			a[highlightType] = 0
			self:Send(guid)
		else
			-- one Send per aura event, only while the HOTCOUNT option has registered UNIT_AURA; the callbacks redraw one frame
			if (highlightType == "HOTCOUNT") then
				a[highlightType] = duration
				self:Send(guid)
			else
				local newEndTime = GetTime() + duration
				if (highlightType == "HEAL" and (UnitInRaid(source) or UnitInParty(source))) then
					if (source and not FPerl.SafeBool(UnitIsUnit("player", source), false)) then
						-- We'll query their cast bar and get accurate highlight time info
						local spellName, _, _, _, endTime = UnitCastingInfo(source)
						if (spellName and CanAccess(endTime)) then
							newEndTime = endTime / 1000
						end

						--newEndTime = newEndTime + 0.8		-- Add some because other highlights expire 1 sec early
					end
				end

				local current = a[highlightType]
				if (not current or current < newEndTime) then
					a[highlightType] = newEndTime
					self:Send(guid)
				end
			end
		end
	end
end

-- xpHigh:TooltipInfo
function xpHigh:TooltipInfo(guid)
	if (not guid or not CanAccess(guid)) then
		return
	end
	local effects = self.list[guid]
	if (effects) then
		local str = ""
		local prefix = FPERL_LOC_STATUSTIP
		for k,v in pairs(effects) do
			local desc = FPERL_LOC_STATUSTIPLIST[k]
			local c = colours[k]
			if (desc and c) then
				str = str..prefix..format("|c00%02X%02X%02X", 255 * c.r, 255 * c.g, 255 * c.b)..desc.."|r"
				prefix = ", "
			end
		end

		if (prefix == ", ") then
			GameTooltip:AddLine("\r"..str)
			GameTooltip:Show()
		end
	end
end

-- xpHigh:Remove
function xpHigh:Remove(guid, highlightType)
	if (not guid or not CanAccess(guid)) then
		return
	end
	if (not strfind(guid, "-")) then
		guid = self.lookup and self.lookup[guid]
	end

	local a = self.list[guid]
	if (a) then
		a[highlightType] = nil
		self:Send(guid)
	end
end

-- xpHigh:HasEffect
function xpHigh:HasEffect(guid, effect)
	if (not guid or not CanAccess(guid)) then
		return
	end
	if (not strfind(guid, "-")) then
		guid = self.lookup and self.lookup[guid]
	end

	local list = self.list[guid]
	if (list) then
		return list[effect]
	end
end

-- xpHigh:OnUpdate
-- The roster refresh, one video frame after the last GROUP_ROSTER_UPDATE
function xpHigh:RosterUpdate()
	if (self.rosterUpdate) then
		self.rosterUpdate = nil
		self:RefreshAllAuras() -- New roster, get all
	end
end

local function expireTick() xpHigh:Expire() end

-- The expiry check, every 0.2 s on the scheduler while HOT / SHIELD / HEAL highlights are on
function xpHigh:Expire()
	-- We expire things 1 second early so people can cast in time for buff to expire
	local now = GetTime() --  + 1

	for guid, list in pairs(self.list) do
		local any
		for k, v in pairs(list) do
			any = true
			if (k ~= "HOTCOUNT") then
				if (v > 0) then
					if (v <= now) then
						self.flashers[guid] = nil
						list[k] = nil
						self:Send(guid)
					elseif (v <= now + 5 and colours[k] and colours[k].canFlash) then
						if (not self.flashers[guid]) then
							self.flashers[guid] = k
							self:Send(guid)
						end
					end
				end
			end
		end

		if (not any) then
			self.list[guid] = nil
			self.flashers[guid] = nil
		end
	end
end

-- xpHigh:Query
function xpHigh:SetHighlight(frame, guid)
	if (not frame.highlight) then
		FPerl.Notice("No .highlight region for "..frame:GetName())
		return
	end

	local unitid
	if (not guid) then
		unitid = SecureButton_GetUnit(frame)
		if (unitid) then
			guid = UnitGUID(unitid)
		else
			return
		end
	end

	-- a secret GUID (creatures inside instances) has no entry
	if (guid and not CanAccess(guid)) then
		guid = nil
	end

	self:RosterUpdate()

	local hotCount, hotBar
	if (guid and conf.highlight.enable) then
		local r = self.list[guid]
		if (r) then
			local r1, g1, b1, r2, g2, b2, t1
			for k, v in pairs(r) do
				if (k == "HOTCOUNT") then
					hotCount = v
				elseif (k == "HOT" and conf.highlight.sparkles) then
					hotBar = true
				else
					if (not r1 or t1 == "TARGET") then
						if frame == FPerl_Player or frame == FPerl_Player_Pet or frame == FPerl_Target or frame == FPerl_TargetTarget or frame == FPerl_TargetTargetTarget or frame == FPerl_Focus or frame == FPerl_FocusTarget or frame == FPerl_partypet1 or frame == FPerl_partypet2 or frame == FPerl_partypet3 or frame == FPerl_partypet4 or frame == FPerl_partypet5 or strmatch(frame:GetName(), "FPerl_Raid_GrpPetsUnitButton") then
						else
							t1 = k
							r1, g1, b1 = colours[k].r, colours[k].g, colours[k].b
						end
					else
						r2, g2, b2 = colours[k].r, colours[k].g, colours[k].b
						break
					end
				end
			end

			if (r1) then
				frame.highlight.tex:Show()
				frame.highlight.tex:SetAlpha(1)

				if (frame.highlight.sel) then
					r1 = min(r1 * 1.2, 1)
					g1 = min(g1 * 1.2, 1)
					b1 = min(b1 * 1.2, 1)
				end

				if (r2) then
					if (frame.highlight.sel) then
						r2 = min(r2 * 1.2, 1)
						g2 = min(g2 * 1.2, 1)
						b2 = min(b2 * 1.2, 1)
					end
					gradFrom.r, gradFrom.g, gradFrom.b, gradTo.r, gradTo.g, gradTo.b = r1, g1, b1, r2, g2, b2
					frame.highlight.tex:SetGradient("HORIZONTAL", gradFrom, gradTo)
				else
					frame.highlight.tex:SetVertexColor(r1, g1, b1)
				end

				if (self.flashers[guid]) then
					FPerl.FrameFlash(frame.highlight.tex)
				else
					FPerl.FrameFlashStop(frame.highlight.tex)
				end
				self:ShowHotCount(frame, hotCount)
				self:ShowHotBar(frame, hotBar)
				return
			end
		end
	end

	self:RemoveHighlight(frame)
	self:ShowHotCount(frame, hotCount)
	self:ShowHotBar(frame, hotBar)
end

-- fluctuateOnUpdate
local function fluctuateOnUpdate(self, elapsed)
	if (self.fluctuate) then
		if (self.fluctuate == "dim" or self.fluctuate == "notbright") then
			self.fluctuatingBrightness = self.fluctuatingBrightness - elapsed
			if (self.fluctuatingBrightness < 0.5) then
				if (self.fluctuate == "dim") then
					self.fluctuatingBrightness = 0.5
					self.fluctuate = "notdim"
				else
					self.fluctuatingBrightness = nil
					self.fluctuate = nil
				end
			end
		elseif (self.fluctuate == "notdim" or self.fluctuate == "bright") then
			self.fluctuatingBrightness = self.fluctuatingBrightness + elapsed
			if (self.fluctuatingBrightness >= 1) then
				if (self.fluctuate == "notdim") then
					self.fluctuatingBrightness = nil
					self.fluctuate = nil
				else
					self.fluctuatingBrightness = 1
					self.fluctuate = "notbright"
				end
			end
		end
	elseif (random(10) == 1) then
		self.fluctuate = random(3) == 2 and "dim" or "bright"
		self.fluctuatingBrightness = 1
	end

	return self.fluctuatingBrightness or 1
end

-- hotBarOnUpdate
local function hotBarOnUpdate(self, elapsed)
	local _, Max = self:GetMinMaxValues()
	local val = self:GetValue()
	if (self.movementMod) then
		val = val - elapsed
		if (val <= 0) then
			self:Hide()
			return
		end

		self:SetValue(val)
	end

	local sparkPosition = self:GetWidth() * (val / Max)
	self.spark:SetPoint("CENTER", self, "LEFT", sparkPosition, 0)

	self.angle = self.angle + elapsed
	if (self.angle > 360) then
		self.angle = self.angle - 360
	end

	local ULx, ULy, LLx, LLy, URx, URy, LRx, LRy = rotate(self.angle)
	self.spark:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
	self.shine:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)

	local a
	if (val < 5) then
		if (self.alphaPulse == "in") then
			a = self.alpha + elapsed * 2
			if (a >= 1) then
				a = 1
				self.alphaPulse = "out"
			end
		else
			a = self.alpha - elapsed * 2
			if (a < 0.3) then
				a = 0.3
				self.alphaPulse = "in"
			end
		end
	else
		a = 1
		self.alphaPulse = "out"
	end

	self.spark:SetVertexColor(1, 1, 1, a * fluctuateOnUpdate(self.spark, elapsed))
	self.shine:SetVertexColor(1, 1, 1, a * fluctuateOnUpdate(self.shine, elapsed))
	self.alpha = a
end

-- CreateShine
function xpHigh:CreateShine(parent)
	local shine = parent:CreateTexture(nil, "OVERLAY")
	shine:SetTexture(166928)
	shine:SetBlendMode("ADD")
	shine:SetWidth(12)
	shine:SetHeight(12)
	return shine
end

-- CreateHotBar
function xpHigh:CreateHotBar(frame)
	local parent = frame.healthBar
	if (not parent) then
		parent = frame.statsFrame and frame.statsFrame.healthBar
	end
	if (not parent) then
		return
	end

	local f = CreateFrame("StatusBar", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
	frame.highlight.hotBar = f
	f:SetPoint("TOPLEFT")
	f:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", 0, -4)
	f:SetMinMaxValues(0, 0.1)
	f:Hide()
	f.movementMod = 1

	f.spark = self:CreateShine(f)
	f.shine = self:CreateShine(f)
	f.shine:SetPoint("CENTER", f, "LEFT")

	f:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	f:GetStatusBarTexture():SetHorizTile(false)
	f:GetStatusBarTexture():SetVertTile(false)
	f:SetStatusBarColor(1, 1, 0)

	f:SetScript("OnUpdate", hotBarOnUpdate)
	f:SetScript("OnShow", function(self)
		self.angle = 0
		self.alpha = 1
		self.alphaPulse = "out"
	end)
end

-- GetMyHotTime
-- aura names and times are secret in restricted content, so a
-- HOT that cannot be read simply does not count. Blizzard blocks this on purpose.
function xpHigh:GetMyHotTime(unit)
	local maxDur, maxTimeLeft = 0, 0
	for i = 1, 40 do
		local name, duration, expirationTime
		local _
		name, _, _, _, duration, expirationTime = UnitAuraByIndex(unit, i, "HELPFUL|PLAYER")
		if (not name) then
			break
		end

		if (CanAccess(name) and hotSpells[name] and CanAccess(expirationTime) and CanAccess(duration)) then
			local timeLeft = expirationTime - GetTime()
			if (timeLeft > maxTimeLeft) then
				maxDur, maxTimeLeft = duration, timeLeft
			end
		end
	end
	return maxDur, maxTimeLeft
end

-- ShowHotBar
function xpHigh:ShowHotBar(frame, show)
	local h = frame.highlight
	if (show and conf.highlight.HOT and conf.highlight.sparkles) then
		local unit = SecureButton_GetUnit(frame)
		if (unit) then
			local dur, timeLeft = self:GetMyHotTime(unit)
			if (dur and dur > 0) then
				if (not h.hotBar) then
					self:CreateHotBar(frame)
				end

				local _, b = h.hotBar:GetMinMaxValues()
				if (b > dur) then
					-- Changing HOTs shouldn't make the bar jump with varying buff durations, just use the max so far.
					dur = b
				end

				h.hotBar.unit = unit
				h.hotBar:SetMinMaxValues(0, dur)
				h.hotBar:SetValue(timeLeft)
				h.hotBar:Show()
				return
			end
		end
	end

	if (h.hotBar) then
		h.hotBar:Hide()
		h.hotBar:SetMinMaxValues(0, 0.1)
	end
end

-- xpHigh:CreateHotCount(frame)
function xpHigh:CreateHotCount(frame)

	local f = frame.highlight:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
	frame.highlight.hot = f

	f:SetTextColor(0, 1, 0)
	f:Hide()

	local sf = _G[frame:GetName().."statsFrame"]
	if (sf) then
		if (strfind(frame:GetName(), "FPerl_Raid_Grp")) then
			f:SetTextHeight(15)
			f:SetPoint("TOPLEFT", sf, "TOPLEFT", 3, -3)
		else
			f:SetPoint("TOPLEFT", sf, "TOPLEFT", 5, -8)
		end
	else
		if (strfind(frame:GetName(), "FPerl_Raid_GrpPets")) then
			f:SetTextHeight(15)
			f:SetPoint("TOPLEFT", 3, -3)
		else
			f:SetPoint("CENTER", 0, 0)
		end
	end
end

-- xpHigh:HasMyHOT(unit)
function xpHigh:HasMyHOT(unit)
	for i = 1, 40 do
		local name
		name = UnitAuraByIndex(unit, i, "HELPFUL|PLAYER")
		if not name then
			break
		end
		if CanAccess(name) and hotSpells[name] then
			return true
		end
	end
end

-- ShowHotCount
function xpHigh:ShowHotCount(frame, hotCount, unitid)
	local h = frame.highlight
	if (conf.highlight.HOTCOUNT) then
		if (hotCount and hotCount > 0) then
			if (not h.hot) then
				self:CreateHotCount(frame)
			end

			h.hot:SetText(hotCount)
			h.hot:Show()

			local unit = SecureButton_GetUnit(frame)
			if (unit and self:HasMyHOT(unit)) then
				h.hot:SetTextColor(0, 1, 0)
			else
				h.hot:SetTextColor(0.8, 0, 0)
			end
			return
		end
	end

	if (h.hot) then
		h.hot:Hide()
	end
end

-- xpHigh:RemoveHighlight
function xpHigh:RemoveHighlight(frame)
	FPerl.FrameFlashStop(frame.highlight.tex)

	frame.highlight.tex:SetVertexColor(0.86, 0.82, 0.41)	-- Default selection colour

	if (frame.highlight.sel and conf.highlightSelection) then
		frame.highlight.tex:Show()
		frame.highlight.tex:SetAlpha(1)
	else
		frame.highlight.tex:Hide()
	end
end

-- xpHigh:ClearAll
function xpHigh:ClearAll(clearType)
	for k, v in pairs(self.list) do
		if (v[clearType]) then
			v[clearType] = nil
			self:Send(k)
		end
	end
end

-- xpHigh:Send
function xpHigh:Send(guid)
	for k, v in pairs(self.callbacks) do
		v[1](v[2], guid)
	end
end

-- FPerl_RegisterFrameHighlighter
function xpHigh:Register(callback, slf)
	tinsert(self.callbacks, {callback, slf})
end

-- Bus listeners (FPerl.On) for the events OptionChange turns on and off.
local busFn = {
	UNIT_HEAL_PREDICTION = function(_, unit) xpHigh:UNIT_HEAL_PREDICTION(unit) end,
	UNIT_AURA = function(_, unit) xpHigh:UNIT_AURA(unit) end,
	GROUP_ROSTER_UPDATE = function() xpHigh:GROUP_ROSTER_UPDATE() end,
}
local busOn = {}
local function listen(event, on)
	if (on == (busOn[event] or false)) then
		return
	end
	busOn[event] = on
	if (on) then
		FPerl.On(event, busFn[event])
	else
		FPerl.Off(event, busFn[event])
	end
end

-- UNIT_HEAL_PREDICTION
function xpHigh:UNIT_HEAL_PREDICTION(unit)
	local guid = UnitGUID(unit)
	if (conf.highlight and conf.highlight.HEAL) then
		local amount = UnitGetIncomingHeals(unit) or 0
		-- a secret heal amount cannot be tested, so no highlight
		if (CanAccess(amount) and amount > 0 and not UnitIsDeadOrGhost(unit)) then
			local health, healthmax = UnitHealth(unit), UnitHealthMax(unit)
			if (CanAccess(health) and CanAccess(healthmax)) then
				local missing = healthmax - health
				if (missing > healthmax / 20) then -- More than 5% to heal
					self:Add(guid, "HEAL", amount)
					return
				end
			end
		end
	end
	self:Remove(guid, "HEAL")
end

-- xpHigh:HasMyShield(unit)
function xpHigh:HasMyShield(unit)
	for i = 1, 40 do
		local name, expirationTime
		local _
		name, _, _, _, _, expirationTime = UnitAuraByIndex(unit, i, "HELPFUL|PLAYER")
		if not name then
			break
		end
		if (CanAccess(name) and shieldSpells[name] and CanAccess(expirationTime)) then
			return expirationTime - GetTime()
		end
	end
end

-- RemoveAllFromGUID
function xpHigh:RemoveAllFromGUID(unit)
	local guid = UnitGUID(unit)
	if guid and CanAccess(guid) and self.list[guid] then
		self.list[guid] = nil
		self:Send(guid)
	end
end

-- xpHigh:UNIT_AURA
-- Scans the unit's auras per event (up to three 40-slot loops) because the client gives no list of
-- who cast an aura or when it expires without iterating; the event names the unit, not the change.
function xpHigh:UNIT_AURA(unit)
	if not UnitInParty(unit) and not UnitPlayerOrPetInRaid(unit) and not UnitPlayerOrPetInParty(unit) then
		return
	end

	local guid = UnitGUID(unit)
	if (not CanAccess(guid)) then
		return
	end
	if UnitIsDeadOrGhost(unit) then
		self:RemoveAllFromGUID(unit)
		return
	end

	-- our own HOTs and shields are found from the unit's auras
	if (conf.highlight.HOT) then
		local _, timeLeft = self:GetMyHotTime(unit)
		if (timeLeft > 0) then
			if (not self:HasEffect(guid, "HOT")) then
				self:Add(guid, "HOT", timeLeft)
			end
		else
			self:Remove(guid, "HOT")
		end
	end
	if (conf.highlight.SHIELD) then
		local timeLeft = self:HasMyShield(unit)
		if (timeLeft and timeLeft > 0) then
			if (not self:HasEffect(guid, "SHIELD")) then
				self:Add(guid, "SHIELD", timeLeft)
			end
		else
			self:Remove(guid, "SHIELD")
		end
	end

	-- Check for pre-mature end of shield buff (Power Word: Shield, Earth Shield)
	if playerClass == "SHAMAN" then	-- or playerClass == "PRIEST") then
		if self:HasEffect(guid, "SHIELD") then
			if not self:HasMyShield(unit) then
				self:Remove(guid, "SHIELD")
			end
		end
	end

	if conf.highlight.HOTCOUNT then
		local hotCount = 0
		for i = 1, 40 do
			local name
			name = UnitAuraByIndex(unit, i, "HELPFUL")
			if not name then
				break
			end
			if CanAccess(name) and hotSpells[name] then
				hotCount = hotCount + 1
			end
		end

		if hotCount == 0 then
			self:Remove(guid, "HOTCOUNT")
		else
			self:Add(guid, "HOTCOUNT", hotCount)
		end
	end
end

-- xpHigh:GROUP_ROSTER_UPDATE
local function rosterUpdateNow()
	xpHigh:RosterUpdate()
end

function xpHigh:GROUP_ROSTER_UPDATE()
	if (not self.rosterUpdate) then
		self.rosterUpdate = true
		C_Timer.After(0, rosterUpdateNow)
	end
end

xpHigh.GROUP_ROSTER_UPDATE = xpHigh.GROUP_ROSTER_UPDATE

-- xpHigh:RefreshAllAuras
function xpHigh:RefreshAllAuras()
	for unitid in FPerl.NextMember do
		self:UNIT_AURA(unitid)
	end
end

-- xpHigh:OptionChange
function xpHigh:OptionChange()

	local _
	_, playerClass = UnitClass("player")

	if (not conf.highlight.enable or not conf.highlight.HOT) then
		self:ClearAll("HOT")
	end
	if (not conf.highlight.enable or not conf.highlight.SHIELD) then
		self:ClearAll("SHIELD")
	end

	if type(UnitGetIncomingHeals) == "function" then
		if (conf.highlight.enable and conf.highlight.HEAL) then
			listen("UNIT_HEAL_PREDICTION", true)
		else
			listen("UNIT_HEAL_PREDICTION", false)
			self:ClearAll("HEAL")
		end
	end

	if (conf.highlight.enable and (conf.highlight.HOTCOUNT or conf.highlight.HOT or conf.highlight.SHIELD)) then
		listen("UNIT_AURA", true)
		listen("GROUP_ROSTER_UPDATE", true)
		self:RefreshAllAuras()
	else
		listen("UNIT_AURA", false)
		listen("GROUP_ROSTER_UPDATE", false)
		self:ClearAll("HOTCOUNT")
		self:ClearAll("HOT")
		self:ClearAll("SHIELD")
	end

	if (not conf.highlight.AGGRO) then
		FPerl_Highlight:ClearAll("AGGRO")
	end

	-- a highlight ends by the clock and no event fires at its end, so the expiry is polled, only while a timed type is on
	if (conf.highlight.enable and (conf.highlight.HOT or conf.highlight.SHIELD or conf.highlight.HEAL)) then
		FPerl.Every(0.2, expireTick)
	else
		FPerl.Cancel(expireTick)
	end
end

FPerl.RegisterOptionChanger(xpHigh.OptionChange, xpHigh, "highlight")
