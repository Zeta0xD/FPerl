-- Author: Resike
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo

-- FPerl.RaidMonitor.InitCast(cast, TableUnits, castColours, UpdateTarget)
-- Defines the UNIT_SPELLCAST_* and UNIT_TARGET handlers on the monitor frame cast
function FPerl.RaidMonitor.InitCast(cast, TableUnits, castColours, UpdateTarget)
	-- cast:UNIT_SPELLCAST_START
	function cast:UNIT_SPELLCAST_START(unit)
		if (not unit or not strfind(unit, "^raid%d+$")) then
			return
		end
		local bar = TableUnits[unit]
		if (bar and bar:IsShown()) then
			local name, _, texture, startTime, endTime = UnitCastingInfo(unit)
			if (name == nil or not FPerl.CanAccess(startTime) or not FPerl.CanAccess(endTime) or startTime >= endTime) then
				return
			end
			bar.castBar.name:SetText(name)
			bar.castBar.icon:SetTexture(texture)
			bar.castBar.spark:Show()
			bar.bar.name:Hide()
			bar.startTime = startTime / 1000
			bar.maxValue = endTime / 1000
			bar.castBar:SetStatusBarColor(castColours.main.r, castColours.main.g, castColours.main.b)
			bar.castBar:SetMinMaxValues(bar.startTime, bar.maxValue)
			bar.castBar:SetValue(bar.startTime)
			bar.castBar:Show()
			bar.castBar:SetAlpha(1)
			bar.holdTime = 0
			bar.casting = true
			bar.channeling = nil
			bar.fadeOut = nil
		end
	end

	-- cast:UNIT_SPELLCAST_STOP
	function cast:UNIT_SPELLCAST_STOP(unit)
		if (not unit or not strfind(unit, "^raid%d+$")) then
			return
		end
		local bar = TableUnits[unit]
		if (bar and bar.casting and bar:IsShown()) then
			bar.castBar.spark:Hide()
			bar.casting = nil
			bar.channeling = nil
			bar.fadeOut = true
		end
	end

	-- cast:UNIT_SPELLCAST_FAILED
	function cast:UNIT_SPELLCAST_FAILED(unit)
		if (not unit or not strfind(unit, "^raid%d+$")) then
			return
		end
		local bar = TableUnits[unit]
		if (bar and bar.casting and bar:IsShown()) then
			bar.castBar.name:SetText(FAILED)
			bar.castBar:SetValue(bar.maxValue or 1)
			bar.castBar:SetStatusBarColor(castColours.failure.r, castColours.failure.g, castColours.failure.b)
			bar.castBar.spark:Hide()
			bar.casting = nil
			bar.channeling = nil
			bar.fadeOut = true
		end
	end

	-- cast:UNIT_SPELLCAST_INTERRUPTED
	function cast:UNIT_SPELLCAST_INTERRUPTED(unit)
		if (not unit or not strfind(unit, "^raid%d+$")) then
			return
		end
		local bar = TableUnits[unit]
		if (bar and bar.casting and bar:IsShown()) then
			bar.castBar.name:SetText(SPELL_FAILED_INTERRUPTED)
			bar.castBar:SetValue(bar.maxValue or 1)
			bar.castBar:SetStatusBarColor(castColours.failure.r, castColours.failure.g, castColours.failure.b)
			bar.castBar.spark:Hide()
			bar.casting = nil
			bar.channeling = nil
			bar.fadeOut = true
		end
	end

	-- cast:UNIT_SPELLCAST_SUCCEEDED
	function cast:UNIT_SPELLCAST_SUCCEEDED(unit)
		if (not unit or not strfind(unit, "^raid%d+$")) then
			return
		end
		local bar = TableUnits[unit]
		if (bar and bar.casting and bar:IsShown()) then
			bar.castBar:SetValue(bar.maxValue or 1)
			bar.castBar:SetStatusBarColor(castColours.success.r, castColours.success.g, castColours.success.b)
			bar.casting = nil
			bar.channeling = nil
			bar.fadeOut = true
			bar.castBar:SetAlpha(1)
		end
	end

	-- cast:UNIT_SPELLCAST_DELAYED
	function cast:UNIT_SPELLCAST_DELAYED(unit)
		if (not unit or not strfind(unit, "^raid%d+$")) then
			return
		end
		local bar = TableUnits[unit]
		if (bar and bar.casting and bar:IsShown()) then
			local name, _, _, startTime, endTime = UnitCastingInfo(unit)
			if (name == nil or not FPerl.CanAccess(startTime) or not FPerl.CanAccess(endTime) or startTime >= endTime) then
				return
			end
			bar.startTime = startTime / 1000
			bar.maxValue = endTime / 1000
			bar.castBar:SetMinMaxValues(bar.startTime, bar.maxValue)
		end
	end

	-- cast:UNIT_SPELLCAST_CHANNEL_START
	function cast:UNIT_SPELLCAST_CHANNEL_START(unit)
		if (not unit or not strfind(unit, "^raid%d+$")) then
			return
		end
		local bar = TableUnits[unit]
		if (bar and bar:IsShown()) then
			local name, _, texture, startTime, endTime = UnitChannelInfo(unit)
			if (name == nil or not FPerl.CanAccess(startTime) or not FPerl.CanAccess(endTime) or startTime >= endTime) then
				return
			end
			bar.castBar:SetStatusBarColor(castColours.channel.r, castColours.channel.g, castColours.channel.b)
			bar.castBar.name:SetText(name)
			bar.castBar.spark:Show()
			bar.bar.name:Hide()
			bar.castBar.icon:SetTexture(texture)
			bar.maxValue = 1
			bar.startTime = startTime / 1000
			bar.endTime = endTime / 1000
			bar.castBar:SetMinMaxValues(bar.startTime, bar.endTime)
			bar.castBar:SetValue(bar.endTime)
			bar.casting = nil
			bar.fadeOut = nil
			bar.channeling = true
			bar.castBar:Show()
			bar.castBar:SetAlpha(1)
		end
	end

	-- cast:UNIT_SPELLCAST_CHANNEL_UPDATE
	function cast:UNIT_SPELLCAST_CHANNEL_UPDATE(unit)
		if (not unit or not strfind(unit, "^raid%d+$")) then
			return
		end
		local bar = TableUnits[unit]
		if (bar and bar.channeling and bar:IsShown()) then
			local name, _, _, startTime, endTime = UnitChannelInfo(unit)
			if (name == nil or not FPerl.CanAccess(startTime) or not FPerl.CanAccess(endTime) or startTime >= endTime) then
				return
			end
			bar.startTime = startTime / 1000
			bar.endTime = endTime / 1000
			bar.maxValue = bar.startTime
			bar.castBar:SetMinMaxValues(bar.startTime, bar.endTime)
		end
	end

	-- cast:UNIT_SPELLCAST_CHANNEL_STOP
	function cast:UNIT_SPELLCAST_CHANNEL_STOP(unit)
		if (not unit or not strfind(unit, "^raid%d+$")) then
			return
		end
		local bar = TableUnits[unit]
		if (bar and bar.channeling and bar:IsShown()) then
			bar.castBar:SetValue(bar.maxValue)
			bar.castBar:SetStatusBarColor(castColours.success.r, castColours.success.g, castColours.success.b)
			bar.castBar.spark:Hide()
			bar.casting = nil
			bar.channeling = nil
			bar.fadeOut = true
		end
	end

	-- cast:UNIT_TARGET
	function cast:UNIT_TARGET(unit)
		if (not unit or not strfind(unit, "^raid%d+$")) then
			return
		end
		local bar = TableUnits[unit]
		if (bar and bar:IsShown()) then
			UpdateTarget(bar.target)
		end
	end

	FPerl.RaidMonitor.InitCast = nil
end
