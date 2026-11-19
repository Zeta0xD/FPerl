-- Author: Resike
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

-- F-Perl 0.x saved-variable names, by the addon whose toc declares them: an upgrade from 0.x moves each to its new name.
-- The tocs declare both names, so the client still loads a 0.x file.
local OLD = {
	FPerl = {FPerlDB = "ZPerlConfigNew", FPerlPerCharacter = "ZPerlConfigSavePerCharacter", FPerlRoster = "ZPerl_Roster"},
	FPerl_RaidAdmin = {FPerlRaidAdminDB = "ZPerl_Admin", FPerlRaidAdminItems = "ZPerl_CheckItems"},
	FPerl_RaidHelper = {FPerlRaidHelperDB = "ZPerlConfigHelper", FPerlRaidHelperTanks = "ZPerl_MainTanks"},
	FPerl_RaidMonitor = {FPerlRaidMonitorDB = "ZPerlRaidMonConfig"},
}

-- FPerl.MigrateSavedNames(addon)
-- Moves the 0.x names of one addon's saved variables to the new names. The old name wins: it holds data only before the
-- first migrated logout, or after a rollback to a 0.x build (which writes the old names and drops the new ones), and in
-- both cases it is the newest. One assignment per name, so nothing is lost if a later step errors, and idempotent: the old
-- name is nil afterwards, so a table emptied in play is not refilled. The core's ADDON_LOADED handler calls it for every
-- FPerl addon before anything reads the data; each raid tool's startup calls it too, so none depends on handler order.
function FPerl.MigrateSavedNames(addon)
	for new, old in pairs(OLD[addon] or {}) do
		if (_G[old] ~= nil) then
			_G[new], _G[old] = _G[old], nil
		end
	end
end

-- FPerl.MigrateConfig()
-- Once, at login. Schema 2 stores an unticked checkbox option as false instead of nil: every stored
-- profile (global, and realm/player) gets false for each listed key that is nil. Schema 3 replaces
-- buffs.above and debuffs.below with the aura side keys. Schema 4 moves the raid frames onto the aura side
-- keys. Runs before anything that could backfill a key. Schema 5 (layouts) is FPerl.MigrateLayouts.
function FPerl.MigrateConfig()
	local schema = FPerlDB.schema
	-- Schema 3: buffs.above becomes the side of both kinds (set: TOP, false: BOTTOM, nil: no side); party
	-- debuffs.below off puts the debuffs on the RIGHT. buffs.above and debuffs.below are deleted.
	local function migrateAuraSides(profile)
		for _, sec in pairs(profile) do
			if (type(sec) == "table") then
				local b, d = sec.buffs, sec.debuffs
				local above = type(b) == "table" and b.above
				local hasAbove = type(b) == "table" and b.above ~= nil
				if (hasAbove) then
					local side = above and "TOP" or "BOTTOM"
					b.side = side
					if (type(d) ~= "table") then
						d = {}
						sec.debuffs = d
					end
					d.side = side
					b.above = nil
				end
				if (type(d) == "table" and d.below ~= nil) then
					if (d.below == false) then
						d.side = "RIGHT"
					end
					d.below = nil
				end
			end
		end
	end
	-- Schema 4: raid.buffs.right (absent = the old default, on) becomes the side of both kinds; castable
	-- covers the debuffs too (debuffs.curable); buffs on wins over debuffs, as the old raid frames showed one
	-- kind. buffs.right, buffs.inside and buffs.untilDebuffed are deleted.
	local function migrateRaidAuras(profile)
		local r = profile.raid
		if (type(r) ~= "table") then
			return
		end
		if (type(r.buffs) ~= "table") then
			r.buffs = {}
		end
		if (type(r.debuffs) ~= "table") then
			r.debuffs = {}
		end
		local b, d = r.buffs, r.debuffs
		if (b.side ~= nil) then
			return
		end
		local side = (b.right == nil or b.right) and "RIGHT" or "BOTTOM"
		b.side, d.side = side, side
		if (b.castable == 1) then
			d.curable = 1
		end
		if (b.enable) then
			d.enable = false
		end
		b.right, b.inside, b.untilDebuffed = nil, nil, nil
	end
	if (schema and schema >= 4) then
		return
	end
	local UNTICKED_SIDES = {{"player", "buffs", "above"}, {"pet", "buffs", "above"}, {"target", "buffs", "above"},
		{"focus", "buffs", "above"}, {"targettarget", "buffs", "above"}, {"focustarget", "buffs", "above"},
		{"pettarget", "buffs", "above"}, {"party", "debuffs", "below"},
		{"raid", "buffs", "right"}, {"raid", "buffs", "inside"}, {"raid", "buffs", "untilDebuffed"}}
	for name, value in pairs(FPerlDB) do
		if (type(value) == "table" and name ~= "savedPositions") then
			local profiles = (name == "global") and {value} or value
			for _, profile in pairs(profiles) do
				if (type(profile) == "table") then
					if (schema ~= 2 and schema ~= 3) then
						FPerl.SetUntickedKeys(profile)
						-- the keys schema 3 took off that list: before schema 2 a nil there was unticked too
						for _, u in ipairs(UNTICKED_SIDES) do
							local t = type(profile[u[1]]) == "table" and profile[u[1]][u[2]]
							if (type(t) == "table" and t[u[3]] == nil and t.side == nil) then
								t[u[3]] = false
							end
						end
					end
					if (schema ~= 3) then
						migrateAuraSides(profile)
					end
					migrateRaidAuras(profile)
				end
			end
		end
	end
	FPerlDB.schema = 4
