--!nonstrict
-- Rebirth: requires every task in Config/Rebirth to be complete AND the home
-- world coin threshold. Resets coins and task progress, keeps pets (configurable),
-- increments rebirths which feeds Formulas.rebirthMultiplier / equipSlots.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local RebirthConfig = require(Shared.Config.Rebirth)
local Network = require(Shared.Network)
local Formulas = require(Shared.Util.Formulas)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)

local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)

local RebirthService = {}

-- Fired with (player) after a successful rebirth so WorldService can send them home.
RebirthService.OnRebirth = Signal.new()

function RebirthService.Rebirth(player: Player): Types.RebirthResult
	local profile = DataService.Get(player)
	if not profile then
		return { ok = false, message = "Data not loaded" }
	end
	local status = RebirthConfig.evaluate(profile)
	if not status.allTasksDone then
		return { ok = false, message = "Finish every rebirth task first" }
	end
	if status.coins < status.threshold then
		return { ok = false, message = "Not enough coins to rebirth" }
	end

	profile.rebirths += 1
	profile.lifetime.Rebirths += 1
	for key in profile.stats do
		profile.stats[key] = 0
	end
	CurrencyService.ResetAll(player)
	if not GameConfig.REBIRTH_KEEP_PETS then
		profile.pets = {}
		profile.equipped = {}
	end
	profile.currentWorld = RebirthConfig.HOME_WORLD
	DataService.MarkDirty(player)

	RebirthService.OnRebirth:Fire(player)

	local mult = Formulas.rebirthMultiplier(profile.rebirths)
	Network.event("Notify"):FireClient(player, `Rebirth {profile.rebirths}! Coin multiplier is now x{mult}`, "success")
	return { ok = true, rebirths = profile.rebirths }
end

function RebirthService.Init()
	Network.func("Rebirth").OnServerInvoke = function(player: Player)
		return RebirthService.Rebirth(player)
	end
end

return RebirthService
