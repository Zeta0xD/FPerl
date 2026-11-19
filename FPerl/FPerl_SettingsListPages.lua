-- The Player, Pet, Target, Focus, Party and Raid pages of the settings list, after the General page of
-- FPerl_SettingsList.lua. Data only: loads under plain lua5.1, calls no API, makes no frame. Format: the header of
-- FPerl_SettingsList.lua.

local R = FPerl.SettingsRow
local list, throttleOf, FRAMES = R.list, R.throttleOf, R.FRAMES
local check, slider, dropdown, button = R.check, R.slider, R.dropdown, R.button
local VIS_ONEGROUP, HEALTHTEXT, auraLayout = R.VIS_ONEGROUP, R.HEALTHTEXT, R.auraLayout

------------------------------------------------------------------------------------------------ Player
R.page = "Player"

R.section = "Size"
check("player.size.enable", "Show player frame", "Show the player frame. Takes effect after a reload.", {reload = true, path = "player.enable", apply = {}})
slider("player.size.scale", "Scale", "The size of the player frame.", {path = "player.scale", min = 0.5, max = 1.5, step = 0.01, percent = true})
slider("player.size.width", "Extra width", "Widen the player frame.", {path = "player.size.width", min = 0, max = 100, step = 1})

R.section = "Shown"
dropdown("player.shown.portrait", "Portrait", "The portrait of the player frame.", {
	base = "player",
	map = {
		{"None", {portrait = false}},
		{"2D", {portrait = 1, portrait3D = false, classPortrait = false}},
		{"3D", {portrait = 1, portrait3D = 1, classPortrait = false}},
		{"Class icon", {portrait = 1, classPortrait = 1}},
	},
})
check("player.shown.level", "Level", "Show the player's level.", {path = "player.level"})
check("player.shown.classicon", "Class icon", "Show the player's class icon.", {path = "player.classIcon"})
check("player.shown.pvp", "PvP flag", "Show the player's PvP status.", {path = "player.pvpIcon"})
local HITPOS = {
	{"Portrait spot", {hitIndicatorPos = "PORTRAIT"}},
	{"Name", {hitIndicatorPos = "NAME"}},
}
check("player.shown.hit", "Hit indicators", "Show damage and heal numbers on the frame, at the portrait spot or the name (Hit text position).", {path = "player.hitIndicator"})
dropdown("player.shown.hitpos", "Hit text position", "Where the hit indicator text appears: at the place the portrait has (also with the portrait off), or over the name.", {
	base = "player", needs = "player.hitIndicator", apply = {},
	map = HITPOS,
})
dropdown("player.shown.healthtext", "Health text", "How health is written on the bars.", {
	base = "player",
	map = HEALTHTEXT,
})
check("player.shown.absorbs", "Absorbs", "Show the absorb bar.", {path = "player.absorbs"})
check("player.shown.healprediction", "Heal prediction", "Show the heal prediction bar.", {path = "player.healprediction"})
check("player.shown.castbar", "Cast bar", "Show a cast bar on the player frame.", {path = "player.castBar.enable"})
dropdown("player.shown.casttime", "Cast time text", "Show the casting time beside or inside every F-Perl cast bar: player, pet, target, focus and party.", {
	base = "player.castBar",
	map = {
		{"Off", {castTime = false, inside = false}, {castTime = false}},
		{"Beside", {castTime = 1, inside = false}},
		{"Inside", {castTime = 1, inside = 1}},
	},
})

R.section = "Auras"
check("player.auras.buffs", "Buffs", "Show the player's buffs.", {path = "player.buffs.enable"})
check("player.auras.debuffs", "Debuffs", "Show the player's debuffs.", {path = "player.debuffs.enable"})
slider("player.auras.buffsize", "Buff size", "The size of the buff icons.", {path = "player.buffs.size", min = 7, max = 38, step = 1})
slider("player.auras.debuffsize", "Debuff size", "The size of the debuff icons.", {path = "player.debuffs.size", min = 7, max = 45, step = 1})
slider("player.auras.aurasize", "Aura size", "The size of the buff and debuff icons together. Buff size and Debuff size set them apart.", {path = "player.buffs.size", with = {"player.debuffs.size"}, min = 7, max = 38, step = 1, apply = {"playerbuffs"}})
check("player.auras.wrap", "Wrap", "Wrap aura icons that exceed the width of the frame.", {path = "player.buffs.wrap"})
check("player.auras.bigbuffs", "Big buffs", "Show your own buffs larger.", {path = "player.buffs.big"})
check("player.auras.enchants", "Weapon enchants", "Show poisons and other weapon enchants first in the buff line; the buffs move over while one is on. Right-click one to remove it.", {path = "player.enchants.enable", needs = "player.buffs.enable"})
auraLayout("player.auras.", "player", {"playerbuffs"})

R.section = "Player"
check("player.player.xp", "XP bar", "Show the experience bar.", {path = "player.xpBar"})
check("player.player.xpdeficit", "As deficit", "Show the experience as what is still needed for the level.", {path = "player.xpDeficit"})
check("player.player.rep", "Reputation bar", "Show the reputation bar.", {path = "player.repBar"})
check("player.player.partynumber", "Party number", "Show the party number when in a raid group.", {path = "player.partyNumber"})
check("player.player.withname", "With name", "Show the party number in the name frame instead of above the player frame.", {path = "player.withName"})
check("player.player.extend", "Extend portrait", "Let the portrait extend to the bottom of the stats frame when extra bars are shown.", {path = "player.extendPortrait"})
check("player.player.nodruidbar", "Hide druid mana bar", "Hide the mana bar that shows mana while shapeshifted.", {path = "player.noDruidBar"})
check("player.player.precast", "Pre-cast latency marker", "Show the part of the cast bar that overlaps your current latency.", {path = "player.castBar.precast"})
check("player.player.originalcastbar", "Keep Blizzard's cast bar", "Use the original cast bar.", {path = "player.castBar.original"})
check("player.player.hideblizzbuffs", "Hide Blizzard's buff bars", "Hide the default buff frames.", {path = "player.buffs.hideBlizzard"})

------------------------------------------------------------------------------------------------ Pet
R.page = "Pet"

