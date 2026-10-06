--!strict
-- Global balance constants. Everything tunable that is not tied to a specific
-- world, ore, fish, egg or pet lives here.

local GameConfig = {
	DATA_VERSION = 1,
	DATASTORE_NAME = "MineAndReel_v1",
	AUTOSAVE_INTERVAL = 90,

	-- Base player stats before pets and rebirth bonuses are applied.
	BASE_STATS = {
		MiningPower = 1,
		MiningLuck = 0,
		FishingPower = 1,
		FishingSpeed = 0,
		FishingLuck = 0,
	},

	-- Pets
	BASE_EQUIP_SLOTS = 3,
	MAX_EQUIP_SLOTS = 6,
	REBIRTHS_PER_EXTRA_SLOT = 2,
	MAX_PET_STORAGE = 100,

	-- Mining
	MINE_SWING_COOLDOWN = 0.45, -- seconds between accepted swings
	MINE_INTERACT_RANGE = 14, -- studs from the player's root to the ore node
	MINE_CRIT_MULTIPLIER = 2,
	-- Each point of Mining Luck adds this much crit chance (capped).
	MINE_CRIT_CHANCE_PER_LUCK = 0.04,
	MINE_CRIT_CHANCE_CAP = 0.6,
	-- Chance of a "Rich Vein" bonus payout when a node breaks.
	RICH_VEIN_BASE_CHANCE = 0.03,
	RICH_VEIN_CHANCE_PER_LUCK = 0.03,
	RICH_VEIN_CHANCE_CAP = 0.5,
	RICH_VEIN_MULTIPLIER = 3,

	-- Fishing
	FISH_INTERACT_RANGE = 16,
	FISH_BITE_WINDOW = 1.6, -- seconds the player has to reel after a bite
	FISH_MIN_WAIT = 2.5, -- base wait before a bite, divided by (1 + FishingSpeed)
	FISH_MAX_WAIT = 6,
	FISH_MIN_WAIT_FLOOR = 0.6,

	-- Rebirth
	REBIRTH_MULTIPLIER_PER_REBIRTH = 0.25, -- coin multiplier = 1 + rebirths * this
	REBIRTH_KEEP_PETS = true,
}

return GameConfig
