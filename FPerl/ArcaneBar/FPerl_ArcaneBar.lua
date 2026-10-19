-- Author: Resike
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

local ArcaneBars = {}

--[===[@debug@
local function d(...)
	ChatFrame1:AddMessage("F-Perl: "..format(...))
end
--@end-debug@]===]

local conf
FPerl.RequestConfig(function(new)
	conf = new
end, "$Revision:  $")


local min = min
local max = max
local pairs = pairs
local format = format
local strfind = strfind

local GetTime = GetTime
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local GetNetStats = GetNetStats
local CreateColor = CreateColor
local CreateFrame = CreateFrame

-- cast times of other units can be secret in restricted content.
-- When the client offers duration objects the bar is driven by Blizzard
-- (SetTimerDuration); otherwise a simple sweep animation is shown.
local CanAccess = FPerl.CanAccess
local IsSecret = FPerl.IsSecret
local UnitCastingDuration = UnitCastingDuration
local UnitChannelDuration = UnitChannelDuration

-- SetSecretTimes
-- Called instead of the start/end time maths when those values are secret
local function SetSecretTimes(self, channeling)
	self.startTime, self.maxValue, self.endTime = nil, nil, nil
	self.timerDuration, self.unknownTime = nil, nil
	self.tex:SetTexCoord(0, 1, 0, 1)

	local durationObject
	if (self.SetTimerDuration) then
		if (channeling and UnitChannelDuration) then
			durationObject = UnitChannelDuration(self.unit)
		elseif (not channeling and UnitCastingDuration) then
			durationObject = UnitCastingDuration(self.unit)
		end
	end

	if (durationObject) then
		self:SetTimerDuration(durationObject)
		self.timerDuration = true
	else
		-- Nothing about the cast can be read: breathe the bar until it ends
		self:SetMinMaxValues(0, 1)
		self:SetValue(0)
		self.unknownTime = true
		self.breathLevel, self.breathDir = 0, 1
	end
end

-- ClearSecretTimes
local function ClearSecretTimes(self)
	if (self.timerDuration) then
		self:SetMinMaxValues(0, 1)
		self:SetValue(1)
	end
	self.timerDuration, self.unknownTime = nil, nil
end

-- SecureUpdate
-- OnUpdate for bars whose cast times are secret
local function SecureUpdate(self, elapsed)
	if (self.unknownTime) then
		-- Fill for 1.2 s, drain for 1.2 s, repeat
		local level = self.breathLevel + (elapsed / 1.2) * self.breathDir
		if (level >= 1) then
			level, self.breathDir = 1, -1
		elseif (level <= 0) then
			level, self.breathDir = 0, 1
		end
		self.breathLevel = level
		self:SetValue(level)
		self.castTimeText:Hide()
	elseif (self.GetRemainingTime) then
		self.castTimeText:SetFormattedText("%.1f", self:GetRemainingTime())
	else
		self.castTimeText:Hide()
	end

	-- Whoever moved the fill, the spark sits on its leading edge
	if (self.barSpark) then
		local fill = self:GetStatusBarTexture()
		if (fill) then
			self.barSpark:ClearAllPoints()
			self.barSpark:SetPoint("CENTER", fill, "RIGHT", 0, 1)
		end
	end
	self.barFlash:Hide()
	if (self.precast) then
		self.precast:Hide()
	end
end

-- SpellName
local function SpellName(name)
	if (CanAccess(name)) then
		return (name:gsub(" %- No Text", ""))
	end
	return name
end

-- SameCast
-- castID comparison that tolerates secret IDs (never filters them out)
local function SameCast(castID, lineGUID)
	if (not CanAccess(castID) or not CanAccess(lineGUID)) then
		return true
	end
	return castID == 0 or castID == lineGUID
end

local CASTING_BAR_HOLD_TIME = CASTING_BAR_HOLD_TIME
local FAILED = FAILED
local SPELL_FAILED_INTERRUPTED = SPELL_FAILED_INTERRUPTED

-- Registers frame to spellcast events.
local barColours = {
	main = {r = 1.0, g = 0.7, b = 0.0},
	channel = {r = 0.0, g = 1.0, b = 0.0},
	success = {r = 0.0, g = 1.0, b = 0.0},
	failure = {r = 1.0, g = 0.0, b = 0.0}
}

local events = {
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP", "PLAYER_ENTERING_WORLD"
}

