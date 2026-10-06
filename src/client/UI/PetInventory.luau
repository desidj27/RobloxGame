--!nonstrict
-- Pet inventory panel: lists owned pets with their stats and equip/unequip/delete buttons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Pets = require(Shared.Config.Pets)
local Rarities = require(Shared.Config.Rarities)
local Format = require(Shared.Util.Format)
local Formulas = require(Shared.Util.Formulas)
local TableUtil = require(Shared.Util.TableUtil)

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

local PetInventory = {}

local frame: Frame
local header: TextLabel
local list: ScrollingFrame
local callbacks

local STAT_SHORT = {
	MiningPower = "MP",
	MiningLuck = "ML",
	FishingPower = "FP",
	FishingSpeed = "FS",
	FishingLuck = "FL",
}

local function statText(def): string
	local parts = {}
	for _, key in Formulas.STAT_KEYS do
		local value = def.stats[key]
		if value then
			table.insert(parts, `+{Format.stat(value)} {STAT_SHORT[key]}`)
		end
	end
	return table.concat(parts, "  ")
end

function PetInventory.Mount(
	parent: ScreenGui,
	cb: {
		equip: (string) -> (),
		unequip: (string) -> (),
		delete: (string) -> (),
		close: () -> (),
	}
)
	callbacks = cb
	header = Create.label("Pets", { Font = Theme.fontBold, TextSize = 20, Size = UDim2.new(1, -40, 0, 28) })
	local closeButton = Create.button("X", Theme.panelLighter, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 28, 0, 28),
	})
	closeButton.Activated:Connect(cb.close)

	list = Create("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 40),
		Size = UDim2.new(1, 0, 1, -40),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, { Create.list(6) })

	frame = Create.panel({
		Name = "PetInventory",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 460, 0, 440),
		Visible = false,
		Parent = parent,
	}, { Create.padding(), header, closeButton, list })
end

function PetInventory.SetVisible(visible: boolean)
	frame.Visible = visible
end

function PetInventory.IsVisible(): boolean
	return frame.Visible
end

local function card(owned, equipped: boolean, order: number): Frame
	local def = Pets[owned.id]
	local rarity = Rarities[def.rarity]

	local action =
		Create.button(if equipped then "Unequip" else "Equip", if equipped then Theme.panelLighter else Theme.success, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -70, 0.5, 0),
			Size = UDim2.new(0, 80, 0, 30),
			TextSize = 14,
		})
	action.Activated:Connect(function()
		if equipped then
			callbacks.unequip(owned.uid)
		else
			callbacks.equip(owned.uid)
		end
	end)

	local delete = Create.button("Delete", Theme.danger, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0, 62, 0, 30),
		TextSize = 13,
	})
	delete.Activated:Connect(function()
		callbacks.delete(owned.uid)
	end)

	return Create("Frame", {
		Size = UDim2.new(1, -8, 0, 62),
		BackgroundColor3 = if equipped then Theme.panelLighter else Theme.panelLight,
		BorderSizePixel = 0,
		LayoutOrder = order,
	}, {
		Create.corner(Theme.radiusSmall),
		Create.stroke(rarity.color, if equipped then 2 else 1),
		Create.padding(8),
		Create("Frame", {
			Size = UDim2.new(0, 10, 1, 0),
			BackgroundColor3 = def.color,
			BorderSizePixel = 0,
		}, { Create.corner(UDim.new(1, 0)) }),
		Create.label(def.name, {
			Position = UDim2.new(0, 18, 0, 0),
			Size = UDim2.new(1, -170, 0, 20),
			Font = Theme.fontBold,
			TextSize = 16,
			TextColor3 = rarity.color,
		}),
		Create.label(`{def.rarity} · {def.focus}`, {
			Position = UDim2.new(0, 18, 0, 18),
			Size = UDim2.new(1, -170, 0, 14),
			TextSize = 12,
			TextColor3 = Theme.textMuted,
		}),
		Create.label(statText(def), {
			Position = UDim2.new(0, 18, 0, 32),
			Size = UDim2.new(1, -170, 0, 14),
			TextSize = 13,
			TextColor3 = if def.focus == "Mining" then Theme.mining else Theme.fishing,
		}),
		action,
		delete,
	}) :: Frame
end

function PetInventory.Update(profile)
	if not frame.Visible then
		return
	end
	local slots = Formulas.equipSlots(profile.rebirths)
	header.Text = `Pets {#profile.pets}/{GameConfig.MAX_PET_STORAGE}  ·  Equipped {#profile.equipped}/{slots}`

	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	if #profile.pets == 0 then
		Create.label("No pets yet. Open an egg at the egg stand near spawn.", {
			Size = UDim2.new(1, 0, 0, 40),
			TextColor3 = Theme.textMuted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = list,
		})
		return
	end

	-- Equipped first, then by rarity (desc), then name.
	local sorted = table.clone(profile.pets)
	table.sort(sorted, function(a, b)
		local aEq = TableUtil.indexOf(profile.equipped, a.uid) ~= nil
		local bEq = TableUtil.indexOf(profile.equipped, b.uid) ~= nil
		if aEq ~= bEq then
			return aEq
		end
		local aDef, bDef = Pets[a.id], Pets[b.id]
		local aOrder = if aDef then Rarities[aDef.rarity].order else 0
		local bOrder = if bDef then Rarities[bDef.rarity].order else 0
		if aOrder ~= bOrder then
			return aOrder > bOrder
		end
		return a.id < b.id
	end)

	for index, owned in sorted do
		if Pets[owned.id] then
			card(owned, TableUtil.indexOf(profile.equipped, owned.uid) ~= nil, index).Parent = list
		end
	end
end

return PetInventory
