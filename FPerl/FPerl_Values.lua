-- Author: Resike
-- License: GNU GPL v3, 18 October 2014



------------------------------------------------------------------------------
-- restricted API support
--
-- The Forever client uses "secret values".
-- A secret cannot be compared, used in maths, used as a table key or tested as
-- a boolean; it can only be handed to Blizzard widget methods. Code that
-- touches unit health, power, auras, names or cast times goes through the
-- helpers below, and the Blizzard helper APIs are used only when the running
-- client provides them.
do
local issecretvalue = issecretvalue
local canaccessvalue = canaccessvalue

-- FPerl.CanAccess(v) - true when addon code may read, compare or index v
function FPerl.CanAccess(v)
	if (v == nil) then
		return false
	end
	if (canaccessvalue) then
		return canaccessvalue(v)
	end
	if (issecretvalue) then
		return not issecretvalue(v)
	end
	return true
end
local CanAccess = FPerl.CanAccess

-- FPerl.IsSecret(v) - true when v exists but addon code may not look inside it
function FPerl.IsSecret(v)
	return v ~= nil and not CanAccess(v)
end
local IsSecret = FPerl.IsSecret

-- FPerl.IsHit(action, damage) - true when a UNIT_COMBAT event dealt damage. The amount is secret on
-- Forever, so a secret amount counts as a hit when the action is a wound.
function FPerl.IsHit(action, damage)
	if (IsSecret(damage)) then
		return action == "WOUND"
	end
	return damage ~= nil and damage > 0
end

-- Feature switches, evaluated once at load
local HasHealthPercent = type(UnitHealthPercent) == "function" and CurveConstants ~= nil
local HasPowerPercent = type(UnitPowerPercent) == "function" and CurveConstants ~= nil
local HasColorCurves = C_CurveUtil ~= nil and type(C_CurveUtil.CreateColorCurve) == "function"
local HasBooleanCurves = C_CurveUtil ~= nil and type(C_CurveUtil.EvaluateColorValueFromBoolean) == "function"
local HasAuraAPI = C_UnitAuras ~= nil and type(C_UnitAuras.GetUnitAuras) == "function"
-- Asks the client whether it knows the template name, rather than assuming
-- from an interface or version number.
local HasAuraContainer = C_XMLUtil ~= nil and type(C_XMLUtil.GetTemplateInfo) == "function" and C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate") ~= nil

-- FPerl.SafeBool(v, default)
-- A boolean that may be secret cannot be tested or combined; return default then
function FPerl.SafeBool(v, default)
	if (not CanAccess(v)) then
		return default
	end
	return v
end

-- Shared with the other modules
FPerl.ForeverAPI = {
	healthPercent = HasHealthPercent,
	powerPercent = HasPowerPercent,
	colorCurves = HasColorCurves,
	booleanCurves = HasBooleanCurves,
	auras = HasAuraAPI,
	auraContainer = HasAuraContainer,
	castDurations = type(UnitCastingDuration) == "function",
	auraSecrecy = C_Secrets ~= nil and type(C_Secrets.ShouldAurasBeSecret) == "function",
}

for _, event in ipairs({"PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE"}) do
	FPerl.On(event, FPerl.GroupVisibilityUpdate)
end

-- FPerl.SetAlphaFromBoolean(region, value, alphaTrue, alphaFalse)
-- Shows/dims a region from a boolean that may be secret
function FPerl.SetAlphaFromBoolean(region, value, alphaTrue, alphaFalse)
	if (not region) then
		return
	end
	if (region.SetAlphaFromBoolean and IsSecret(value)) then
		region:SetAlphaFromBoolean(value, alphaTrue, alphaFalse)
	elseif (value and CanAccess(value)) then
		region:SetAlpha(alphaTrue)
	else
		region:SetAlpha(alphaFalse)
	end
end

-- FPerl.GetPowerPercent(unit, powerType)
-- Returns a 0..100 value for text display only; secret in the client (UnitPower is always secret).
function FPerl.GetPowerPercent(unit, powerType)
	if (HasPowerPercent and unit) then
		return UnitPowerPercent(unit, powerType, false, CurveConstants.ScaleTo100)
	end
	return 0
end

-- Aura enumeration -----------------------------------------------------------
local auraCacheUnit, auraCacheFilter, auraCacheTime, auraCacheList

-- FPerl.AurasSecret()
-- True while the client hides aura data from addons (in combat).
-- In that state every C_UnitAuras read raises a Lua error for addon code,
-- so callers check this before asking.
local ShouldAurasBeSecret = C_Secrets and C_Secrets.ShouldAurasBeSecret
function FPerl.AurasSecret()
	return ShouldAurasBeSecret ~= nil and ShouldAurasBeSecret() == true
end

if (HasAuraAPI) then
	-- Drop the cached vector as soon as any aura changes
	FPerl.On("UNIT_AURA", function()
		auraCacheList = nil
	end)
end
-- FPerl.UnitAuraByIndex(unit, index, filter)
-- Returns name, icon, applications, dispelName, duration, expirationTime, sourceUnit, isStealable,
-- nameplateShowPersonal, spellId, auraInstanceID, isFromPlayerOrPlayerPet.
-- Uses C_UnitAuras.GetUnitAuras when the client has it. The vector is cached for
-- the current frame so index loops do not re-query the client each step.
function FPerl.UnitAuraByIndex(unit, index, filter)
	if (FPerl.AurasSecret()) then
		auraCacheList = nil
		return nil
	end

	if (not HasAuraAPI) then
		return nil
	end

	local now = GetTime()
	if (auraCacheUnit ~= unit or auraCacheFilter ~= filter or auraCacheTime ~= now or not auraCacheList) then
		auraCacheUnit, auraCacheFilter, auraCacheTime = unit, filter, now
		-- pcall: the secrecy flag can flip between the check above and the query
		local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, filter or "HELPFUL", 40)
		auraCacheList = ok and list or nil
	end

	local aura = auraCacheList and auraCacheList[index]
	if (not aura) then
		return nil
	end
	return aura.name, aura.icon, aura.applications, aura.dispelName, aura.duration, aura.expirationTime, aura.sourceUnit, aura.isStealable, aura.nameplateShowPersonal, aura.spellId, aura.auraInstanceID, aura.isFromPlayerOrPlayerPet
end

-- FPerl.SafeSetWidthFromText(frame, textObject, padding, fallbackWidth)
-- GetStringWidth() can come back a secret number even for a FontString
-- holding plain, non-secret text: taint follows the execution path of the
-- surrounding update, not just the value being measured, so a readable
-- source string (e.g. checked via CanAccess) is not enough on its own.
-- Guard the width itself.
function FPerl.SafeSetWidthFromText(frame, textObject, padding, fallbackWidth)
	local width = textObject:GetStringWidth()
	if (IsSecret(width)) then
		frame:SetWidth(fallbackWidth)
	else
		frame:SetWidth(width + (padding or 0))
	end
end

-- FPerl.UnitFullName(unit)
-- Forever gives units a mandatory surname in UnitName's second return, joined
-- as Blizzard displays it ("Ana Forever"). The separator is ForeverGame.nameJoin, not
-- detected: the player's own name arrives pre-combined.
function FPerl.UnitFullName(unit)
	local n, s = UnitName(unit)
	if (s and CanAccess(s) and CanAccess(n) and s ~= "") then
		return n..FPerl.ForeverGame.nameJoin..s
	end
	return n
end
end -- restricted API support
