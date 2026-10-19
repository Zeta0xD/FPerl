-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)
--
-- Hides chosen buffs on the Target, Focus, Target's Target and Focus Target
-- frames. The only links to the core are FPerl.AuraBlacklist.Set (read by
-- FPerl.AurasRebuild) and an entry in FPerl.SettingsPages for its settings page.

if (not FPerl.AurasUpdate or not FPerl.CanAccess or not FPerl.SafeBool) then
	return
end

local floor = floor
local format = format
local next = next
local pairs = pairs
local sort = table.sort
local strlower = strlower
local strtrim = strtrim
local tonumber = tonumber
local type = type
local wipe = wipe

local CanAccess = FPerl.CanAccess
local GetSpellTextureFunc = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture

local ADDON_NAME = "FPerl"
local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"
local ROWS = 16
local ROW_HEIGHT = 22

-- self.partyid of the frames that are filtered
local filteredUnits = {
	target = true,
	focus = true,
	targettarget = true,
	focustarget = true,
}

-- Units searched when a buff is added by name
local scanUnits = {"target", "focus", "targettarget", "focustarget", "player"}

local db			-- FPerlDB.account.blacklist
local spells		-- db.spells: [spellID] = {name = "...", showMine = true|nil}
local sorted = {}	-- spell IDs in display order
local sortKeys = {}
local config		-- options tab content, built the first time the tab is shown

-- SpellNameIcon(spell) - name, icon, spellID for a spell ID or name; nil if unknown
local function SpellNameIcon(spell)
	local name, icon, id
	if (C_Spell and C_Spell.GetSpellInfo) then
		local info = C_Spell.GetSpellInfo(spell)
		if (info) then
			name, icon, id = info.name, info.iconID, info.spellID
		end
	elseif (GetSpellInfo) then
		local _
		name, _, icon, _, _, _, id = GetSpellInfo(spell)
	end
	if (not CanAccess(name)) then
		return nil
	end
	return name, icon, id
end

-- DisplayName(id, entry)
local function DisplayName(id, entry)
	return entry.name or format(FPERL_AURABL_SPELL, id)
end

-- SortByName
local function SortByName(a, b)
	local ka, kb = sortKeys[a], sortKeys[b]
	if (ka ~= kb) then
		return ka < kb
	end
	return a < b
end

-- RebuildSorted() - only after add / remove / import, never per frame
local function RebuildSorted()
	wipe(sorted)
	wipe(sortKeys)
	if (not spells) then
		return
	end
	for id, entry in pairs(spells) do
		sorted[#sorted + 1] = id
		sortKeys[id] = strlower(DisplayName(id, entry))
	end
	sort(sorted, SortByName)
end

-- GetBBFList() - BetterBlizzFrames' blacklist (read only), or nil
local function GetBBFList()
	local bbf = BetterBlizzFramesDB
	if (type(bbf) == "table" and type(bbf.auraBlacklist) == "table") then
		return bbf.auraBlacklist
	end
end

-- InitDB() - on our ADDON_LOADED (SavedVariables are ready then)
local function InitDB()
	-- Account-wide, outside layouts.
	local cfg = FPerlDB
	if (type(cfg.account) ~= "table") then
		cfg.account = {}
	end
	if (type(cfg.account.blacklist) ~= "table") then
		cfg.account.blacklist = {}
	end
	db = cfg.account.blacklist
	if (db.enabled == nil) then
		db.enabled = true
	end
	if (type(db.spells) ~= "table") then
		db.spells = {}
	end
	-- Drop anything that is not [integer] = table, and bad name/showMine values, so lookups and sorting stay safe
	for id, entry in pairs(db.spells) do
		if (type(id) ~= "number" or id ~= floor(id) or id < 1 or id > 2^31 or type(entry) ~= "table") then
			db.spells[id] = nil
		elseif (type(entry.name) ~= "string") then
			entry.name = nil
		end
		if (db.spells[id] and entry.showMine ~= nil and entry.showMine ~= true) then
			entry.showMine = nil
		end
	end
	spells = db.spells
end

-- Aura exclusion ------------------------------------------------------------
-- FPerl.AurasRebuild asks FPerl.AuraBlacklist.Set(frame) for the spell IDs to drop from the frame's
-- buff group and merges them into the group's candidate filters (FPerl.AurasGroups). The set holds
-- every listed ID: Blizzard skips excludeSpellIDs per aura where identity filtering is not permitted,
-- never-secret spells excepted (AuraContainerUtil.CanApplyIdentityCandidateFilters). "Show if mine"
-- cannot be honoured in one group.

local excludeSet		-- [spellID] = true for every listed ID; nil when the list is empty
local setDirty = true	-- rebuild the set on next use

function FPerl.AuraBlacklist.Set(frame)
	if (not db or not db.enabled or not frame or not filteredUnits[frame.partyid]) then
		return nil
	end
	if (setDirty) then
		local all = {}
		for id in pairs(spells) do
			all[id] = true
		end
		excludeSet = next(all) and all or nil
		setDirty = nil
	end
	return excludeSet
end

-- Refresh(frame) - rebuild the frame's containers with the current list (a rebuild in combat stays
-- pending until auras are readable), then show the result
local function Refresh(frame)
	if (frame and frame.buffContainer) then
		FPerl.AurasRebuild(frame)
		if (frame:IsShown()) then
			FPerl.AurasUpdate(frame)
		end
	end
