# Changelog

## 1.3.0 (2026-11-20)

- New: in unlock mode, a dragged frame shows a box over all of its art and lines where it will snap; it snaps by its nearest edges.
- New: a Labels toggle in unlock mode names every movable frame. The Raid Admin, Raid Helper and Raid Monitor anchors can be dragged by their labels.
- New: in unlock mode, Target, Focus and their target frames show you, so they can be placed without a target.
- Fixed: the alignment grid in unlock mode is centered on the screen, and frames snap to it.
- Less memory churn while the options window is open.

## 1.2.0 (2026-11-18)

- Raid target marks show on F-Perl's frames.
- Fixed: the Ctrl setting for tooltips now shows the tooltip only while Ctrl is held.
- Focus has its own out-of-range icon option (off by default). Its range icon and hit text follow the Focus options, not the Target options.
- Fixed: the out-of-range icon on the Target frame showed for units in range.
- Fixed: frames could fade as out of range in combat.
- Fixed: Raid > class None turned the classes back on at the next login.
- Fixed: the buff tooltip's list of players without the buff did not refresh.
- Fixed: the unlocked raid box did not fit the layout when sorted by class.
- Fixed: the master looter icon stayed after master loot ended.
- Hidden health percents round to the nearest whole number (99.6 shows 100).
- The pet's target frame no longer takes the aura color highlight.
- Faster layout switches and group changes.
- Raid Helper: fixed sorting of players without a class, the focus target in the assist list, and the `/fphelper` usage line.
- The Aura blacklist's "Show if mine" column is removed; it had no effect.
- The minimap button's tooltip no longer shows memory use (the game's addon list shows it). The minimap menu lists Raid Admin before the Casting Monitor.

## 1.1.0 (2026-11-17)

- New options window with one tab per frame group, basic and advanced options, and search. It replaces F-Perl's pages in the game's settings panel.
- Unlock mode: click a frame to open a popup with its basic options.
- Buffs and debuffs can be moved by dragging in unlock mode, raid frames included, or with the Buff X / Y and Debuff X / Y options.
- Weapon enchants (poisons, oils, sharpening stones) show in the Player frame's buff line. Right-click one to remove it.
- Right-click a buff on the Player frame to remove it.
- Hit indicators show with the portrait off. New option: Hit text position.
- Fixed: hit indicators and the incoming heal glow when the game hides the amounts.

## 1.0.2 (2026-11-15)

- Fixed: druids, shamans, and priests got an error at login that left the Player frame's health percent hidden and caused an error on every hit taken.
- New: General > Highlights > Aggro warning text, the Raid Helper aggro warning as a checkbox.

## 1.0.1 (2026-11-05)

- Fixed: errors when party frames faded out of range (bars and cast bar).
- Fixed: errors when fitting the Player frame's XP text and Raid Helper's main tank names.
- Fixed: errors on damage the game hides the amount of.
- Fixed: the level color on frames now uses the game's difficulty color.

## 1.0.0 (2026-10-19)

- First release.