R.section = "Size"
check("pet.size.enable", "Show pet frame", "Show the pet frame. Takes effect after a reload.", {reload = true, path = "pet.enable", apply = {}})
slider("pet.size.scale", "Scale", "The size of the pet frame.", {path = "pet.scale", min = 0.5, max = 1.5, step = 0.01, percent = true})
slider("pet.size.width", "Extra width", "Widen the pet frame.", {path = "pet.size.width", min = 0, max = 100, step = 1})

R.section = "Shown"
dropdown("pet.shown.portrait", "Portrait", "The portrait of the pet frame.", {
	base = "pet",
	map = {
		{"None", {portrait = false}},
		{"2D", {portrait = 1, portrait3D = false}},
		{"3D", {portrait = 1, portrait3D = 1}},
	},
})
check("pet.shown.level", "Level", "Show the pet's level.", {path = "pet.level"})
check("pet.shown.hit", "Hit indicators", "Show damage and heal numbers on the frame, at the portrait spot or the name (Hit text position).", {path = "pet.hitIndicator"})
dropdown("pet.shown.hitpos", "Hit text position", "Where the hit indicator text appears: at the place the portrait has (also with the portrait off), or over the name.", {
	base = "pet", needs = "pet.hitIndicator", apply = {},
	map = HITPOS,
})
check("pet.shown.healthtext", "Health and mana text", "Show the health and mana numbers on the pet bars.", {path = "pet.values"})
check("pet.shown.absorbs", "Absorbs", "Show the absorb bar.", {path = "pet.absorbs"})
check("pet.shown.healprediction", "Heal prediction", "Show the heal prediction bar.", {path = "pet.healprediction"})
check("pet.shown.castbar", "Cast bar", "Show a cast bar on the pet frame.", {path = "pet.castBar.enable"})

R.section = "Auras"
check("pet.auras.buffs", "Buffs", "Show the pet's buffs.", {path = "pet.buffs.enable"})
check("pet.auras.debuffs", "Debuffs", "Show the pet's debuffs.", {path = "pet.debuffs.enable"})
slider("pet.auras.buffsize", "Buff size", "The size of the buff icons.", {path = "pet.buffs.size", min = 7, max = 38, step = 1})
slider("pet.auras.debuffsize", "Debuff size", "The size of the debuff icons.", {path = "pet.debuffs.size", min = 7, max = 38, step = 1})
slider("pet.auras.aurasize", "Aura size", "The size of the buff and debuff icons together. Buff size and Debuff size set them apart.", {path = "pet.buffs.size", with = {"pet.debuffs.size"}, min = 7, max = 38, step = 1, apply = {"playerpet"}})
check("pet.auras.wrap", "Wrap", "Wrap aura icons that exceed the width of the frame.", {path = "pet.buffs.wrap"})
slider("pet.auras.rows", "Rows", "The most rows of wrapped aura icons.", {path = "pet.buffs.rows", min = 1, max = 10, step = 1})
check("pet.auras.castable", "Castable only", "Only show the buffs you can cast.", {path = "pet.buffs.castable"})
check("pet.auras.curable", "Curable only", "Only show the debuffs you can cure.", {path = "pet.debuffs.curable"})
check("pet.auras.bigbuffs", "Big buffs", "Double the size of the buffs you cast.", {path = "pet.buffs.big"})
check("pet.auras.bigdebuffs", "Big debuffs", "Double the size of the debuffs you cast.", {path = "pet.debuffs.big"})
auraLayout("pet.auras.", "pet", {"playerpet"})

R.section = "Pet"
check("pet.pet.name", "Name", "Show the pet's name.", {path = "pet.name"})
check("pet.pet.happiness", "Happiness icon", "Show the pet's happiness icon. Hunters only.", {path = "pet.happiness.enable"})
check("pet.pet.onlysad", "Only when sad", "Show the happiness icon only while the pet is not happy.", {path = "pet.happiness.onlyWhenSad"})
check("pet.pet.flashsad", "Flash when sad", "Flash the happiness icon while the pet is not happy.", {path = "pet.happiness.flashWhenSad"})
check("pet.pet.extend", "Extend portrait", "Let the portrait extend to the bottom of the stats frame when extra bars are shown.", {path = "pet.extendPortrait"})
dropdown("pet.pet.threat", "Threat", "Show the pet's threat against its target: a bar on the name, or a dial on the portrait.", {
	base = "pet",
	map = {
		{"Off", {threat = false}},
		{"Bar on name", {threat = 1, threatMode = "nameFrame"}},
		{"Dial on portrait", {threat = 1, threatMode = "portraitFrame"}},
	},
})

