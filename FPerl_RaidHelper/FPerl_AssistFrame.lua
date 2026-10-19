-- Author: Resike
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

local conf
FPerl.RequestConfig(function(new)
	conf = new
end, "$Revision:  $")

local myClass
local playerAggro, petAggro
local doUpdate					-- In cases where we get multiple UNIT_TARGET events in 1 frame, we just set a flag and do during OnUpdate
local friendlyUnitList = {"player", "pet"}
local enemyUnitList = {}			-- Players with mobs targetted that target me
local wholeEnemyUnitList = { }			-- Players with mobs targetted
local currentPlayerAggro = { }

local GetNumGroupMembers = GetNumGroupMembers
local GetNumSubgroupMembers = GetNumSubgroupMembers

-- FPerl.RaidHelper.AssistsOnLoad(self)
function FPerl.RaidHelper.AssistsOnLoad(self)
	if self.SetResizeBounds then
		self:SetResizeBounds(170, 40, 1000, 600)
	else
		self:SetMinResize(170, 40)
		self:SetMaxResize(1000, 600)
	end

	self:RegisterEvent("VARIABLES_LOADED")
	self:RegisterEvent("UNIT_TARGET")
	self:RegisterEvent("GROUP_ROSTER_UPDATE")
	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_DEAD")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")

	self:SetScript("OnEvent", FPerl.RaidHelper.AssistsOnEvent)
	self:SetScript("OnMouseDown", FPerl.RaidHelper.AssistsMouseDown)
	self:SetScript("OnMouseUp", FPerl.RaidHelper.AssistsMouseUp)

	FPerl.RaidHelper.AssistsOnLoad = nil
end

-- FPerl.RaidHelper.SetFrameSides
function FPerl.RaidHelper.SetFrameSides()
	if (FPerl_Assists_Frame.LastSetView and FPerl_Assists_Frame.LastSetView[1] == FPerlRaidHelperDB.AssistsFrame and FPerl_Assists_Frame.LastSetView[2] == FPerlRaidHelperDB.TargettingFrame) then
		-- Frames the same from last time
		return
	end

	if (FPerlRaidHelperDB.AssistsFrame == 1 or FPerlRaidHelperDB.TargettingFrame == 1) then
		FPerl_Assists_Frame:Show()

		FPerl_Target_Targetting_ScrollFrame:ClearAllPoints()
		FPerl_Target_Assists_ScrollFrame:ClearAllPoints()

		if (FPerlRaidHelperDB.AssistsFrame == 1 and FPerlRaidHelperDB.TargettingFrame == 1) then
			FPerl_Target_Targetting_ScrollFrame:SetPoint("TOPLEFT", 4, -5)
			FPerl_Target_Targetting_ScrollFrame:SetPoint("BOTTOMRIGHT", FPerl_Assists_Frame, "BOTTOM", -0.5, 5)
			FPerl_Target_Targetting_ScrollFrame:Show()

			FPerl_Target_Assists_ScrollFrame:SetPoint("TOPLEFT", FPerl_Assists_Frame, "TOP", 0.5, -5)
			FPerl_Target_Assists_ScrollFrame:SetPoint("BOTTOMRIGHT", -4, 5)
			FPerl_Target_Assists_ScrollFrame:Show()

			FPerl_ScrollSeperator:Show()
			FPerl_ScrollSeperator:ClearAllPoints()
			FPerl_ScrollSeperator:SetPoint("TOPLEFT", FPerl_Target_Targetting_ScrollFrame, "TOPRIGHT", 0, 0)
			FPerl_ScrollSeperator:SetPoint("BOTTOMRIGHT", FPerl_Target_Assists_ScrollFrame, "BOTTOMLEFT", 0, 0)
		else
			FPerl_ScrollSeperator:Hide()

			if (FPerlRaidHelperDB.AssistsFrame == 1) then
				FPerl_Target_Assists_ScrollFrame:SetPoint("TOPLEFT", 4, -5)
				FPerl_Target_Assists_ScrollFrame:SetPoint("BOTTOMRIGHT", -4, 5)
				FPerl_Target_Assists_ScrollFrame:Show()
				FPerl_Target_Targetting_ScrollFrame:Hide()
			else
				FPerl_Target_Targetting_ScrollFrame:SetPoint("TOPLEFT", 4, -5)
				FPerl_Target_Targetting_ScrollFrame:SetPoint("BOTTOMRIGHT", -4, 5)
				FPerl_Target_Targetting_ScrollFrame:Show()
				FPerl_Target_Assists_ScrollFrame:Hide()
			end
		end
	else
		FPerl_Assists_Frame:Hide()
	end

	FPerl_Assists_Frame.LastSetView = {FPerlRaidHelperDB.AssistsFrame, FPerlRaidHelperDB.TargettingFrame}
