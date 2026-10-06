--!nonstrict
-- Tiny declarative Instance factory plus a few pre-styled widgets.
--   Create("Frame", { Size = ..., Parent = ... }, { child1, child2 })

local Theme = require(script.Parent.Theme)

local function Create(className: string, props: { [string]: any }?, children: { Instance }?): Instance
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local Widgets = {}

function Widgets.corner(radius: UDim?): UICorner
	return Create("UICorner", { CornerRadius = radius or Theme.radius }) :: UICorner
end

function Widgets.stroke(color: Color3?, thickness: number?): UIStroke
	return Create("UIStroke", {
		Color = color or Theme.stroke,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}) :: UIStroke
end

function Widgets.padding(all: number?): UIPadding
	local amount = UDim.new(0, all or Theme.padding)
	return Create("UIPadding", {
		PaddingTop = amount,
		PaddingBottom = amount,
		PaddingLeft = amount,
		PaddingRight = amount,
	}) :: UIPadding
end

function Widgets.list(padding: number?, direction: Enum.FillDirection?, align: Enum.HorizontalAlignment?): UIListLayout
	return Create("UIListLayout", {
		Padding = UDim.new(0, padding or 8),
		FillDirection = direction or Enum.FillDirection.Vertical,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}) :: UIListLayout
end

function Widgets.label(text: string, props: { [string]: any }?): TextLabel
	local merged = {
		Text = text,
		BackgroundTransparency = 1,
		Font = Theme.font,
		TextColor3 = Theme.text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 20),
	}
	if props then
		for key, value in props do
			merged[key] = value
		end
	end
	return Create("TextLabel", merged) :: TextLabel
end

function Widgets.button(text: string, color: Color3?, props: { [string]: any }?): TextButton
	local merged = {
		Text = text,
		Font = Theme.fontBold,
		TextColor3 = Theme.text,
		TextSize = 16,
		BackgroundColor3 = color or Theme.accent,
		AutoButtonColor = true,
		Size = UDim2.new(0, 120, 0, 36),
		BorderSizePixel = 0,
	}
	if props then
		for key, value in props do
			merged[key] = value
		end
	end
	local button = Create("TextButton", merged, { Widgets.corner(Theme.radiusSmall) }) :: TextButton
	return button
end

function Widgets.panel(props: { [string]: any }?, children: { Instance }?): Frame
	local merged = {
		BackgroundColor3 = Theme.panel,
		BorderSizePixel = 0,
	}
	if props then
		for key, value in props do
			merged[key] = value
		end
	end
	local kids = { Widgets.corner(), Widgets.stroke() }
	if children then
		for _, child in children do
			table.insert(kids, child)
		end
	end
	return Create("Frame", merged, kids) :: Frame
end

-- Horizontal progress bar; returns the frame and a setter taking 0..1.
function Widgets.progressBar(color: Color3?, height: number?): (Frame, (number) -> ())
	local fill = Create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color or Theme.accent,
		BorderSizePixel = 0,
	}, { Widgets.corner(UDim.new(1, 0)) })
	local track = Create("Frame", {
		Size = UDim2.new(1, 0, 0, height or 10),
		BackgroundColor3 = Theme.panelLighter,
		BorderSizePixel = 0,
	}, { Widgets.corner(UDim.new(1, 0)), fill })
	return track :: Frame, function(alpha: number)
		fill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
	end
end

return setmetatable(Widgets, {
	__call = function(_, ...)
		return Create(...)
	end,
})
