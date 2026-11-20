-- The options window's controls: one "line" per row of FPerl.SettingsList (several rows for an `inline` tag), built on
-- first use and kept. A line is {ids, page, label, ctl, tip, box, h, full, Refresh(line, combat)}; `ctl` is the control
-- frame (CheckButton, Slider, Button, DropdownButton, or the group frame of an inline line). Values read and write
-- through FPerl.SettingsCore (FPerl_Settings.lua), which handles each row's `with`, `also`, `each` and applier.

local format, floor = string.format, math.floor
local C = {}
FPerl.OptionsControls = C

local COLW = 310
C.COLW = COLW
C.onChange = function() end -- the window sets it: called after a control wrote a value

local K -- FPerl.SettingsCore, read at first use (FPerl_Settings.lua loads before this file; the table is complete by then)
local function core()
	K = K or FPerl.SettingsCore
	return K
end

------------------------------------------------------------------------------------------------ needs and tips
local keyLabel
local function labelFor(key)
	if (not keyLabel) then
		keyLabel = {}
		for _, e in ipairs(FPerl.SettingsList) do
			if (e.path and not keyLabel[e.path]) then keyLabel[e.path] = e.label end
			for _, k in ipairs(e.keys or {}) do
				if (not keyLabel[k]) then keyLabel[k] = e.label end
			end
		end
	end
	return keyLabel[key] or key
end

-- true when the row's `needs` holds; else false and what it needs
local function needsMet(e)
	local n = e.needs
	if (n == nil) then return true end
	if (type(n) == "string" or n.key) then n = {n} end
	local k = core()
	local missing
	for _, c in ipairs(n) do
		local ok, text
		if (type(c) == "string") then
			ok, text = k.on(k.read(FPerl.layout, c)), "Needs: " .. labelFor(c)
		else
			ok, text = k.norm(k.read(FPerl.layout, c.key)) ~= k.norm(c["not"]), "Needs: " .. labelFor(c.key) .. " set to something else"
		end
		if (not ok) then missing = missing and (missing .. "; " .. text) or text end
	end
	return missing == nil, missing
end
C.needsMet = needsMet

local function reloadRow(e) return e.reload == true end
C.reloadRow = reloadRow

local function tipOf(e)
	if (e.each) then return core().sharedTip(e)() end
	return e.tip
end

local function showTip(line)
	return function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(line.label, 1, 1, 1)
		GameTooltip:AddLine(line.tip or "", 0.9, 0.9, 0.9, true)
		GameTooltip:Show()
	end
end
local function hookTip(frame, line)
	if (frame.HookScript) then
		frame:HookScript("OnEnter", showTip(line))
		frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
	end
	if (frame.SetMotionScriptsWhileDisabled) then frame:SetMotionScriptsWhileDisabled(true) end
end

-- The state is also kept on the control: a Slider answers IsEnabled from it.
local function setEnabled(ctl, on)
	ctl.fpOn = on
	if (ctl.SetEnabled) then
		ctl:SetEnabled(on)
	elseif (on) then
		ctl:Enable()
	else
		ctl:Disable()
	end
end

------------------------------------------------------------------------------------------------ pieces
local function text(parent, font, str)
	local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
	fs:SetJustifyH("LEFT")
	if (str) then fs:SetText(str) end
	return fs
end

local function newBox(parent, h)
	local box = CreateFrame("Frame", nil, parent)
	box:SetSize(COLW, h)
	return box
end

local function labelOf(e) return e.label .. (reloadRow(e) and " (reload)" or "") end

local function sliderFormat(e)
	if (e.percent) then return function(v) return format("%d%%", floor(v * 100 + 0.5)) end end
	if (e.step >= 1) then return function(v) return e.zero and v < 0.5 and e.zero or format("%d", floor(v + 0.5)) end end
	return function(v) return (format("%.2f", v):gsub("(%.%d-)0+$", "%1"):gsub("%.$", "")) end
end

local function choices(e)
	local out = {}
	if (e.map) then
		for i, m in ipairs(e.map) do out[i] = {i, m[1]} end
	elseif (type(e.options) == "table") then
		for i, o in ipairs(e.options) do out[i] = {i, o[2]} end
	else
		for i, o in ipairs(e.options()) do out[i] = {o[1], o[2]} end
	end
	return out
end

local function hex2rgb(hex)
	local r, g, b = hex:match("^%x%x(%x%x)(%x%x)(%x%x)$")
	if (not r) then return 1, 1, 1 end
	return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end
