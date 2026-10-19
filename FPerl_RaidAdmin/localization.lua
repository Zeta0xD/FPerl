--[[
	Localisation file
]]

FPERL_ADMIN_TITLE	= FPerl.ShortProductName.." Raid Admin"

FPERL_MSG_PREFIX	= "|c00C05050F-Perl|r "

-- Raid Admin
FPERL_BUTTON_ADMIN_PIN		= "Pin Window"
FPERL_BUTTON_ADMIN_LOCKOPEN	= "Lock Window Open"
FPERL_BUTTON_ADMIN_SAVE1	= "Save Roster"
FPERL_BUTTON_ADMIN_SAVE2	= "Saves the current roster layout with the name specified. If no name given, the current time will be used as the name"
FPERL_BUTTON_ADMIN_LOAD1	= "Load Roster"
FPERL_BUTTON_ADMIN_LOAD2	= "Load the selected roster. Any raid members of the saved roster who are no longer in the raid will be replaced by members of the same class who are not saved in the roster"
FPERL_BUTTON_ADMIN_DELETE1	= "Delete Roster"
FPERL_BUTTON_ADMIN_DELETE2	= "Delete the selected roster"
FPERL_BUTTON_ADMIN_STOPLOAD1	= "Stop Load"
FPERL_BUTTON_ADMIN_STOPLOAD2	= "Aborts the roster load procedure"

FPERL_LOAD			= "Load"

FPERL_SAVED_ROSTER		= "Saved roster called '%s'"
FPERL_ADMIN_DIFFERENCES		= "%d differences to current roster"
FPERL_NO_ROSTER_NAME_GIVEN	= "No roster name given"
FPERL_NO_ROSTER_CALLED		= "No roster saved called '%s'"

-- Item Checker
FPERL_CHECK_TITLE		= FPerl.ShortProductName.." Item Check"

FPERL_CHECK_NAME		= "Name"

FPERL_CHECK_DROPITEMTIP1	= "Drop Items"
FPERL_CHECK_DROPITEMTIP2	= "Items can be dropped into this frame and added to the list of queryable items.\rYou may also use the /raitem command as normal and items will also be added here and used in the future."
FPERL_CHECK_QUERY_DESC1		= "Query"
FPERL_CHECK_QUERY_DESC2		= "Performs item check (/raitem) on all ticked items\rQuery always gets current durablity, resistance and reagents information"
FPERL_CHECK_LAST_DESC1		= "Last"
FPERL_CHECK_LAST_DESC2		= "Re-tick the last search items"
FPERL_CHECK_ALL_DESC1		= ALL
FPERL_CHECK_ALL_DESC2		= "Tick all the items"
FPERL_CHECK_NONE_DESC1		= NONE
FPERL_CHECK_NONE_DESC2		= "Un-tick all the items"
FPERL_CHECK_DELETE_DESC1	= DELETE
FPERL_CHECK_DELETE_DESC2	= "Permenantly remove all the ticked items from the list"
FPERL_CHECK_REPORT_DESC1	= "Report"
FPERL_CHECK_REPORT_DESC2	= "Show report of the selected results to the raid chat"
FPERL_CHECK_REPORT_WITH_DESC1	= "With"
FPERL_CHECK_REPORT_WITH_DESC2	= "Report people with the item (or don't have the item equipped) to the raid chat. If an equipment scan has been performed, these results will be shown instead."
FPERL_CHECK_REPORT_WITHOUT_DESC1= "Without"
FPERL_CHECK_REPORT_WITHOUT_DESC2= "Report people without the item (or have the item equipped) to the raid chat"
FPERL_CHECK_SCAN_DESC1		= "Scan"
FPERL_CHECK_SCAN_DESC2		= "Will check anyone in raid within inspect range, to see whether they have the selected item equipped and indicate this on the player list. Move closer (10 yards) to people in the raid until all are checked."
FPERL_CHECK_SCANSTOP_DESC1	= "Stop Scan"
FPERL_CHECK_SCANSTOP_DESC2	= "Stop scanning player's equipment for the selected item"
FPERL_CHECK_REPORTPLAYER_DESC1	= "Report Player"
FPERL_CHECK_REPORTPLAYER_DESC2	= "Report selected player's details for this item or status to the raid chat"

