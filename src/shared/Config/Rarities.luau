--!strict
-- Shared rarity ladder for pets, ores and fish.

export type RarityInfo = {
	order: number,
	color: Color3,
}

local Rarities: { [string]: RarityInfo } = {
	Common = { order = 1, color = Color3.fromRGB(190, 190, 190) },
	Uncommon = { order = 2, color = Color3.fromRGB(96, 200, 96) },
	Rare = { order = 3, color = Color3.fromRGB(80, 140, 255) },
	Epic = { order = 4, color = Color3.fromRGB(180, 80, 255) },
	Legendary = { order = 5, color = Color3.fromRGB(255, 170, 40) },
}

return Rarities