-- enableToggle
-- Each enabled bar listens on the bus (FPerl.On) for the cast events and its target/focus/party event.
local function listen(self, event)
	local fn = self.busFn
	if (not fn) then
		fn = function(...)
			FPerl.ArcaneBar.OnEvent(self, ...)
		end
		self.busFn = fn
		self.busEvents = {}
	end
	FPerl.On(event, fn)
	tinsert(self.busEvents, event)
end

local function enableToggle(self, value)
	if (value) then
		if (not self.Enabled) then
			for i, event in pairs(events) do
				listen(self, event)
			end

			self:SetScript("OnUpdate", FPerl.ArcaneBar.OnUpdate)
			if (self.unit == "target") then
				listen(self, "PLAYER_TARGET_CHANGED")
			elseif (self.unit == "focus") then
				listen(self, "PLAYER_FOCUS_CHANGED")
			elseif (strfind(self.unit, "^party")) then
				listen(self, "PARTY_MEMBER_ENABLE")
				listen(self, "PARTY_MEMBER_DISABLE")
			end
			self.Enabled = 1
		end
	else
		if (self.Enabled) then
			for i, event in ipairs(self.busEvents) do
				FPerl.Off(event, self.busFn)
			end
			wipe(self.busEvents)
			self:SetScript("OnUpdate", nil)
			self.Enabled = nil
			self:Hide()
		end
	end
end

