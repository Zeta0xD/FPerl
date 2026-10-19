-- Author: Resike
-- License: GNU GPL v3, 18 October 2014

-- Fading bars, flashing, portraits, level and tooltip updates, the health prediction bars and the threat display.

local conf

FPerl.RequestConfig(function(New)
	conf = New
end, "$Revision: 1 $")

local abs = abs
local cos = cos
local error = error
local max = max
local min = min
local next = next
local pairs = pairs
local sin = sin
local strmatch = strmatch
local tinsert = tinsert
local tonumber = tonumber
local tremove = tremove
local type = type
local CreateFrame = CreateFrame
local GetDifficultyColor = GetDifficultyColor or GetQuestDifficultyColor
local GetNumGroupMembers = GetNumGroupMembers
local GetNumSubgroupMembers = GetNumSubgroupMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local GetRaidTargetIndex = GetRaidTargetIndex
local GetReadyCheckStatus = GetReadyCheckStatus
local GetRealZoneText = GetRealZoneText
local IsInRaid = IsInRaid
local SetPortraitTexture = SetPortraitTexture
local SetPortraitToTexture = SetPortraitToTexture or function(texture, asset)
	-- Removed from newer clients; plain texture swap is equivalent here
	texture:SetTexture(asset)
	texture:SetTexCoord(0, 1, 0, 1)
end
local SetRaidTargetIconTexture = SetRaidTargetIconTexture
local UnitAffectingCombat = UnitAffectingCombat
local UnitCanAttack = UnitCanAttack
local UnitClass = UnitClass
local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local UnitExists = UnitExists
local UnitGetIncomingHeals = UnitGetIncomingHeals
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local UnitGUID = UnitGUID
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsAFK = UnitIsAFK
local UnitIsConnected = UnitIsConnected
local UnitIsDead = UnitIsDead
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsGhost = UnitIsGhost
local UnitIsPlayer = UnitIsPlayer
local UnitIsVisible = UnitIsVisible
local UnitLevel = UnitLevel
local UnitName = UnitName
local UIParent = UIParent

local CanAccess, IsSecret = FPerl.CanAccess, FPerl.IsSecret
local colourCurves = FPerl.colourCurves

local function rotate(angle)
	local A = cos(angle)
	local B = sin(angle)
	local ULx, ULy = -0.5 * A - -0.5 * B, -0.5 * B + -0.5 * A
	local LLx, LLy = -0.5 * A - 0.5 * B, -0.5 * B + 0.5 * A
	local URx, URy = 0.5 * A - -0.5 * B, 0.5 * B + -0.5 * A
	local LRx, LRy = 0.5 * A - 0.5 * B, 0.5 * B + 0.5 * A
	return ULx + 0.5, ULy + 0.5, LLx + 0.5, LLy + 0.5, URx + 0.5, URy + 0.5, LRx + 0.5, LRy + 0.5
end

-- smoothColor
local function smoothColor(percentage)
	local r, g, b
	if (percentage < 0.5) then
		r = 1
		g = min(1, max(0, 2 * percentage))
		b = 0
	else
		g = 1
		r = min(1, max(0, 2 * (1 - percentage)))
		b = 0
	end

	return r, g, b
end

----------------------
-- Fading Bar Stuff --
----------------------
local fadeBars = {}
local freeFadeBars = {}
local tempDisableFadeBars

function FPerl.NoFadeBars(tempDisable)
	tempDisableFadeBars = tempDisable
end

-- CheckOnUpdate
local function CheckOnUpdate()
	if next(fadeBars) then
		FPerl_Globals:SetScript("OnUpdate", FPerl.BarUpdate)
	else
		FPerl_Globals:SetScript("OnUpdate", nil)
	end
end

-- FPerl.BarUpdate
--local speakerTimer = 0
--local speakerCycle = 0
function FPerl.BarUpdate(self, arg1)
	local did
	for k, v in pairs(fadeBars) do
		if k:IsShown() then
			v:SetAlpha(k.fadeAlpha)
			k.fadeAlpha = k.fadeAlpha - (arg1 / conf.bar.fadeTime)

			local r, g, b = v.tex:GetVertexColor()
			v:SetStatusBarColor(r, g, b)
		else
			-- Not shown, so end it
			k.fadeAlpha = 0
		end

		if k.fadeAlpha <= 0 then
			tinsert(freeFadeBars, v)
			fadeBars[k] = nil
			k.fadeAlpha = nil
			k.fadeBar = nil
			v:SetValue(0)
			v:Hide()
			v.tex = nil
			did = true
		end
	end

	if did then
		CheckOnUpdate()
	end