end


-- FPerl.MigrateLayouts()
-- Schema 5, once, after FPerl.MigrateConfig: the profiles become named layouts.
-- The old top-level tables move into FPerlDB.schema4. Each character with a profile or a saved
-- position table gets a layout "Name - Realm" (its profile, else the global one, else the defaults, plus its
-- positions) and starts on it (migrated["Realm / Name"]); the global profile becomes Default, without
-- positions; each old positions-only layout gets the global settings.
function FPerl.MigrateLayouts()
	local s = FPerlDB
	if (s.schema and s.schema >= 5) then
		return
	end
	-- Everything is built into locals first; the store changes in the last block only, which cannot raise.
	-- The schema 5 keys are not swept: a rollback to an older build and a second upgrade leaves them behind.
	local KEEP = {layouts = true, active = true, migrated = true, schema4 = true, account = true}
	local old = {}
	for k, v in pairs(s) do
		if (type(v) == "table" and not KEEP[k]) then
			old[k] = v
		end
	end

	local function settings(own)
		local p = type(own) == "table" and own or old.global
		if (type(p) == "table") then
			return FPerl.CopyTable(p)
		end
		local d = {}
		FPerl.Defaults(d)
		return d
	end
	local function with(profile, positions)
		profile.positions = positions and FPerl.CopyTable(positions) or nil
		return profile
	end

	local chars = {}
	for realm, list in pairs(old) do
		if (realm ~= "global" and realm ~= "savedPositions") then
			for player, profile in pairs(list) do
				if (type(profile) == "table") then
					chars[tostring(realm) .. " / " .. tostring(player)] = {realm = tostring(realm), player = tostring(player), profile = profile}
				end
			end
		end
	end
	local positions = type(old.savedPositions) == "table" and old.savedPositions or {}
	for realm, list in pairs(positions) do
		if (realm ~= "saved" and type(list) == "table") then
			for player, pos in pairs(list) do
				if (type(pos) == "table") then
					local key = tostring(realm) .. " / " .. tostring(player)
					local c = chars[key]
					if (not c) then
						c = {realm = tostring(realm), player = tostring(player)}
						chars[key] = c
					end
					c.positions = pos
				end
			end
		end
	end

	-- Layouts left by a rollback stay; the migrated ones take the names that are free.
	local keep = type(s.layouts) == "table" and s.layouts or nil
	local added, migrated, taken = {}, {}, {}
	for name in pairs(keep or {}) do
		taken[tostring(name):lower()] = true
	end
	local function add(name, layout)
		while (taken[name:lower()]) do
			name = name .. " (old layout)"
		end
		taken[name:lower()] = true
		added[name] = layout
		return name
	end
	for key, c in pairs(chars) do
		migrated[key] = add(c.player .. " - " .. c.realm, with(settings(c.profile), c.positions))
	end
	add("Default", settings())
	if (type(positions.saved) == "table") then
		for name, pos in pairs(positions.saved) do
			if (type(pos) == "table") then
				add(tostring(name), with(settings(), pos))
			end
		end
	end

	local layouts = keep or {}
	local pending = type(s.migrated) == "table" and s.migrated or {}
	for k, v in pairs(migrated) do
		pending[k] = v
	end
	for k, v in pairs(added) do
		layouts[k] = v
	end
	for k in pairs(old) do
		s[k] = nil
	end
	-- after a rollback the first backup (the store before any schema 5) stays; the swept tables live on as layouts
	s.layouts, s.migrated = layouts, pending
	s.schema4 = type(s.schema4) == "table" and s.schema4 or old
	s.active = type(s.active) == "table" and s.active or {}
	s.schema = 5
