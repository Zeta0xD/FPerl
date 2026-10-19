-- Author: Resike
-- License: GNU GPL v3, 18 October 2014

FPerl.SetModuleRevision("$Revision:  $")

-- SlashHandler
local function SlashHandler(msg)
	local args = { }
	for value in string.gmatch(msg, "[^ ]+") do
		tinsert(args, string.lower(value))
	end
	if (args[1] == nil or args[1] == FPERL_CMD_MENU or args[1] == FPERL_CMD_OPTIONS) then
		FPerl.OpenSettings()
	elseif (args[1] == FPERL_CMD_LOCK) then
		FPerl.LockFrames()
	elseif (args[1] == FPERL_CMD_UNLOCK) then
		FPerl.UnlockFrames()
	elseif (args[1] == FPERL_CMD_LAYOUT) then
		local active = FPerl.ActiveLayout()
		local wanted = msg:match("^%s*%S+%s+(.-)%s*$")
		if (wanted == "") then
			wanted = nil
		end
		if (not wanted) then
			FPerl.Notice(FPERL_LAYOUT_LIST)
			for _, name in ipairs(FPerl.LayoutNames()) do
				DEFAULT_CHAT_FRAME:AddMessage(format("|c00FFFF80%s%s", name, name == active and FPERL_LAYOUT_CURRENT or ""))
			end
		else
			for _, name in ipairs(FPerl.LayoutNames()) do
				if (strlower(name) == strlower(wanted)) then
					FPerl.SelectLayout(name)
					return
				end
			end
			FPerl.Notice(FPERL_LAYOUT_UNKNOWN, wanted)
		end
	else
		DEFAULT_CHAT_FRAME:AddMessage(FPERL_CMD_HELP)
	end
end

SlashCmdList["FPERL"] = SlashHandler
SLASH_FPERL1 = "/fperl"
