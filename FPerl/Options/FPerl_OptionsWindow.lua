-- F-Perl's own options window: a title bar (search, "Show advanced options", close), a tab list (the pages of
-- FPerl.SettingsList, then the pages other modules add through FPerl.SettingsPages), and the rows of the tab in their
-- sections. Controls: FPerl_OptionsControls.lua. Values: FPerl.SettingsCore (FPerl_Settings.lua).
--
-- Window state (position, tab, "Show advanced options") is account-wide: FPerlDB.options = {x, y, tab, advanced}; it is
-- not part of a layout. Which sections are open is session state.
--
-- API: FPerl.Options.Open(tab), SelectTab(name), SetAdvanced(bool),
-- SetSearch(text), ExpandAll(), Lines(), Refresh().

local C = FPerl.OptionsControls
local O = {}
FPerl.Options = O

local WIDTH, HEIGHT, TABW = 900, 660, 150
local CONTENTW = WIDTH - TABW - 56
local COLX = C.COLW + 20

local win, scroll, content, box, advanced, tabs, reloadBtn, reloadNote
local state = {tab = "General", advanced = false, search = "", open = {}}
local lines, built = {}, {}
local heads, subs = {}, {}
local needReload = false
local tabList = {}

local function saved()
	if not FPerlDB then return state end
	FPerlDB.options = FPerlDB.options or {}
	return FPerlDB.options
end