end

-- FPerl.MigrateDeadKeys()
-- Schema 6, once, after FPerl.MigrateLayouts: deletes from every layout the keys nothing reads (those of the
-- options window F-Perl 0.x ported from Z-Perl's options addon, and options no code reads), and that window's frame
-- position. schema4 is left alone.
function FPerl.MigrateDeadKeys()
	local s = FPerlDB
	if ((s.schema and s.schema >= 6) or type(s.layouts) ~= "table") then
		return
	end
	local DEAD = {
		"optionsColour", "player.fullScreen.lowHP", "player.fullScreen.highHP",
		"focus.combo", "focus.comboindicator",
		"party.castBar.castTime", "pettarget.absorbs", "pettarget.healprediction",
		"player.buffs.cooldown", "player.threat", "player.threatMode", "raid.healerMode.type",
		"positions.XPerl_OptionsAnchor",
		"highlight.TARGET", "target.defer", "target.showTalents", "target.talentsAsText", "target.combo.pos",
		"buffs.ignoreSeasonal", "buffs.names",
		"focus.buffs.bigpet", "focustarget.buffs.bigpet", "party.buffs.bigpet", "pet.buffs.bigpet",
		"pettarget.buffs.bigpet", "target.buffs.bigpet", "targettarget.buffs.bigpet",
	}
	for _, layout in pairs(s.layouts) do
		for _, path in ipairs(DEAD) do
			local t, parts = layout, {}
			for part in path:gmatch("[^.]+") do
				parts[#parts + 1] = part
			end
			for i = 1, #parts - 1 do
				t = type(t) == "table" and t[parts[i]] or nil
			end
			if (type(t) == "table") then
				t[parts[#parts]] = nil
			end
		end
	end
	s.schema = 6
end

-- FPerl.MigrateEngineNames()
-- Schema 7, once, after FPerl.MigrateDeadKeys: the frame names the
-- stored positions are keyed by, the old role icons key and the bar texture path in every layout take the
-- F-Perl names. The texture path also loses the upstream folder names (ZPerl, XPerlForever). schema4 is a
-- backup nothing reads and is left alone.
function FPerl.MigrateEngineNames()
	local s = FPerlDB
	if ((s.schema and s.schema >= 7) or type(s.layouts) ~= "table") then
		return
	end
	local function frame(name)
		if (type(name) ~= "string") then
			return name
		end
		name = name:gsub("^[XZ]Perl_", "FPerl_")
		return (name:gsub("^[XZ]Perl(%u)", "FPerl_%1"))
	end
	local function path(texture)
		if (type(texture) ~= "string") then
			return texture
		end
		texture = texture:gsub("Interface\\Add[oO]ns\\ZPerl", "Interface\\AddOns\\FPerl")
		texture = texture:gsub("Interface\\Add[oO]ns\\XPerlForever", "Interface\\AddOns\\FPerl")
		return (texture:gsub("Images\\[XZ]Perl_", "Images\\FPerl_"))
	end
	for _, layout in pairs(s.layouts) do
		if (type(layout) == "table") then
			local positions = layout.positions
			if (type(positions) == "table") then
				-- collected first: keys are not added while the table is traversed
				local renamed = {}
				for k, v in pairs(positions) do
					local new = frame(k)
					if (new ~= k) then
						renamed[#renamed + 1] = {k, new, v}
					end
				end
				for _, r in ipairs(renamed) do
					positions[r[1]] = nil
					if (positions[r[2]] == nil) then
						positions[r[2]] = r[3]
					end
				end
			end
			if (layout.xperlOldroleicons ~= nil) then
				if (layout.oldRoleIcons == nil) then
					layout.oldRoleIcons = layout.xperlOldroleicons
				end
				layout.xperlOldroleicons = nil
			end
			local texture = type(layout.bar) == "table" and layout.bar.texture
			if (type(texture) == "table") then
				texture[2] = path(texture[2])
			end
		end
	end
	s.schema = 7
end

------------------------------------------------------------------------------------------------ restore at load
-- A development build snapshots FPerlDB in FPerlDB.devRestore (tag, time, digest, data)
-- and restores it when its run ends. A run cut off leaves the snapshot in the file; FPerl.RestoreAtLoad puts the
-- settings back at the next login, in every build.
local RESTORE_MAX_AGE = 24 * 3600 -- an older snapshot is dropped, not restored
local restoreNotice

-- FPerl.RestoreInto(live, from)
-- Puts the contents of from into live without replacing any table both hold: keys absent from from are deleted, tables
-- recurse, other values (and tables live lacks, copied) are assigned.
function FPerl.RestoreInto(live, from)
	for k in pairs(live) do
		if (from[k] == nil) then
			live[k] = nil
		end
	end
	for k, v in pairs(from) do
		local lv = live[k]
		if (type(v) == "table") then
			if (type(lv) == "table") then
				FPerl.RestoreInto(lv, v)
			else
				live[k] = FPerl.CopyTable(v)
			end
		else
			live[k] = v
		end
	end
end

local function canon(v, out)
	local t = type(v)
	if (t == "table") then
		local keys = {}
		for k in pairs(v) do
			keys[#keys + 1] = k
		end
		table.sort(keys, function(a, b) return type(a) .. tostring(a) < type(b) .. tostring(b) end)
		out[#out + 1] = "{"
		for _, k in ipairs(keys) do
			canon(k, out)
			out[#out + 1] = "="
			canon(v[k], out)
			out[#out + 1] = ";"
		end
		out[#out + 1] = "}"
	elseif (t == "number") then
		out[#out + 1] = string.format("%.6f", v)
	elseif (t == "string") then
		out[#out + 1] = string.format("%q", v)
	elseif (t == "boolean") then
		out[#out + 1] = tostring(v)
	else
		out[#out + 1] = "<" .. t .. ">"
	end
end

-- FPerl.DigestOf(t)
-- A short checksum of a table's contents, "<hash>-<length>", and the canonical string it is taken from.
function FPerl.DigestOf(t)
	local out = {}
	canon(t, out)
	local s = table.concat(out)
	local h, byte = 5381, string.byte
	for i = 1, #s do
		h = (h * 33 + byte(s, i)) % 4294967296
	end
	return string.format("%08x-%d", h, #s), s
end

-- FPerl.RestoreAtLoad()
-- Called for "FPerl" at ADDON_LOADED, before the settings are read. A snapshot is restored only when its data matches
-- its digest and it is under 24 h old; anything else is dropped and the live settings stay. Either way the player gets
-- one line, and FPerl.restoredAtLoad is the tag on a restore, "dropped: <reason>" on a drop, nil with no snapshot.
function FPerl.RestoreAtLoad()
	local snap = type(FPerlDB) == "table" and FPerlDB.devRestore
	if (not snap) then
		return
	end
	local tag, when, why = "?", "unknown date", nil
	if (type(snap) ~= "table") then
		why = "not a table"
	else
		if (snap.tag ~= nil) then
			tag = tostring(snap.tag)
		end
		if (type(snap.time) == "number") then
			local ok, d = pcall(date, "%Y-%m-%d", snap.time)
			when = ok and d or when
		end
		if (type(snap.data) ~= "table") then
			why = "data is not a table"
		elseif (type(snap.time) ~= "number") then
			why = "no time"
		elseif (type(snap.digest) ~= "string") then
			why = "no digest"
		elseif (time() - snap.time > RESTORE_MAX_AGE) then
			why = "older than 24 h"
		elseif ((FPerl.DigestOf(snap.data)) ~= snap.digest) then
			why = "digest mismatch"
		end
	end
	if (why) then
		FPerlDB.devRestore = nil
		FPerl.restoredAtLoad = "dropped: " .. why
		restoreNotice = string.format("Dropped dev snapshot %s of %s: %s.", tag, when, why)
	else
		FPerl.RestoreInto(FPerlDB, snap.data)
		FPerlDB.devRestore = nil
		FPerl.restoredAtLoad = tag
		restoreNotice = string.format("Restored settings from dev snapshot %s of %s.", tag, when)
	end
	FPerl.PrintRestoreNotice()
end

-- FPerl.PrintRestoreNotice()
-- Prints the restore line once the chat frame exists; PLAYER_LOGIN calls it again for a restore that found none.
function FPerl.PrintRestoreNotice()
	if (restoreNotice and DEFAULT_CHAT_FRAME) then
		FPerl.Notice("%s", restoreNotice)
		restoreNotice = nil
	end
end