R.section = "Pet's target"
check("pet.pettarget.enable", "Show pet's target", "Show the frame of the pet's target.", {path = "pettarget.enable"})
slider("pet.pettarget.scale", "Scale", "The size of the pet's target frame.", {path = "pettarget.scale", min = 0.4, max = 1.5, step = 0.01, percent = true})
check("pet.pettarget.mana", "Mana bar", "Show the mana bar on the pet's target frame.", {path = "pettarget.mana"})
check("pet.pettarget.buffs", "Buffs", "Show the auras on the pet's target frame.", {path = "pettarget.buffs.enable", with = {"pettarget.debuffs.enable"}})
check("pet.pettarget.bigbuffs", "Big buffs", "Show your own buffs larger.", {path = "pettarget.buffs.big"})
check("pet.pettarget.bigdebuffs", "Big debuffs", "Show your own debuffs larger.", {path = "pettarget.debuffs.big"})
auraLayout("pet.pettarget.", "pettarget", {"targettarget"})
check("pet.pettarget.level", "Level", "Show the unit's level.", {path = "pettarget.level"})
dropdown("pet.pettarget.healthtext", "Health text", "How health is written on the bars.", {
	base = "pettarget", map = HEALTHTEXT,
})
------------------------------------------------------------------------------------------------ Target and Focus
-- One layout for both pages: `unitPage` adds a page, `unitFrame` the section of a target-of-target
-- style frame. Every frame has its own aura settings.
local TOT = {"targettarget"} -- the changer for target of target, target of target of target, focus target and pet target
-- The aura settings of profile table k. Target and Focus (main) have Big stealable
-- buffs, the target-of-target style frames Big debuffs.
local function auraSettings(id, k, who, ap, main)
	check(id .. ".buffs", "Buffs", "Show the " .. who .. "'s buffs.", {path = k .. ".buffs.enable", apply = ap})
	check(id .. ".debuffs", "Debuffs", "Show the " .. who .. "'s debuffs.", {path = k .. ".debuffs.enable", apply = ap})
	slider(id .. ".buffsize", "Buff size", "The size of the buff icons.", {path = k .. ".buffs.size", min = 7, max = 38, step = 1, apply = ap})
	slider(id .. ".debuffsize", "Debuff size", "The size of the debuff icons.", {path = k .. ".debuffs.size", min = 7, max = 45, step = 1, apply = ap})
	if (main) then
		slider(id .. ".aurasize", "Aura size", "The size of the buff and debuff icons together. Buff size and Debuff size set them apart.", {path = k .. ".buffs.size", with = {k .. ".debuffs.size"}, min = 7, max = 38, step = 1, apply = ap})
	end
	check(id .. ".wrap", "Wrap", "Wrap aura icons that exceed the width of the frame.", {path = k .. ".buffs.wrap", apply = ap})
	slider(id .. ".rows", "Rows", "The most rows of aura icons when wrapping.", {path = k .. ".buffs.rows", min = 1, max = 10, step = 1, apply = ap})
	check(id .. ".castable", "Castable buffs only", "Show only the buffs you can cast.", {path = k .. ".buffs.castable", apply = ap})
	check(id .. ".curable", "Curable debuffs only", "Show only the debuffs you can cure.", {path = k .. ".debuffs.curable", apply = ap})
	check(id .. ".onlymybuffs", "Only my buffs", "Show only the buffs you cast.", {path = k .. ".buffs.onlyMine", apply = ap})
	check(id .. ".onlymydebuffs", "Only my debuffs", "Show only the debuffs you cast.", {path = k .. ".debuffs.onlyMine", apply = ap})
	check(id .. ".bigbuffs", "Big buffs", "Show your own buffs larger.", {path = k .. ".buffs.big", apply = ap})
	if (main) then
		check(id .. ".bigstealable", "Big stealable buffs", "Show the buffs you can steal larger.", {path = k .. ".buffs.bigStealable", apply = ap})
	else
		check(id .. ".bigdebuffs", "Big debuffs", "Show your own debuffs larger.", {path = k .. ".debuffs.big", apply = ap})
	end
	auraLayout(id .. ".", k, ap)
end

-- The section of a target-of-target style frame (profile table k): its switch, size, what it shows, its auras.
local function unitFrame(sectionName, id, k, who)
	R.section = sectionName
	check(id .. ".enable", "Show " .. who .. " frame", "Show the " .. who .. " frame.", {path = k .. ".enable", apply = TOT})
	slider(id .. ".scale", "Scale", "The size of the " .. who .. " frame.", {path = k .. ".scale", min = 0.5, max = 1.5, step = 0.01, percent = true, apply = TOT})
	slider(id .. ".width", "Extra width", "Widen the " .. who .. " frame.", {path = k .. ".size.width", min = 0, max = 100, step = 1, apply = TOT})
	check(id .. ".mana", "Mana bar", "Show the mana bar under the health bar.", {path = k .. ".mana", apply = TOT})
	check(id .. ".level", "Level", "Show the unit's level.", {path = k .. ".level", apply = TOT})
	dropdown(id .. ".healthtext", "Health text", "How health is written on the bars.", {base = k, map = HEALTHTEXT, apply = TOT})
	check(id .. ".absorbs", "Absorbs", "Show the absorb bar.", {path = k .. ".absorbs", apply = TOT})
	check(id .. ".healprediction", "Heal prediction", "Show the heal prediction bar.", {path = k .. ".healprediction", apply = TOT})
	auraSettings(id, k, who, TOT, false)
end

