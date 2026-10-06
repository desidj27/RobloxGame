--!nonstrict
-- Always-visible HUD: current world currency, live stats, rebirth info and the
-- buttons that open the Pets / Rebirth panels.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Formulas = require(Shared.Util.Formulas)

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

local HUD = {}

local refs = {}

local STAT_ROWS = {
	{ key = "MiningPower", label = "Mining Power", color = Theme.mining },
	{ key = "MiningLuck", label = "Mining Luck", color = Theme.mining },
	{ key = "FishingPower", label = "Fishing Power", color = Theme.fishing },
	{ key = "FishingSpeed", label = "Fishing Speed", color = Theme.fishing },
	{ key = "FishingLuck", label = "Fishing Luck", color = Theme.fishing },
}

function HUD.Mount(parent: ScreenGui, callbacks: { openPets: () -> (), openRebirth: () -> () })
	-- Currency card (top-left)
	refs.coinSymbol = Create.label("¢", {
		Size = UDim2.new(0, 34, 1, 0),
		Font = Theme.fontBlack,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	refs.coinAmount = Create.label("0", {
		Position = UDim2.new(0, 40, 0, 4),
		Size = UDim2.new(1, -40, 0, 26),
		Font = Theme.fontBlack,
		TextSize = 24,
	})
	refs.coinWorld = Create.label("Grassy Hills · Coins", {
		Position = UDim2.new(0, 40, 0, 30),
		Size = UDim2.new(1, -40, 0, 16),
		TextSize = 13,
		TextColor3 = Theme.textMuted,
	})
	Create.panel({
		Name = "Currency",
		Position = UDim2.new(0, 16, 0, 16),
		Size = UDim2.new(0, 230, 0, 56),
		Parent = parent,
	}, { Create.padding(6), refs.coinSymbol, refs.coinAmount, refs.coinWorld })

	-- Rebirth card (under currency)
	refs.rebirthLabel = Create.label("Rebirth 0 · x1 coins", {
		Size = UDim2.new(1, 0, 1, 0),
		Font = Theme.fontBold,
		TextSize = 14,
		TextColor3 = Theme.warning,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Create.panel({
		Name = "RebirthInfo",
		Position = UDim2.new(0, 16, 0, 80),
		Size = UDim2.new(0, 230, 0, 30),
		Parent = parent,
	}, { refs.rebirthLabel })

	-- Stats card (top-right)
	refs.statLabels = {}
	local statChildren = { Create.padding(10), Create.list(4) }
	for index, row in STAT_ROWS do
		local value = Create.label("1", {
			Size = UDim2.new(0.35, 0, 1, 0),
			Position = UDim2.new(0.65, 0, 0, 0),
			Font = Theme.fontBold,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextSize = 14,
		})
		refs.statLabels[row.key] = value
		table.insert(
			statChildren,
			Create("Frame", {
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				LayoutOrder = index,
			}, {
				Create.label(row.label, {
					Size = UDim2.new(0.65, 0, 1, 0),
					TextSize = 14,
					TextColor3 = row.color,
				}),
				value,
			})
		)
	end
	Create.panel({
		Name = "Stats",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.new(0, 210, 0, 130),
		Parent = parent,
	}, statChildren)

	-- Menu buttons (bottom-left)
	local petsButton = Create.button("Pets", Theme.accent, { Size = UDim2.new(0, 110, 0, 40), LayoutOrder = 1 })
	local rebirthButton = Create.button("Rebirth", Theme.warning, {
		Size = UDim2.new(0, 110, 0, 40),
		LayoutOrder = 2,
		TextColor3 = Color3.fromRGB(40, 30, 10),
	})
	petsButton.Activated:Connect(callbacks.openPets)
	rebirthButton.Activated:Connect(callbacks.openRebirth)
	refs.rebirthButton = rebirthButton
	Create("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.new(0, 240, 0, 40),
		BackgroundTransparency = 1,
		Parent = parent,
	}, { Create.list(8, Enum.FillDirection.Horizontal), petsButton, rebirthButton })

	-- Hint (bottom-centre)
	refs.hint = Create.label("Walk up to an ore node or the pond and press E", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.new(0, 520, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.textMuted,
		TextSize = 14,
		Parent = parent,
	})
end

function HUD.Update(profile, stats, world, canRebirth: boolean)
	refs.coinSymbol.Text = world.currency.symbol
	refs.coinSymbol.TextColor3 = world.currency.color
	refs.coinAmount.Text = Format.abbreviate(profile.coins[world.id] or 0)
	refs.coinWorld.Text = `{world.name} · {world.currency.name}`

	local mult = Formulas.rebirthMultiplier(profile.rebirths)
	refs.rebirthLabel.Text = `Rebirth {profile.rebirths} · x{Format.stat(mult)} coins`
	refs.rebirthButton.Text = if canRebirth then "Rebirth!" else "Rebirth"

	for key, label in refs.statLabels do
		label.Text = Format.stat(stats[key])
	end
end

function HUD.SetHint(text: string)
	refs.hint.Text = text
end

return HUD