end

local function RefreshFrames()
	Refresh(FPerl_Target)
	Refresh(FPerl_Focus)
	Refresh(FPerl_TargetTarget)
	Refresh(FPerl_FocusTarget)
end

-- Load() - the login path again: read the saved list, drop the cached set, rebuild the frames
function FPerl.AuraBlacklist.Load()
	InitDB()
	setDirty = true
	RefreshFrames()
end

-- Config_UpdateList() - fills the visible rows only
local function Config_UpdateList()
	if (not config or not config:IsVisible() or not spells) then
		return
	end
	local total = #sorted
	FauxScrollFrame_Update(config.scroll, total, ROWS, ROW_HEIGHT)
	local offset = FauxScrollFrame_GetOffset(config.scroll)
	for i = 1, ROWS do
		local row = config.rows[i]
		local id = sorted[offset + i]
		local entry = id and spells[id]
		if (entry) then
			row.spellID = id
			row.icon:SetTexture((GetSpellTextureFunc and GetSpellTextureFunc(id)) or QUESTION_MARK)
			row.name:SetText(DisplayName(id, entry))
			row.idText:SetText(id)
			row.mine:SetChecked(entry.showMine and true or false)
			row:Show()
		else
			row.spellID = nil
			row:Hide()
		end
	end
	config.count:SetText(format(FPERL_AURABL_COUNT, total))
	config.enable:SetChecked(db.enabled and true or false)
	config.import:SetEnabled(GetBBFList() ~= nil)
end

-- ListChanged(resort) - after any change to the list or the master toggle
local function ListChanged(resort)
	if (resort) then
		RebuildSorted()
		setDirty = true
	end
	Config_UpdateList()
	RefreshFrames()
end

-- FindAuraByName(name) - spell ID of a readable helpful aura with exactly this name
local function FindAuraByName(name)
	local lname = strlower(name)
	for u = 1, #scanUnits do
		local unit = scanUnits[u]
		if (UnitExists(unit)) then
			for i = 1, 40 do
				local auraName, _, _, _, _, _, _, _, _, spellID = FPerl.UnitAuraByIndex(unit, i, "HELPFUL")
				if (not auraName) then
					break
				end
				if (CanAccess(auraName) and CanAccess(spellID) and strlower(auraName) == lname) then
					return spellID
				end
			end
		end
	end
end

-- AddSpell(text) - text is a spell ID or an exact spell name. Returns true when added.
local function AddSpell(text)
	text = strtrim(text or "")
	if (text == "" or not spells) then
		return
	end

	local id = tonumber(text)
	local name
	if (id) then
		-- Whole numbers from 1 to 2^31 only (rejects fractions, inf and nan)
		if (id > 0 and id <= 2^31 and id == floor(id)) then
			name = SpellNameIcon(id)
		end
		if (not name) then
			FPerl.Notice(FPERL_AURABL_NOTFOUND, text)
			return
		end
	else
		id = FindAuraByName(text)
		if (id) then
			name = SpellNameIcon(id) or text
		else
			local _
			name, _, id = SpellNameIcon(text)
			if (not id or not name or strlower(name) ~= strlower(text)) then
				FPerl.Notice(FPERL_AURABL_NOTFOUND, text)
				return
			end
		end
	end

	if (spells[id]) then
		FPerl.Notice(FPERL_AURABL_EXISTS, DisplayName(id, spells[id]), id)
		return
	end

	spells[id] = {name = name}
	FPerl.Notice(FPERL_AURABL_ADDED, name, id)
	ListChanged(true)
	return true
end

