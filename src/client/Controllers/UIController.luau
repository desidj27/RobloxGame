--!nonstrict
-- Owns the ScreenGui and wires controller signals into the UI modules.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ores = require(Shared.Config.Ores)
local RebirthConfig = require(Shared.Config.Rebirth)
local Network = require(Shared.Network)
local Format = require(Shared.Util.Format)

local DataController = require(script.Parent.DataController)
local FishingController = require(script.Parent.FishingController)
local MiningController = require(script.Parent.MiningController)
local PetController = require(script.Parent.PetController)

local UI = script.Parent.Parent.UI
local EggShop = require(UI.EggShop)
local FishingOverlay = require(UI.FishingOverlay)
local HatchPopup = require(UI.HatchPopup)
local HUD = require(UI.HUD)
local Notifications = require(UI.Notifications)
local PetInventory = require(UI.PetInventory)
local RebirthPanel = require(UI.RebirthPanel)

local UIController = {}

UIController.EGG_TAG = "EggStand"

local player = Players.LocalPlayer

local function closeAll()
	PetInventory.SetVisible(false)
	RebirthPanel.SetVisible(false)
	EggShop.Close()
end

local function refresh()
	local profile = DataController.Get()
	if not profile then
		return
	end
	local stats = DataController.GetStats()
	local world = DataController.GetWorld()
	local status = RebirthConfig.evaluate(profile)
	HUD.Update(profile, stats, world, status.canRebirth)
	PetInventory.Update(profile)
	RebirthPanel.Update(profile)
	EggShop.Update(profile)
end

local function hookEggStand(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local prompt = part:FindFirstChildOfClass("ProximityPrompt") or part:WaitForChild("ProximityPrompt", 5)
	if prompt then
		prompt.Triggered:Connect(function()
			local eggId = part:GetAttribute("EggId")
			local profile = DataController.Get()
			if eggId and profile then
				closeAll()
				EggShop.Open(eggId, profile)
			end
		end)
	end
end

function UIController.Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MineAndReel"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	Notifications.Mount(gui)
	HUD.Mount(gui, {
		openPets = function()
			local open = PetInventory.IsVisible()
			closeAll()
			PetInventory.SetVisible(not open)
			refresh()
		end,
		openRebirth = function()
			local open = RebirthPanel.IsVisible()
			closeAll()
			RebirthPanel.SetVisible(not open)
			refresh()
		end,
	})
	PetInventory.Mount(gui, {
		equip = PetController.Equip,
		unequip = PetController.Unequip,
		delete = PetController.Delete,
		close = closeAll,
	})
	EggShop.Mount(gui, {
		hatch = function(eggId)
			task.spawn(function()
				local result = PetController.Hatch(eggId)
				EggShop.OnHatchFinished()
				if not result.ok then
					Notifications.Push(result.message or "Hatch failed", "error")
				end
			end)
		end,
		close = closeAll,
	})
	RebirthPanel.Mount(gui, {
		rebirth = function()
			task.spawn(function()
				local ok, result = pcall(function()
					return Network.func("Rebirth"):InvokeServer()
				end)
				RebirthPanel.OnRebirthFinished()
				if not ok then
					Notifications.Push("Rebirth request failed", "error")
				elseif not result.ok then
					Notifications.Push(result.message or "Cannot rebirth yet", "error")
				else
					closeAll()
				end
			end)
		end,
		close = closeAll,
	})
	FishingOverlay.Mount(gui, FishingController.Reel)
	HatchPopup.Mount(gui)
end

function UIController.Start()
	DataController.Changed:Connect(refresh)
	DataController.Notified:Connect(Notifications.Push)

	PetController.Hatched:Connect(function(owned)
		HatchPopup.Show(owned.id)
	end)

	MiningController.TargetChanged:Connect(function(part)
		if part then
			local ore = Ores[part:GetAttribute("OreId")]
			HUD.SetHint(`Mining {if ore then ore.name else "ore"}... press E again or walk away to stop`)
		else
			HUD.SetHint("Walk up to an ore node or the pond and press E")
		end
	end)

	MiningController.Broke:Connect(function(oreId, coins, richVein)
		local ore = Ores[oreId]
		local world = DataController.GetWorld()
		local name = if ore then ore.name else "ore"
		if richVein then
			Notifications.Push(`Rich vein! {name} paid {Format.commas(coins)} {world.currency.name}`, "success")
		end
	end)

	FishingController.StateChanged:Connect(function(state, payload)
		if state == "waiting" then
			FishingOverlay.ShowWaiting()
		elseif state == "bite" then
			FishingOverlay.ShowBite(payload.window)
		end
	end)
	FishingController.Result:Connect(function(fishId, coins)
		FishingOverlay.ShowResult(fishId, coins)
	end)

	for _, part in CollectionService:GetTagged(UIController.EGG_TAG) do
		task.spawn(hookEggStand, part)
	end
	CollectionService:GetInstanceAddedSignal(UIController.EGG_TAG):Connect(hookEggStand)

	refresh()
end

return UIController
