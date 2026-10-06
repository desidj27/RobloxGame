--!nonstrict
-- Rebirth panel: task checklist, coin threshold progress and the Rebirth button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RebirthConfig = require(Shared.Config.Rebirth)
local Worlds = require(Shared.Config.Worlds)
local Format = require(Shared.Util.Format)
local Formulas = require(Shared.Util.Formulas)

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

local RebirthPanel = {}

local frame: Frame
local list: Frame
local coinLabel: TextLabel
local setCoinBar: (number) -> ()
local rewardLabel: TextLabel
local rebirthButton: TextButton
local busy = false

function RebirthPanel.Mount(parent: ScreenGui, cb: { rebirth: () -> (), close: () -> () })
	local title = Create.label("Rebirth", { Font = Theme.fontBold, TextSize = 20, Size = UDim2.new(1, -40, 0, 28) })
	local closeButton = Create.button("X", Theme.panelLighter, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 28, 0, 28),
	})
	closeButton.Activated:Connect(cb.close)

	local subtitle = Create.label(
		"Complete every task and reach the coin goal. Rebirthing resets coins and task progress but keeps your pets.",
		{
			Position = UDim2.new(0, 0, 0, 30),
			Size = UDim2.new(1, 0, 0, 36),
			TextWrapped = true,
			TextSize = 13,
			TextColor3 = Theme.textMuted,
		}
	)

	list = Create("Frame", {
		Position = UDim2.new(0, 0, 0, 72),
		Size = UDim2.new(1, 0, 0, 200),
		BackgroundTransparency = 1,
	}, { Create.list(6) })

	coinLabel = Create.label("", {
		Position = UDim2.new(0, 0, 0, 280),
		Size = UDim2.new(1, 0, 0, 18),
		Font = Theme.fontBold,
		TextSize = 14,
	})
	local coinBar
	coinBar, setCoinBar = Create.progressBar(Theme.warning, 10)
	coinBar.Position = UDim2.new(0, 0, 0, 302)

	rewardLabel = Create.label("", {
		Position = UDim2.new(0, 0, 0, 320),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 13,
		TextColor3 = Theme.textMuted,
	})

	rebirthButton = Create.button("Rebirth", Theme.warning, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 18,
		TextColor3 = Color3.fromRGB(40, 30, 10),
	})
	rebirthButton.Activated:Connect(function()
		if not busy then
			busy = true
			rebirthButton.Text = "Rebirthing..."
			cb.rebirth()
		end
	end)

	frame = Create.panel({
		Name = "RebirthPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 420, 0, 420),
		Visible = false,
		Parent = parent,
	}, { Create.padding(), title, closeButton, subtitle, list, coinLabel, coinBar, rewardLabel, rebirthButton })
end

function RebirthPanel.SetVisible(visible: boolean)
	frame.Visible = visible
end

function RebirthPanel.IsVisible(): boolean
	return frame.Visible
end

function RebirthPanel.OnRebirthFinished()
	busy = false
	rebirthButton.Text = "Rebirth"
end

function RebirthPanel.Update(profile)
	if not frame.Visible then
		return
	end
	local status = RebirthConfig.evaluate(profile)
	local home = Worlds[RebirthConfig.HOME_WORLD]

	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for index, task in status.tasks do
		local bar, setBar = Create.progressBar(if task.done then Theme.success else Theme.accent, 8)
		bar.Position = UDim2.new(0, 0, 1, -8)
		setBar(task.progress / math.max(1, task.target))
		Create("Frame", {
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = Theme.panelLight,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Parent = list,
		}, {
			Create.corner(Theme.radiusSmall),
			Create.padding(8),
			Create.label(task.label, {
				Size = UDim2.new(0.7, 0, 0, 18),
				TextSize = 14,
				Font = Theme.fontBold,
				TextColor3 = if task.done then Theme.success else Theme.text,
			}),
			Create.label(`{Format.commas(math.min(task.progress, task.target))} / {Format.commas(task.target)}`, {
				Position = UDim2.new(0.7, 0, 0, 0),
				Size = UDim2.new(0.3, 0, 0, 18),
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = Theme.textMuted,
			}),
			bar,
		})
	end

	coinLabel.Text = `{home.currency.name}: {Format.commas(status.coins)} / {Format.commas(status.threshold)}`
	coinLabel.TextColor3 = if status.coins >= status.threshold then Theme.success else Theme.text
	setCoinBar(status.coins / math.max(1, status.threshold))

	local nextMult = Formulas.rebirthMultiplier(profile.rebirths + 1)
	local nextSlots = Formulas.equipSlots(profile.rebirths + 1)
	rewardLabel.Text = `Reward: coin multiplier x{Format.stat(nextMult)} · {nextSlots} pet slots`

	rebirthButton.BackgroundColor3 = if status.canRebirth then Theme.warning else Theme.panelLighter
	rebirthButton.TextColor3 = if status.canRebirth then Color3.fromRGB(40, 30, 10) else Theme.textMuted
end

return RebirthPanel
