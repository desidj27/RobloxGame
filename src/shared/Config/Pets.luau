--!strict
-- Pet roster. Every pet is either mining-focused or fishing-focused and its
-- stat bonuses are additive: equipped pets' stats are summed and fed into
-- Formulas.luau. Stats not listed default to 0.

export type PetStats = {
	MiningPower: number?,
	MiningLuck: number?,
	FishingPower: number?,
	FishingSpeed: number?,
	FishingLuck: number?,
}

export type PetDef = {
	id: string,
	name: string,
	rarity: string,
	focus: "Mining" | "Fishing",
	stats: PetStats,
	color: Color3,
}

local Pets: { [string]: PetDef } = {
	-- Meadow Egg (Grassy Hills)
	Mole = {
		id = "Mole",
		name = "Mole",
		rarity = "Common",
		focus = "Mining",
		stats = { MiningPower = 1 },
		color = Color3.fromRGB(110, 80, 60),
	},
	Duckling = {
		id = "Duckling",
		name = "Duckling",
		rarity = "Common",
		focus = "Fishing",
		stats = { FishingSpeed = 0.5 },
		color = Color3.fromRGB(250, 230, 90),
	},
	Badger = {
		id = "Badger",
		name = "Badger",
		rarity = "Uncommon",
		focus = "Mining",
		stats = { MiningPower = 2, MiningLuck = 0.5 },
		color = Color3.fromRGB(70, 70, 75),
	},
	Otter = {
		id = "Otter",
		name = "Otter",
		rarity = "Uncommon",
		focus = "Fishing",
		stats = { FishingPower = 1, FishingSpeed = 0.5 },
		color = Color3.fromRGB(130, 90, 55),
	},
	Fox = {
		id = "Fox",
		name = "Lucky Fox",
		rarity = "Rare",
		focus = "Mining",
		stats = { MiningLuck = 2 },
		color = Color3.fromRGB(235, 120, 50),
	},
	Heron = {
		id = "Heron",
		name = "Heron",
		rarity = "Rare",
		focus = "Fishing",
		stats = { FishingPower = 2, FishingLuck = 1 },
		color = Color3.fromRGB(200, 210, 225),
	},
	Golem = {
		id = "Golem",
		name = "Pebble Golem",
		rarity = "Epic",
		focus = "Mining",
		stats = { MiningPower = 6, MiningLuck = 1 },
		color = Color3.fromRGB(120, 130, 140),
	},
	Kingfisher = {
		id = "Kingfisher",
		name = "Kingfisher",
		rarity = "Epic",
		focus = "Fishing",
		stats = { FishingPower = 3, FishingSpeed = 1.5, FishingLuck = 1 },
		color = Color3.fromRGB(40, 140, 220),
	},
	Dragon = {
		id = "Dragon",
		name = "Ember Dragon",
		rarity = "Legendary",
		focus = "Mining",
		stats = { MiningPower = 15, MiningLuck = 4 },
		color = Color3.fromRGB(220, 60, 50),
	},

	-- Crystal Egg (Crystal Caverns)
	CaveBat = {
		id = "CaveBat",
		name = "Cave Bat",
		rarity = "Common",
		focus = "Mining",
		stats = { MiningPower = 5 },
		color = Color3.fromRGB(60, 50, 80),
	},
	Axolotl = {
		id = "Axolotl",
		name = "Axolotl",
		rarity = "Common",
		focus = "Fishing",
		stats = { FishingPower = 3, FishingSpeed = 0.5 },
		color = Color3.fromRGB(255, 170, 200),
	},
	CrystalCrab = {
		id = "CrystalCrab",
		name = "Crystal Crab",
		rarity = "Rare",
		focus = "Fishing",
		stats = { FishingPower = 6, FishingLuck = 2 },
		color = Color3.fromRGB(150, 230, 255),
	},
	GeodeTortoise = {
		id = "GeodeTortoise",
		name = "Geode Tortoise",
		rarity = "Epic",
		focus = "Mining",
		stats = { MiningPower = 18, MiningLuck = 3 },
		color = Color3.fromRGB(150, 90, 220),
	},
	Leviathan = {
		id = "Leviathan",
		name = "Glow Leviathan",
		rarity = "Legendary",
		focus = "Fishing",
		stats = { FishingPower = 14, FishingSpeed = 3, FishingLuck = 5 },
		color = Color3.fromRGB(80, 255, 220),
	},
}

return Pets
