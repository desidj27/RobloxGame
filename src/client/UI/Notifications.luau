--!nonstrict
-- Toast stack at the top centre of the screen.

local TweenService = game:GetService("TweenService")

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

local Notifications = {}

local container: Frame

local COLORS = {
	info = Theme.accent,
	success = Theme.success,
	error = Theme.danger,
}

function Notifications.Mount(parent: ScreenGui)
	container = Create("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(0, 360, 1, 0),
		BackgroundTransparency = 1,
		Parent = parent,
	}, { Create.list(6, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Center) })
end

function Notifications.Push(message: string, kind: string?)
	if not container then
		return
	end
	local color = COLORS[kind or "info"] or Theme.accent
	local toast = Create.panel({
		Size = UDim2.new(1, 0, 0, 40),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.panelLight,
		BackgroundTransparency = 0.05,
	}, {
		Create.padding(10),
		Create("Frame", {
			Size = UDim2.new(0, 4, 1, 0),
			Position = UDim2.new(0, -10, 0, 0),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}, { Create.corner(UDim.new(1, 0)) }),
		Create.label(message, {
			Size = UDim2.new(1, 0, 0, 20),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			Font = Theme.fontBold,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
	})
	toast.Parent = container

	task.delay(3, function()
		local tween = TweenService:Create(toast, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
		for _, child in toast:GetDescendants() do
			if child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			elseif child:IsA("UIStroke") then
				TweenService:Create(child, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			elseif child:IsA("Frame") then
				TweenService:Create(child, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			end
		end
		tween:Play()
		tween.Completed:Wait()
		toast:Destroy()
	end)
end

return Notifications