local function rgb2hex(r, g, b)
	return format("FF%02X%02X%02X", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

------------------------------------------------------------------------------------------------ builders
-- Each builder returns the control, its label (or nil), and an update function that re-reads the row's value into the control.
local B = {}

function B.check(line, e, parent, x, labelText)
	local k = core()
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	cb:SetPoint("TOPLEFT", x or 0, 0)
	local fs = text(parent, "GameFontHighlight", labelText or labelOf(e))
	fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
	fs:SetWidth(COLW - 30)
	cb:SetScript("OnClick", function(self)
		k.store(e, self:GetChecked() and true or false)
		C.onChange(e)
	end)
	hookTip(cb, line)
	return cb, fs, function() cb:SetChecked(k.valueOf(e, FPerl.layout) and true or false) end
end

function B.slider(line, e, box)
	local k = core()
	local fs = text(box, "GameFontHighlight", labelOf(e))
	fs:SetPoint("TOPLEFT", 0, 0)
	local val = text(box, "GameFontNormal")
	val:SetPoint("TOPRIGHT", -6, 0)
	local s = CreateFrame("Slider", nil, box)
	s:SetOrientation("HORIZONTAL")
	s:SetSize(COLW - 20, 14)
	s:SetPoint("TOPLEFT", 4, -20)
	local bar = s:CreateTexture(nil, "BACKGROUND")
	bar:SetColorTexture(0.35, 0.35, 0.4, 0.9)
	bar:SetPoint("LEFT")
	bar:SetPoint("RIGHT")
	bar:SetHeight(4)
	s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
	s:GetThumbTexture():SetSize(14, 22)
	s:SetMinMaxValues(e.min, e.max)
	s:SetValueStep(e.step)
	if (s.SetObeyStepOnDrag) then s:SetObeyStepOnDrag(true) end
	s:EnableMouse(true)
	s.IsEnabled = function(self) return self.fpOn ~= false end
	local fmt = sliderFormat(e)
	local busy
	s:SetScript("OnValueChanged", function(_, v)
		if (busy or s.fpOn == false) then return end
		k.store(e, v)
		val:SetText(fmt(k.valueOf(e, FPerl.layout)))
		C.onChange(e)
	end)
	hookTip(s, line)
	line.fs = fs
	return s, nil, function()
		busy = true
		local v = k.valueOf(e, FPerl.layout)
		s:SetValue(v)
		val:SetText(fmt(v))
		busy = false
	end
end

function B.dropdown(line, e, box)
	local k = core()
	local fs = text(box, "GameFontHighlight", labelOf(e))
	fs:SetPoint("TOPLEFT", 0, 0)
	local dd = CreateFrame("DropdownButton", nil, box, "WowStyle1DropdownTemplate")
	dd:SetWidth(COLW - 14)
	dd:SetPoint("TOPLEFT", 0, -18)
	dd:SetupMenu(function(_, root)
		for _, c in ipairs(choices(e)) do
			local key = c[1]
			root:CreateRadio(c[2], function() return k.valueOf(e, FPerl.layout) == key end, function()
				k.store(e, key)
				C.onChange(e)
			end)
		end
	end)
	hookTip(dd, line)
	-- The dropdown rebuilds its menu when it opens. A refresh rebuilds it only when the choices can change (options is a
	-- function); otherwise Update() re-reads the selection without rebuilding the menu, which relabels the button because
	-- each radio reads the value when asked.
	if (type(e.options) == "function") then return dd, fs, function() dd:GenerateMenu() end end
	return dd, fs, function() dd:Update() end
end

function B.frames(line, e, box)
	local k = core()
	local fs = text(box, "GameFontHighlight", labelOf(e))
	fs:SetPoint("TOPLEFT", 0, 0)
	local dd = CreateFrame("DropdownButton", nil, box, "WowStyle1DropdownTemplate")
	dd:SetWidth(COLW - 14)
	dd:SetPoint("TOPLEFT", 0, -18)
	dd:SetupMenu(function(_, root)
		for i, fl in ipairs(FPerl.SettingsFrames) do
			root:CreateCheckbox(fl, function() return k.ticked(k.maskOf(e.section), i) end, function()
				k.setMask(e.section, bit.bxor(k.maskOf(e.section), bit.lshift(1, i - 1)))
			end)
		end
	end)
	hookTip(dd, line)
	return dd, fs, function()
		local n, all = 0, #FPerl.SettingsFrames
		for i = 1, all do if (k.ticked(k.maskOf(e.section), i)) then n = n + 1 end end
		if (dd.OverrideText) then dd:OverrideText(n == 0 and "None" or n == all and "All frames" or (n .. " frames")) end
	end
end

function B.colour(line, e, box)
	local k = core()
	local btn = CreateFrame("Button", nil, box)
	btn:SetSize(22, 22)
	btn:SetPoint("TOPLEFT", 0, 0)
	local border = btn:CreateTexture(nil, "BACKGROUND")
	border:SetAllPoints()
	border:SetColorTexture(0.8, 0.8, 0.8, 1)
	local sw = btn:CreateTexture(nil, "ARTWORK")
	sw:SetPoint("TOPLEFT", 2, -2)
	sw:SetPoint("BOTTOMRIGHT", -2, 2)
	local fs = text(box, "GameFontHighlight", labelOf(e))
	fs:SetPoint("LEFT", btn, "RIGHT", 6, 0)
	local function update()
		sw:SetColorTexture(hex2rgb(k.valueOf(e, FPerl.layout)))
	end
	btn:SetScript("OnClick", function()
		local r, g, b = hex2rgb(k.valueOf(e, FPerl.layout))
		-- the swatch has no opacity: the store keeps the stored alpha (the opacity has its own slider row)
		ColorPickerFrame:SetupColorPickerAndShow({
			r = r, g = g, b = b, hasOpacity = false,
			swatchFunc = function()
				k.store(e, rgb2hex(ColorPickerFrame:GetColorRGB()))
				C.onChange(e)
			end,
			cancelFunc = function()
				k.store(e, rgb2hex(r, g, b))
				C.onChange(e)
			end,
		})
	end)
	hookTip(btn, line)
	return btn, fs, update
end

function B.button(line, e, box)
	local k = core()
	local b = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
	b:SetSize(COLW - 14, 24)
	b:SetPoint("TOPLEFT", 0, 0)
	b:SetText(e.label)
	b:SetScript("OnClick", function()
		k.click(e)
		C.onChange(e)
	end)
	hookTip(b, line)
	return b, nil, function() end
end

-- An inline line: a title and one small check per row, in one line.
local function buildInline(line, rows, box)
	local k = core()
	local title = line.label
	local fs = text(box, "GameFontHighlight", title)
	fs:SetPoint("TOPLEFT", 0, -4)
	local subs = {}
	for i, e in ipairs(rows) do
		local cb = CreateFrame("CheckButton", nil, box, "UICheckButtonTemplate")
		cb:SetSize(24, 24)
		cb:SetPoint("TOPLEFT", 70 + (i - 1) * 46, 0)
		local num = text(box, "GameFontHighlight", (e.label:gsub("^%a+ ", "")))
		num:SetPoint("LEFT", cb, "RIGHT", 0, 0)
		cb:SetScript("OnClick", function(self)
			k.store(e, self:GetChecked() and true or false)
			C.onChange(e)
		end)
		hookTip(cb, {label = e.label, tip = e.tip})
		subs[i] = {e = e, cb = cb}
	end
	box.IsEnabled = function() return subs[1].cb:IsEnabled() end
	return function(combat)
		local allOk = true
		for _, s in ipairs(subs) do
			s.cb:SetChecked(k.valueOf(s.e, FPerl.layout) and true or false)
			local ok = needsMet(s.e)
			allOk = allOk and ok
			setEnabled(s.cb, ok and not combat)
		end
		return allOk
	end
end

------------------------------------------------------------------------------------------------ line
local HEIGHT = {check = 26, colour = 26, button = 28, slider = 44, dropdown = 46, frames = 46}

-- rows: the rows of the line (one, or all rows of an inline tag). parent: the window's content frame.
function C.Make(parent, rows)
	local e = rows[1]
	local line = {rows = rows, ids = {}, page = e.page, label = e.label}
	for i, r in ipairs(rows) do line.ids[i] = r.id end
	local inline = e.inline ~= nil
	line.full = inline
	line.h = inline and 28 or HEIGHT[e.type] or 26
	local box = newBox(parent, line.h)
	if (inline) then
		box:SetWidth(8 * 46 + 80)
		line.label = (e.inline == "groups") and "Groups" or e.inline
		line.box = box
		local refresh = buildInline(line, rows, box)
		line.ctl = box
		function line.Refresh(self, combat)
			local ok = refresh(combat)
			self.tip = e.tip
			box:SetAlpha(1)
			return ok
		end
		return line
	end
	line.box = box
	local ctl, fs, update
	local t = e.type
	if (t == "check") then
		ctl, fs, update = B.check(line, e, box)
	else
		ctl, fs, update = B[t](line, e, box)
	end
	fs = fs or line.fs
	line.ctl = ctl
	function line.Refresh(self, combat)
		update()
		local ok, miss = needsMet(e)
		local tip = tipOf(e) or ""
		self.tip = ok and tip or (tip .. "\n" .. miss)
		local on = ok and not combat
		setEnabled(ctl, on)
		box:SetAlpha(on and 1 or 0.5)
		if (fs and fs.SetTextColor) then
			if (on) then fs:SetTextColor(1, 1, 1) else fs:SetTextColor(0.6, 0.6, 0.6) end
		end
		return ok
	end
	return line
end
