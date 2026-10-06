--!nonstrict
-- Egg panel: shows the pets inside an egg with hatch chances and a Hatch button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Eggs = require(Shared.Config.Eggs)
local Pets = require(Shared.Config.Pets)
local Rarities = require(Shared.Config.Rarities)
local Worlds = require(Shared.Config.Worlds)
local Format = require(Shared.Util.Format)
local Weighted = require(Shared.Util.Weighted)

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

local EggShop = {}

local frame: Frame
local title: TextLabel
local costLabel: TextLabel
local list: Frame
local hatchButton: TextButton
local currentEggId: string? = nil
local busy = false

function EggShop.Mount(parent: ScreenGui, cb: { hatch: (string) -> (), close: () -> () })
	title = Create.label("Egg", { Font = Theme.fontBold, TextSize = 20, Size = UDim2.new(1, -40, 0, 28) })
	local closeButton = Create.button("X", Theme.panelLighter, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 28, 0, 28),
	})
	closeButton.Activated:Connect(cb.close)

	list = Create("Frame", {
		Position = UDim2.new(0, 0, 0, 40),
		Size = UDim2.new(1, 0, 1, -100),
		BackgroundTransparency = 1,
	}, { Create.list(4) })

	costLabel = Create.label("", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -44),
		Size = UDim2.new(1, 0, 0, 18),
		TextColor3 = Theme.textMuted,
		TextSize = 14,
	})

	hatchButton = Create.button("Hatch", Theme.success, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 18,
	})
	hatchButton.Activated:Connect(function()
		if currentEggId and not busy then
			busy = true
			hatchButton.Text = "Hatching..."
			cb.hatch(currentEggId)
		end
	end)

	frame = Create.panel({
		Name = "EggShop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 380, 0, 420),
		Visible = false,
		Parent = parent,
	}, { Create.padding(), title, closeButton, list, costLabel, hatchButton })
end

function EggShop.Open(eggId: string, profile)
	local egg = Eggs[eggId]
	if not egg then
		return
	end
	currentEggId = eggId
	frame.Visible = true

	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local chances = Weighted.chances(egg.pets)
	local ids = {}
	for id in egg.pets do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return chances[a] > chances[b]
	end)

	for index, id in ids do
		local def = Pets[id]
		if def then
			local rarity = Rarities[def.rarity]
			Create("Frame", {
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundColor3 = Theme.panelLight,
				BorderSizePixel = 0,
				LayoutOrder = index,
				Parent = list,
			}, {
				Create.corner(Theme.radiusSmall),
				Create.padding(6),
				Create.label(
					def.name,
					{ Size = UDim2.new(0.5, 0, 1, 0), TextColor3 = rarity.color, Font = Theme.fontBold, TextSize = 14 }
				),
				Create.label(def.focus, {
					Position = UDim2.new(0.5, 0, 0, 0),
					Size = UDim2.new(0.25, 0, 1, 0),
					TextSize = 13,
					TextColor3 = if def.focus == "Mining" then Theme.mining else Theme.fishing,
				}),
				Create.label(Format.percent(chances[id], 1), {
					Position = UDim2.new(0.75, 0, 0, 0),
					Size = UDim2.new(0.25, 0, 1, 0),
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
			})
		end
	end

	EggShop.Update(profile)
end

function EggShop.Update(profile)
	if not frame.Visible or not currentEggId then
		return
	end
	local egg = Eggs[currentEggId]
	local world = Worlds[egg.worldId]
	local balance = profile.coins[egg.worldId] or 0
	title.Text = egg.name
	costLabel.Text = `Cost: {Format.commas(egg.cost)} {world.currency.name}  ·  You have {Format.commas(balance)}`
	hatchButton.BackgroundColor3 = if balance >= egg.cost then Theme.success else Theme.panelLighter
end

function EggShop.Close()
	frame.Visible = false
	currentEggId = nil
end

function EggShop.OnHatchFinished()
	busy = false
	hatchButton.Text = "Hatch"
end

function EggShop.IsVisible(): boolean
	return frame.Visible
end

return EggShop
