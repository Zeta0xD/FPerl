-- Author: Resike
-- License: GNU GPL v3, 18 October 2014

-- Blizzard's AuraContainer as F-Perl uses it: loading it, the reconfigure gate while auras are secret, building
-- a frame's containers and initialising their buttons.

-- FPerl.HasAuraContainerNow()
-- Blizzard_AuraContainer is load-on-demand, so the one-shot check in FPerl_Values.lua
-- can run before it exists and freeze the flag false for the session.
-- Checks again on demand and loads it.
function FPerl.HasAuraContainerNow()
	if (not C_XMLUtil or type(C_XMLUtil.GetTemplateInfo) ~= "function") then
		return false
	end
	if (C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate") ~= nil) then
		FPerl.ForeverAPI.auraContainer = true
		return true
	end
	-- LoadAddOn is not safe to call in combat lockdown; try again once out.
	if (InCombatLockdown()) then
		return false
	end
	local loader = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
	if (type(loader) == "function") then
		FPerl.Pcall(loader, "Blizzard_AuraContainer")
	end
	local present = C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate") ~= nil
	FPerl.ForeverAPI.auraContainer = present
	return present
end

-- Room under an aura row for its duration text (GameFontNormalSmall), used
-- between rows and between a frame's buff and debuff containers.
FPerl.AuraTextGap = 12

-- FPerl.AuraGap(c): the room under an aura line for its duration text; 0 while duration text is off
-- (the global buffs.countdown, or c.auraText == false for the frame whose options are c).
function FPerl.AuraGap(c)
	if (c and c.auraText == false) then
		return 0
	end
	return FPerl.layout.buffs.countdown and FPerl.AuraTextGap or 0
end

-- FPerl.AuraContainerSafeToReconfigure()
-- An already-adopted group/button can reject reconfiguration while secret.
-- Creating one fresh is fine; touching a live one must defer.
function FPerl.AuraContainerSafeToReconfigure()
	return not FPerl.AurasSecret()
end

-- FPerl.AuraContainerGate(frame)
-- The one gate for reconfiguring a live container or its buttons (AddAuraGroup on a live container
-- included): while auras are secret the client rejects it ("forbidden object"), so nothing is touched,
-- the frame is marked pending, and the next FPerl.AurasUpdate with auras readable applies the spec.
-- Returns true when it is safe to go on.
function FPerl.AuraContainerGate(frame)
	if (FPerl.AuraContainerSafeToReconfigure()) then
		return true
	end
	frame.auraContainerPending = true
	return false
end

local function sameFilters(a, b)
	a, b = a or {}, b or {}
	for k, v in pairs(a) do
		if (b[k] ~= v) then
			return false
		end
	end
	for k in pairs(b) do
		if (a[k] == nil) then
			return false
		end
	end
	return true
end

local function groupLayout(g)
	return {
		elementWidth = g.size,
		elementHeight = g.size,
		elementSpacing = 3,
		lineSpacing = g.gap or FPerl.AuraGap(),
		layoutIndex = g.layoutIndex,
	}
end

-- FPerl.AuraContainerCreate(self, holderKey, name, groups, lineSize)
-- Builds a holder + AuraContainer pair holding the groups of FPerl.AurasGroups; caller positions the
-- holder. Every frame goes through here so the setup steps that each silently break rendering when
-- missing live in one place.
function FPerl.AuraContainerCreate(self, holderKey, name, groups, lineSize)
	local level = self:GetFrameLevel() + 10
	local holder = self[holderKey]
	if (not holder) then
		holder = CreateFrame("Frame", nil, self, "DisableUntrustedLayoutScriptsTemplate")
		self[holderKey] = holder
	end
	holder:SetFrameLevel(level)
	holder:Show()

	-- cfg[key] is the group's current spec; its buttons' init reads it
	local container = name and _G[name]
	local cfg
	-- on a frame that sets auraCancel (Target, the player's buffs), right-click on a buff button cancels the player's own buff
	local cancel = holderKey == "buffHalfFrame" and self.auraCancel or false
	local function addGroup(g)
		cfg[g.key] = g
		container:AddAuraGroup(g.key, g.filter, {
			maxFrameCount = g.maxFrameCount,
			layout = groupLayout(g),
			candidateFilters = g.candidateFilters,
			initializeFrame = function(button)
				local cg = cfg[g.key]
				FPerl.AuraContainerInitButtonCommon(button, cg, cancel)
			end,
		})
	end

	-- Frames cannot be destroyed, so a rebuild reconfigures the existing container;
	-- creating a new one each time would leak its frames on every reset.
	if (container and container.fperlAuraCfg) then
		if (not FPerl.AuraContainerGate(self)) then
			return container, holder
		end
		cfg = container.fperlAuraCfg
		container:SetFrameLevel(level)
		container:SetUnit(self.partyid)
		-- groups are never removed: those the spec does not ask for are disabled
		local wanted = {}
		for _, g in ipairs(groups) do
			wanted[g.key] = true
		end
		for key in pairs(cfg) do
			if (not wanted[key] and container:IsAuraGroupEnabled(key)) then
				container:SetAuraGroupEnabled(key, false)
			end
		end
		for _, g in ipairs(groups) do
			if (not container:HasAuraGroup(g.key)) then
				addGroup(g)
			else
				local old = cfg[g.key]
				cfg[g.key] = g
				if (not container:IsAuraGroupEnabled(g.key)) then
					container:SetAuraGroupEnabled(g.key, true)
				end
				container:SetAuraGroupFilterString(g.key, g.filter)
				if (not sameFilters(old and old.candidateFilters, g.candidateFilters)) then
					container:SetAuraGroupCandidateFilters(g.key, g.candidateFilters or {})
				end
				container:SetAuraGroupMaxFrameCount(g.key, g.maxFrameCount)
				container:SetAuraGroupLayout(g.key, groupLayout(g))
				for i = 1, container:GetAuraGroupFrameCount(g.key) do
					FPerl.AuraContainerInitButtonCommon(container:GetAuraGroupFrame(g.key, i), g, cancel)
				end
			end
		end
		if (container.SetFlowLayoutMaximumLineSize) then
			container:SetFlowLayoutMaximumLineSize(lineSize)
		end
		return container, holder
	end

	cfg = {}
	container = CreateFrame("AuraContainer", name, holder, "CustomAuraContainerTemplate,DisableUntrustedLayoutScriptsTemplate")
	container.fperlAuraCfg = cfg
	container:ClearAllPoints()
	container:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
	container:SetFrameLevel(level)
	container:SetSize(1, 1)
	container:SetUnit(self.partyid)
	for _, g in ipairs(groups) do
		addGroup(g)
	end
	if (container.SetFlowLayoutMaximumLineSize) then
		container:SetFlowLayoutMaximumLineSize(lineSize)
	end
	return container, holder
end

-- FPerl.AuraContainerInitButtonCommon(button, g, cancel)
-- g is the group spec of FPerl.AurasGroups: size, cooldown (swipe) and countdown (duration text).
-- cancel: right-click cancels the aura. Runs again on every reconfigure.
-- An aura button arrives blank: no icon texture, no cooldown. Skip creating them
-- and it still sizes, lays out and tooltips correctly while drawing nothing at
-- all. Per-aura detail stays Blizzard's to draw.
function FPerl.AuraContainerInitButtonCommon(button, g, cancel)
	if (not button) then
		return
	end
	local size, showSwipe = g.size, g.cooldown
	if (size) then
		button:SetSize(size, size)
	end
	if (not button.icon and button.SetIcon) then
		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetAllPoints(button)
		button:SetIcon(button.icon)
	end
	if (not button.cooldown and button.SetDurationCooldown) then
		button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
		button.cooldown:SetAllPoints(button)
		button.cooldown:SetReverse(true)
		button:SetDurationCooldown(button.cooldown)
	end
	-- Blizzard fills both strings, secret values included: the buff bar's gold
	-- duration text under the icon and its stack count.
	if (not button.fperlDuration and button.SetDurationText) then
		button.fperlDuration = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		button.fperlDuration:SetPoint("TOP", button, "BOTTOM")
	end
	if (button.fperlDuration) then
		if (g.countdown) then
			button.fperlDuration:Show()
			button:SetDurationText(button.fperlDuration)
		elseif (button.ClearDurationText) then
			button:ClearDurationText()
			button.fperlDuration:Hide()
		end
	end
	-- tooltips off: the button ignores the mouse, and right-click cancel goes with it (the game shows a
	-- tooltip on every aura button that has the mouse)
	button:EnableMouse((FPerl.layout and FPerl.layout.tooltip and FPerl.layout.tooltip.enableBuffs) and true or false)
	if (cancel and button.SetCancelAuraButtons) then
		button:SetCancelAuraButtons("RightButtonUp")
	end
	if (not button.countText and button.SetApplicationCount) then
		-- A region draws under every child frame of its parent, so the count sits
		-- on a frame above the cooldown swipe.
		local carrier = CreateFrame("Frame", nil, button)
		carrier:SetAllPoints(button)
		button.countCarrier = carrier
		button.countText = carrier:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		button.countText:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
		button:SetApplicationCount(button.countText)
	end
	-- the container moves its buttons to its own level when it is reconfigured: the children follow
	if (button.cooldown) then
		button.cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
	end
	if (button.countCarrier) then
		button.countCarrier:SetFrameLevel(button:GetFrameLevel() + 2)
	end
	if (button.cooldown) then
		if (button.cooldown.SetDrawEdge) then
			button.cooldown:SetDrawEdge(false)
		end
		if (button.cooldown.SetDrawSwipe) then
			button.cooldown:SetDrawSwipe(showSwipe and true or false)
		end
		-- Countdown-text handling for container buttons:
		-- without it every icon force-shows Blizzard's
		-- numbers whatever the option says, and OmniCC-style addons attach too
		-- (F-Perl does not support them: noCooldownCount keeps them off).
		local bconf = FPerl.layout and FPerl.layout.buffs
		if (button.cooldown.SetHideCountdownNumbers) then
			button.cooldown:SetHideCountdownNumbers(not (bconf and bconf.blizzard))
		end
		button.cooldown.noCooldownCount = true
	end
end
