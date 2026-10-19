-- Author: Resike
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

FPerl.ProductName		= "|cFFD00000F-Perl|r"
FPerl.ShortProductName	= "|cFFD00000F-Perl|r"
FPerl.Description		= FPerl.ProductName
FPerl.VersionNumber		= C_AddOns.GetAddOnMetadata("FPerl", "Version")
FPerl.Version			= FPerl.Description.." - "..FPerl.VersionNumber
FPerl.ModMenuIcon		= "Interface\\Icons\\INV_Misc_Gem_Pearl_02"

FPERL_MINIMAP_HELP1		= "|c00FFFFFFLeft click|r for Options"
FPERL_MINIMAP_HELP2		= "|c00FFFFFFRight click|r to drag this icon"
FPERL_MINIMAP_HELP5		= "|c00FFFFFFAlt|r for F-Perl memory usage"
FPERL_MINIMAP_HELP6		= "|c00FFFFFF+Shift|r for F-Perl memory usage since startup"

FPERL_MINIMENU_OPTIONS	= "Options"
FPERL_MINIMENU_ASSIST	= "Show Assists Frame"
FPERL_MINIMENU_CASTMON	= "Show Casting Monitor"
FPERL_MINIMENU_RAIDAD	= "Show Raid Admin"
FPERL_MINIMENU_ITEMCHK	= "Show Item Checker"
FPERL_MINIMENU_ROSTERTEXT="Roster Text"

FPERL_TYPE_NOT_SPECIFIED	= "Not specified"
FPERL_TYPE_PET				= PET
FPERL_TYPE_BOSS				= "Boss"
FPERL_TYPE_RAREPLUS 		= "Rare+"
FPERL_TYPE_ELITE			= "Elite"
FPERL_TYPE_RARE				= "Rare"

-- Zones
FPERL_LOC_ZONE_ANTORUS				= "Antorus"
FPERL_LOC_ZONE_BARADIN_HOLD 		= "Baradin Hold"
FPERL_LOC_ZONE_BASTION_OF_TWILIGHT	= "Basion of Twilight"
FPERL_LOC_ZONE_BLACK_TEMPLE			= "Black Temple"
FPERL_LOC_ZONE_BLACKWING_DECENT		= "Blackwing Decent"
FPERL_LOC_ZONE_DRAGONSOUL			= "Dragonsoul"
FPERL_LOC_ZONE_EYE_OF_ETERNITY		= "The Eye of Eternity"
FPERL_LOC_ZONE_FIRELANDS			= "Firelands"
FPERL_LOC_ZONE_HYJAL_SUMMIT			= "Hyjal Summit"
FPERL_LOC_ZONE_ICECROWN_CITADEL		= "Icecrown Citadel"
FPERL_LOC_ZONE_KARAZHAN				= "Karazhan"
FPERL_LOC_ZONE_NAXXRAMAS			= "Naxxramas"
FPERL_LOC_ZONE_OBSIDIAN_SANCTUM		= "The Obsidian Sanctum"
FPERL_LOC_ZONE_RUBY_SANCTUM			= "The Ruby Sanctum"
FPERL_LOC_ZONE_SERPENTSHRINE_CAVERN	= "Serpentshrine Cavern"
FPERL_LOC_ZONE_SUNWELL_PLATEAU		= "Sunwell Plateau"
FPERL_LOC_ZONE_THRONE_OF_FOUR_WINDS = "Throne of Four Winds"
FPERL_LOC_ZONE_TOMB_OF_SARGERAS		= "Tomb of Sargeras"
FPERL_LOC_ZONE_TRIAL_OF_THE_CRUSADER= "Trial of the Crusader"
FPERL_LOC_ZONE_ULDUAR				= "Ulduar"
--Any zones 4.x and higher can all be localized from EJ, in 5.0, even these above zones are in EJ which means the rest can go bye bye too

-- Status
FPERL_LOC_DEAD		= DEAD			-- "Dead"
FPERL_LOC_GHOST 	= "Ghost"
FPERL_LOC_OFFLINE	= PLAYER_OFFLINE	-- "Offline"
FPERL_LOC_RESURRECTED	= "Resurrected"
FPERL_LOC_SS_AVAILABLE	= "SS Available"
FPERL_LOC_UPDATING	= "Updating"
FPERL_LOC_ACCEPTEDRES	= "Accepted"		-- Res accepted
FPERL_RAID_GROUP	= "Group %d"
FPERL_RAID_GROUPSHORT	= "G%d"

FPERL_LOC_NONEWATCHED	= "none watched"

FPERL_LOC_STATUSTIP = "Status Highlights: " 	-- Tooltip explanation of status highlight on unit
FPERL_LOC_STATUSTIPLIST = {
	HOT = "Heal over Time",
	AGGRO = "Aggro",
	HEAL = "Being healed",
	SHIELD = "Shielded"
}


FPERL_LOC_LARGENUMTAG		= "K"
FPERL_LOC_HUGENUMTAG		= "M"
FPERL_LOC_VERYHUGENUMTAG	= "G"

