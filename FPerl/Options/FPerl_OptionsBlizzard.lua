-- F-Perl's entry in Blizzard's Settings panel: one canvas category with a line and a button that opens the options window.
-- No setting, vertical list or shown predicate is registered there (bug O33: they tainted the panel's list).

local function build()
	local frame = CreateFrame("Frame")
	frame:Hide()
	local line = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	line:SetPoint("TOPLEFT", 16, -16)
	line:SetText("F-Perl's options are in their own window.")
	local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	button:SetSize(200, 26)
	button:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -12)
	button:SetText("Open F-Perl options")
	button:SetScript("OnClick", function() FPerl.Options.Open() end)
	Settings.RegisterAddOnCategory((Settings.RegisterCanvasLayoutCategory(frame, "F-Perl")))
end

local function onLogin()
	FPerl.Off("PLAYER_LOGIN", onLogin)
	build()
end
FPerl.On("PLAYER_LOGIN", onLogin)
