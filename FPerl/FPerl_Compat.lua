-- F-Perl - API compatibility shims
--
-- The client ships the retail addon API, which lacks some globals the Z-Perl code
-- base calls (GetItemInfo is nil; C_Item.GetItemInfo has the same returns). Each
-- shim below defines a missing global from its C_* replacement, only when the
-- global is missing and the replacement exists.

-- The addon table. Every function and shared table is a field of FPerl, or of the sub-table of its module or raid
-- tool (FPerl.Party.OnLoad). Frames and templates keep the FPerl_ prefix because the engine owns their global names.
FPerl = {}
for _, module in ipairs({"ArcaneBar", "AuraBlacklist", "CustomHighlight", "Party", "PartyPet", "Player", "PlayerBuffs",
	"PlayerPet", "Raid", "RaidPets", "Target", "TargetTarget", "RaidAdmin", "RaidHelper", "RaidMonitor"}) do
	FPerl[module] = {}
end

-- The highlight manager, created here with no-op methods so a frame that calls
-- one finds it even when FPerl_Highlight.lua errors before defining its own.
-- FPerl_Highlight.lua reuses this frame and replaces the methods.
if (not FPerl_Highlight) then
	FPerl_Highlight = CreateFrame("Frame", "FPerl_Highlight")
	local function NoOp() end
	FPerl_Highlight.Register = NoOp
	FPerl_Highlight.SetHighlight = NoOp
	FPerl_Highlight.RemoveHighlight = NoOp
	FPerl_Highlight.ClearAll = NoOp
	FPerl_Highlight.Add = NoOp
	FPerl_Highlight.Remove = NoOp
	FPerl_Highlight.TooltipInfo = NoOp
end

-- FPerl.SpellName(spellID)
-- Spell name for use as a table key. The lookup returns nil for a spell ID the
-- client does not have, and "[nil] = true" in a table constructor errors and
-- aborts the rest of the file. A unique placeholder that can never match a real
-- aura name is returned instead.
function FPerl.SpellName(spellID)
	local name
	if (C_Spell and C_Spell.GetSpellInfo) then
		local info = C_Spell.GetSpellInfo(spellID)
		name = info and info.name
	elseif (GetSpellInfo) then
		name = GetSpellInfo(spellID)
	end
	return name or ("FPerl_NoSpell_"..tostring(spellID))
end

if (not GetSpellInfo and C_Spell and C_Spell.GetSpellInfo) then
	GetSpellInfo = function(spell)
		local info = C_Spell.GetSpellInfo(spell)
		if (info) then
			return info.name, nil, info.iconID, info.castTime, info.minRange, info.maxRange, info.spellID, info.originalIconID
		end
	end
end

if (not GetItemInfo and C_Item and C_Item.GetItemInfo) then
	GetItemInfo = C_Item.GetItemInfo
end

if (not GetItemCount and C_Item and C_Item.GetItemCount) then
	GetItemCount = C_Item.GetItemCount
end

if (not IsAddOnLoaded and C_AddOns and C_AddOns.IsAddOnLoaded) then
	IsAddOnLoaded = C_AddOns.IsAddOnLoaded
end

if (not GetAddOnMetadata and C_AddOns and C_AddOns.GetAddOnMetadata) then
	GetAddOnMetadata = C_AddOns.GetAddOnMetadata
end

if (not GetAddOnInfo and C_AddOns and C_AddOns.GetAddOnInfo) then
	GetAddOnInfo = C_AddOns.GetAddOnInfo
end

if (not LoadAddOn and C_AddOns and C_AddOns.LoadAddOn) then
	LoadAddOn = C_AddOns.LoadAddOn
end

if (not EnableAddOn and C_AddOns and C_AddOns.EnableAddOn) then
	EnableAddOn = C_AddOns.EnableAddOn
end

if (not DisableAddOn and C_AddOns and C_AddOns.DisableAddOn) then
	DisableAddOn = C_AddOns.DisableAddOn
end
