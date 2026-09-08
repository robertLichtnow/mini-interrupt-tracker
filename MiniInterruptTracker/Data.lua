local ADDON_NAME, ns = ...

-- Per-spec interrupt data. Specs with no reliable baseline interrupt
-- (Holy/Discipline Priest, Restoration Druid, Mistweaver Monk) are
-- intentionally omitted -- their members are dropped from the bars entirely.
--
-- role is one of "tank" | "melee" | "ranged" (healers bucket into "ranged"
-- for sort-tiebreak purposes, matching the 3-bucket priority order used).
--
-- `interrupts` is a list because a spec can have more than one trackable
-- interrupt ability -- each entry becomes its own bar for that character.
-- Per-interrupt fields:
--   spellID  -- the ability's spell ID.
--   cooldown -- current-patch baseline cooldown in seconds; may need
--               adjustment if Blizzard retunes it. This table is the
--               single place to update.
--   viaPet   -- true if the ability is cast by the player's pet rather
--               than the player (detection watches the "pet" unit too).
ns.specData = {
	-- Warrior
	[71] = { class = "WARRIOR", spec = "Arms", role = "melee", interrupts = {
		{ spellID = 6552, cooldown = 15 },
	}},
	[72] = { class = "WARRIOR", spec = "Fury", role = "melee", interrupts = {
		{ spellID = 6552, cooldown = 15 },
	}},
	[73] = { class = "WARRIOR", spec = "Protection", role = "tank", interrupts = {
		{ spellID = 6552, cooldown = 15 },
	}},

	-- Paladin
	[65] = { class = "PALADIN", spec = "Holy", role = "ranged", interrupts = {
		{ spellID = 96231, cooldown = 15 },
	}},
	[66] = { class = "PALADIN", spec = "Protection", role = "tank", interrupts = {
		{ spellID = 96231, cooldown = 15 },
	}},
	[70] = { class = "PALADIN", spec = "Retribution", role = "melee", interrupts = {
		{ spellID = 96231, cooldown = 15 },
	}},

	-- Hunter
	[253] = { class = "HUNTER", spec = "Beast Mastery", role = "ranged", interrupts = {
		{ spellID = 147362, cooldown = 24 },
	}},
	[254] = { class = "HUNTER", spec = "Marksmanship", role = "ranged", interrupts = {
		{ spellID = 147362, cooldown = 24 },
	}},
	[255] = { class = "HUNTER", spec = "Survival", role = "melee", interrupts = {
		{ spellID = 187707, cooldown = 15 },
	}},

	-- Rogue
	[259] = { class = "ROGUE", spec = "Assassination", role = "melee", interrupts = {
		{ spellID = 1766, cooldown = 15 },
	}},
	[260] = { class = "ROGUE", spec = "Outlaw", role = "melee", interrupts = {
		{ spellID = 1766, cooldown = 15 },
	}},
	[261] = { class = "ROGUE", spec = "Subtlety", role = "melee", interrupts = {
		{ spellID = 1766, cooldown = 15 },
	}},

	-- Priest (Shadow only -- Silence)
	[258] = { class = "PRIEST", spec = "Shadow", role = "ranged", interrupts = {
		{ spellID = 15487, cooldown = 45 },
	}},

	-- Death Knight
	[250] = { class = "DEATHKNIGHT", spec = "Blood", role = "tank", interrupts = {
		{ spellID = 47528, cooldown = 15 },
	}},
	[251] = { class = "DEATHKNIGHT", spec = "Frost", role = "melee", interrupts = {
		{ spellID = 47528, cooldown = 15 },
	}},
	[252] = { class = "DEATHKNIGHT", spec = "Unholy", role = "melee", interrupts = {
		{ spellID = 47528, cooldown = 15 },
	}},

	-- Shaman
	[262] = { class = "SHAMAN", spec = "Elemental", role = "ranged", interrupts = {
		{ spellID = 57994, cooldown = 12 },
	}},
	[263] = { class = "SHAMAN", spec = "Enhancement", role = "melee", interrupts = {
		{ spellID = 57994, cooldown = 12 },
	}},
	[264] = { class = "SHAMAN", spec = "Restoration", role = "ranged", interrupts = {
		{ spellID = 57994, cooldown = 12 },
	}},

	-- Mage
	[62] = { class = "MAGE", spec = "Arcane", role = "ranged", interrupts = {
		{ spellID = 2139, cooldown = 24 },
	}},
	[63] = { class = "MAGE", spec = "Fire", role = "ranged", interrupts = {
		{ spellID = 2139, cooldown = 24 },
	}},
	[64] = { class = "MAGE", spec = "Frost", role = "ranged", interrupts = {
		{ spellID = 2139, cooldown = 24 },
	}},

	-- Warlock (interrupt is cast by the pet)
	[265] = { class = "WARLOCK", spec = "Affliction", role = "ranged", interrupts = {
		{ spellID = 19647, cooldown = 24, viaPet = true },
	}},
	[266] = { class = "WARLOCK", spec = "Demonology", role = "ranged", interrupts = {
		{ spellID = 119910, cooldown = 30, viaPet = true },
	}},
	[267] = { class = "WARLOCK", spec = "Destruction", role = "ranged", interrupts = {
		{ spellID = 19647, cooldown = 24, viaPet = true },
	}},

	-- Monk
	[268] = { class = "MONK", spec = "Brewmaster", role = "tank", interrupts = {
		{ spellID = 116705, cooldown = 15 },
	}},
	[269] = { class = "MONK", spec = "Windwalker", role = "melee", interrupts = {
		{ spellID = 116705, cooldown = 15 },
	}},

	-- Druid
	[102] = { class = "DRUID", spec = "Balance", role = "ranged", interrupts = {
		{ spellID = 78675, cooldown = 60 },
	}},
	[103] = { class = "DRUID", spec = "Feral", role = "melee", interrupts = {
		{ spellID = 106839, cooldown = 15 },
	}},
	[104] = { class = "DRUID", spec = "Guardian", role = "tank", interrupts = {
		{ spellID = 106839, cooldown = 15 },
	}},

	-- Demon Hunter
	[577] = { class = "DEMONHUNTER", spec = "Havoc", role = "melee", interrupts = {
		{ spellID = 183752, cooldown = 15 },
	}},
	[581] = { class = "DEMONHUNTER", spec = "Vengeance", role = "tank", interrupts = {
		{ spellID = 183752, cooldown = 15 },
	}},

	-- Evoker
	[1467] = { class = "EVOKER", spec = "Devastation", role = "ranged", interrupts = {
		{ spellID = 351338, cooldown = 20 },
	}},
	[1468] = { class = "EVOKER", spec = "Preservation", role = "ranged", interrupts = {
		{ spellID = 351338, cooldown = 20 },
	}},
	[1473] = { class = "EVOKER", spec = "Augmentation", role = "ranged", interrupts = {
		{ spellID = 351338, cooldown = 20 },
	}},
}

local ROLE_PRIORITY = { tank = 1, melee = 2, ranged = 3 }
ns.ROLE_PRIORITY = ROLE_PRIORITY

-- Reverse lookup: spellID -> cooldown, so an incoming KICK message (or a
-- locally observed cast) can be resolved to a duration/icon without needing
-- to know the caster's spec.
ns.spellIDToCooldown = {}
for _, data in pairs(ns.specData) do
	for _, interrupt in ipairs(data.interrupts) do
		ns.spellIDToCooldown[interrupt.spellID] = interrupt.cooldown
	end
end