-- A page for the target or the focus (profile table k).
local function unitPage(pageName, k, isTarget)
	local id, ap = k, {"target"} -- ap: the changer of FPerl_Target and FPerl_Focus
	local own = id .. "." .. id
	R.page = pageName
	R.section = "Size"
	if (isTarget) then
		check(id .. ".size.enable", "Show target frame", "Show the target frame. Takes effect after a reload.", {reload = true, path = k .. ".enable", apply = {}})
	end
	slider(id .. ".size.scale", "Scale", "The size of the " .. k .. " frame.", {path = k .. ".scale", min = 0.5, max = 1.5, step = 0.01, percent = true, apply = ap})
	slider(id .. ".size.width", "Extra width", "Widen the " .. k .. " frame.", {path = k .. ".size.width", min = 0, max = 100, step = 1, apply = ap})

	R.section = "Shown"
	dropdown(id .. ".shown.portrait", "Portrait", "The portrait of the " .. k .. " frame.", {
		base = k, apply = ap,
		map = {
			{"None", {portrait = false}},
			{"2D", {portrait = 1, portrait3D = false, classPortrait = false}},
			{"3D", {portrait = 1, portrait3D = 1, classPortrait = false}},
			{"Class icon", {portrait = 1, classPortrait = 1}},
		},
	})
	check(id .. ".shown.level", "Level", "Show the unit's level.", {path = k .. ".level", apply = ap})
	check(id .. ".shown.classicon", "Class icon", "Show the unit's class icon.", {path = k .. ".classIcon", apply = ap})
	check(id .. ".shown.pvp", "PvP flag", "Show the unit's PvP status.", {path = k .. ".pvpIcon", apply = ap})
	check(id .. ".shown.hit", "Hit indicators", "Show damage and heal numbers on the frame, at the portrait spot or the name (Hit text position).", {path = k .. ".hitIndicator", apply = {}})
	dropdown(id .. ".shown.hitpos", "Hit text position", "Where the hit indicator text appears: at the place the portrait has (also with the portrait off), or over the name.", {
		base = k, needs = k .. ".hitIndicator", apply = {}, map = HITPOS,
	})
	dropdown(id .. ".shown.healthtext", "Health text", "How health is written on the bars.", {
		base = k, map = HEALTHTEXT, apply = ap,
	})
	check(id .. ".shown.absorbs", "Absorbs", "Show the absorb bar.", {path = k .. ".absorbs", apply = ap})
	check(id .. ".shown.healprediction", "Heal prediction", "Show the heal prediction bar.", {path = k .. ".healprediction", apply = ap})
	check(id .. ".shown.castbar", "Cast bar", "Show a cast bar on the " .. k .. " frame.", {path = k .. ".castBar.enable", apply = {"arcanebar"}})
	check(id .. ".shown.mana", "Mana bar", "Show the mana, rage or energy bar under the health bar.", {path = k .. ".mana", apply = ap})
	dropdown(id .. ".shown.debuffhighlight", "Debuff highlight", "Colour the frame while the unit has a debuff, for all units, friendly units or enemy units.", {
		base = k .. ".highlightDebuffs", apply = ap,
		map = {
			{"Off", {enable = false}},
			{"All units", {enable = 1, who = 1}},
			{"Friendly units", {enable = 1, who = 2}},
			{"Enemy units", {enable = 1, who = 3}},
		},
	})

	R.section = "Auras"
	auraSettings(id .. ".auras", k, k, ap, true)

	R.section = pageName
	if (not isTarget) then
		check(own .. ".enable", "Show focus frame", "Show the focus frame.", {path = k .. ".enable", apply = ap})
	end
	dropdown(own .. ".classification", "Classification", "How rare, elite and boss units are marked: not at all, as text, or as a graphic on the portrait.", {
		base = k, apply = ap,
		map = {
			{"None", {elite = 1, eliteGfx = false, eliteNone = 1}, {eliteNone = 1}},
			{"Text", {elite = 1, eliteGfx = false, eliteNone = false}, {eliteGfx = false, eliteNone = false}},
			{"Graphic", {elite = 1, eliteGfx = 1, eliteNone = false}, {eliteGfx = 1}},
		},
	})
	check(own .. ".mobtype", "Creature type", "Show the creature type under the portrait for units that are not players.", {path = k .. ".mobType", apply = ap})
	check(own .. ".classtext", "Class text", "Write the class name in place of the class icon. Needs the class icon.", {path = k .. ".classText", apply = ap})
	check(own .. ".reaction", "Reaction colouring", "Colour the name plate by the unit's reaction to you.", {path = k .. ".reactionHighlight", apply = ap})
	dropdown(own .. ".threat", "Threat", "Show the unit's threat against you as a needle on the name plate or a dial on the portrait.", {
		base = k, apply = ap,
		map = {
			{"Off", {threat = false}},
			{"Bar on name", {threat = 1, threatMode = "nameFrame"}},
			{"Dial on portrait", {threat = 1, threatMode = "portraitFrame"}},
		},
	})
	if (isTarget) then
		dropdown(own .. ".combo", "Combo points", "How combo points are shown: squares above the name plate, a bar in the name plate, or a number.", {
			base = k, apply = ap,
			map = {
				{"Off", {["combo.blizzard"] = false, ["combo.enable"] = false, ["comboindicator.enable"] = false}},
				{"Squares", {["combo.blizzard"] = 1, ["combo.enable"] = false, ["comboindicator.enable"] = false}, {["combo.blizzard"] = 1}},
				{"Bar", {["combo.blizzard"] = false, ["combo.enable"] = 1, ["comboindicator.enable"] = false}, {["combo.blizzard"] = false, ["combo.enable"] = 1}},
				{"Number", {["combo.blizzard"] = false, ["combo.enable"] = false, ["comboindicator.enable"] = 1}, {["combo.blizzard"] = false, ["combo.enable"] = false, ["comboindicator.enable"] = 1}},
			},
		})
	end
	check(own .. ".sound", "Sound on " .. k .. " change", "Play a sound when the " .. k .. " changes: one for enemies, friendly and neutral units.", {path = k .. ".sound", apply = {}})
	check(own .. ".raidicon", "Alternate raid icon spot", "Put the raid icon small in the top right corner of the name plate instead of large in its centre.", {path = k .. ".raidIconAlternate", apply = isTarget and {"target", "targettarget"} or ap})
	check(own .. ".rangehand", "Out-of-range hand icon", "Show a hand icon on the name plate when the unit is out of range. Works for group members.", {path = k .. ".range30yard", apply = ap})

	if (isTarget) then
		unitFrame("Target of target", id .. ".tot", "targettarget", "target of target")
		unitFrame("Target of target of target", id .. ".tott", "targettargettarget", "target of target of target")
	else
		unitFrame("Focus target", id .. ".focustarget", "focustarget", "focus target")
	end
end

unitPage("Target", "target", true)
unitPage("Focus", "focus", false)
------------------------------------------------------------------------------------------------ Party
R.page = "Party"

R.section = "Size"
check("party.size.enable", "Show party frames", "Show the party frames.", {path = "party.enable", apply = {"party"}})
slider("party.size.scale", "Scale", "The size of the party frames.", {path = "party.scale", min = 0.5, max = 1.5, step = 0.01, percent = true})
slider("party.size.width", "Extra width", "Widen the party frames.", {path = "party.size.width", min = 0, max = 100, step = 1})

R.section = "Shown"
dropdown("party.shown.portrait", "Portrait", "The portrait of the party frames.", {
	base = "party",
	map = {
		{"None", {portrait = false}},
		{"2D", {portrait = 1, portrait3D = false, classPortrait = false}},
		{"3D", {portrait = 1, portrait3D = 1, classPortrait = false}},
		{"Class icon", {portrait = 1, classPortrait = 1}},
	},
})
check("party.shown.level", "Level", "Show the party members' levels.", {path = "party.level"})
check("party.shown.classicon", "Class icon", "Show the party members' class icons.", {path = "party.classIcon"})
check("party.shown.pvp", "PvP flag", "Show the party members' PvP status.", {path = "party.pvpIcon"})
check("party.shown.hit", "Hit indicators", "Show damage and heal numbers on the frame, at the portrait spot or the name (Hit text position).", {path = "party.hitIndicator"})
dropdown("party.shown.hitpos", "Hit text position", "Where the hit indicator text appears: at the place the portrait has (also with the portrait off), or over the name.", {
	base = "party", needs = "party.hitIndicator", apply = {},
	map = HITPOS,
})
dropdown("party.shown.healthtext", "Health text", "How health is written on the bars.", {
	base = "party",
	map = HEALTHTEXT,
})
check("party.shown.absorbs", "Absorbs", "Show the absorb bar.", {path = "party.absorbs"})
check("party.shown.healprediction", "Heal prediction", "Show the heal prediction bar.", {path = "party.healprediction"})
check("party.shown.castbar", "Cast bar", "Show a cast bar on the party frames.", {path = "party.castBar.enable"})

