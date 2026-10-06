--!nonstrict
-- Pet ownership, equipping and egg hatching. Also the single place the server
-- computes a player's live stats from their equipped pets.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Eggs = require(Shared.Config.Eggs)
local GameConfig = require(Shared.Config.GameConfig)
local Pets = require(Shared.Config.Pets)
local Network = require(Shared.Network)
local Formulas = require(Shared.Util.Formulas)
local TableUtil = require(Shared.Util.TableUtil)
local Weighted = require(Shared.Util.Weighted)
local Types = require(Shared.Types)

local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)

type Profile = Types.Profile
type OwnedPet = Types.OwnedPet

local PetService = {}

local rng = Random.new()

local function notify(player: Player, message: string, kind: string?)
	Network.event("Notify"):FireClient(player, message, kind or "info")
end

local function findPet(profile: Profile, uid: string): (OwnedPet?, number?)
	for index, owned in profile.pets do
		if owned.uid == uid then
			return owned, index
		end
	end
	return nil, nil
end

function PetService.GetStats(player: Player): Types.Stats
	local profile = DataService.Get(player)
	if not profile then
		return table.clone(GameConfig.BASE_STATS)
	end
	return Formulas.computeStats(profile)
end

function PetService.AddPet(player: Player, petId: string): OwnedPet?
	local profile = DataService.Get(player)
	if not profile or not Pets[petId] then
		return nil
	end
	if #profile.pets >= GameConfig.MAX_PET_STORAGE then
		return nil
	end
	local owned: OwnedPet = {
		uid = HttpService:GenerateGUID(false),
		id = petId,
		obtainedAt = os.time(),
	}
	table.insert(profile.pets, owned)
	if #profile.equipped < Formulas.equipSlots(profile.rebirths) then
		table.insert(profile.equipped, owned.uid)
	end
	DataService.MarkDirty(player)
	return owned
end

function PetService.Equip(player: Player, uid: string): Types.SimpleResult
	local profile = DataService.Get(player)
	if not profile then
		return { ok = false, message = "Data not loaded" }
	end
	if not findPet(profile, uid) then
		return { ok = false, message = "You don't own that pet" }
	end
	if TableUtil.indexOf(profile.equipped, uid) then
		return { ok = false, message = "Already equipped" }
	end
	if #profile.equipped >= Formulas.equipSlots(profile.rebirths) then
		return { ok = false, message = "All equip slots are full" }
	end
	table.insert(profile.equipped, uid)
	DataService.MarkDirty(player)
	return { ok = true }
end

function PetService.Unequip(player: Player, uid: string): Types.SimpleResult
	local profile = DataService.Get(player)
	if not profile then
		return { ok = false, message = "Data not loaded" }
	end
	local index = TableUtil.indexOf(profile.equipped, uid)
	if not index then
		return { ok = false, message = "That pet is not equipped" }
	end
	table.remove(profile.equipped, index)
	DataService.MarkDirty(player)
	return { ok = true }
end

function PetService.Delete(player: Player, uid: string): Types.SimpleResult
	local profile = DataService.Get(player)
	if not profile then
		return { ok = false, message = "Data not loaded" }
	end
	local _, index = findPet(profile, uid)
	if not index then
		return { ok = false, message = "You don't own that pet" }
	end
	table.remove(profile.pets, index)
	local equippedIndex = TableUtil.indexOf(profile.equipped, uid)
	if equippedIndex then
		table.remove(profile.equipped, equippedIndex)
	end
	DataService.MarkDirty(player)
	return { ok = true }
end

function PetService.Hatch(player: Player, eggId: string): Types.HatchResult
	local profile = DataService.Get(player)
	if not profile then
		return { ok = false, message = "Data not loaded" }
	end
	local egg = Eggs[eggId]
	if not egg then
		return { ok = false, message = "Unknown egg" }
	end
	if profile.currentWorld ~= egg.worldId then
		return { ok = false, message = "Travel to that world to open this egg" }
	end
	if #profile.pets >= GameConfig.MAX_PET_STORAGE then
		return { ok = false, message = `Pet storage is full ({GameConfig.MAX_PET_STORAGE})` }
	end
	if not CurrencyService.Spend(player, egg.worldId, egg.cost) then
		return { ok = false, message = "Not enough coins" }
	end

	local petId = Weighted.pick(egg.pets, rng:NextNumber())
	local owned = petId and PetService.AddPet(player, petId)
	if not owned then
		-- Refund if something went wrong after the spend.
		CurrencyService.Add(player, egg.worldId, egg.cost)
		return { ok = false, message = "Hatch failed" }
	end

	profile.stats.EggsHatched += 1
	profile.lifetime.EggsHatched += 1
	DataService.MarkDirty(player)

	Network.event("PetHatched"):FireClient(player, owned)
	return { ok = true, pet = owned }
end

function PetService.Init()
	Network.func("HatchEgg").OnServerInvoke = function(player: Player, eggId: any)
		if type(eggId) ~= "string" then
			return { ok = false, message = "Bad request" }
		end
		return PetService.Hatch(player, eggId)
	end

	local function wrap(fn)
		return function(player: Player, uid: any)
			if type(uid) ~= "string" then
				return
			end
			local result = fn(player, uid)
			if not result.ok and result.message then
				notify(player, result.message, "error")
			end
		end
	end

	Network.event("EquipPet").OnServerEvent:Connect(wrap(PetService.Equip))
	Network.event("UnequipPet").OnServerEvent:Connect(wrap(PetService.Unequip))
	Network.event("DeletePet").OnServerEvent:Connect(wrap(PetService.Delete))
end

return PetService
