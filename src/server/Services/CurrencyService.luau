--!nonstrict
-- Per-world currency. Each world has its own coin pool in profile.coins[worldId].

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Worlds = require(Shared.Config.Worlds)

local DataService = require(script.Parent.DataService)

local CurrencyService = {}

function CurrencyService.Get(player: Player, worldId: string): number
	local profile = DataService.Get(player)
	if not profile then
		return 0
	end
	return profile.coins[worldId] or 0
end

function CurrencyService.Add(player: Player, worldId: string, amount: number)
	assert(Worlds[worldId], `Unknown world "{worldId}"`)
	local profile = DataService.Get(player)
	if not profile or amount <= 0 then
		return
	end
	profile.coins[worldId] = (profile.coins[worldId] or 0) + amount
	profile.lifetime.CoinsEarned += amount
	DataService.MarkDirty(player)
end

function CurrencyService.Spend(player: Player, worldId: string, amount: number): boolean
	local profile = DataService.Get(player)
	if not profile then
		return false
	end
	local balance = profile.coins[worldId] or 0
	if balance < amount then
		return false
	end
	profile.coins[worldId] = balance - amount
	DataService.MarkDirty(player)
	return true
end

function CurrencyService.ResetAll(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	profile.coins = {}
	DataService.MarkDirty(player)
end

return CurrencyService
