--!nonstrict
-- Client side of the fishing minigame. Fires FishCast from the spot's prompt,
-- waits for FishingBite, and lets the player reel with the prompt key, a
-- click/tap, or the on-screen button. The UI listens to StateChanged.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared.Network)
local Signal = require(Shared.Util.Signal)

local FishingController = {}

FishingController.SPOT_TAG = "FishingSpot"

export type State = "idle" | "waiting" | "bite"

-- StateChanged(state, payload) where payload is { spotId, window } for "bite".
FishingController.StateChanged = Signal.new()
-- Result(fishId | nil, coins)
FishingController.Result = Signal.new()

local state: State = "idle"
local activeSpot: string? = nil

local REEL_ACTION = "FishingReel"

local function setState(newState: State, payload: any?)
	state = newState
	FishingController.StateChanged:Fire(newState, payload)
end

local function unbindReel()
	ContextActionService:UnbindAction(REEL_ACTION)
end

function FishingController.Reel()
	if state == "idle" or not activeSpot then
		return
	end
	Network.event("FishReel"):FireServer(activeSpot)
end

local function bindReel()
	ContextActionService:BindAction(REEL_ACTION, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			FishingController.Reel()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.E, Enum.KeyCode.Space, Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch)
end

function FishingController.Cast(spotId: string)
	if state ~= "idle" then
		return
	end
	activeSpot = spotId
	Network.event("FishCast"):FireServer(spotId)
	setState("waiting", { spotId = spotId })
end

function FishingController.GetState(): State
	return state
end

local function hookSpot(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local spotId = part:GetAttribute("SpotId") or part.Name
	local prompt = part:FindFirstChildOfClass("ProximityPrompt") or part:WaitForChild("ProximityPrompt", 5)
	if prompt then
		prompt.Triggered:Connect(function()
			if state == "idle" then
				FishingController.Cast(spotId)
			elseif state == "bite" then
				FishingController.Reel()
			end
		end)
	end
end

function FishingController.Init()
	for _, part in CollectionService:GetTagged(FishingController.SPOT_TAG) do
		task.spawn(hookSpot, part)
	end
	CollectionService:GetInstanceAddedSignal(FishingController.SPOT_TAG):Connect(hookSpot)

	Network.event("FishingBite").OnClientEvent:Connect(function(spotId, window)
		if spotId ~= activeSpot then
			return
		end
		setState("bite", { spotId = spotId, window = window })
		bindReel()
	end)

	Network.event("FishingResult").OnClientEvent:Connect(function(spotId, fishId, coins)
		if spotId ~= activeSpot then
			return
		end
		unbindReel()
		activeSpot = nil
		setState("idle")
		FishingController.Result:Fire(fishId, coins)
	end)
end

return FishingController
