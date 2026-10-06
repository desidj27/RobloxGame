--!strict
-- Eggs are bought with the currency of the world they live in. `pets` maps
-- pet id -> weight; the hatch chance shown in the UI is weight / total.

export type EggDef = {
	id: string,
	name: string,
	worldId: string,
	cost: number,
	color: Color3,
	pets: { [string]: number },
}

local Eggs: { [string]: EggDef } = {
	MeadowEgg = {
		id = "MeadowEgg",
		name = "Meadow Egg",
		worldId = "GrassyHills",
		cost = 150,
		color = Color3.fromRGB(200, 240, 160),
		pets = {
			Mole = 30,
			Duckling = 30,
			Badger = 15,
			Otter = 15,
			Fox = 4,
			Heron = 4,
			Golem = 1,
			Kingfisher = 1,
			Dragon = 0.1,
		},
	},
	CrystalEgg = {
		id = "CrystalEgg",
		name = "Crystal Egg",
		worldId = "CrystalCaverns",
		cost = 900,
		color = Color3.fromRGB(170, 140, 255),
		pets = {
			CaveBat = 40,
			Axolotl = 40,
			CrystalCrab = 12,
			GeodeTortoise = 7,
			Leviathan = 0.5,
		},
	},
}

return Eggs
