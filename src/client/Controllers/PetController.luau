--!nonstrict
-- Thin client API over the pet remotes plus a hatch signal for the UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared.Network)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)

local PetController = {}

PetController.Hatched = Signal.new()

function PetController.Equip(uid: string)
	Network.event("EquipPet"):FireServer(uid)
end

function PetController.Unequip(uid: string)
	Network.event("UnequipPet"):FireServer(uid)
end

function PetController.Delete(uid: string)
	Network.event("DeletePet"):FireServer(uid)
end

function PetController.Hatch(eggId: string): Types.HatchResult
	local ok, result = pcall(function()
		return Network.func("HatchEgg"):InvokeServer(eggId)
	end)
	if not ok then
		return { ok = false, message = "Hatch request failed" }
	end
	return result
end

function PetController.Init()
	Network.event("PetHatched").OnClientEvent:Connect(function(owned)
		PetController.Hatched:Fire(owned)
	end)
end

return PetController