local function pageNames()
	local out, seen = {}, {}
	for _, e in ipairs(FPerl.SettingsList) do
		if not seen[e.page] then
			seen[e.page] = true
			out[#out + 1] = e.page
		end
	end
	for _, p in ipairs(FPerl.SettingsPages) do out[#out + 1] = p.name end
	return out
end
local function pageOf(name)
	for _, p in ipairs(FPerl.SettingsPages) do
		if p.name == name then return p end
	end
end

------------------------------------------------------------------------------------------------ layout
local function sectionOpen(sec)
	local o = state.open[sec.key]
	if o == nil then return sec.hasBasic end
	return o
end

-- The sections to show, each {key, page, name, lines = {rows...}, tags, hasBasic}.
local function collect()
	local secs, byKey = {}, {}
	local q = state.search ~= "" and state.search:lower() or nil
	for _, e in ipairs(FPerl.SettingsList) do
		local want
		if q then
			want = (e.label:lower():find(q, 1, true) or (type(e.tip) == "string" and e.tip:lower():find(q, 1, true))) ~= nil
		else
			want = e.page == state.tab and (state.advanced or e.basic)
		end
		if want and not (e.showif and not e.showif()) then
			local key = e.page .. "|" .. e.section
			local sec = byKey[key]
			if not sec then
				sec = {key = key, page = e.page, name = e.section, lines = {}, tags = {}, hasBasic = false}
				byKey[key] = sec
				secs[#secs + 1] = sec
			end
			if e.basic then sec.hasBasic = true end
			if e.inline and sec.tags[e.inline] then
				local rows = sec.tags[e.inline]
				rows[#rows + 1] = e
			else
				local rows = {e}
				sec.lines[#sec.lines + 1] = rows
				if e.inline then sec.tags[e.inline] = rows end
			end
		end
	end
	return secs
end

local function lineFor(rows)
	local key = {}
	for i, r in ipairs(rows) do key[i] = r.id end
	key = table.concat(key, "|")
	local l = built[key]
	if not l then
		l = C.Make(content, rows)
		built[key] = l
	end
	return l
end

local function head(i)
	local h = heads[i]
	if not h then
		h = CreateFrame("Button", nil, content)
		h:SetHeight(24)
		h.fs = h:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
		h.fs:SetPoint("LEFT", 2, 0)
		h.line = h:CreateTexture(nil, "BACKGROUND")
		h.line:SetColorTexture(0.5, 0.42, 0.1, 0.6)
		h.line:SetHeight(1)
		h.line:SetPoint("BOTTOMLEFT")
		h.line:SetPoint("BOTTOMRIGHT")
		h:SetScript("OnClick", function(self)
			if self.sec then
				state.open[self.sec.key] = not sectionOpen(self.sec)
				O.Layout()
			end
		end)
		heads[i] = h
	end
	return h
end
local function sub(i)
	local s = subs[i]
	if not s then
		s = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		subs[i] = s
	end
	return s
end

function O.Layout()
	if not win then return end
	for _, l in pairs(built) do l.box:Hide() end
	for _, h in ipairs(heads) do h:Hide() end
	for _, s in ipairs(subs) do s:Hide() end
	lines = {}
	local searching = state.search ~= ""
	local pg = pageOf(state.tab)
	if pg and not searching then
		scroll:Hide()
		if not pg.frame then
			pg.frame = CreateFrame("Frame", nil, win)
			pg.frame:SetPoint("TOPLEFT", scroll, "TOPLEFT")
			pg.frame:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT")
			xpcall(pg.create, geterrorhandler(), pg.frame)
		end
		pg.frame:Show()
		return
	end
	for _, p in ipairs(FPerl.SettingsPages) do
		if p.frame then p.frame:Hide() end
	end
	scroll:Show()

	local y, nh, ns = 0, 0, 0
	local col, rowTop, rowH = 0, 0, 0
	local function flush()
		if col == 1 then y = rowTop - rowH - 4 end
		col = 0
	end
	local lastPage
	for _, sec in ipairs(collect()) do
		flush()
		local n = #sec.lines
		local h
		nh = nh + 1
		h = head(nh)
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
		h:SetWidth(CONTENTW)
		h.sec = nil
		local title = sec.name
		if searching and sec.page ~= lastPage then title = sec.page .. ": " .. sec.name end
		lastPage = sec.page
		local open = true
		if not searching and state.advanced then
			h.sec = sec
			open = sectionOpen(sec)
			title = (open and "- " or "+ ") .. title .. " (" .. n .. ")"
		end
		h.fs:SetText(title)
		h:Show()
		y = y - 30
		if open then
			local group
			for _, rows in ipairs(sec.lines) do
				local e = rows[1]
				local l = lineFor(rows)
				if e.group ~= group then
					group = e.group
					if group then
						flush()
						ns = ns + 1
						local s = sub(ns)
						s:ClearAllPoints()
						s:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
						s:SetText(group)
						s:Show()
						y = y - 18
					end
				end
				l.box:ClearAllPoints()
				if l.full then
					flush()
					l.box:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
					y = y - l.h - 4
				elseif col == 0 then
					rowTop, rowH, col = y, l.h, 1
					l.box:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
				else
					rowH = math.max(rowH, l.h)
					l.box:SetPoint("TOPLEFT", content, "TOPLEFT", COLX, rowTop)
					y = rowTop - rowH - 4
					col = 0
				end
				l.box:Show()
				lines[#lines + 1] = l
			end
		end
		flush()
		y = y - 8
	end
	content:SetSize(CONTENTW, math.max(1, -y + 10))
	O.Refresh()
end

------------------------------------------------------------------------------------------------ refresh
function O.Refresh()
	if not win or not win:IsShown() then return end
	local combat = InCombatLockdown() and true or false
	for _, l in ipairs(lines) do l:Refresh(combat) end
	if reloadBtn then
		reloadBtn:SetShown(needReload)
		reloadNote:SetShown(needReload)
	end
end

function O.Lines()
	local out = {}
	for i, l in ipairs(lines) do out[i] = {ids = l.ids, page = l.page, label = l.label, ctl = l.ctl, tip = l.tip} end
	return out
end

C.onChange = function(e)
	if C.reloadRow(e) then needReload = true end
	O.Refresh()
end

------------------------------------------------------------------------------------------------ state
local function selectedLook()
	for name, b in pairs(tabs) do b.sel:SetShown(name == state.tab and state.search == "") end
end

function O.SelectTab(name)
	O.Create()
	if not tabs[name] then return end
	state.tab = name
	saved().tab = name
	if state.search ~= "" then
		box:SetText("")
		state.search = ""
	end
	selectedLook()
	scroll:SetVerticalScroll(0)
	O.Layout()
end

function O.SetAdvanced(on)
	O.Create()
	on = on and true or false
	state.advanced = on
	saved().advanced = on
	advanced:SetChecked(on)
	O.Layout()
end

function O.SetSearch(text)
	O.Create()
	text = text or ""
	if box:GetText() ~= text then box:SetText(text) end
	if state.search ~= text then
		state.search = text
		selectedLook()
		scroll:SetVerticalScroll(0)
		O.Layout()
	end
end

function O.ExpandAll()
	for _, sec in ipairs(collect()) do state.open[sec.key] = true end
	O.Layout()
end

------------------------------------------------------------------------------------------------ frame
local function savePosition()
	local x, y = win:GetLeft(), win:GetBottom()
	if x and y then
		local s = saved()
		s.x, s.y = x, y
	end
end

function O.Create()
	if win then return win end
	win = CreateFrame("Frame", "FPerl_OptionsWindow", UIParent, "BackdropTemplate")
	win:Hide()
	win:SetSize(WIDTH, HEIGHT)
	win:SetFrameStrata("FULLSCREEN_DIALOG")
	win:SetClampedToScreen(true)
	win:SetMovable(true)
	win:EnableMouse(true)
	win:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
	win:SetBackdropColor(0.07, 0.07, 0.09, 0.96)
	win:SetBackdropBorderColor(0.5, 0.42, 0.1, 1)
	tinsert(UISpecialFrames, "FPerl_OptionsWindow")

	local s = saved()
	if s.x and s.y then
		win:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", s.x, s.y)
	else
		win:SetPoint("CENTER")
	end

	-- The title strip drags the window through the window's own drag scripts, so no frame lies over the title bar's controls.
	win:RegisterForDrag("LeftButton")
	win:SetScript("OnDragStart", function(self)
		local _, cy = GetCursorPosition()
		local top = self:GetTop()
		if top and (top * self:GetEffectiveScale() - cy) <= 36 * self:GetEffectiveScale() then self:StartMoving() end
	end)
	win:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		savePosition()
	end)
	local title = win:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 14, -9)
	title:SetText("F-Perl")
	local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)

	box = CreateFrame("EditBox", nil, win, "SearchBoxTemplate")
	box:SetSize(190, 22)
	box:SetPoint("LEFT", title, "RIGHT", 24, 0)
	box:HookScript("OnTextChanged", function(self) O.SetSearch(self:GetText()) end)

	advanced = CreateFrame("CheckButton", nil, win, "UICheckButtonTemplate")
	advanced:SetSize(24, 24)
	advanced:SetFrameLevel(win:GetFrameLevel() + 10)
	advanced:SetPoint("LEFT", box, "RIGHT", 24, 0)
	local at = win:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	at:SetPoint("LEFT", advanced, "RIGHT", 6, 0)
	at:SetText("Show advanced options")
	advanced.label = at
	advanced:SetHitRectInsets(0, -(at:GetStringWidth() + 6), 0, 0) -- the label clicks the box
	advanced:SetScript("OnClick", function(self) O.SetAdvanced(self:GetChecked()) end)

	tabs = {}
	local ty = -44
	for _, name in ipairs(pageNames()) do
		local b = CreateFrame("Button", nil, win)
		b:SetSize(TABW - 10, 26)
		b:SetPoint("TOPLEFT", 10, ty)
		ty = ty - 28
		b.sel = b:CreateTexture(nil, "BACKGROUND")
		b.sel:SetAllPoints()
		b.sel:SetColorTexture(0.5, 0.42, 0.1, 0.3)
		b.sel:Hide()
		local hl = b:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetColorTexture(1, 1, 1, 0.08)
		local fs = b:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		fs:SetPoint("LEFT", 8, 0)
		fs:SetText(name)
		b:SetScript("OnClick", function() O.SelectTab(name) end)
		tabs[name] = b
		tabList[#tabList + 1] = name
	end

	scroll = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", TABW + 10, -44)
	scroll:SetPoint("BOTTOMRIGHT", -30, 40)
	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(CONTENTW, 10)
	scroll:SetScrollChild(content)

	reloadBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
	reloadBtn:SetSize(120, 24)
	reloadBtn:SetPoint("BOTTOMRIGHT", -14, 10)
	reloadBtn:SetText("Reload UI")
	reloadBtn:SetScript("OnClick", ReloadUI)
	reloadBtn:Hide()
	reloadNote = win:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	reloadNote:SetPoint("RIGHT", reloadBtn, "LEFT", -10, 0)
	reloadNote:SetText("A change needs a reload.")
	reloadNote:Hide()

	win:SetScript("OnShow", function() O.Layout() FPerl.AlignmentGridUpdate() end)
	win:SetScript("OnHide", FPerl.AlignmentGridUpdate)
	win:RegisterEvent("PLAYER_REGEN_DISABLED")
	win:RegisterEvent("PLAYER_REGEN_ENABLED")
	win:SetScript("OnEvent", function() O.Refresh() end)

	state.advanced = s.advanced and true or false
	advanced:SetChecked(state.advanced)
	state.tab = tabs[s.tab] and s.tab or "General"
	selectedLook()
	return win
end

function O.Open(tab)
	O.Create()
	if tab and tabs[tab] then
		state.tab = tab
		saved().tab = tab
		if state.search ~= "" then
			box:SetText("")
			state.search = ""
		end
		selectedLook()
	end
	if win:IsShown() then O.Layout() else win:Show() end
end

function FPerl.OpenSettings() O.Open() end
function FPerl.SettingsOpenPage(name) O.Open(name) end
