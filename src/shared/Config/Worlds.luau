--!strict
-- World definitions. Each world has its own currency, its own ore spawn
-- points, fishing spots and egg stands. Positions are relative to `origin`,
-- so a world can be moved by changing a single vector.

export type OreSpawn = {
	position: Vector3,
	ores: { [string]: number }, -- ore id -> spawn weight
}

export type FishingSpot = {
	id: string,
	position: Vector3,
	size: Vector3,
	fish: { [string]: number }, -- fish id -> catch weight
}

export type EggStand = {
	eggId: string,
	position: Vector3,
}

export type Portal = {
	targetWorld: string,
	position: Vector3,
}

export type WorldDef = {
	id: string,
	name: string,
	order: number,
	currency: {
		name: string,
		symbol: string,
		color: Color3,
	},
	requiredRebirths: number,
	origin: Vector3,
	groundSize: Vector3,
	groundColor: Color3,
	spawnOffset: Vector3,
	-- Used for hand-placed ore nodes / fishing spots that have no Ores / Fish attribute.
	defaultOres: { [string]: number },
	defaultFish: { [string]: number },
	-- Generated only when the world folder has no hand-placed objects of that kind.
	oreSpawns: { OreSpawn },
	fishingSpots: { FishingSpot },
	eggStands: { EggStand },
	portals: { Portal },
}

local Worlds: { [string]: WorldDef } = {}

Worlds.GrassyHills = {
	id = "GrassyHills",
	name = "Grassy Hills",
	order = 1,
	currency = {
		name = "Coins",
		symbol = "¢",
		color = Color3.fromRGB(255, 205, 60),
	},
	requiredRebirths = 0,
	origin = Vector3.new(0, 0, 0),
	groundSize = Vector3.new(180, 4, 180),
	groundColor = Color3.fromRGB(92, 160, 72),
	spawnOffset = Vector3.new(0, 6, 0),
	defaultOres = { Stone = 10, Coal = 5, Copper = 2 },
	defaultFish = { Minnow = 10, Bass = 5, Trout = 3, Koi = 1 },
	oreSpawns = {
		{ position = Vector3.new(-40, 0, -30), ores = { Stone = 10, Coal = 4 } },
		{ position = Vector3.new(-48, 0, -22), ores = { Stone = 10, Coal = 4 } },
		{ position = Vector3.new(-56, 0, -32), ores = { Stone = 8, Coal = 5, Copper = 2 } },
		{ position = Vector3.new(-44, 0, -42), ores = { Stone = 6, Coal = 5, Copper = 3 } },
		{ position = Vector3.new(-54, 0, -46), ores = { Coal = 5, Copper = 3, Gold = 1 } },
		{ position = Vector3.new(-62, 0, -40), ores = { Copper = 3, Gold = 1 } },
	},
	fishingSpots = {
		{
			id = "GrassyPond",
			position = Vector3.new(45, -1, -30),
			size = Vector3.new(40, 2, 30),
			fish = { Minnow = 10, Bass = 5, Trout = 3, Koi = 1 },
		},
	},
	eggStands = {
		{ eggId = "MeadowEgg", position = Vector3.new(0, 0, -45) },
	},
	portals = {
		{ targetWorld = "CrystalCaverns", position = Vector3.new(0, 0, 60) },
	},
}

Worlds.CrystalCaverns = {
	id = "CrystalCaverns",
	name = "Crystal Caverns",
	order = 2,
	currency = {
		name = "Shards",
		symbol = "◆",
		color = Color3.fromRGB(120, 220, 255),
	},
	requiredRebirths = 1,
	origin = Vector3.new(600, 0, 0),
	groundSize = Vector3.new(180, 4, 180),
	groundColor = Color3.fromRGB(70, 60, 95),
	spawnOffset = Vector3.new(0, 6, 0),
	defaultOres = { Copper = 8, Gold = 4, Amethyst = 1 },
	defaultFish = { CaveEel = 10, GlowCarp = 5, CrystalPike = 3, AbyssAngler = 1 },
	oreSpawns = {
		{ position = Vector3.new(-40, 0, -30), ores = { Copper = 8, Gold = 4 } },
		{ position = Vector3.new(-48, 0, -22), ores = { Copper = 8, Gold = 4 } },
		{ position = Vector3.new(-56, 0, -32), ores = { Gold = 6, Amethyst = 2 } },
		{ position = Vector3.new(-44, 0, -42), ores = { Gold = 5, Amethyst = 3 } },
		{ position = Vector3.new(-54, 0, -46), ores = { Gold = 4, Amethyst = 3, Diamond = 1 } },
		{ position = Vector3.new(-62, 0, -40), ores = { Amethyst = 3, Diamond = 1 } },
	},
	fishingSpots = {
		{
			id = "GlowLake",
			position = Vector3.new(45, -1, -30),
			size = Vector3.new(40, 2, 30),
			fish = { CaveEel = 10, GlowCarp = 5, CrystalPike = 3, AbyssAngler = 1 },
		},
	},
	eggStands = {
		{ eggId = "CrystalEgg", position = Vector3.new(0, 0, -45) },
	},
	portals = {
		{ targetWorld = "GrassyHills", position = Vector3.new(0, 0, 60) },
	},
}

return Worlds