end

-- GetFreeFader
local function GetFreeFader(parent)
	local bar = freeFadeBars[1]
	if bar then
		tremove(freeFadeBars, 1)
		bar:SetParent(parent)
	else
		-- Creates only when the pool is empty: the pool grows to the most bars fading at once and is
		-- never freed, so a steady state creates nothing. Frames cannot be destroyed, so pooling is the bound.
		bar = CreateFrame("StatusBar", nil, parent)
	end

	if bar then
		fadeBars[parent] = bar
		CheckOnUpdate()

		bar.tex = parent.tex

		local tex = parent:GetStatusBarTexture()
		if tex:GetTexture() then
			bar:SetStatusBarTexture(tex:GetTexture())
			bar:GetStatusBarTexture():SetHorizTile(false)
			bar:GetStatusBarTexture():SetVertTile(false)
		end

		local r, g, b = bar.tex:GetVertexColor()
		bar:SetStatusBarColor(r, g, b)

		bar:SetFrameLevel(parent:GetFrameLevel())

		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", 0, 0)
		bar:SetPoint("BOTTOMRIGHT", 0, 0)
		bar:SetAlpha(1)

		return bar
	end
end

-- FPerl.StatusBarSetValue
function FPerl.StatusBarSetValue(self, val)
	if not tempDisableFadeBars and conf.bar.fading and self:GetName() then
		local min, max = self:GetMinMaxValues()
		local current = self:GetValue()

		-- secret values (health always, power always) cannot be compared, so every update fades
		-- from the old value; after a gain the fader lies inside the bar's own fill and does not show
		local readable = CanAccess(val) and CanAccess(current) and CanAccess(max)
		if not readable or (val < current and val <= max and val >= min) then
			local bar = fadeBars[self]

			if not bar then
				bar = GetFreeFader(self)
			end

			if bar then
				if not self.fadeAlpha then
					self.fadeAlpha = self:GetParent():GetAlpha()
					bar:SetValue(current)
				end

				bar:SetMinMaxValues(min, max)
				bar:SetAlpha(self.fadeAlpha)
				bar:Show()
			end
		end
	end

	FPerl.OldStatusBarSetValue(self, val)
end

-- FPerl.RegisterClickCastFrame
function FPerl.RegisterClickCastFrame(self)
	if not ClickCastFrames then
		ClickCastFrames = { }
	end
	ClickCastFrames[self] = true
end

-- FPerl.SecureUnitButtonOnLoad
function FPerl.SecureUnitButtonOnLoad(self, unit, menufunc, m1, m2, toggledisabled)
	self:SetAttribute("*type1", "target")
	if toggledisabled then
		self:SetAttribute("type2", "menu")
	else
		self:SetAttribute("type2", "togglemenu")
	end

	if unit then
		self:SetAttribute("unit", unit)
	end

	FPerl.RegisterClickCastFrame(self)
end

-- FPerl.UpdateRaidIcon
function FPerl.UpdateRaidIcon(self, unit)
	local index = GetRaidTargetIndex(unit)
	if CanAccess(index) then
		local mark
		if unit == "player" or unit == "vehicle" or unit == "target" or unit == "focus" then
			if self.texture then
				mark = self.texture
			else
				mark = self
			end
		else
			mark = self
		end
		SetRaidTargetIconTexture(mark, index)
		self:Show()
	else
		self:Hide()
	end
end

------------------------------------------------------------------------------
-- Flashing frames handler. Is hidden when there's nothing to do.
local FlashFrame = CreateFrame("Frame", "FPerl_FlashFrame", nil, BackdropTemplateMixin and "BackdropTemplate")
FlashFrame.list = { }
FlashFrame:Hide() -- its OnUpdate runs only while a flash is active (FPerl.FrameFlash shows it)