FPERL_CHECK_BROKEN		= "Broken"
FPERL_CHECK_REPORT_DURABILITY	= "Average Raid Durability: %d%% and %d people with a total of %d broken items"
FPERL_CHECK_REPORT_PDURABILITY	= "%s's Durability: %d%% with %d broken items"
FPERL_CHECK_REPORT_RESISTS	= "Average Raid resists: %d "..SPELL_SCHOOL2_CAP..", %d "..SPELL_SCHOOL3_CAP..", %d "..SPELL_SCHOOL4_CAP..", %d "..SPELL_SCHOOL5_CAP..", %d "..SPELL_SCHOOL6_CAP
FPERL_CHECK_REPORT_PRESISTS	= "%s's Resists: %d "..SPELL_SCHOOL2_CAP..", %d "..SPELL_SCHOOL3_CAP..", %d "..SPELL_SCHOOL4_CAP..", %d "..SPELL_SCHOOL5_CAP..", %d "..SPELL_SCHOOL6_CAP
FPERL_CHECK_REPORT_WITH		= " - with: "
FPERL_CHECK_REPORT_WITHOUT	= " - without: "
FPERL_CHECK_REPORT_WITH_EQ	= " - with (or not equipped): "
FPERL_CHECK_REPORT_WITHOUT_EQ	= " - without (or equipped): "
FPERL_CHECK_REPORT_EQUIPED	= " : equipped: "
FPERL_CHECK_REPORT_NOTEQUIPED	= " : NOT equipped: "
FPERL_CHECK_REPORT_ALLEQUIPED	= "Everyone has %s equipped"
FPERL_CHECK_REPORT_ALLEQUIPEDOFF= "Everyone has %s equipped, but %d member(s) offline"
FPERL_CHECK_REPORT_PITEM	= "%s has %d %s in inventory"
FPERL_CHECK_REPORT_PEQUIPED	= "%s has %s equipped"
FPERL_CHECK_REPORT_PNOTEQUIPED	= "%s DOES NOT have %s equipped"
FPERL_CHECK_REPORT_DROPDOWN	= "Output Channel"
FPERL_CHECK_REPORT_DROPDOWN_DESC= "Select output channel for Item Checker results"

FPERL_CHECK_REPORT_WITHSHORT	= " : %d with"
FPERL_CHECK_REPORT_WITHOUTSHORT	= " : %d without"
FPERL_CHECK_REPORT_EQUIPEDSHORT	= " : %d equipped"
FPERL_CHECK_REPORT_NOTEQUIPEDSHORT	= " : %d NOT equipped"
FPERL_CHECK_REPORT_OFFLINE	= " : %d offline"
FPERL_CHECK_REPORT_TOTAL	= " : %d Total Items"
FPERL_CHECK_REPORT_NOTSCANNED	= " : %d un-checked"

FPERL_CHECK_LASTINFO		= "Last data received %sago"

FPERL_CHECK_AVERAGE		= "Average"
FPERL_CHECK_TOTALS		= "Total"
FPERL_CHECK_EQUIPED		= "Equipped"

FPERL_CHECK_SCAN_MISSING	= "Scanning inspectable players for item. (%d un-scanned)"

FPERL_REAGENTS			= {PRIEST = "Sacred Candle", MAGE = "Arcane Powder", DRUID = "Wild Thornroot",
					SHAMAN = "Ankh", WARLOCK = "Soul Shard", PALADIN = "Symbol of Divinity",
					ROGUE = "Flash Powder"}

FPERL_CHECK_REAGENTS		= "Reagents"

-- Roster Text
FPERL_ROSTERTEXT_TITLE		= FPerl.ShortProductName.." Roster Text"
FPERL_ROSTERTEXT_GROUP		= "Group %d"
FPERL_ROSTERTEXT_GROUP_DESC	= "Use names from group %d"
FPERL_ROSTERTEXT_SAMEZONE	= "Same Zone Only"
FPERL_ROSTERTEXT_SAMEZONE_DESC	= "Only include names of players in the same zone as yourself"
FPERL_ROSTERTEXT_HELP		= "Press Ctrl-C to copy the text to the clipboard"
FPERL_ROSTERTEXT_TOTAL		= "Total: %d"
FPERL_ROSTERTEXT_SETN		= "%d Man"
FPERL_ROSTERTEXT_SETN_DESC	= "Auto select the groups for a %d man raid"
FPERL_ROSTERTEXT_TOGGLE		= "Toggle"
FPERL_ROSTERTEXT_TOGGLE_DESC	= "Toggle the selected groups"
FPERL_ROSTERTEXT_SORT		= "Sort"
FPERL_ROSTERTEXT_SORT_DESC	= "Sort by name instead of by group+name"