BINDING_HEADER_FPERL = FPerl.ProductName
BINDING_NAME_FPERL_TOGGLERAID = "Toggle Raid Windows"
BINDING_NAME_FPERL_TOGGLERAIDPETS = "Toggle Raid Pets"
BINDING_NAME_FPERL_TOGGLEOPTIONS = "Toggle Options Window"
BINDING_NAME_FPERL_TOGGLEBUFFTYPE = "Toggle Buffs/Debuffs/none"
BINDING_NAME_FPERL_TOGGLEBUFFCASTABLE = "Toggle Castable/Curable"
BINDING_NAME_FPERL_TOGGLERANGEFINDER = "Toggle Range Finder"

FPERL_KEY_NOTICE_RAID_BUFFANY = "All buffs/debuffs shown"
FPERL_KEY_NOTICE_RAID_BUFFCURECAST = "Only castable/curable buffs or debuffs shown"
FPERL_KEY_NOTICE_RAID_BUFFS = "Raid Buffs shown"
FPERL_KEY_NOTICE_RAID_DEBUFFS = "Raid Debuffs shown"
FPERL_KEY_NOTICE_RAID_BUFFS_AND_DEBUFFS = "Raid Buffs and Debuffs shown"
FPERL_KEY_NOTICE_RAID_NOBUFFS = "No raid buffs shown"

FPERL_DRAGHINT1		= "|c00FFFFFFClick|r to scale window"
FPERL_DRAGHINT2		= "|c00FFFFFFShift+Click|r to resize window"


FPERL_CMD_MENU		= "menu"
FPERL_CMD_OPTIONS	= "options"
FPERL_CMD_LOCK		= "lock"
FPERL_CMD_UNLOCK	= "unlock"
FPERL_CMD_LAYOUT	= "layout"
FPERL_CMD_HELP		= "|c00FFFF80Usage: |c00FFFFFF/fperl menu | lock | unlock | layout [name]"
FPERL_LAYOUT_LIST		= "Layouts:"
FPERL_LAYOUT_CURRENT		= " (Current)"
FPERL_LAYOUT_UNKNOWN		= "No layout named %s"

FPERL_RAID_TOOLTIP_WITHBUFF	= "With buff: (%s)"
FPERL_RAID_TOOLTIP_WITHOUTBUFF	= "Without buff: (%s)"



-- Status highlight spells
FPERL_HIGHLIGHT_SPELLS = {
	hotSpells  = {
		[FPerl.SpellName(774)] = 12,			-- Rejuvenation (old id 26982)
		--[FPerl.SpellName(155777)] = 12,		-- Rejuvenation Germination
		[FPerl.SpellName(8936)] = 6,			-- Regrowth (old id 26980)
		[FPerl.SpellName(139)] = 12,			-- Renew (old id 25222)
		--[FPerl.SpellName(48438)] = 7,			-- Wild Growth
		--[FPerl.SpellName(33763)] = 8,			-- Lifebloom
		--[FPerl.SpellName(28880)] = 15,			-- Gift of the Naaru (Racial)
		--[FPerl.SpellName(61295)] = 15,			-- Riptide
		--[FPerl.SpellName(119611)] = 18,		-- Renewing Mist
		--[FPerl.SpellName(115175)] = 8,			-- Soothing Mist
		--[FPerl.SpellName(124682)] = 6,			-- Enveloping Mist
		--[FPerl.SpellName(114163)] = 30			-- Eternal Flame
	},
	shieldSpells = {
		[FPerl.SpellName(17)] = 15,			-- Power Word: Shield
		--[FPerl.SpellName(76669)] = 15,			-- Illuminated Healing
		--[FPerl.SpellName(974)] = 600			-- Earth Shield	(old id 32594)
	},
}


-- Don't highlight these magical debuffs
FPerl.ArcaneExclusions = {
	--[FPerl.SpellName(63559)] = true,						-- Bind Life
	--[FPerl.SpellName(30451)] = true,						-- Arcane Blast (again) (old 42897)
	--[FPerl.SpellName(30108)] = true,						-- Unstable Affliction (old 30405)
	--[FPerl.SpellName(15822)] = true,						-- Dreamless Sleep
	--[FPerl.SpellName(24360)] = true,						-- Greater Dreamless Sleep
	--[FPerl.SpellName(28504)] = true,						-- Major Dreamless Sleep
	--[FPerl.SpellName(31257)] = true,						-- Chilled
	[FPerl.SpellName(710)] = true,							-- Banish
	--[FPerl.SpellName(44836)] = true,						-- Also Banish !?
	--[FPerl.SpellName(24306)] = true,						-- Delusions of Jin'do
	--[FPerl.SpellName(46543)] = {ROGUE = true, WARRIOR = true},	-- Ignite Mana
	--[FPerl.SpellName(16567)] = {ROGUE = true, WARRIOR = true},	-- Tainted Mind
	--[FPerl.SpellName(39052)] = {ROGUE = true},				-- Sonic Burst
	--[FPerl.SpellName(41190)] = {ROGUE = true, WARRIOR = true}, -- Mind-numbing Poison
	[FPerl.SpellName(25195)] = {ROGUE = true},				-- Curse of Tongues
	--[FPerl.SpellName(30129)] = true,						-- Charred Earth - Nightbane debuff, can't be cleansed, but shows as magic
	--[FPerl.SpellName(31651)] = {MAGE = true, WARLOCK = true, PRIEST = true},	-- Banshee Curse, Melee hit rating debuff
	--[FPerl.SpellName(38913)] = {ROGUE = true},				-- Silence
	--[FPerl.SpellName(31555)] = {ROGUE = true, WARRIOR = true},	-- Decayed Intellect
}