-- FrameFlashOnUpdate(self, elapsed)
local function FrameFlashOnUpdate(self, elapsed)
	for k, v in pairs(self.list) do
		if (k.frameFlash.out) then
			k.frameFlash.alpha = k.frameFlash.alpha - elapsed
			if (k.frameFlash.alpha < 0.2) then
				k.frameFlash.alpha = 0.2
				k.frameFlash.out = nil

				if (k.frameFlash.method == "out") then
					FPerl.FrameFlashStop(k)
				end
			end
		else
			k.frameFlash.alpha = k.frameFlash.alpha + elapsed
			if (k.frameFlash.alpha > 1) then
				k.frameFlash.alpha = 1
				k.frameFlash.out = true

				if (k.frameFlash.method == "in") then
					FPerl.FrameFlashStop(k)
				end
			end
		end

		if (k.frameFlash) then
			k:SetAlpha(k.frameFlash.alpha)
		end
	end
end

FlashFrame:SetScript("OnUpdate", FrameFlashOnUpdate)

-- FPerl.FrameFlash
function FPerl.FrameFlash(self)
	if (not FlashFrame.list[self]) then
		if (self.frameFlash) then
			error("F-Perl ["..self:GetName()..".frameFlash is set with no entry in FlashFrame.list]")
		end

		self.frameFlash = {out = true, alpha = 1, shown = self:IsShown()}

		FlashFrame.list[self] = true
		FlashFrame:Show()
		self:Show()
	end
end

-- FPerl.FrameFlashStop
function FPerl.FrameFlashStop(self, method)
	if (not self.frameFlash) then
		return
	end

	if (method) then
		self.frameFlash.method = method
		return
	end

	if (not self.frameFlash.shown) then
		self:Hide()
	end

	--FPerl.FreeTable(self.frameFlash)
	self.frameFlash = nil

	self:SetAlpha(1)

	FlashFrame.list[self] = nil

	if (not next(FlashFrame.list)) then
		FlashFrame:Hide()
	end
end

-- FPerl.ProtectedCall
function FPerl.ProtectedCall(func, self)
	if (func) then
		FPerl.AfterCombat(func, self)
	end
end

-- nextMember(last)
function FPerl.NextMember(_, last)
	if (last) then
		local raidCount = GetNumGroupMembers()
		if (raidCount > 0) then
			if (IsInRaid()) then
				local i = tonumber(strmatch(last, "^raid(%d+)"))
				if (i and i < raidCount) then
					i = i + 1
					local unitName, _, group, _, _, unitClass, zone, online, dead = GetRaidRosterInfo(i)
					return "raid"..i, unitName, unitClass, group, zone, online, dead
				end
			else
				local partyCount = GetNumSubgroupMembers()
				if (partyCount > 0) then
					local id
					if (last == "player") then
						id = "party1"
					else
						local i = tonumber(strmatch(last, "^party(%d+)"))
						if (i and i < partyCount) then
							i = i + 1
							id = "party"..i
						end
					end

					if (id) then
						local _, class = UnitClass(id)
						return id, UnitName(id), class, 1, "", UnitIsConnected(id), UnitIsDeadOrGhost(id)
					end
				end
			end
		end
	else
		if (IsInRaid()) then
			local unitName, _, group, _, _, unitClass, zone, online, dead = GetRaidRosterInfo(1)
			return "raid1", unitName, unitClass, group, zone, online, dead
		else
			local _, class = UnitClass("player")
			return "player", UnitName("player"), class, 1, GetRealZoneText(), 1, UnitIsDeadOrGhost("player")
		end
	end
end

