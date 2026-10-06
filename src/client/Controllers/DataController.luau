--!nonstrict
-- Holds the local player's replicated profile and derives stats from it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Worlds = require(Shared.Config.Worlds)
local Network = require(Shared.Network)
local Formulas = require(Shared.Util.Formulas)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)

local DataController = {}

DataController.Changed = Signal.new()
DataController.Notified = Signal.new()

local profile: Types.Profile? = nil

function DataController.Get(): Types.Profile?
	return profile
end

function DataController.WaitFor(): Types.Profile
	while not profile do
		task.wait(0.1)
	end
	return profile :: Types.Profile
end

function DataController.GetStats(): Types.Stats
	if not profile then
		return table.clone(GameConfig.BASE_STATS)
	end
	return Formulas.computeStats(profile)
end

function DataController.GetWorld()
	local worldId = if profile then profile.currentWorld else "GrassyHills"
	return Worlds[worldId] or Worlds.GrassyHills
end

function DataController.GetCoins(worldId: string?): number
	if not profile then
		return 0
	end
	return profile.coins[worldId or profile.currentWorld] or 0
end

function DataController.Init()
	Network.event("ProfileChanged").OnClientEvent:Connect(function(newProfile)
		profile = newProfile
		DataController.Changed:Fire(newProfile)
	end)

	Network.event("Notify").OnClientEvent:Connect(function(message, kind)
		DataController.Notified:Fire(message, kind)
	end)
end

function DataController.Start()
	local ok, result = pcall(function()
		return Network.func("GetProfile"):InvokeServer()
	end)
	if ok and result and not profile then
		profile = result
		DataController.Changed:Fire(result)
	end
end

return DataController
