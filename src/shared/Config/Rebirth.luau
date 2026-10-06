--!strict
-- Rebirth requirements. A player may rebirth once EVERY task is complete AND
-- they hold at least `coinThreshold(rebirths)` of their home world's currency.
-- Task targets scale with the player's current rebirth count so each cycle is
-- a little longer than the last.

local Types = require(script.Parent.Parent.Types)

export type TaskDef = {
	id: string,
	stat: string, -- key in profile.stats (reset on rebirth)
	label: string,
	baseTarget: number,
	perRebirth: number,
}

local Rebirth = {}

Rebirth.HOME_WORLD = "GrassyHills"

local tasks: { TaskDef } = {
	{ id = "MineOres", stat = "OresMined", label = "Break %d ore nodes", baseTarget = 40, perRebirth = 20 },
	{ id = "CatchFish", stat = "FishCaught", label = "Catch %d fish", baseTarget = 20, perRebirth = 10 },
	{ id = "HatchEggs", stat = "EggsHatched", label = "Hatch %d eggs", baseTarget = 5, perRebirth = 3 },
	{ id = "RareFinds", stat = "RareFinds", label = "Find %d Rare+ ores or fish", baseTarget = 3, perRebirth = 2 },
}
Rebirth.tasks = tasks

Rebirth.BASE_COIN_THRESHOLD = 5000
Rebirth.COIN_THRESHOLD_GROWTH = 1.6 -- threshold = base * growth ^ rebirths

function Rebirth.taskTarget(task: TaskDef, rebirths: number): number
	return task.baseTarget + task.perRebirth * rebirths
end

function Rebirth.coinThreshold(rebirths: number): number
	return math.floor(Rebirth.BASE_COIN_THRESHOLD * Rebirth.COIN_THRESHOLD_GROWTH ^ rebirths)
end

export type TaskStatus = {
	id: string,
	label: string,
	progress: number,
	target: number,
	done: boolean,
}

export type Status = {
	tasks: { TaskStatus },
	allTasksDone: boolean,
	coins: number,
	threshold: number,
	canRebirth: boolean,
}

-- Pure evaluation used by both the server (to authorise) and the client (to render).
function Rebirth.evaluate(profile: Types.Profile): Status
	local tasks: { TaskStatus } = {}
	local allTasksDone = true
	for _, task in Rebirth.tasks do
		local target = Rebirth.taskTarget(task, profile.rebirths)
		local progress = profile.stats[task.stat] or 0
		local done = progress >= target
		allTasksDone = allTasksDone and done
		table.insert(tasks, {
			id = task.id,
			label = string.format(task.label, target),
			progress = progress,
			target = target,
			done = done,
		})
	end
	local threshold = Rebirth.coinThreshold(profile.rebirths)
	local coins = profile.coins[Rebirth.HOME_WORLD] or 0
	return {
		tasks = tasks,
		allTasksDone = allTasksDone,
		coins = coins,
		threshold = threshold,
		canRebirth = allTasksDone and coins >= threshold,
	}
end

return Rebirth