-- FPerl.UnitUpdatePortrait
function FPerl.UnitUpdatePortrait(self, force)
	if (self.conf and self.conf.portrait) then
		if self.conf.classPortrait then
			local _, englishClass = UnitClass(self.partyid)
			if UnitIsPlayer(self.partyid) and englishClass then
				SetPortraitToTexture(self.portraitFrame.portrait, "Interface\\Icons\\ClassIcon_"..englishClass)
			else
				SetPortraitTexture(self.portraitFrame.portrait, self.partyid)
			end
		else
			SetPortraitTexture(self.portraitFrame.portrait, self.partyid)
		end
		-- If a player moves out of range for a 3D portrait, it will show their proper 2D one.
		-- NPC 3D portraits also frequently fail to render at all inside instances
		-- (dungeons/raids) on this client, leaving a blank spot instead of a model --
		-- use the already-populated 2D portrait for NPCs there instead of attempting
		-- 3D. Real players keep their animated portrait everywhere, since that case
		-- has been reliable.
		if (self.conf.portrait3D and UnitIsVisible(self.partyid) and (not IsInInstance() or UnitIsPlayer(self.partyid))) then
			self.portraitFrame.portrait:Hide()
			local guid = UnitGUID(self.partyid)
			-- A secret GUID cannot be compared, and that includes the *stored*
			-- one from a previous secret-identity target -- this crashed on a
			-- perfectly readable new guid because the stored one was secret.
			-- Guard both sides; always refresh if either is unreadable.
			if force or not CanAccess(guid) or not CanAccess(self.portraitFrame.portrait3D.guid) or guid ~= self.portraitFrame.portrait3D.guid or not self.portraitFrame.portrait3D:IsShown() then
				self.portraitFrame.portrait3D:Show()
				self.portraitFrame.portrait3D:ClearModel()
				self.portraitFrame.portrait3D:SetUnit(self.partyid)
				self.portraitFrame.portrait3D:SetPortraitZoom(0.8)
				self.portraitFrame.portrait3D.guid = guid
			end
		else
			self.portraitFrame.portrait:Show()
			self.portraitFrame.portrait3D:Hide()
		end
	end
end

-- FPerl.UnitUpdateLevel
colourCurves.levelSecret = {r = 1, g = 1, b = 1}
function FPerl.UnitUpdateLevel(self)
	local level = UnitLevel(self.partyid)
	-- creature levels can be secret inside instances
	local readable = CanAccess(level)
	local color = readable and GetDifficultyColor(level) or colourCurves.levelSecret
	if (self.levelFrame) then
		self.levelFrame.text:SetTextColor(color.r,color.g,color.b)
		self.levelFrame.text:SetText(level)
	elseif (self.nameFrame.level) then
		if (readable and level == 0) then
			level = ""
		end
		self.nameFrame.level:SetTextColor(color.r,color.g,color.b)
		self.nameFrame.level:SetText(level)
	end
end

-- FPerl.Differs(a, b): whether a poll must redraw: a or b is secret (it cannot be compared, so the
-- poll redraws every tick) or they differ.
function FPerl.Differs(a, b)
	return IsSecret(a) or IsSecret(b) or a ~= b
end

-- FPerl.UnitOnEnter
function FPerl.UnitOnEnter(self)
	FPerl.PlayerTip(self)
	if (self.highlight) then
		self.highlight:Select()
	end

	if (self.statsFrame and self.statsFrame.healthBar and self.statsFrame.healthBar.text and not self.statsFrame.healthBar.text:IsShown()) then
		self.hideValues = true
		self.statsFrame.healthBar.text:Show()
		if (self.statsFrame.manaBar) then
			self.statsFrame.manaBar.text:Show()
		end
		if (self.statsFrame.xpBar and self.statsFrame.xpBar:IsShown()) then
			self.statsFrame.xpBar.text:Show()
		end
		if (self.statsFrame.repBar and self.statsFrame.repBar:IsShown()) then
			self.statsFrame.repBar.text:Show()
		end
	end
end

-- FPerl.UnitOnLeave
function FPerl.UnitOnLeave(self)
	FPerl.PlayerTipHide()
	if (self.highlight) then
		self.highlight:Deselect()
	end

	if (self.hideValues) then
		self.hideValues = nil

		self.statsFrame.healthBar.text:Hide()
		if (self.statsFrame.manaBar) then
			self.statsFrame.manaBar.text:Hide()
		end
		if (self.statsFrame.xpBar and self.statsFrame.xpBar:IsShown()) then
			self.statsFrame.xpBar.text:Hide()
		end
		if (self.statsFrame.repBar and self.statsFrame.repBar:IsShown()) then
			self.statsFrame.repBar.text:Hide()
		end
	end
end

-- FPerl.UnitUpdateReadyState
function FPerl.UnitUpdateReadyState(self)
	local status = conf.showReadyCheck and self.partyid and GetReadyCheckStatus(self.partyid)
	if status then
		self.statsFrame.ready:Show()
		if status == "ready" then
			self.statsFrame.ready.check:SetTexture(READY_CHECK_READY_TEXTURE)
		elseif status == "waiting" then
			self.statsFrame.ready.check:SetTexture(READY_CHECK_WAITING_TEXTURE)
		elseif status == "notready" then
			self.statsFrame.ready.check:SetTexture(READY_CHECK_NOT_READY_TEXTURE)
		else
			self.statsFrame.ready:Hide()
		end
	else
		self.statsFrame.ready:Hide()
	end
