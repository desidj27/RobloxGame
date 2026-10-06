--!strict
-- Every stat and payout formula in one place so the client and server agree
-- and the design doc has a single source of truth.

local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local Pets = require(Shared.Config.Pets)
local Types = require(Shared.Types)

type Stats = Types.Stats
type Profile = Types.Profile

local Formulas = {}

local STAT_KEYS = { "MiningPower", "MiningLuck", "FishingPower", "FishingSpeed", "FishingLuck" }
Formulas.STAT_KEYS = STAT_KEYS

-- Coin multiplier granted by rebirths: 1 + 0.25 per rebirth by default.
function Formulas.rebirthMultiplier(rebirths: number): number
	return 1 + rebirths * GameConfig.REBIRTH_MULTIPLIER_PER_REBIRTH
end

function Formulas.equipSlots(rebirths: number): number
	local extra = math.floor(rebirths / GameConfig.REBIRTHS_PER_EXTRA_SLOT)
	return math.min(GameConfig.MAX_EQUIP_SLOTS, GameConfig.BASE_EQUIP_SLOTS + extra)
end

-- Sum of the equipped pets' stat bonuses (additive).
function Formulas.petBonuses(profile: Profile): Stats
	local total = { MiningPower = 0, MiningLuck = 0, FishingPower = 0, FishingSpeed = 0, FishingLuck = 0 }
	local byUid: { [string]: Types.OwnedPet } = {}
	for _, owned in profile.pets do
		byUid[owned.uid] = owned
	end
	for _, uid in profile.equipped do
		local owned = byUid[uid]
		local def = owned and Pets[owned.id]
		if def then
			for _, key in STAT_KEYS do
				local value = (def.stats :: any)[key]
				if value then
					(total :: any)[key] += value
				end
			end
		end
	end
	return total
end

-- Final stats fed into the minigames:
--   MiningPower  = (base + Σ pets) × rebirthMultiplier
--   MiningLuck   = base + Σ pets
--   FishingPower = (base + Σ pets) × rebirthMultiplier
--   FishingSpeed = base + Σ pets
--   FishingLuck  = base + Σ pets
function Formulas.computeStats(profile: Profile): Stats
	local bonus = Formulas.petBonuses(profile)
	local base = GameConfig.BASE_STATS
	local mult = Formulas.rebirthMultiplier(profile.rebirths)
	return {
		MiningPower = (base.MiningPower + bonus.MiningPower) * mult,
		MiningLuck = base.MiningLuck + bonus.MiningLuck,
		FishingPower = (base.FishingPower + bonus.FishingPower) * mult,
		FishingSpeed = base.FishingSpeed + bonus.FishingSpeed,
		FishingLuck = base.FishingLuck + bonus.FishingLuck,
	}
end

-- Mining -------------------------------------------------------------------

function Formulas.critChance(miningLuck: number): number
	return math.min(GameConfig.MINE_CRIT_CHANCE_CAP, miningLuck * GameConfig.MINE_CRIT_CHANCE_PER_LUCK)
end

function Formulas.richVeinChance(miningLuck: number): number
	return math.min(
		GameConfig.RICH_VEIN_CHANCE_CAP,
		GameConfig.RICH_VEIN_BASE_CHANCE + miningLuck * GameConfig.RICH_VEIN_CHANCE_PER_LUCK
	)
end

function Formulas.orePayout(baseCoins: number, rebirths: number, richVein: boolean): number
	local coins = baseCoins * Formulas.rebirthMultiplier(rebirths)
	if richVein then
		coins *= GameConfig.RICH_VEIN_MULTIPLIER
	end
	return math.floor(coins + 0.5)
end

-- Fishing ------------------------------------------------------------------

-- Wait before a bite. Speed is additive (0 = base speed, 1 = twice as fast).
function Formulas.biteWait(fishingSpeed: number, roll: number): number
	local base = GameConfig.FISH_MIN_WAIT + (GameConfig.FISH_MAX_WAIT - GameConfig.FISH_MIN_WAIT) * roll
	return math.max(GameConfig.FISH_MIN_WAIT_FLOOR, base / (1 + fishingSpeed))
end

-- Luck scales the weight of rarer fish. Weight multiplier = 1 + luck * (rarityOrder - 1) * 0.5
-- so Common is unaffected and Legendary gets the largest boost.
function Formulas.luckWeight(baseWeight: number, rarityOrder: number, luck: number): number
	return baseWeight * (1 + luck * (rarityOrder - 1) * 0.5)
end

function Formulas.fishPayout(baseCoins: number, rebirths: number): number
	return math.floor(baseCoins * Formulas.rebirthMultiplier(rebirths) + 0.5)
end

return Formulas
