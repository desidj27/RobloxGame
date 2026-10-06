--!nonstrict
-- Centre-screen reveal card shown after hatching an egg.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pets = require(Shared.Config.Pets)
local Rarities = require(Shared.Config.Rarities)
local Format = require(Shared.Util.Format)
local Formulas = require(Shared.Util.Formulas)

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

local HatchPopup = {}

local frame: Frame
local swatch: Frame
local nameLabel: TextLabel
local rarityLabel: TextLabel
local statsLabel: TextLabel
local stroke: UIStroke
local hideThread: thread? = nil

function HatchPopup.Mount(parent: ScreenGui)
	swatch = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.new(0, 72, 0, 72),
		BorderSizePixel = 0,
	}, { Create.corner(UDim.new(1, 0)) })
	nameLabel = Create.label("", {
		Position = UDim2.new(0, 0, 0, 82),
		Size = UDim2.new(1, 0, 0, 28),
		Font = Theme.fontBlack,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	rarityLabel = Create.label("", {
		Position = UDim2.new(0, 0, 0, 110),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.textMuted,
	})
	statsLabel = Create.label("", {
		Position = UDim2.new(0, 0, 0, 132),
		Size = UDim2.new(1, 0, 0, 18),
		Font = Theme.fontBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	frame = Create.panel({
		Name = "HatchPopup",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.32, 0),
		Size = UDim2.new(0, 300, 0, 180),
		Visible = false,
		Parent = parent,
	}, { Create.padding(14), swatch, nameLabel, rarityLabel, statsLabel })
	stroke = frame:FindFirstChildOfClass("UIStroke") :: UIStroke
end

function HatchPopup.Show(petId: string)
	local def = Pets[petId]
	if not def then
		return
	end
	local rarity = Rarities[def.rarity]
	swatch.BackgroundColor3 = def.color
	nameLabel.Text = def.name
	nameLabel.TextColor3 = rarity.color
	rarityLabel.Text = `{def.rarity} · {def.focus} pet`
	local parts = {}
	for _, key in Formulas.STAT_KEYS do
		local value = def.stats[key]
		if value then
			local spaced = (key:gsub("(%l)(%u)", "%1 %2"))
			table.insert(parts, `+{Format.stat(value)} {spaced}`)
		end
	end
	statsLabel.Text = table.concat(parts, "   ")
	statsLabel.TextColor3 = if def.focus == "Mining" then Theme.mining else Theme.fishing
	stroke.Color = rarity.color
	stroke.Thickness = 2

	frame.Visible = true
	frame.Size = UDim2.new(0, 240, 0, 144)
	TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.new(0, 300, 0, 180) }):Play()

	if hideThread then
		task.cancel(hideThread)
	end
	hideThread = task.delay(2.5, function()
		frame.Visible = false
		hideThread = nil
	end)
end

return HatchPopup