-- ImportBBF() - merge BetterBlizzFramesDB.auraBlacklist; never writes to BBF
local function ImportBBF()
	local src = GetBBFList()
	if (not src or not spells) then
		FPerl.Notice(FPERL_AURABL_IMPORT_NONE)
		return
	end

	local added, existing, skipped = 0, 0, 0
	for key, entry in pairs(src) do
		local id = tonumber(key)
		if (not id and type(entry) == "table" and entry.id) then
			id = tonumber(entry.id)
		end
		if (id and id > 0 and id <= 2^31 and id == floor(id)) then
			if (spells[id]) then
				existing = existing + 1
			else
				local name, showMine
				if (type(entry) == "table") then
					if (type(entry.name) == "string" and entry.name ~= "") then
						name = entry.name
					end
					showMine = entry.showMine and true or nil
				end
				spells[id] = {name = name or SpellNameIcon(id), showMine = showMine}
				added = added + 1
			end
		else
			skipped = skipped + 1
		end
	end

	FPerl.Notice(FPERL_AURABL_IMPORTED, added, existing, skipped)
	if (added > 0) then
		ListChanged(true)
	end
end

-- Tooltips
local function ShowTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText(self.tooltipTitle, 1, 1, 1)
	if (self.tooltipText) then
		GameTooltip:AddLine(self.tooltipText, nil, nil, nil, true)
	end
	GameTooltip:Show()
end

local function Row_OnEnter(self)
	if (self.spellID and GameTooltip.SetSpellByID) then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetSpellByID(self.spellID)
		GameTooltip:Show()
	end
end

-- Rows sit on top of the scroll frame, so pass the wheel on to it
local function List_OnMouseWheel(self, delta)
	local scroll = config and config.scroll
	local handler = scroll and scroll:GetScript("OnMouseWheel")
	if (handler) then
		handler(scroll, delta)
	end
end

local function Mine_OnClick(self)
	local row = self:GetParent()
	local entry = row.spellID and spells[row.spellID]
	if (entry) then
		entry.showMine = self:GetChecked() and true or nil
		ListChanged(false)
	end
end

local function Remove_OnClick(self)
	local row = self:GetParent()
	if (row.spellID and spells[row.spellID]) then
		spells[row.spellID] = nil
		ListChanged(true)
	end
end

local function CreateLabel(parent, text, font)
	local label = parent:CreateFontString(nil, "ARTWORK", font or "GameFontNormalSmall")
	label:SetText(text)
	return label
end

-- CreateRow(list, i)
local function CreateRow(list, i)
	local row = CreateFrame("Frame", nil, list)
	row:SetSize(400, ROW_HEIGHT)
	row:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -8 - (i - 1) * ROW_HEIGHT)
	row:EnableMouse(true)
	row:EnableMouseWheel(true)
	row:SetScript("OnEnter", Row_OnEnter)
	row:SetScript("OnLeave", GameTooltip_Hide)
	row:SetScript("OnMouseWheel", List_OnMouseWheel)

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(18, 18)
	row.icon:SetPoint("LEFT", 0, 0)
	row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	row.name:SetPoint("LEFT", 24, 0)
	row.name:SetSize(216, ROW_HEIGHT)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)

	row.idText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	row.idText:SetPoint("LEFT", 248, 0)
	row.idText:SetSize(64, ROW_HEIGHT)
	row.idText:SetJustifyH("LEFT")

	row.mine = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	row.mine:SetSize(22, 22)
	row.mine:SetPoint("LEFT", 318, 0)
	row.mine.tooltipTitle = FPERL_AURABL_COL_MINE
	row.mine.tooltipText = FPERL_AURABL_MINE_DESC
	row.mine:SetScript("OnClick", Mine_OnClick)
	row.mine:SetScript("OnEnter", ShowTooltip)
	row.mine:SetScript("OnLeave", GameTooltip_Hide)

	row.remove = CreateFrame("Button", nil, row, "UIPanelCloseButton")
	row.remove:SetSize(22, 22)
	row.remove:SetPoint("LEFT", 370, 0)
	row.remove.tooltipTitle = FPERL_AURABL_REMOVE
	row.remove:SetScript("OnClick", Remove_OnClick)
	row.remove:SetScript("OnEnter", ShowTooltip)
	row.remove:SetScript("OnLeave", GameTooltip_Hide)

	row:Hide()
	return row
end