-- overrideToggle(value): value (Keep Blizzard's cast bar) shows Blizzard's player cast bar
local function overrideToggle(value)
	if (ArcaneBars.player) then
		FPerl.BlizzFrameHide(PlayerCastingBarFrame, not value)
	end
end

-- ActiveCasting
-- See if we're probably still casting a spell, even though some other spell END event occured
local function ActiveCasting(self)
	local t = GetTime() * 1000
	local name, _, _, _, endTime = UnitCastingInfo(self.unit)
	if (not name) then
		name, _, _, _, endTime = UnitChannelInfo(self.unit)
	end
	if (name) then
		-- a secret end time means we cannot tell, assume active
		if (not CanAccess(endTime) or endTime > t + 500) then
			return true
		end
	end
end

--------------------------------------------------
--
-- Event/Update Handlers
--
--------------------------------------------------

-- FPerl.ArcaneBar.OnEvent
function FPerl.ArcaneBar.OnEvent(self, event, unit, ...)
	-- Override for showPlayer attribute in party.
	if self.unit == "partyplayer" then
		self.unit = "player"
	end

	if (event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" or event == "PARTY_MEMBER_ENABLE" or event == "PARTY_MEMBER_DISABLE") then
		local nameChannel = UnitChannelInfo(self.unit)
		local nameSpell = UnitCastingInfo(self.unit)
		if nameChannel then
			event = "UNIT_SPELLCAST_CHANNEL_START"
			unit = self.unit
		elseif (nameSpell) then
			event = "UNIT_SPELLCAST_START"
			unit = self.unit
		else
			self:Hide()
			self.castTimeText:Hide()
			self.barParentName:SetAlpha(conf.transparency.text)
			self.barParentName:Show()
			return
		end
	end

	if (unit ~= self.unit) then
		return
	end

	if (event == "UNIT_SPELLCAST_START") then
		local name, _, _, startTime, endTime, isTradeSkill, castID = UnitCastingInfo(self.unit)
		if (not name or (not self.showTradeSkills and isTradeSkill)) then
			self:Hide()
			return
		end

		self:SetStatusBarColor(barColours.main.r, barColours.main.g, barColours.main.b, conf.transparency.frame)
		self.spellText:SetText(SpellName(name))
		self.castID = castID
		self.barParentName:Hide()
		self.barSpark:Show()
		if (IsSecret(startTime) or IsSecret(endTime)) then
			SetSecretTimes(self, false)
		else
			ClearSecretTimes(self)
			self.startTime = startTime / 1000
			self.maxValue = endTime / 1000
			self:SetMinMaxValues(self.startTime, self.maxValue)
			self:SetValue(self.startTime)
		end
		self:SetAlpha(0.8)
		self.holdTime = 0
		self.casting, self.channeling, self.fadeOut, self.flash = 1, nil, nil, nil
		self:Show()
		self.delaySum = 0
		if (conf.player.castBar.castTime) then
			self.castTimeText:Show()
		else
			self.castTimeText:Hide()
		end
	elseif ((event == "UNIT_SPELLCAST_STOP" and self.casting) or (event == "UNIT_SPELLCAST_CHANNEL_STOP" and self.channeling)) then
		local lineGUID = ...
		if event == "UNIT_SPELLCAST_STOP" and not SameCast(self.castID, lineGUID) then
			return
		end
		if (not ActiveCasting(self)) then
			self.delaySum = 0
			self.sign = "+"
			self.castTimeText:Hide()
			if (not self:IsVisible()) then
				self:Hide()
			end
			if (self:IsShown()) then
				ClearSecretTimes(self)
				if (self.maxValue) then
					self:SetValue(self.maxValue)
				end
				self:SetStatusBarColor(barColours.success.r, barColours.success.g, barColours.success.b, conf.transparency.frame)
				self.barSpark:Hide()
				self.barFlash:SetAlpha(0)
				self.barFlash:Show()
				self.casting = nil
				self.channeling = nil
				if (not self.fadeOut or event == "UNIT_SPELLCAST_CHANNEL_STOP") then
					self.flash = 1
				end
				self.fadeOut = 1
				self.holdTime = 0
			end
		end
	elseif (event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED") then
		local lineGUID = ...
		if not SameCast(self.castID, lineGUID) then
			return
		end
		if (not self.fadeOut and self:IsShown() and not ActiveCasting(self)) then
			if (event == "UNIT_SPELLCAST_FAILED") then
				self.spellText:SetText(FAILED)
			else
				self.spellText:SetText(SPELL_FAILED_INTERRUPTED)
			end

			ClearSecretTimes(self)
			if (self.maxValue) then
				self:SetValue(self.maxValue)
			end
			self:SetStatusBarColor(barColours.failure.r, barColours.failure.g, barColours.failure.b, conf.transparency.frame)
			self.barSpark:Hide()
			self.casting = nil
			self.channeling = nil
			if (not self.fadeOut) then
				self.flash = 1
			end
			self.fadeOut = 1
			self.holdTime = GetTime() + (CASTING_BAR_HOLD_TIME or 1)
		end
	elseif (event == "UNIT_SPELLCAST_INTERRUPTIBLE") or (event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE") then
		if (self:IsShown()) then
			local name, _, _, startTime, endTime, isTradeSkill = UnitCastingInfo(self.unit)
			if (not name) then
				name, _, _, startTime, endTime, isTradeSkill = UnitChannelInfo(self.unit)
			end
			if (not name or (not self.showTradeSkills and isTradeSkill)) then
				-- if there is no name, there is no bar
				self:Hide()
				return
			end
			self.spellText:SetText(SpellName(name))
			if (IsSecret(startTime) or IsSecret(endTime)) then
				SetSecretTimes(self, self.channeling)
			else
				self.startTime = startTime / 1000
				self.maxValue = endTime / 1000
				self:SetMinMaxValues(self.startTime, self.maxValue)
			end
		end
	elseif (event == "UNIT_SPELLCAST_DELAYED") then
		if (self:IsShown()) then
			local name, _, _, startTime, endTime, isTradeSkill = UnitCastingInfo(self.unit)
			if (not name or (not self.showTradeSkills and isTradeSkill)) then
				-- if there is no name, there is no bar
				self:Hide()
				return
			end
			if (IsSecret(startTime) or IsSecret(endTime)) then
				SetSecretTimes(self, false)
			else
				self.startTime = startTime / 1000
				self.maxValue = endTime / 1000
				self:SetMinMaxValues(self.startTime, self.maxValue)
			end
		end
	elseif (event == "UNIT_SPELLCAST_CHANNEL_START") then
		local name, _, _, startTime, endTime, isTradeSkill = UnitChannelInfo(self.unit)
		if (not name or (not self.showTradeSkills and isTradeSkill)) then
			-- if there is no name, there is no bar
			self:Hide()
			return
		end

		self:SetStatusBarColor(barColours.channel.r, barColours.channel.g, barColours.channel.b, conf.transparency.frame)
		self.barSpark:Show()
		self.barParentName:Hide()
		self.spellText:SetText(SpellName(name))
		if (IsSecret(startTime) or IsSecret(endTime)) then
			SetSecretTimes(self, true)
		else
			ClearSecretTimes(self)
			self.maxValue = 1
			self.startTime = startTime / 1000
			self.endTime = endTime / 1000
			self:SetMinMaxValues(self.startTime, self.endTime)
			self:SetValue(self.endTime)
		end
		self:SetAlpha(1.0)
		self.holdTime = 0
		self.casting, self.channeling, self.fadeOut, self.flash = nil, 1, nil, nil
		self:Show()
		self.delaySum = 0
		if (conf.player.castBar.castTime) then
			self.castTimeText:Show()
		else
			self.castTimeText:Hide()
		end
	elseif (event == "UNIT_SPELLCAST_CHANNEL_UPDATE") then
		if (self:IsShown()) then
			local name, _, _, startTime, endTime, isTradeSkill = UnitChannelInfo(self.unit)
			if (not name or (not self.showTradeSkills and isTradeSkill)) then
				-- if there is no name, there is no bar
				self:Hide()
				return
			end
			if (IsSecret(startTime) or IsSecret(endTime)) then
				SetSecretTimes(self, true)
			else
				self.startTime = startTime / 1000
				self.endTime = endTime / 1000
				self.maxValue = self.startTime
				self:SetMinMaxValues(self.startTime, self.endTime)
			end
		end
	end

	if (not self:IsShown()) then
		self.castTimeText:Hide()
		self.barParentName:SetAlpha(conf.transparency.text)
		self.barParentName:Show()
	end
end

local function ShowPrecast(self, side)
	if (self.precast) then
		if (conf.player.castBar.precast and CanAccess(self.maxValue) and CanAccess(self.startTime)) then
			local _, _, _, latencyWorld = GetNetStats()
			local lag = min(1000, latencyWorld)
			if (lag < 10) then
				self.precast:Hide()
			else
				local total = self.maxValue - self.startTime
				if total == 0 then
					total = 1.5
				end
				local width = self:GetWidth() / ((total * 1000) / lag)

				self.precast:ClearAllPoints()
				self.precast:SetPoint(side)
				self.precast:SetWidth(width)
				self.precast:SetHeight(self:GetHeight())
				self.precast:Show()
			end
		else
			self.precast:Hide()
		end
	end
end

-- FPerl.ArcaneBar.OnUpdate
function FPerl.ArcaneBar.OnUpdate(self, elapsed)
	-- secret cast times, no maths possible here
	if ((self.timerDuration or self.unknownTime) and (self.casting or self.channeling)) then
		SecureUpdate(self, elapsed)
		return
	end

	local getTime = GetTime()
	local current_time = (self.maxValue or getTime) - getTime
	if (self.channeling) then
		current_time = self.endTime - getTime
	end
	if (current_time < 0) then
		current_time = 0
	end
	local text = format("%.1f", current_time)

	self.castTimeText:SetText(text)

	if (self.casting) then
		local status = getTime
		if (status > self.maxValue) then
			status = self.maxValue
			self:SetValue(status)
			self.barSpark:Hide()
			self:SetStatusBarColor(barColours.success.r, barColours.success.g, barColours.success.b, conf.transparency.frame)
			self.tex:SetTexCoord(0, 1, 0, 1)
			self.casting = nil
			self.barFlash:SetAlpha(0)
			self.barFlash:Show()
			if (not self.fadeOut) then
				self.flash = 1
			end
			self.holdTime = 0
			self.fadeOut = 1
			return
		end

		self.tex:SetTexCoord(0, (status - self.startTime) / (self.maxValue - self.startTime), 0, 1)
		self:SetValue(status)
		self.barFlash:Hide()

		local sparkPosition = ((status - self.startTime) / (self.maxValue - self.startTime)) * self:GetWidth()
		if (sparkPosition < 0) then
			sparkPosition = 0
		end
		self.barSpark:SetPoint("CENTER", self, "LEFT", sparkPosition, 1)

		ShowPrecast(self, "RIGHT")
	elseif (self.channeling) then
		local time = getTime
		if (time > self.endTime) then
			time = self.endTime
		end
		if (time == self.endTime) then
			self.channeling = nil
			self.barSpark:Hide()
			self.barFlash:SetAlpha(0)
			self.barFlash:Show()
			if (not self.fadeOut) then
				self.flash = 1
			end
			self.holdTime = 0
			self.fadeOut = 1
			return
		end
		local barValue = self.startTime + (self.endTime - time)
		self.tex:SetTexCoord(0, min(1, max(0, (barValue - self.startTime) / (self.endTime - self.startTime))), 0, 1)
		self:SetValue( barValue )
		self.barFlash:Hide()

		local sparkPosition = ((barValue - self.startTime) / (self.endTime - self.startTime)) * self:GetWidth()
		self.barSpark:SetPoint("CENTER", self, "LEFT", sparkPosition, 1)

		ShowPrecast(self, "LEFT")
	elseif (getTime < self.holdTime) then
		return
	elseif (self.flash) then
		-- A brief, restrained highlight, followed by the existing smooth fade.
		-- Clamp the final frame too: a long frame must not skip the peak.
		local alpha = min(0.22, self.barFlash:GetAlpha() + elapsed * 1.5)
		self.barFlash:SetAlpha(alpha)
		if (alpha >= 0.22) then
			self.flash = nil
		end
	elseif (self.fadeOut) then
		local alpha = self:GetAlpha() - elapsed * 2			-- CASTING_BAR_ALPHA_STEP
		if (alpha > 0) then
			self:SetAlpha(alpha)
			self.barParentName:SetAlpha((1 - alpha) * conf.transparency.text)
			self.barParentName:Show()
		else
			self.fadeOut = nil
			self:Hide()
		end
	end

	if (not self:IsShown()) then
		self.castTimeText:Hide()
		self.barParentName:SetAlpha(conf.transparency.text)
		self.barParentName:Show()
	end
end

-- FPerl.ArcaneBar.OnLoad
function FPerl.ArcaneBar.OnLoad(self)
	FPerl.SetChildMembers(self)

	-- Keep completion light inside the cast bar, below the spell text.
	self.barFlash:ClearAllPoints()
	self.barFlash:SetAllPoints(self)
	self.barFlash:SetFrameLevel(self:GetFrameLevel())
	self.barFlash.tex:SetColorTexture(1, 1, 1, 1)
	self.barFlash.tex:SetBlendMode("BLEND")
	-- Only clip the spark: the optional timer outside the bar stays visible.
	self.sparkClip = CreateFrame("Frame", nil, self)
	self.sparkClip:SetAllPoints(self)
	self.sparkClip:SetClipsChildren(true)
	self.sparkClip:SetFrameLevel(self:GetFrameLevel())
	self.barSpark:SetParent(self.sparkClip)
	self.barSpark:SetSize(14, 24)
	self.tex:SetTexture("Interface\\AddOns\\FPerl\\Images\\FPerl_StatusBar")
	self.tex:SetHorizTile(false)
	self.tex:SetVertTile(false)

	self.casting = nil
	self.holdTime = 0

	FPerl.RegisterBar(self)
end

-- FPerl.ArcaneBar.Set
function FPerl.ArcaneBar.Set()
	if (conf) then
		for k, v in pairs(ArcaneBars) do
			if (v.optFrame and v.optFrame.conf and v.optFrame.conf.castBar) then
				enableToggle(v.bar, v.optFrame.conf.castBar.enable)

				v.bar.castTimeText:ClearAllPoints()
				if (conf.player.castBar.inside) then
					v.bar.castTimeText:SetPoint("RIGHT", v.bar, "RIGHT", -2, 0)
					v.bar.castTimeText:SetJustifyH("RIGHT")
				else
					v.bar.castTimeText:SetPoint("LEFT", v.bar, "RIGHT", 2, 0)
					v.bar.castTimeText:SetJustifyH("LEFT")
				end
			end
		end

		overrideToggle(conf.player.castBar.original)
	end
end

-- SetArcaneBar
local function SetArcaneBar(value, new)
	for k, v in pairs(ArcaneBars) do
		if (v.bar == new.bar) then
			ArcaneBars[k] = nil
		end
	end

	ArcaneBars[value] = new
end

-- MakePreCast
local function MakePreCast(self)
	local tex = FPerl.GetBarTexture()
	self.precast = self:CreateTexture(nil, "ARTWORK")
	self.precast:SetTexture(tex)
	self.precast:SetPoint("RIGHT")
	self.precast:SetWidth(1)
	self.precast:Hide()
	self.precast:SetBlendMode("ADD")
	self.precast:SetGradient("HORIZONTAL", CreateColor(0, 0, 1, 1), CreateColor(1, 0, 0, 1))
end

-- FPerl.ArcaneBar.RegisterFrame
function FPerl.ArcaneBar.RegisterFrame(self, unit)
	local f = self.castBar
	if (not f) then
		f = CreateFrame("StatusBar", self:GetName().."CastBar", self, "FPerl_ArcaneBarTemplate")
		self.castBar = f
	end

	if (unit == "player") then
		MakePreCast(f)
	end

	f.unit = unit
	f.showTradeSkills = true
	f.barParentName = self.text
	f:SetPoint("TOPLEFT", 4, -4)
	f:SetPoint("BOTTOMRIGHT", -4, 4)

	SetArcaneBar(unit, {bar = f, optFrame = self:GetParent()})

	FPerl.ArcaneBar.Set()
end

-- FPerl.ArcaneBar.SetUnit
function FPerl.ArcaneBar.SetUnit(self, unit)
	if (self.castBar) then
		self.castBar.unit = unit
	end
end

FPerl.RegisterOptionChanger(FPerl.ArcaneBar.Set, nil, "arcanebar")