end

-- FPerl.SwitchAnchor(self, new)
-- Changes anchored corner without actually moving the frame

-- FPerl.SwitchAnchor
function FPerl.SwitchAnchor(self, New)
	local left, top, ratio = FPerl.FramePointUI(self)
	if (left and not self:GetPoint(2)) then
		local a1, f, a2 = self:GetPoint(1)

		if (a1 == a2 and New ~= a1) then
			local x, y
			local newV =strmatch(New, "TOP") or strmatch(New, "BOTTOM")
			local newH = strmatch(New, "LEFT") or strmatch(New, "RIGHT")

			if (newV == "TOP") then
				y = (top - 768 / UIParent:GetEffectiveScale()) / ratio
			elseif (newV == "BOTTOM") then
				y = self:GetBottom()
			else
				y = self:GetBottom() + self:GetHeight() / 2
			end

			if (newH == "LEFT") then
				x = left / ratio
			elseif (newH == "RIGHT") then
				x = self:GetRight()
			else
				x = self:GetLeft() + self:GetWidth() / 2
			end

			self:ClearAllPoints()
			self:SetPoint(New, f, New, x, y)
		end
	end
end

-- FPerl.SetExpectedAbsorbs
function FPerl.SetExpectedAbsorbs(self)
	local bar
	if self.statsFrame and self.statsFrame.expectedAbsorbs then
		bar = self.statsFrame.expectedAbsorbs
	else
		bar = self.expectedAbsorbs
	end
	if (bar) then
		local unit = self.partyid

		if not unit then
			unit = self:GetParent().targetid
		end

		local amount = type(UnitGetTotalAbsorbs) == "function" and UnitGetTotalAbsorbs(unit)

		if (IsSecret(amount)) then
			-- the amount cannot be positioned by maths. Draw it as
			-- a reverse-filled overlay on the health bar; Blizzard scales it.
			local healthBar
			if self.statsFrame and self.statsFrame.healthBar then
				healthBar = self.statsFrame.healthBar
			else
				healthBar = self.healthBar
			end
			if (not conf.colour.bar.absorb) then
				conf.colour.bar.absorb = {r = 0.14, g = 0.33, b = 0.7, a = 0.7}
			end
			bar:SetStatusBarColor(conf.colour.bar.absorb.r, conf.colour.bar.absorb.g, conf.colour.bar.absorb.b, conf.colour.bar.absorb.a)
			-- Anchored on every call on purpose: the readable path below anchors and fills the same bar
			-- differently, and a secret amount changes with each health event. Setters only, no table.
			if (healthBar) then
				bar:ClearAllPoints()
				bar:SetPoint("TOPLEFT", healthBar, "TOPLEFT", 0, 0)
				bar:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 0, 0)
				if (bar.SetFrameLevel and healthBar.GetFrameLevel) then
					bar:SetFrameLevel(healthBar:GetFrameLevel() + 1)
				end
			end
			if (bar.SetReverseFill) then
				bar:SetReverseFill(true)
			end
			bar:SetMinMaxValues(0, UnitHealthMax(unit))
			bar:SetValue(amount)
			bar:Show()
			return
		end

		-- identity-based secrecy for this unit is independent
		-- of amount's own secrecy above -- guard these too.
		if (amount and amount > 0 and not FPerl.SafeBool(UnitIsDeadOrGhost(unit), false)) then
			local healthMax = UnitHealthMax(unit)

			if FPerl.SafeBool(UnitIsAFK(unit), false) then
				bar:SetStatusBarColor(0.2, 0.2, 0.2, 0.7)
			else
				if not conf.colour.bar.absorb then
					conf.colour.bar.absorb = { }
					conf.colour.bar.absorb.r = 0.14
					conf.colour.bar.absorb.g = 0.33
					conf.colour.bar.absorb.b = 0.7
					conf.colour.bar.absorb.a = 0.7
				end

				bar:SetStatusBarColor(conf.colour.bar.absorb.r, conf.colour.bar.absorb.g, conf.colour.bar.absorb.b, conf.colour.bar.absorb.a)
			end

			if (bar.SetReverseFill) then
				bar:SetReverseFill(false)
			end
			bar:Show()
			bar:SetMinMaxValues(0, healthMax)

			local healthBar
			if self.statsFrame and self.statsFrame.healthBar then
				healthBar = self.statsFrame.healthBar
			else
				healthBar = self.healthBar
			end
			local _, max = healthBar:GetMinMaxValues()
			local value = healthBar:GetValue()
			if (not CanAccess(max) or not CanAccess(value) or max == 0) then
				bar:Hide()
				return
			end
			local position = ((max - value) / max) * healthBar:GetWidth()

			if healthBar:GetWidth() <= 0 or healthBar:GetWidth() == position then
				return
			end

			bar:SetValue(amount * (healthBar:GetWidth() / (healthBar:GetWidth() - position)))

			bar:SetPoint("TopRight", healthBar, "TopRight", -position, 0)
			bar:SetPoint("BottomRight", healthBar, "BottomRight", -position, 0)
			return
		end
		bar:Hide()
	end
