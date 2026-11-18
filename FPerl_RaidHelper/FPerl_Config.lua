-- Author: Resike
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

FPerl.SetModuleRevision("$Revision:  $")

function FPerl.Message(...)
	DEFAULT_CHAT_FRAME:AddMessage(FPERL_MSG_PREFIX.."- "..format(...))
end

function FPerl.RaidHelper.SetupFrames()

	local function ValidAlpha(alpha)
		alpha = tonumber(alpha)
		if (alpha < 0 or alpha > 1) then
			alpha = 1
		end
		return alpha
	end

	if (FPerlRaidHelperDB) then
		FPerlRaidHelperDB.AssistsFrame_Transparency = ValidAlpha(FPerlRaidHelperDB.AssistsFrame_Transparency)
		FPerl_Assists_Frame:SetAlpha(FPerlRaidHelperDB.AssistsFrame_Transparency)

		FPerlRaidHelperDB.Targets_Transparency = ValidAlpha(FPerlRaidHelperDB.Targets_Transparency)
		FPerl_RaidHelper_Frame:SetAlpha(FPerlRaidHelperDB.Targets_Transparency)

		FPerl.RaidHelper.SetupFrameSimple(FPerl_RaidHelper_Frame, FPerlRaidHelperDB.Background_Transparency)
		FPerl.RaidHelper.SetupFrameSimple(FPerl_MTTargets)
		FPerl.RaidHelper.SetupFrameSimple(FPerl_Assists_Frame, FPerlRaidHelperDB.Assists_BackTransparency)
		FPerl_ScrollSeperator:SetAlpha(FPerlRaidHelperDB.Assists_BackTransparency)

		FPerl_RaidHelper_Frame_TitleBar_ToggleMTTargets:SetButtonTex()
		FPerl_RaidHelper_Frame_TitleBar_ToggleLabels:SetButtonTex()
		FPerl_RaidHelper_Frame_TitleBar_ToggleShowMT:SetButtonTex()
		FPerl_RaidHelper_Frame_TitleBar_Pin:SetButtonTex()
	end

	if (FPerl.RegisterHighlight) then
		FPerl.RegisterHighlight(FPerl_Player_TargettingFrame, 4)
		FPerl.RegisterHighlight(FPerl_Target_AssistFrame, 4)
		FPerl.RegisterPerlFrames(FPerl_Player_TargettingFrame)
		FPerl.RegisterPerlFrames(FPerl_Target_AssistFrame)
	end
end

-- FPerl.RaidHelper.Slash
function FPerl.RaidHelper.Slash(msg)

	local commands = {}
	for x in string.gmatch(msg, "[^ ]+") do
		tinsert(commands, string.lower(x))
	end

	local function SubCommandMatch(cmd, match)
		return strsub(match, 1, strlen(cmd)) == cmd
	end

	local function setAlpha()
		if (commands[2] and commands[3]) then
			if (SubCommandMatch(commands[2], "raid")) then
				FPerlRaidHelperDB.Targets_Transparency = commands[3]
				return true
			elseif (SubCommandMatch(commands[2], "assists")) then
				FPerlRaidHelperDB.AssistsFrame_Transparency = commands[3]
				return true
			end
		end
	end

	local options = {
		{"assists",	FPerl.RaidHelper.AssistsViewOpen,		"Open Assists View"},
		{"raid",	FPerl.RaidHelper.RaidHelpShow,		"Open Raid Helper"},
		{"alpha",	setAlpha,			"Set Alpha Level"},
		{"ctra",	FPerl.RaidHelper.ToggleUseCTRATargets,	"Toggle Use of CTRA MT Targets"},
	}

	local foundFunc
	local foundDesc
	if (commands[1]) then
		local len = strlen(commands[1])
		if (len) then
			for i,entry in pairs(options) do
				if (strsub(entry[1], 1, len) == commands[1]) then
					if (foundFunc) then
						FPerl.Message("Ambiguous command, failed.")
						foundFunc = nil
						break
					end
					foundFunc = entry[2]
					foundDesc = entry[3]
				end
			end
		end
	end

	if (foundFunc) then
		if (foundFunc(msg, commands[2], commands[3], commands[4])) then
			FPerl.RaidHelper.SetupFrames()
			if (foundDesc) then
				FPerl.Message(foundDesc.." - |c0000C020done!|r")
			end
			return
		end
	end

	FPerl.Message("Options: /fphelper [|c00FFFF00assists|r] [|c00FFFF00raid|r] [|c00FFFF00alpha|r raid|assists] [|c00FFFF00ctra|r]")
end

local function DefaultVar(name, value)
	if (FPerlRaidHelperDB[name] == nil or (type(value) ~= type(FPerlRaidHelperDB[name]))) then
		FPerlRaidHelperDB[name] = value
	end
end

local function Defaults()
	DefaultVar("RaidHelper",		1)
	DefaultVar("UnitWidth",			100)
	DefaultVar("UnitHeight",		26)
	DefaultVar("UseCTRATargets",		1)
	DefaultVar("NoAutoList",		0)
	DefaultVar("ShowMT",			1)
	DefaultVar("MTLabels",			0)
	DefaultVar("MTTargetTargets",		1)
	DefaultVar("Targets_Transparency",	0.8)
	DefaultVar("Background_Transparency",	1)
	DefaultVar("Tooltips",			0)
	DefaultVar("TooltipsWhich",		2)
	DefaultVar("MaxMainTanks",		10)
	DefaultVar("MTListUpward",		0)
	DefaultVar("HealerMode",		0)
	DefaultVar("HealerModeType",		1)

	DefaultVar("TargetCounters",		1)
	DefaultVar("TargetCountersSelf",	1)
	DefaultVar("TargetCountersEnemy",	1)
	DefaultVar("ShowTargetCounters",	1)
	DefaultVar("AssistsFrame",		1)
	DefaultVar("TargettingFrame",		1)
	DefaultVar("AssistsFrame_Transparency",	0.8)
	DefaultVar("Assists_BackTransparency",	1)
	DefaultVar("AggroWarning",		1)

	DefaultVar("BorderColour",		{r = 0.5, g = 0.5, b = 0.5, a = 1})
end

-- FPerl.RaidHelper.Startup
-- Called after VARIABLES_LOADED
function FPerl.RaidHelper.Startup()

	if (not FPerlRaidHelperDB) then
		FPerlRaidHelperDB = {}
	end
	Defaults()
	if (FPerl.RaidHelper.StartAssists) then
		FPerl.RaidHelper.StartAssists()
	end

	FPerl.RaidHelper.SetupFrames()

	FPerl_AssistPin:SetButtonTex()
	FPerl_RaidHelper_Frame_TitleBar_Pin:SetButtonTex()

	if (FPerl.RegisterOptionChanger) then
		FPerl.RegisterOptionChanger(FPerl.RaidHelper.SetupFrames, nil, "raidhelper")
	end
end
