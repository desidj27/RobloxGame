--!strict
-- Single registry of every RemoteEvent / RemoteFunction in the game.
-- The server creates the instances on first require; the client waits for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local Network = {}

Network.Events = {
	-- server -> client
	ProfileChanged = "ProfileChanged", -- (profile)
	Notify = "Notify", -- (message: string, kind: "info" | "success" | "error")
	MiningHit = "MiningHit", -- (nodeName, damage, crit, remainingHealth)
	MiningBroke = "MiningBroke", -- (nodeName, oreId, coins, richVein)
	FishingBite = "FishingBite", -- (spotId, windowSeconds)
	FishingResult = "FishingResult", -- (spotId, fishId | nil, coins)
	PetHatched = "PetHatched", -- (ownedPet)

	-- client -> server
	MineHit = "MineHit", -- (nodeName)
	FishCast = "FishCast", -- (spotId)
	FishReel = "FishReel", -- (spotId)
	EquipPet = "EquipPet", -- (uid)
	UnequipPet = "UnequipPet", -- (uid)
	DeletePet = "DeletePet", -- (uid)
}

Network.Functions = {
	GetProfile = "GetProfile", -- () -> profile
	HatchEgg = "HatchEgg", -- (eggId) -> HatchResult
	Rebirth = "Rebirth", -- () -> RebirthResult
}

local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing and existing:IsA("Folder") then
			folder = existing
		else
			local created = Instance.new("Folder")
			created.Name = FOLDER_NAME
			created.Parent = ReplicatedStorage
			folder = created
		end
		for _, name in Network.Events do
			if not (folder :: Folder):FindFirstChild(name) then
				local event = Instance.new("RemoteEvent")
				event.Name = name
				event.Parent = folder
			end
		end
		for _, name in Network.Functions do
			if not (folder :: Folder):FindFirstChild(name) then
				local fn = Instance.new("RemoteFunction")
				fn.Name = name
				fn.Parent = folder
			end
		end
	else
		folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
	end
	return folder :: Folder
end

function Network.event(name: string): RemoteEvent
	assert(Network.Events[name], `Unknown RemoteEvent "{name}"`)
	local remote = if RunService:IsServer() then getFolder():FindFirstChild(name) else getFolder():WaitForChild(name)
	return remote :: RemoteEvent
end

function Network.func(name: string): RemoteFunction
	assert(Network.Functions[name], `Unknown RemoteFunction "{name}"`)
	local remote = if RunService:IsServer() then getFolder():FindFirstChild(name) else getFolder():WaitForChild(name)
	return remote :: RemoteFunction
end

return Network