-- CreateConfig(parent) - the options tab content, built the first time the tab is shown
local function CreateConfig(parent)
	local f = CreateFrame("Frame", "FPerl_AuraBlacklist_Config", parent)
	f:SetPoint("TOPLEFT")
	f:SetSize(460, 510)

	-- Master toggle
	local enable = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	enable:SetSize(24, 24)
	enable:SetPoint("TOPLEFT", 12, -10)
	enable:SetScript("OnClick", function(self)
		db.enabled = self:GetChecked() and true or false
		ListChanged(false)
	end)
	local enableLabel = CreateLabel(f, FPERL_AURABL_ENABLE, "GameFontHighlight")
	enableLabel:SetPoint("LEFT", enable, "RIGHT", 2, 0)
	f.enable = enable

	-- Import from BetterBlizzFrames
	local import = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	import:SetSize(200, 22)
	import:SetPoint("TOPRIGHT", -14, -11)
	import:SetText(FPERL_AURABL_IMPORT)
	import:SetScript("OnClick", ImportBBF)
	import.tooltipTitle = FPERL_AURABL_IMPORT
	import.tooltipText = FPERL_AURABL_IMPORT_DESC
	import:SetScript("OnEnter", ShowTooltip)
	import:SetScript("OnLeave", GameTooltip_Hide)
	if (import.SetMotionScriptsWhileDisabled) then
		import:SetMotionScriptsWhileDisabled(true)
	end
	f.import = import

	-- Add by spell ID or exact name
	local addLabel = CreateLabel(f, FPERL_AURABL_ADD_DESC)
	addLabel:SetPoint("TOPLEFT", 16, -44)

	local edit = CreateFrame("EditBox", "FPerl_AuraBlacklist_ConfigAdd", f, "InputBoxTemplate")
	edit:SetSize(260, 20)
	edit:SetPoint("TOPLEFT", 22, -60)
	edit:SetAutoFocus(false)
	edit:SetMaxLetters(100)
	local function DoAdd()
		if (AddSpell(edit:GetText())) then
			edit:SetText("")
		end
		edit:ClearFocus()
	end
	edit:SetScript("OnEnterPressed", DoAdd)
	edit:SetScript("OnEscapePressed", edit.ClearFocus)

	local add = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	add:SetSize(80, 22)
	add:SetPoint("LEFT", edit, "RIGHT", 8, 0)
	add:SetText(FPERL_AURABL_ADD)
	add:SetScript("OnClick", DoAdd)

	-- List
	local list = CreateFrame("Frame", nil, f, "FPerl_BackdropTemplate")
	list:SetPoint("TOPLEFT", 12, -108)
	list:SetPoint("BOTTOMRIGHT", -12, 34)
	list:SetBackdrop(FPerl.TooltipEdge9)
	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", List_OnMouseWheel)

	local colName = CreateLabel(f, FPERL_AURABL_COL_NAME)
	colName:SetPoint("BOTTOMLEFT", list, "TOPLEFT", 32, 2)
	local colID = CreateLabel(f, FPERL_AURABL_COL_ID)
	colID:SetPoint("BOTTOMLEFT", list, "TOPLEFT", 256, 2)
	local colMine = CreateLabel(f, FPERL_AURABL_COL_MINE)
	colMine:SetPoint("BOTTOMLEFT", list, "TOPLEFT", 316, 2)

	local scroll = CreateFrame("ScrollFrame", "FPerl_AuraBlacklist_ConfigScroll", list, "FauxScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 4, -8)
	scroll:SetPoint("BOTTOMRIGHT", -28, 8)
	scroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, Config_UpdateList)
	end)
	f.scroll = scroll

	f.rows = {}
	for i = 1, ROWS do
		f.rows[i] = CreateRow(list, i)
	end

	local count = CreateLabel(f, "")
	count:SetPoint("BOTTOMLEFT", 16, 14)
	f.count = count

	f:SetScript("OnShow", Config_UpdateList)
	-- Switching tab or closing the options must not leave the add box focused
	f:SetScript("OnHide", function()
		edit:ClearFocus()
	end)
	return f
end

-- Our page in F-Perl's settings panel. FPerl_Settings.lua reads this list at login and registers each entry as
-- a subcategory; create() runs the first time the page is shown.
FPerl.SettingsPages = FPerl.SettingsPages or {}
tinsert(FPerl.SettingsPages, {
	key = "AuraBlacklist",
	name = "Aura blacklist",
	create = function(page)
		config = CreateConfig(page)
		RebuildSorted()
		Config_UpdateList()
	end,
})

local function onAddonLoaded(_, name)
	if (name == ADDON_NAME) then
		InitDB()
		FPerl.Off("ADDON_LOADED", onAddonLoaded)
		-- frames built before the list was loaded rebuild with it
		RefreshFrames()
	end
end
FPerl.On("ADDON_LOADED", onAddonLoaded)