end

-- ToggleAssistsFrame()
function FPerl.RaidHelper.ToggleAssistsFrame(param)
	if (param == "assists") then
		if (FPerlRaidHelperDB.AssistsFrame == 1) then
			FPerlRaidHelperDB.AssistsFrame = 0
		else
			FPerlRaidHelperDB.AssistsFrame = 1
		end
	else
		if (FPerlRaidHelperDB.TargettingFrame == 1) then
			FPerlRaidHelperDB.TargettingFrame = 0
		else
			FPerlRaidHelperDB.TargettingFrame = 1
		end
	end
end

-- FPerl.RaidHelper.AssistsViewClose
function FPerl.RaidHelper.AssistsViewOpen()
	FPerlRaidHelperDB.AssistsFrame = 1
	FPerlRaidHelperDB.TargettingFrame = 1
	FPerl.RaidHelper.SetFrameSides()
	return true
end

function FPerl.RaidHelper.AssistsViewClose()
	FPerlRaidHelperDB.AssistsFrame = 0
	FPerlRaidHelperDB.TargettingFrame = 0
	FPerl.RaidHelper.SetFrameSides()
end

-- SortByClass(t1, t2)
local function SortByClass(t1, t2)
	-- enemy names are secret inside instances and cannot be
	-- compared, so they keep their scan order
	if (not FPerl.CanAccess(t1[1]) or not FPerl.CanAccess(t2[1])) then
		return false
	end
	if (t1[2] == t2[2]) then
		return t1[1] < t2[1]
	else
		local t1c = t1[2]
		local t2c = t2[2]
		if (t1c == myClass) then
			t1c = "A"..t1c
		elseif (t1c ~= "") then
			t1c = "B"..t1c
		else
			t1c = "Z"
		end
		if (t2c == myClass) then
			t2c = "A"..t2c
		elseif (t2c ~= "") then
			t2c = "B"..t2c
		else
			t1c = "Z"
		end

		return t1c..t1[1] < t2c..t2[1]
	end
end

-- FPerl.RaidHelper.MakeAssistsString
function FPerl.RaidHelper.MakeAssistsString(List, title)
	local text = title

	if (List ~= nil) then
		local lastClass
		local any = false
		local nAssists = #List
		if (nAssists > 0) then
			text = text.." "..nAssists
		end
		text = text.."\13"

		sort(List, SortByClass)

		for i,unit in ipairs(List) do
			if (not any) then
				if (unit[2] == "") then
					text = text.."|c00FF0000"..unit[1]
				else
					text = text..FPerl.ColourTable[unit[2]]..unit[1]
				end
				lastClass, any = unit[2], true
			else
				if (lastClass) then
					if (unit[2] == "" or lastClass ~= unit[2]) then
						lastClass = unit[2]

						if (unit[2] == "") then
							text = text.."\r|c00FF0000"..unit[1]
						else
							text = text.."\r"..FPerl.ColourTable[unit[2]]..unit[1]
						end
					else
						text = text.." "..unit[1]
					end
				else
					text = text.." "..unit[1]

					lastClass = unit[2]
				end
			end
		end
	end

	return (text)
end

-- FillList
local function FillList(List, cFrame, title)
	local text = FPerl.RaidHelper.MakeAssistsString(List, title)
	_G["FPerl_Target_Assists_ScrollChild_"..cFrame.."Text"]:SetText(text)
end

