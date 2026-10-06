--!strict
-- Fish that can be caught at fishing spots. `requiredPower` gates the fish:
-- a player whose Fishing Power is below it can never roll that fish, so
-- fishing pets unlock new catches rather than just speeding things up.

export type FishDef = {
	id: string,
	name: string,
	rarity: string,
	coins: number,
	requiredPower: number,
}

local Fish: { [string]: FishDef } = {
	Minnow = { id = "Minnow", name = "Minnow", rarity = "Common", coins = 6, requiredPower = 1 },
	Bass = { id = "Bass", name = "Bass", rarity = "Uncommon", coins = 18, requiredPower = 1 },
	Trout = { id = "Trout", name = "Rainbow Trout", rarity = "Rare", coins = 55, requiredPower = 3 },
	Koi = { id = "Koi", name = "Golden Koi", rarity = "Legendary", coins = 260, requiredPower = 6 },

	CaveEel = { id = "CaveEel", name = "Cave Eel", rarity = "Common", coins = 40, requiredPower = 4 },
	GlowCarp = { id = "GlowCarp", name = "Glow Carp", rarity = "Uncommon", coins = 110, requiredPower = 6 },
	CrystalPike = { id = "CrystalPike", name = "Crystal Pike", rarity = "Epic", coins = 320, requiredPower = 10 },
	AbyssAngler = { id = "AbyssAngler", name = "Abyss Angler", rarity = "Legendary", coins = 1200, requiredPower = 16 },
}

return Fish