end

-- FPerl.SetExpectedHealth
function FPerl.SetExpectedHealth(self)
	local bar
	if self.statsFrame and self.statsFrame.expectedHealth then
		bar = self.statsFrame.expectedHealth
	else
		bar = self.expectedHealth
	end
	if (bar) then
		local unit = self.partyid

		if not unit then
			unit = self:GetParent().targetid
		end

		-- the client's own incoming heal value
		local amount
		if (type(UnitGetIncomingHeals) == "function") then
			amount = UnitGetIncomingHeals(unit)
		end

		if not conf.colour.bar.healprediction then
			conf.colour.bar.healprediction = { }
			conf.colour.bar.healprediction.r = 0
			conf.colour.bar.healprediction.g = 1
			conf.colour.bar.healprediction.b = 1
			conf.colour.bar.healprediction.a = 1
		end

		if (IsSecret(amount)) then
			-- Secret heal amount: UnitHealth(unit, true) is health plus incoming
			-- heals as computed by Blizzard, which is exactly this bar's value.
			bar:SetStatusBarColor(conf.colour.bar.healprediction.r, conf.colour.bar.healprediction.g, conf.colour.bar.healprediction.b, conf.colour.bar.healprediction.a)
			bar:SetMinMaxValues(0, UnitHealthMax(unit))
			bar:SetValue(UnitHealth(unit, true))
			bar:Show()
			return
		end

		if (amount and amount > 0 and not UnitIsDeadOrGhost(unit)) then
			local healthMax = UnitHealthMax(unit)
			local health = UnitIsGhost(unit) and 1 or (UnitIsDead(unit) and 0 or UnitHealth(unit))
			if (not CanAccess(health) or not CanAccess(healthMax)) then
				bar:Hide()
				return
			end

			bar:SetStatusBarColor(conf.colour.bar.healprediction.r, conf.colour.bar.healprediction.g, conf.colour.bar.healprediction.b, conf.colour.bar.healprediction.a)

			bar:Show()
			bar:SetMinMaxValues(0, healthMax)
			bar:SetValue(min(healthMax, health + amount))

			return
		end
		bar:Hide()
	end
end

-- Threat Display
local function DrawHand(self, percent)
	local angle = 360 - (percent * 2.7 - 135)
	local ULx, ULy, LLx, LLy, URx, URy, LRx, LRy = rotate(angle)
	self.needle:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
end

local function DrawSlider(self, percent)
	local offset = (self:GetWidth() - 9) / 100 * percent
	self.needle:ClearAllPoints()
	self.needle:SetPoint("CENTER", self, "TOPLEFT", offset + 5, -2)

	local r, g, b
	if (percent <= 70) then
		r, g, b = 0, 1, 0
	else
		r, g, b = smoothColor(abs((percent - 100) / 30))
	end

	self.needle:SetVertexColor(r, g, b)
end

-- FPerl.ThreatDisplayOnLoad
function FPerl.ThreatDisplayOnLoad(self, mode)
	FPerl.SetChildMembers(self)
	self:SetFrameLevel(self:GetParent():GetFrameLevel() + 4)
	self.text:SetWidth(100)
	self.current, self.target = 0, 0
	self.mode = mode

	if (mode == "nameFrame") then
		self.Draw = DrawSlider
	else
		self.Draw = DrawHand
	end
	self:Draw(0)