-- FPerl.RaidHelper.ShowAssists()
function FPerl.RaidHelper.ShowAssists()
	if (FPerlRaidHelperDB and (FPerlRaidHelperDB.AssistsFrame == 1 or FPerlRaidHelperDB.TargettingFrame == 1)) then
		if (FPerlRaidHelperDB.AssistsFrame == 1 and FPerl_Assists_Frame.assists ~= nil) then
			FillList(FPerl_Assists_Frame.assists, "Assists", FPERL_TOOLTIP_ASSISTING)
		end

		if (FPerlRaidHelperDB.TargettingFrame == 1 and FPerl_Assists_Frame.targetting ~= nil) then
			local title
			if (#FPerl_Assists_Frame.targetting > 0 and FPerl_Assists_Frame.targetting[1][2] == "") then
				title = FPERL_TOOLTIP_ENEMYONME
			else
				if (FPerlRaidHelperDB.TargetCountersSelf == 0) then
					title = FPERL_TOOLTIP_ALLONME
				else
					title = FPERL_TOOLTIP_HEALERS
				end
			end

			FillList(FPerl_Assists_Frame.targetting, "Targetting", title)
		end
	end
end

-- FPerl.RaidHelper.AssistsMouseDown
function FPerl.RaidHelper.AssistsMouseDown(self, button, param)
	if (button == "LeftButton") then
		if (not FPerlRaidHelperDB or not FPerlRaidHelperDB.AssistPinned or (IsAltKeyDown() and IsControlKeyDown() and IsShiftKeyDown())) then
			--if (param and (param == "TOPLEFT" or param == "BOTTOMLEFT" or param == "BOTTOMRIGHT")) then
			--	self:StartSizing(param)
			--else
				FPerl_Assists_FrameAnchor:StartMoving()
			--end
		end

	elseif (button == "RightButton") then
		local n = self:GetName()
		if (n and strfind (n, "FPerl_Target_Assists_ScrollChild_Targetting")) then
			param = "targetFrame"
		end

		if (param and param == "targetFrame") then
			if (FPerlRaidHelperDB.TargetCountersSelf == 1) then
				FPerlRaidHelperDB.TargetCountersSelf = 0
			else
				FPerlRaidHelperDB.TargetCountersSelf = 1
			end
			FPerl.RaidHelper.UpdateAssists()
			FPerl.RaidHelper.ShowAssists()
		end
	end
end

-- FPerl.RaidHelper.AssistsMouseUp
function FPerl.RaidHelper.AssistsMouseUp(self, button)
	--FPerl_Assists_Frame:StopMovingOrSizing()
	FPerl_Assists_FrameAnchor:StopMovingOrSizing()
	if (FPerl.SavePosition) then
		FPerl.SavePosition(FPerl_Assists_FrameAnchor)
	end

	-- FPerl.RegisterScalableFrame(self, FPerl_Assists_FrameAnchor, nil, nil, nil, true, true)
end

-- MakeFriendlyUnitList
local function MakeFriendlyUnitList()
	local start, prefix, total
	if IsInRaid() then
		start, prefix, total = 1, "raid", GetNumGroupMembers()
	else
		start, prefix, total = 0, "party", GetNumSubgroupMembers()
	end

	--friendlyUnitList = {"player", "pet"}
	--FPerl.FreeTable(friendlyUnitList)
	--friendlyUnitList = FPerl.GetReusableTable()
	friendlyUnitList = { }
	tinsert(friendlyUnitList, "player")
	tinsert(friendlyUnitList, "pet")

	local name, petname
	for i = start, total do
		if (i == 0) then
			name, petname = "player", "pet"
		else
			name, petname = prefix..i, prefix.."pet"..i
		end

		if (not FPerl.SafeBool(UnitIsUnit(name, "player"), false)) then
			if (UnitExists(name)) then
				tinsert(friendlyUnitList, name)
			end
			if (UnitExists(petname)) then
				tinsert(friendlyUnitList, petname)
			end
		end
	end
end

-- Events
function FPerl.RaidHelper.AssistsOnEvent(self, event, unit)
	-- UNIT_TARGET's own unit argument can itself be an
	-- indirect unit like "targettarget" (Confirmed crashing
	-- exactly there) -- this was wrongly judged low-risk earlier in this
	-- session on the assumption unit would always be a direct party/raid
	-- member; the live crash disproves that.
	if (event == "PLAYER_TARGET_CHANGED" or (event == "UNIT_TARGET" and not FPerl.SafeBool(UnitIsUnit(unit, "player"), true))) then
		doUpdate = true
	elseif (event == "VARIABLES_LOADED") then
		MakeFriendlyUnitList()
		FPerl.RaidHelper.UpdateAssists()
		FPerl.RaidHelper.ShowAssists()

		FPerl.RegisterScalableFrame(self, FPerl_Assists_FrameAnchor, nil, nil, nil, true, true)
		self.corner.onSizeChanged = function(self, x, y)
			FPerlRaidHelperDB.sizeAssistsX = x
			FPerlRaidHelperDB.sizeAssistsY = y
		end
		self.corner.onScaleChanged = function(self, s)
			FPerlRaidHelperDB.sizeAssistsS = s
		end
		FPerl_AssistPin:SetButtonTex()
	elseif (event == "GROUP_ROSTER_UPDATE") then
		MakeFriendlyUnitList()
		doUpdate = true
	elseif (event == "PLAYER_DEAD" or event == "PLAYER_REGEN_ENABLED") then
		--FPerl.FreeTable(currentPlayerAggro)
		--currentPlayerAggro = FPerl.GetReusableTable()
		currentPlayerAggro = { }
		if (FPerl_Highlight) then
			FPerl_Highlight:ClearAll("AGGRO")
		end
		FPerl.RaidHelper.UpdateAssists()
		FPerl.RaidHelper.ShowAssists()
	elseif (event == "PLAYER_ENTERING_WORLD") then
		if (FPerl_Highlight) then
			FPerl_Highlight:ClearAll("AGGRO")
		end

		MakeFriendlyUnitList()
		doUpdate = true
	end
end

-- FPerl.RaidHelper.AssistsOnUpdate
local UpdateTime = 0
function FPerl.RaidHelper.AssistsOnUpdate(self, arg1)
	UpdateTime = arg1 + UpdateTime
	if (doUpdate or UpdateTime >= 0.2) then
		if (doUpdate or #enemyUnitList > 0) then
			doUpdate = false
			FPerl.RaidHelper.UpdateAssists()
			FPerl.RaidHelper.ShowAssists()
		end
		UpdateTime = 0
	end
end

---------------------------------
-- Targetting counters         --
---------------------------------

local assists
local targetting

-- FoundEnemyBefore
local function FoundEnemyBefore(FoundEnemy, name)
	-- same indirect-unit secret-boolean risk as the rest of
	-- this file; this helper is called from every site already fixed above.
	for previous in pairs(FoundEnemy) do
		if (FPerl.SafeBool(UnitIsUnit(previous.."target", name.."target"), false)) then
			return true
		end
	end
	return false
end

-- AddEnemy
local function AddEnemy(anyEnemy, FoundEnemy, name)
	local namet = name.."target"
	local namett = namet.."target"
	if (not FoundEnemyBefore(wholeEnemyUnitList, name)) then
		if (UnitExists(namet)) then
			wholeEnemyUnitList[name] = true

			if (FPerl_Highlight and conf and conf.highlight.AGGRO) then
				-- same doubly-indirect secret-boolean risk as
				-- below; fixed proactively alongside the confirmed crash.
				if (FPerl.SafeBool(UnitInRaid(namett), false) or FPerl.SafeBool(UnitInParty(namett), false)) then
					local aggroName = UnitName(namett)
					if (aggroName and FPerl.CanAccess(aggroName)) then
						currentPlayerAggro[aggroName] = UnitGUID(namett)
					end
				end
			end
		end
	end

	-- namett (name.."target".."target") is doubly indirect --
	-- an even higher secret-boolean risk than the single-indirect units
	-- already fixed above (section 3). Confirmed crashing on
	-- UnitIsUnit("target", "playertargettarget").
	if (FPerl.SafeBool(UnitIsUnit("player", namett), false)) then
		if (not FoundEnemyBefore(FoundEnemy, name)) then
			if (not playerAggro and FPerlRaidHelperDB.AggroWarning == 1) then
				playerAggro = true
				FPerl_AggroPlayer:Show()
			end

			FoundEnemy[name] = true
			tinsert(targetting, {UnitName(namet), ""})
			return true
		end
	-- 1.8.3 Added check to see if mob is targetting our target, and add to that list
	elseif (UnitExists("target") and FPerl.SafeBool(UnitIsUnit("target", namett), false)) then
		-- We can still use the FoundEnemy list, because it's not too important if
		-- we're targetting ourself and the mob doesn't show on both self and target lists
		if (not FoundEnemyBefore(FoundEnemy, name)) then
			FoundEnemy[name] = true
			tinsert(assists, {UnitName(namet), ""})
			return true
		end
	elseif (not petAggro and FPerlRaidHelperDB.AggroWarning == 1 and UnitExists(namett) and FPerl.SafeBool(UnitIsUnit("pet", namett), false)) then
		petAggro = true
		--petFadeStart = GetTime()
		FPerl_AggroPet:Show()
	end

	return false
end

local HealerClasses = {PRIEST = true, SHAMAN = true, PALADIN = true, DRUID = true}

-- FPerl.RaidHelper.UpdateAssists
function FPerl.RaidHelper.UpdateAssists()
	--FPerl.FreeTable(wholeEnemyUnitList)
	--wholeEnemyUnitList = FPerl.GetReusableTable()
	wholeEnemyUnitList = { }

	local oldPlayerAggro = currentPlayerAggro
	--currentPlayerAggro = FPerl.GetReusableTable()
	currentPlayerAggro = { }
	if FPerlRaidHelperDB and FPerlRaidHelperDB.TargetCounters == 0 then
		if (FPerl_Target_AssistFrame) then
			FPerl_Target_AssistFrame:Hide()
		end
		if (FPerl_Player_TargettingFrame) then
			FPerl_Player_TargettingFrame:Hide()
		end
		return
	end

	local selfFlag, enemyFlag
	if FPerlRaidHelperDB then
		selfFlag = FPerlRaidHelperDB.TargetCountersSelf == 1
		enemyFlag = FPerlRaidHelperDB.TargetCountersEnemy == 1
	end

	local assistCount, targettingCount, anyEnemy = 0, 0, false
	--local start, i, total, prefix, name, petname

	--local FoundEnemy = FPerl.GetReusableTable()
	local FoundEnemy = { }

	-- Re-use all the old tables from last pass
	--assists = FPerl_Assists_Frame.assists
	--targetting = FPerl_Assists_Frame.targetting
	--FPerl.FreeTable(assists)
	--FPerl.FreeTable(targetting)
	--assists = { }
	--targetting = { }

	-- Get new tables
	--assists = FPerl.GetReusableTable()
	assists = { }
	--targetting = FPerl.GetReusableTable()
	targetting = { }

	playerAggro, petAggro = false, false

	local targetname = UnitName("target")
	for i, name in pairs(friendlyUnitList) do
		if (UnitExists(name.."target") and not UnitIsDeadOrGhost(name)) then
			local _, engClass = UnitClass(name)

			-- name.."target" is an indirect unit -- these
			-- three UnitIsUnit/UnitCanAttack booleans can be secret (section
			-- 3), Confirmed crashing on UnitIsUnit("target",
			-- "playertarget").
			if (targetname) then
				if (FPerl.SafeBool(UnitIsUnit("target", name.."target"), false)) then
					assistCount = assistCount + 1
					tinsert(assists, {UnitName(name), engClass})
				end
			end

			-- 0 for Anyone, 1 for Healers
			if (not selfFlag or HealerClasses[engClass]) then
				if (FPerl.SafeBool(UnitIsUnit("player", name.."target"), false)) then
					targettingCount = targettingCount + 1
					tinsert(targetting, {UnitName(name), engClass})
				end
			end

			-- Count enemy targetting us?
			if (enemyFlag) then
				if (FPerl.SafeBool(UnitCanAttack("player", name.."target"), false)) then	-- not UnitIsFriend("player", name.."target")) then
					if (AddEnemy(anyEnemy, FoundEnemy, name)) then
						anyEnemy = true
						targettingCount = targettingCount + 1
					end
				end
			end
		end
	end

	if (enemyFlag) then
		-- same indirect-unit secret-boolean shape as above;
		-- "focustarget" is indirect too. Default to "friend"/"not a match" so
		-- an unreadable state just skips the aggro warning rather than
		-- risking a false one.
		if (not FPerl.SafeBool(UnitIsFriend("player", "focus"), true)) then
			if (FPerl.SafeBool(UnitIsUnit("player", "focustarget"), false)) then
				if (FPerl_Highlight and conf and conf.highlight.AGGRO) then
					currentPlayerAggro[UnitName("player")] = UnitGUID("player")
				end

				if (not FoundEnemyBefore(FoundEnemy, "focus")) then
					if (not playerAggro and FPerlRaidHelperDB.AggroWarning == 1) then
						playerAggro = true
						FPerl_AggroPlayer:Show()
					end

					FoundEnemy["focus"] = true
					tinsert(targetting, {UnitName("focus"), ""})
					return true
				end
			end
		end
	end

	FPerl_Assists_Frame.assists, FPerl_Assists_Frame.targetting = assists, targetting

	if (playerAggro or petAggro) then
		FPerl_Aggro:Show()
	end

	enemyUnitList = FoundEnemy

	if (FPerl_Highlight and conf and conf.highlight.AGGRO) then
		for k, v in pairs(oldPlayerAggro) do
			if (not currentPlayerAggro[k]) then
				FPerl_Highlight:Remove(v, "AGGRO")
			end
		end
		for k, v in pairs(currentPlayerAggro) do
			if (not oldPlayerAggro[k]) then
				FPerl_Highlight:Add(v, "AGGRO", 0)
			end
		end
	end

	if FPerlRaidHelperDB and FPerlRaidHelperDB.ShowTargetCounters == 1 then
		if (FPerl_Player_TargettingFrame) then
			if (FPerl_Player) then
				local color = (conf and conf.colour.border) or (FPerlRaidHelperDB and FPerlRaidHelperDB.BorderColour) or {r = 0.5, g = 0.5, b = 0.5}

				if (anyEnemy) then
					FPerl_Player_TargettingFrame:SetBackdropBorderColor(1, 0.2, 0.2, color.a)
				else
					FPerl_Player_TargettingFrame:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
				end

				if (targettingCount == 0) then
					FPerl_Player_TargettingFrametext:SetTextColor(1, 0.5, 0.5, conf.transparency.text)
				elseif (targettingCount > 5) then
					FPerl_Player_TargettingFrametext:SetTextColor(0.5, 1, 0.5, conf.transparency.text)
				else
					FPerl_Player_TargettingFrametext:SetTextColor(0.5, 0.5, 1, conf.transparency.text)
				end

				FPerl_Player_TargettingFrame:SetText(targettingCount)
				FPerl_Player_TargettingFrame:Show()
			else
				FPerl_Player_TargettingFrame:Hide()
			end
		end

		if (FPerl_Target_AssistFrame) then
			if (FPerl_Target) then
				if (assistCount < 2) then
					FPerl_Target_AssistFrametext:SetTextColor(1, 0.5, 0.5, conf.transparency.text)
				elseif (assistCount > (#friendlyUnitList / 2)) then
					FPerl_Target_AssistFrametext:SetTextColor(0.5, 1, 0.5, conf.transparency.text)
				else
					FPerl_Target_AssistFrametext:SetTextColor(0.5, 0.5, 1, conf.transparency.text)
				end

				if (targetname) then
					FPerl_Target_AssistFrame:SetText(assistCount)
				end
				FPerl_Target_AssistFrame:Show()
			else
				FPerl_Target_AssistFrame:Hide()
			end
		end
	else
		FPerl_Player_TargettingFrame:Hide()
		FPerl_Target_AssistFrame:Hide()
	end

	--FPerl.FreeTable(oldPlayerAggro)
	--FPerl.FreeTable(FoundEnemy)
end

-- FPerl.RaidHelper.AssistsGetEnemyUnitList
function FPerl.RaidHelper.AssistsGetEnemyUnitList()
	return wholeEnemyUnitList
end

-- FPerl.RaidHelper.StartAssists
function FPerl.RaidHelper.StartAssists()
	local _
	_, myClass = UnitClass("player")

	FPerl.ColourTable.pet = "|c008080FF"

	if (FPerl.RegisterPerlFrames) then
		FPerl.RegisterPerlFrames(FPerl_Assists_Frame)
	end

	FPerl.RaidHelper.SetFrameSides()
end

-- FPerl.RaidHelper.RefreshAggro
function FPerl.RaidHelper.RefreshAggro(self)
	if (playerAggro) then
		FPerl_AggroPlayer:SetVertexColor(1, 0, 0, 1)
	else
		if (self.playerFadeStart) then
			local elapsed = GetTime() - self.playerFadeStart
			if (elapsed < 1) then
				FPerl_AggroPlayer:SetVertexColor(0, 1, 0, 1 - elapsed)
			else
				FPerl_AggroPlayer:Hide()
				self.playerFadeStart = nil
				if (not FPerl_AggroPet:IsShown()) then
					self:Hide()
				end
			end
		else
			self.playerFadeStart = GetTime()
		end
	end
	if (petAggro) then
		FPerl_AggroPet:SetVertexColor(1, 0, 0, 1)
	else
		if (self.petFadeStart) then
			local elapsed = GetTime() - self.petFadeStart
			if (elapsed < 1) then
				FPerl_AggroPet:SetVertexColor(0, 1, 0, 1 - elapsed)
			else
				FPerl_AggroPet:Hide()
				self.petFadeStart = nil
				if (not FPerl_AggroPlayer:IsShown()) then
					self:Hide()
				end
			end
		else
			self.petFadeStart = GetTime()
		end
	end
end
