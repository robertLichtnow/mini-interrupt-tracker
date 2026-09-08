local ADDON_NAME, ns = ...

-- Per-spec interrupt data. Specs with no reliable baseline interrupt
-- (Holy/Discipline Priest, Restoration Druid, Mistweaver Monk) are
-- intentionally omitted -- their members are dropped from the bars entirely.
--
-- role is one of "tank" | "melee" | "ranged" (healers bucket into "ranged"
-- for sort-tiebreak purposes, matching the 3-bucket priority order used).
--
-- viaPet = true means the ability is cast by the player's pet, not the
-- player, so detection has to watch the "pet" unit's spell casts instead
-- of "player". Cooldowns are current-patch baselines and may need
-- adjustment if Blizzard retunes them -- this table is the single place
-- to update.
ns.specData = {
	-- Warrior
	[71] = { class = "WARRIOR", spec = "Arms", role = "melee", spellID = 6552, cooldown = 15 },
	[72] = { class = "WARRIOR", spec = "Fury", role = "melee", spellID = 6552, cooldown = 15 },
	[73] = { class = "WARRIOR", spec = "Protection", role = "tank", spellID = 6552, cooldown = 15 },

	-- Paladin
	[65] = { class = "PALADIN", spec = "Holy", role = "ranged", spellID = 96231, cooldown = 15 },
	[66] = { class = "PALADIN", spec = "Protection", role = "tank", spellID = 96231, cooldown = 15 },
	[70] = { class = "PALADIN", spec = "Retribution", role = "melee", spellID = 96231, cooldown = 15 },

	-- Hunter
	[253] = { class = "HUNTER", spec = "Beast Mastery", role = "ranged", spellID = 147362, cooldown = 24 },
	[254] = { class = "HUNTER", spec = "Marksmanship", role = "ranged", spellID = 147362, cooldown = 24 },
	[255] = { class = "HUNTER", spec = "Survival", role = "melee", spellID = 187707, cooldown = 15 },

	-- Rogue
	[259] = { class = "ROGUE", spec = "Assassination", role = "melee", spellID = 1766, cooldown = 15 },
	[260] = { class = "ROGUE", spec = "Outlaw", role = "melee", spellID = 1766, cooldown = 15 },
	[261] = { class = "ROGUE", spec = "Subtlety", role = "melee", spellID = 1766, cooldown = 15 },

	-- Priest (Shadow only -- Silence)
	[258] = { class = "PRIEST", spec = "Shadow", role = "ranged", spellID = 15487, cooldown = 45 },

	-- Death Knight
	[250] = { class = "DEATHKNIGHT", spec = "Blood", role = "tank", spellID = 47528, cooldown = 15 },
	[251] = { class = "DEATHKNIGHT", spec = "Frost", role = "melee", spellID = 47528, cooldown = 15 },
	[252] = { class = "DEATHKNIGHT", spec = "Unholy", role = "melee", spellID = 47528, cooldown = 15 },

	-- Shaman
	[262] = { class = "SHAMAN", spec = "Elemental", role = "ranged", spellID = 57994, cooldown = 12 },
	[263] = { class = "SHAMAN", spec = "Enhancement", role = "melee", spellID = 57994, cooldown = 12 },
	[264] = { class = "SHAMAN", spec = "Restoration", role = "ranged", spellID = 57994, cooldown = 12 },

	-- Mage
	[62] = { class = "MAGE", spec = "Arcane", role = "ranged", spellID = 2139, cooldown = 24 },
	[63] = { class = "MAGE", spec = "Fire", role = "ranged", spellID = 2139, cooldown = 24 },
	[64] = { class = "MAGE", spec = "Frost", role = "ranged", spellID = 2139, cooldown = 24 },

	-- Warlock (interrupt is cast by the pet)
	[265] = { class = "WARLOCK", spec = "Affliction", role = "ranged", spellID = 19647, cooldown = 24, viaPet = true },
	[266] = { class = "WARLOCK", spec = "Demonology", role = "ranged", spellID = 119910, cooldown = 30, viaPet = true },
	[267] = { class = "WARLOCK", spec = "Destruction", role = "ranged", spellID = 19647, cooldown = 24, viaPet = true },

	-- Monk
	[268] = { class = "MONK", spec = "Brewmaster", role = "tank", spellID = 116705, cooldown = 15 },
	[269] = { class = "MONK", spec = "Windwalker", role = "melee", spellID = 116705, cooldown = 15 },

	-- Druid
	[102] = { class = "DRUID", spec = "Balance", role = "ranged", spellID = 78675, cooldown = 60 },
	[103] = { class = "DRUID", spec = "Feral", role = "melee", spellID = 106839, cooldown = 15 },
	[104] = { class = "DRUID", spec = "Guardian", role = "tank", spellID = 106839, cooldown = 15 },

	-- Demon Hunter
	[577] = { class = "DEMONHUNTER", spec = "Havoc", role = "melee", spellID = 183752, cooldown = 15 },
	[581] = { class = "DEMONHUNTER", spec = "Vengeance", role = "tank", spellID = 183752, cooldown = 15 },

	-- Evoker
	[1467] = { class = "EVOKER", spec = "Devastation", role = "ranged", spellID = 351338, cooldown = 20 },
	[1468] = { class = "EVOKER", spec = "Preservation", role = "ranged", spellID = 351338, cooldown = 20 },
	[1473] = { class = "EVOKER", spec = "Augmentation", role = "ranged", spellID = 351338, cooldown = 20 },
}

local ROLE_PRIORITY = { tank = 1, melee = 2, ranged = 3 }
ns.ROLE_PRIORITY = ROLE_PRIORITY

-- Reverse lookup: spellID -> cooldown, so an incoming KICK message (or a
-- locally observed cast) can be resolved to a duration/icon without needing
-- to know the caster's spec.
ns.spellIDToCooldown = {}
for _, data in pairs(ns.specData) do
	ns.spellIDToCooldown[data.spellID] = data.cooldown
end
