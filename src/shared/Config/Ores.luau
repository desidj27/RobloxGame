--!strict
-- Ore nodes that spawn at a world's ore spawn points.

export type OreDef = {
	id: string,
	name: string,
	rarity: string,
	health: number, -- total Mining Power needed to break the node
	coins: number, -- base payout in the world's currency
	respawnTime: number,
	color: Color3,
	material: Enum.Material,
	size: number,
}

local Ores: { [string]: OreDef } = {
	Stone = {
		id = "Stone",
		name = "Stone",
		rarity = "Common",
		health = 5,
		coins = 4,
		respawnTime = 6,
		color = Color3.fromRGB(140, 140, 140),
		material = Enum.Material.Slate,
		size = 4,
	},
	Coal = {
		id = "Coal",
		name = "Coal",
		rarity = "Common",
		health = 10,
		coins = 10,
		respawnTime = 8,
		color = Color3.fromRGB(45, 45, 50),
		material = Enum.Material.Basalt,
		size = 4,
	},
	Copper = {
		id = "Copper",
		name = "Copper",
		rarity = "Uncommon",
		health = 22,
		coins = 28,
		respawnTime = 12,
		color = Color3.fromRGB(200, 120, 60),
		material = Enum.Material.CorrodedMetal,
		size = 4.5,
	},
	Gold = {
		id = "Gold",
		name = "Gold",
		rarity = "Rare",
		health = 50,
		coins = 80,
		respawnTime = 18,
		color = Color3.fromRGB(255, 205, 60),
		material = Enum.Material.Metal,
		size = 4.5,
	},
	Amethyst = {
		id = "Amethyst",
		name = "Amethyst",
		rarity = "Epic",
		health = 120,
		coins = 220,
		respawnTime = 25,
		color = Color3.fromRGB(170, 80, 230),
		material = Enum.Material.Glass,
		size = 5,
	},
	Diamond = {
		id = "Diamond",
		name = "Diamond",
		rarity = "Legendary",
		health = 300,
		coins = 700,
		respawnTime = 40,
		color = Color3.fromRGB(150, 240, 255),
		material = Enum.Material.Glass,
		size = 5,
	},
}

return Ores
