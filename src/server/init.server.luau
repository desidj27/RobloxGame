-- Server bootstrap. Every module under Services/ is a service table with
-- optional Init() and Start() methods. Init runs on all services before any
-- Start, so services may safely reference each other inside Start.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared.Network)

-- Creating the remotes before anything else means the client never waits on them.
Network.event("ProfileChanged")

local ORDER = {
	"DataService",
	"CurrencyService",
	"PetService",
	"MiningService",
	"FishingService",
	"RebirthService",
	"WorldService",
}

local services = {}
for _, name in ORDER do
	services[name] = require(script.Services[name])
end

for _, name in ORDER do
	local service = services[name]
	if service.Init then
		service.Init()
	end
end

for _, name in ORDER do
	local service = services[name]
	if service.Start then
		task.spawn(service.Start)
	end
end

print("[MineAndReel] server started")