R.section = "Auras"
check("party.auras.buffs", "Buffs", "Show the party members' buffs.", {path = "party.buffs.enable"})
check("party.auras.debuffs", "Debuffs", "Show the party members' debuffs.", {path = "party.debuffs.enable"})
slider("party.auras.buffsize", "Buff size", "The size of the buff icons.", {path = "party.buffs.size", min = 7, max = 38, step = 1})
slider("party.auras.debuffsize", "Debuff size", "The size of the debuff icons.", {path = "party.debuffs.size", min = 7, max = 45, step = 1})
slider("party.auras.aurasize", "Aura size", "The size of the buff and debuff icons together. Buff size and Debuff size set them apart.", {path = "party.buffs.size", with = {"party.debuffs.size"}, min = 7, max = 38, step = 1, apply = {"party"}})
check("party.auras.wrap", "Wrap", "Wrap aura icons that exceed the width of the frame.", {path = "party.buffs.wrap"})
check("party.auras.castable", "Castable buffs only", "Only show the buffs you can cast.", {path = "party.buffs.castable"})
check("party.auras.curable", "Curable debuffs only", "Only show the debuffs you can cure.", {path = "party.debuffs.curable"})
check("party.auras.onlymine", "Only my buffs", "Only show the buffs you cast.", {path = "party.buffs.onlyMine"})
check("party.auras.big", "Big buffs", "Show your own buffs bigger.", {path = "party.buffs.big"})
slider("party.auras.rows", "Buff rows", "The number of rows wrapped buffs fill.", {path = "party.buffs.rows", min = 1, max = 10, step = 1})
check("party.auras.halfsize", "Wrap lots", "Show many debuffs at half size.", {path = "party.debuffs.halfSize"})
auraLayout("party.auras.", "party", {"party"})

R.section = "Party"
check("party.party.names", "Names", "Show the party members' names.", {path = "party.name"})
check("party.party.showplayer", "Show yourself", "Show yourself in the party frames.", {path = "party.showPlayer"})
check("party.party.targets", "Party targets", "Show the target of each party member.", {path = "party.target.enable"})
slider("party.party.targetsize", "Target size", "The size of the party targets.", {path = "party.target.size", min = 66, max = 200, step = 1})
check("party.party.targetlarge", "Health bar", "Show a health bar on the party targets.", {path = "party.target.large"})
check("party.party.range", "Out-of-range hand icon", "Show an icon on party members who are out of range.", {path = "party.range30yard"})
dropdown("party.party.threat", "Threat", "Show threat on the party frames: a bar on the name, or a dial on the portrait.", {
	base = "party",
	map = {
		{"Off", {threat = false}},
		{"Bar on name", {threat = 1, threatMode = "nameFrame"}},
		{"Dial on portrait", {threat = 1, threatMode = "portraitFrame"}, {threat = 1, threatMode = {"portraitFrame", false}}},
	},
})

R.section = "Layout"
dropdown("party.layout.anchor", "Anchor", "The side of the anchor the party frames grow from.", {
	path = "party.anchor",
	options = {{"TOP", "Top"}, {"BOTTOM", "Bottom"}, {"LEFT", "Left"}, {"RIGHT", "Right"}},
})
check("party.layout.flip", "Flip", "Mirror the party frame layout.", {path = "party.flip"})
slider("party.layout.spacing", "Spacing", "The gap in pixels between party frames.", {path = "party.spacing", min = 0, max = 200, step = 1})

R.section = "Party pets"
check("party.pets.enable", "Party pets", "Show the party members' pet frames.", {path = "partypet.enable"})
slider("party.pets.scale", "Scale", "The size of the party pet frames.", {path = "partypet.scale", min = 0.5, max = 1.5, step = 0.01, percent = true})
check("party.pets.name", "Name", "Show the pets' names.", {path = "partypet.name"})
check("party.pets.level", "Level", "Show the pets' levels.", {path = "partypet.level"})
check("party.pets.mana", "Mana bar", "Show the pets' mana bars.", {path = "partypet.mana"})
check("party.pets.buffs", "Buffs", "Show the pets' buffs and debuffs.", {path = "partypet.buffs.enable"})
slider("party.pets.buffsize", "Buff size", "The size of the pets' buff icons.", {path = "partypet.buffs.size", min = 5, max = 20, step = 1})
slider("party.pets.debuffsize", "Debuff size", "The size of the pets' debuff icons.", {path = "partypet.debuffs.size", min = 5, max = 20, step = 1})
auraLayout("party.pets.", "partypet", {"partypet"})

R.section = "Visibility (party and raid)"
dropdown("party.visibility.inparty", "In a party use", "Which frames show for the members of a party: the party frames, or the raid frames.", {
	base = "raid",
	map = {
		{"Party frames", {inParty = false}},
		{"Raid frames", {inParty = 1}},
	},
})
dropdown("party.visibility.insmallraid", "In a one-group raid use", "Which frames show in a raid of one group: the party frames, or the raid frames. Raid frames also hide the party frames in a raid of several groups.", {
	base = "party",
	map = VIS_ONEGROUP,
})

------------------------------------------------------------------------------------------------ Raid
R.page = "Raid"

R.section = "Size"
slider("raid.size.scale", "Scale", "The size of the raid frames.", {path = "raid.scale", min = 0.5, max = 1.5, step = 0.01, percent = true})
slider("raid.size.width", "Extra width", "Widen the raid frames.", {path = "raid.size.width", min = 0, max = 100, step = 1})