end

-- threatOnUpdate
local function threatOnUpdate(self, elapsed)
	local diff = (self.target - self.current) * 0.2
	self.current = min(100, max(0, self.current + diff))
	if (abs(self.current - self.target) <= 0.01) then
		self.current = self.target
		self:SetScript("OnUpdate", nil)
	end

	self:Draw(self.current)
end

-- FPerl.UnitThreatStatus
function FPerl.UnitThreatStatus(self, relative, immediate)
	if (type(UnitDetailedThreatSituation) ~= "function" or not self.partyid or not self.conf) then
		return
	end

	local mode = self.conf.threatMode or (self.conf.portrait and "portraitFrame" or "nameFrame")
	local t = self.threatFrames and self.threatFrames[mode]
	if (not self.conf.threat) then
		if (t) then
			t:Hide()
		end
		return
	end

	if (not t) then
		if (self.threatFrames) then
			for _,frame in pairs(self.threatFrames) do
				frame:SetScript("OnUpdate", nil)
				frame.current, frame.target = 0, 0
				frame:Hide()
			end
		else
			self.threatFrames = {}
		end
		if (self[mode]) then -- If desired parent frame exists
			-- Once per frame and mode: the `not t` guard above creates it on the first call and every
			-- later call reuses self.threatFrames[mode]; the frame carries the mode's template.
			t = CreateFrame("Frame", self:GetName().."Threat"..mode, self[mode], BackdropTemplateMixin and "BackdropTemplate,FPerl_ThreatTemplate"..mode or "FPerl_ThreatTemplate"..mode)
			t:SetAllPoints()
			self.threatFrames[mode] = t
		end

		self.threat = self.threatFrames[mode]
	end

	if (t) then
		local _, scaledPercent
		local one, two
		-- attack/combat flags for compound units can be secret
		if (FPerl.SafeBool(UnitAffectingCombat(self.partyid), false) or (relative and FPerl.SafeBool(UnitAffectingCombat(relative), false))) then
			if (relative and FPerl.SafeBool(UnitCanAttack(relative, self.partyid), false)) then
				one, two = relative, self.partyid
			else
				if (UnitExists("target") and FPerl.SafeBool(UnitCanAttack(self.partyid, "target"), false)) then
					one, two = self.partyid, "target"
				elseif (FPerl.SafeBool(UnitCanAttack("player", self.partyid), false)) then
					one, two = "player", self.partyid
				elseif (FPerl.SafeBool(UnitCanAttack(self.partyid, self.partyid.."target"), false)) then
					one, two = self.partyid, self.partyid.."target"
				end
			end

			if (one) then
				-- scaledPercent is 0% - 100%, 100 means you pull agro
				-- rawPercent is before normalization so can go up to 110% or 130% before you pull agro
				_, _, scaledPercent = UnitDetailedThreatSituation(one, two)
			end
		end

		if (scaledPercent) then
			if (CanAccess(scaledPercent)) then
				if (scaledPercent ~= t.target) then
					t.target = scaledPercent
					if (immediate) then
						t.current = scaledPercent
					end
					t.one = one
					t.two = two
					t:SetScript("OnUpdate", threatOnUpdate)
				end

				local r, g, b = smoothColor(scaledPercent)
				t.text:SetTextColor(r, g, b)
			else
				-- the text sink can show a secret percent, but the
				-- needle animation needs maths, so it stays where it is.
				t:SetScript("OnUpdate", nil)
				t.text:SetTextColor(1, 1, 1)
			end

			t.text:SetFormattedText("%d%%", scaledPercent)

			t:Show()
			return
		end

		t:Hide()
	end
end

-- FPerl.RegisterPrediction(self, conf, element)
-- The heal prediction option turns the frame's heal element (UNIT_HEAL_PREDICTION for the frame's
-- units) on or off. The frame must have run FPerl.UnitFrameInit.
function FPerl.RegisterPrediction(self, conf, element)
	if not self then
		return
	end

	-- the client's own event drives the bar
	if conf.healprediction and type(UnitGetIncomingHeals) == "function" then
		FPerl.UnitFrameEnable(self, element)
	else
		FPerl.UnitFrameDisable(self, element)
	end
end