R.section = "Shown"
dropdown("raid.shown.healthtext", "Health text", "How health is written on the bars. Missing (healer mode) shows the missing health.", {
	base = "raid",
	map = {
		{"Percent", {percent = 1, values = false, ["healerMode.enable"] = false}},
		{"Current and maximum", {percent = 1, values = 1, ["healerMode.enable"] = false}},
		{"Missing (healer mode)", {percent = 1, ["healerMode.enable"] = 1}},
		{"None", {percent = false, values = false, ["healerMode.enable"] = false}, {percent = false}},
	},
})
check("raid.shown.absorbs", "Absorbs", "Show the absorb bar.", {path = "raid.absorbs"})
check("raid.shown.healprediction", "Heal prediction", "Show the heal prediction bar.", {path = "raid.healprediction"})
check("raid.shown.role", "Role icons", "Show the role icons of the raid players.", {path = "raid.role"})
check("raid.shown.mana", "Mana bar", "Show the mana bars of the raid players.", {path = "raid.mana"})
check("raid.shown.manapercent", "Mana percent", "Show the mana percentage on the mana bars.", {path = "raid.manaPercent"})
check("raid.shown.precision", "Precision percentages", "Show health percentages with an additional decimal digit.", {path = "raid.precisionPercent"})
check("raid.shown.manaprecision", "Precision mana percentages", "Show mana percentages with an additional decimal digit.", {path = "raid.precisionManaPercent"})

R.section = "Auras"
dropdown("raid.auras.show", "Auras shown", "Show the buffs, the debuffs or both of each raid player, or neither.", {
	base = "raid",
	map = {
		{"None", {["buffs.enable"] = false, ["debuffs.enable"] = false}},
		{"Buffs", {["buffs.enable"] = 1, ["debuffs.enable"] = false}},
		{"Debuffs", {["buffs.enable"] = false, ["debuffs.enable"] = 1}},
		{"Both", {["buffs.enable"] = 1, ["debuffs.enable"] = 1}},
	},
})
dropdown("raid.auras.castable", "Aura filter", "Limit the buff and debuff display to the ones you can cast or cure.", {
	base = "raid",
	map = {
		{"All", {["buffs.castable"] = false, ["debuffs.curable"] = false}, {["buffs.castable"] = {0, false}}},
		{"Castable or curable only", {["buffs.castable"] = 1, ["debuffs.curable"] = 1}},
	},
})
slider("raid.auras.aurasize", "Aura size", "The size of the buff and debuff icons together.", {path = "raid.buffs.size", with = {"raid.debuffs.size"}, min = 5, max = 20, step = 1, apply = {"raid"}})
check("raid.auras.text", "Duration text", "Show the time left on the raid aura icons, as the General duration text setting says. Off by default: the text does not fit the raid frame.", {path = "raid.auraText", on = true, off = false})
auraLayout("raid.auras.", "raid", {"raid"})

R.section = "Raid"
check("raid.raid.enable", "Show raid frames", "Show the raid frames. Blizzard's own raid frames are hidden while this is on, after a reload.", {reload = true, get = FPerl.SettingsGetRaid, set = FPerl.SettingsSetRaid, keys = {"raid.enable"}})
check("raid.raid.titles", "Group titles", "Show the titles of the raid groups.", {path = "raid.titles"})
check("raid.raid.notinbg", "Hide in battlegrounds", "Do not show the raid frames in a battleground.", {path = "raid.notInBG"})

R.section = "Groups"
-- the class columns and the groups 9-12 of Sort by Class are saved with the sort
local RAID_SORT_KEYS = {}
for i = 9, 12 do RAID_SORT_KEYS[#RAID_SORT_KEYS + 1] = "raid.group." .. i end
for i = 1, 9 do
	RAID_SORT_KEYS[#RAID_SORT_KEYS + 1] = "raid.class." .. i .. ".enable"
	RAID_SORT_KEYS[#RAID_SORT_KEYS + 1] = "raid.class." .. i .. ".name"
end
for i = 1, 8 do
	check("raid.groups." .. i, "Group " .. i, "Show raid group " .. i .. ".", {get = FPerl["SettingsGetRaidGroup" .. i], set = FPerl["SettingsSetRaidGroup" .. i], keys = {"raid.group." .. i}})
end
button("raid.groups.all", "All groups", "Show every raid group.", {func = FPerl.SettingsRaidGroupsAll})
button("raid.groups.none", "No groups", "Hide every raid group.", {func = FPerl.SettingsRaidGroupsNone})
dropdown("raid.groups.sort", "Sort", "Order the raid frames by group, by class (in the game's class order) or by role.", {
	base = "raid", keys = RAID_SORT_KEYS,
	map = {
		{"Group", {sortByClass = false, sortByRole = false}},
		{"Class", {sortByClass = 1, sortByRole = false}},
		{"Role", {sortByRole = 1, sortByClass = false}, {sortByRole = 1}},
	},
})
check("raid.groups.alpha", "Alphabetical", "Sort the players of each raid group by name.", {path = "raid.sortAlpha"})

R.section = "Layout"
dropdown("raid.layout.anchor", "Anchor", "The direction the raid groups grow from their titles.", {
	path = "raid.anchor",
	options = {{"TOP", "Top"}, {"LEFT", "Left"}, {"BOTTOM", "Bottom"}, {"RIGHT", "Right"}},
})
slider("raid.layout.gap", "Gap", "The gap in pixels between neighbouring raid groups in a row, or in a column for the Left and Right anchors. Moves the groups.", {path = "raid.gap", min = 0, max = 100, step = 1})
slider("raid.layout.spacing", "Spacing", "The spacing between the raid frames of a group.", {path = "raid.spacing", min = -5, max = 20, step = 1, throttle = true}) -- setting the raid header attributes takes longer than a frame

R.section = "Raid pets"
check("raid.pets.enable", "Show raid pets", "Show the pets of the raid members.", {path = "raidpet.enable"})
check("raid.pets.align", "Align to raid", "Align the pet frames to the last raid frame. Changes only out of combat.", {path = "raidpet.alignToRaid"})

R.section = "Buff helper"
check("raid.helper.enable", "Buff helper in tooltips", "Show the buffs and debuffs a raid or party member has and lacks in their tooltip.", {path = "buffHelper.enable"})
dropdown("raid.helper.sort", "Sort", "How the buff helper sorts the players: not at all, by group or by class.", {
	path = "buffHelper.sort",
	options = {{false, "No sort"}, {"group", "Group"}, {"class", "Class"}},
})
check("raid.helper.visible", "Shown groups only", "The buff helper lists only the players of the raid groups that are shown.", {path = "buffHelper.visible"})

R.section = "Custom highlights"
check("raid.custom.enable", "Custom highlights", "Show icons on the raid frames for debuffs in the current zone's list. The list is not editable here.", {path = "custom.enable"})
slider("raid.custom.alpha", "Alpha", "The opacity of the custom highlight icons.", {path = "custom.alpha", min = 0, max = 1, step = 0.05, percent = true, default = 0.5})
dropdown("raid.custom.blend", "Blend", "How the custom highlight icons blend with the frame: Add brightens, Blend overlays normally.", {
	path = "custom.blend",
	options = {{"ADD", "Add"}, {"BLEND", "Blend"}},
})

-- Shared controls: resolve `each` (the per-frame entries are defined by now). A dropdown's options are the union of
-- its frames' choice labels, in frame order (renamed back by `alias`); a slider spans its frames' ranges; `apply` is the
-- union of the frames' appliers.
do
	local byId = {}
	for _, e in ipairs(list) do byId[e.id] = e end
	local function choices(fe)
		local out = {}
		if (fe.map) then
			for i, m in ipairs(fe.map) do out[i] = m[1] end
		elseif (type(fe.options) == "table") then
			for i, o in ipairs(fe.options) do out[i] = o[2] end
		end
		return out
	end
	for _, e in ipairs(list) do
		if (e.each) then
			local seen, apply = {}, {}
			if (e.type == "dropdown") then e.options = {} end
			for _, fl in ipairs(FRAMES) do
				local fe = byId[e.each[fl]]
				if (fe) then
					for _, n in ipairs(fe.apply) do
						if (not seen[n]) then
							seen[n] = true
							apply[#apply + 1] = n
						end
					end
					if (e.type == "dropdown") then
						for _, c in ipairs(choices(fe)) do
							for s, f in pairs(e.alias and e.alias[fl] or {}) do if (f == c) then c = s end end
							local have
							for _, o in ipairs(e.options) do have = have or o[2] == c end
							if (not have) then e.options[#e.options + 1] = {c, c} end
						end
					elseif (e.type == "slider") then
						e.min = math.min(e.min or fe.min, fe.min)
						e.max = math.max(e.max or fe.max, fe.max)
						e.step = e.step or fe.step
						e.zero = e.zero or fe.zero
						if (e.percent == nil) then e.percent = fe.percent end
					end
				end
			end
			e.apply = apply
			if (e.type == "slider") then e.throttle = throttleOf(apply) end
		end
	end
end

-- Fields for the own options window (format: the header of FPerl_SettingsList.lua): `basic` rows, the `inline` group of the
-- raid group checks, and `needs`. A misspelled id is an error at load.
do
	local byId = {}
	for _, e in ipairs(list) do byId[e.id] = e end
	local function row(id) return byId[id] or error("settings list: no row " .. id) end
	local function need(id, ...)
		local e = row(id)
		local n = e.needs
		if (n == nil) then n = {} elseif (type(n) == "string" or n.key) then n = {n} end
		for _, c in ipairs({...}) do n[#n + 1] = c end
		e.needs = #n == 1 and n[1] or n
	end
	for _, id in ipairs({
		"general.frames.arrange", "general.layouts.active", "general.profiles.reset", "general.look.bartexture", "general.look.transparency",
		"general.colours.classbars", "general.colours.classnames", "general.highlights.debuff", "general.range.enable", "general.tooltips.unit",
		"general.auras.cooldown", "general.auras.countdown", "general.misc.minimap",
		"player.size.enable", "player.size.scale", "player.shown.portrait", "player.shown.healthtext", "player.shown.castbar", "player.auras.buffs", "player.auras.debuffs", "player.auras.enchants",
		"player.auras.aurasize", "player.player.xp", "player.player.rep",
		"pet.size.enable", "pet.size.scale", "pet.shown.portrait", "pet.shown.healthtext", "pet.shown.castbar", "pet.auras.buffs", "pet.auras.debuffs",
		"pet.auras.aurasize", "pet.pet.happiness", "pet.pettarget.enable",
		"target.size.enable", "target.size.scale", "target.shown.portrait", "target.shown.healthtext", "target.shown.castbar", "target.auras.buffs",
		"target.auras.debuffs", "target.auras.aurasize", "target.auras.onlymybuffs", "target.auras.onlymydebuffs", "target.target.combo", "target.tot.enable",
		"focus.focus.enable", "focus.size.scale", "focus.shown.portrait", "focus.shown.healthtext", "focus.shown.castbar", "focus.auras.buffs",
		"focus.auras.debuffs", "focus.auras.aurasize", "focus.auras.onlymybuffs", "focus.auras.onlymydebuffs", "focus.focustarget.enable",
		"party.size.enable", "party.size.scale", "party.shown.portrait", "party.shown.healthtext", "party.shown.castbar", "party.auras.buffs",
		"party.auras.debuffs", "party.auras.aurasize", "party.party.showplayer", "party.pets.enable", "party.party.targets",
		"party.visibility.inparty", "party.visibility.insmallraid",
		"raid.raid.enable", "raid.size.scale", "raid.shown.healthtext", "raid.auras.show", "raid.auras.aurasize", "raid.groups.sort", "raid.shown.role",
	}) do row(id).basic = true end
	for i = 1, 8 do
		local e = row("raid.groups." .. i)
		e.basic, e.inline = true, "groups"
	end

	-- every row of a frame needs that frame switched on (the switch row itself excepted)
	local function switchOf(e)
		local pg, sec = e.page, e.section
		if (pg == "Player") then return "player.enable"
		elseif (pg == "Pet") then return sec == "Pet's target" and "pettarget.enable" or "pet.enable"
		elseif (pg == "Target") then
			return sec == "Target of target" and "targettarget.enable" or sec == "Target of target of target" and "targettargettarget.enable" or "target.enable"
		elseif (pg == "Focus") then return sec == "Focus target" and "focustarget.enable" or "focus.enable"
		elseif (pg == "Party") then
			if (sec:find("^Visibility")) then return nil end
			return sec == "Party pets" and "partypet.enable" or "party.enable"
		elseif (pg == "Raid") then
			if (sec == "Buff helper" or sec == "Custom highlights") then return nil end
			return sec == "Raid pets" and "raidpet.enable" or "raid.enable"
		end
	end
	for _, e in ipairs(list) do
		local key = switchOf(e)
		if (key and e.type ~= "frames" and e.path ~= key and not (e.keys and e.keys[1] == key)) then need(e.id, key) end
	end

	-- aura rows: the matching Buffs or Debuffs switch (a pet's target and the party pets switch both with Buffs); icons per line and Rows need Wrap
	local AURAS = {
		{"player.auras.", "player"}, {"pet.auras.", "pet"}, {"pet.pettarget.", "pettarget"}, {"target.auras.", "target"},
		{"target.tot.", "targettarget"}, {"target.tott.", "targettargettarget"}, {"focus.auras.", "focus"},
		{"focus.focustarget.", "focustarget"}, {"party.auras.", "party"}, {"party.pets.", "partypet"}, {"raid.auras.", "raid"},
	}
	for _, f in ipairs(AURAS) do
		local pre, k = f[1], f[2]
		local buffs = k .. ".buffs.enable"
		local debuffs = (k == "partypet") and buffs or k .. ".debuffs.enable"
		local wrap = k .. ".buffs.wrap"
		local function on(suffixes, key)
			for _, sfx in ipairs(suffixes) do if (byId[pre .. sfx]) then need(pre .. sfx, key) end end
		end
		on({"buffside", "buffreverse", "buffsize", "bigbuffs", "bigstealable", "onlymybuffs", "onlymine", "big"}, buffs)
		on({"debuffside", "debuffreverse", "debuffsize", "bigdebuffs", "onlymydebuffs", "halfsize"}, debuffs)
		if (k ~= "raid") then on({"castable"}, buffs) end
		on({"curable"}, debuffs)
		on({"buffperline"}, buffs)
		on({"debuffperline"}, debuffs)
		if (byId[pre .. "wrap"] or k == "raid") then on({"buffperline", "debuffperline", "rows"}, wrap) end
	end

	need("general.look.fadetime", "bar.fading")
	for _, id in ipairs({"gradientstart", "gradientstart.alpha", "gradientend", "gradientend.alpha"}) do need("general.look." .. id, "colour.gradient.enable") end
	need("general.colours.brightness", "colour.classbar")
	for _, id in ipairs({"debuff", "curable", "aggro", "aggrowarning", "target", "heal", "hots", "shields", "hotcount", "sparkles"}) do need("general.highlights." .. id, "highlight.enable") end
	need("general.highlights.curable", "highlightDebuffs.enable")
	need("general.range.raidonly", "rangeFinder.enabled")
	for part, key in pairs({main = "Main", name = "NameFrame", bars = "StatsFrame"}) do
		local on = "rangeFinder." .. key .. ".enabled"
		need("general.range." .. part .. ".enable", "rangeFinder.enabled")
		for _, id in ipairs({"fade", "debuff"}) do need("general.range." .. part .. "." .. id, "rangeFinder.enabled", on) end
	end
	for _, id in ipairs({"modifier", "hideincombat", "fading"}) do need("general.tooltips." .. id, "tooltip.enable") end
	need("general.auras.cooldownany", "buffs.cooldown")
	need("general.auras.countdownany", "buffs.countdown")
	need("general.auras.blizzardnumbers", "buffs.countdown")
	need("pet.pet.onlysad", "pet.happiness.enable")
	need("pet.pet.flashsad", "pet.happiness.enable")
	need("target.target.classtext", "target.classIcon")
	need("focus.focus.classtext", "focus.classIcon")
	need("party.party.targetsize", "party.target.enable")
	need("party.party.targetlarge", "party.target.enable")
	need("raid.pets.align", "raidpet.enable")
	need("raid.helper.sort", "buffHelper.enable")
	need("raid.helper.visible", "buffHelper.enable")
	need("raid.custom.alpha", "custom.enable")
	need("raid.custom.blend", "custom.enable")
	need("raid.shown.manapercent", "raid.mana")
	need("raid.shown.manaprecision", "raid.mana")
end

-- Canonical order: rows that several frame sections share come first, in this order, in every section of the frame pages
-- (the enable row leads); a section's own rows follow in the order they were added. Listed by label.
do
	local ORDER = {
		"Scale", "Extra width", "Portrait", "Level", "Class icon", "PvP flag", "Hit indicators", "Hit text position", "Health text",
		"Health and mana text", "Absorbs", "Heal prediction", "Cast bar", "Cast time text", "Mana bar", "Debuff highlight",
		"Buffs", "Debuffs", "Buff size", "Debuff size", "Aura size", "Wrap", "Rows", "Buff rows", "Castable only", "Castable buffs only",
		"Curable only", "Curable debuffs only", "Only my buffs", "Only my debuffs", "Big buffs", "Big stealable buffs", "Big debuffs",
	}
	local rank = {}
	for i, l in ipairs(ORDER) do rank[l] = i + 1 end
	local function rankOf(e) return e.id:find("%.enable$") and 1 or rank[e.label] or 1000 end
	local bySec = {}
	for i, e in ipairs(list) do
		if (e.page ~= "General") then
			local k = e.page .. "|" .. e.section
			bySec[k] = bySec[k] or {}
			local t = bySec[k]
			t[#t + 1] = {e = e, i = i}
		end
	end
	local out = {}
	local done = {}
	for i, e in ipairs(list) do
		if (e.page == "General") then
			out[#out + 1] = e
		else
			local k = e.page .. "|" .. e.section
			if (not done[k]) then
				done[k] = true
				local t = bySec[k]
				table.sort(t, function(a, b)
					local ra, rb = rankOf(a.e), rankOf(b.e)
					if (ra ~= rb) then return ra < rb end
					return a.i < b.i
				end)
				for _, x in ipairs(t) do out[#out + 1] = x.e end
			end
		end
	end
	for i = 1, #list do list[i] = out[i] end
end

FPerl.SettingsList = list
