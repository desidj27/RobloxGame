--!nonstrict
-- Bottom-centre fishing prompt: "waiting" spinner text, then a shrinking
-- reaction bar during the bite window with a Reel button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fish = require(Shared.Config.Fish)
local Rarities = require(Shared.Config.Rarities)
local Format = require(Shared.Util.Format)

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

local FishingOverlay = {}

local frame: Frame
local label: TextLabel
local setBar: (number) -> ()
local bar: Frame
local reelButton: TextButton
local connection: RBXScriptConnection? = nil

function FishingOverlay.Mount(parent: ScreenGui, onReel: () -> ())
	label = Create.label("Waiting for a bite...", {
		Size = UDim2.new(1, 0, 0, 24),
		Font = Theme.fontBold,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	bar, setBar = Create.progressBar(Theme.fishing, 12)
	bar.Position = UDim2.new(0, 0, 0, 32)

	reelButton = Create.button("REEL!  (E / click)", Theme.fishing, {
		Position = UDim2.new(0, 0, 0, 52),
		Size = UDim2.new(1, 0, 0, 36),
		TextSize = 16,
		Visible = false,
	})
	reelButton.Activated:Connect(onReel)

	frame = Create.panel({
		Name = "Fishing",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -60),
		Size = UDim2.new(0, 320, 0, 112),
		Visible = false,
		Parent = parent,
	}, { Create.padding(), label, bar, reelButton })
end

local function stopTimer()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

function FishingOverlay.ShowWaiting()
	stopTimer()
	frame.Visible = true
	label.Text = "Waiting for a bite..."
	label.TextColor3 = Theme.text
	bar.Visible = true
	setBar(1)
	reelButton.Visible = false
	local start = os.clock()
	connection = RunService.Heartbeat:Connect(function()
		local dots = string.rep(".", math.floor((os.clock() - start) * 2) % 4)
		label.Text = `Waiting for a bite{dots}`
	end)
end

function FishingOverlay.ShowBite(window: number)
	stopTimer()
	frame.Visible = true
	label.Text = "Bite! Reel it in!"
	label.TextColor3 = Theme.warning
	bar.Visible = true
	reelButton.Visible = true
	local start = os.clock()
	connection = RunService.Heartbeat:Connect(function()
		local remaining = 1 - (os.clock() - start) / window
		setBar(remaining)
		if remaining <= 0 then
			stopTimer()
		end
	end)
end

function FishingOverlay.ShowResult(fishId: string?, coins: number)
	stopTimer()
	frame.Visible = true
	bar.Visible = false
	reelButton.Visible = false
	if fishId and Fish[fishId] then
		local def = Fish[fishId]
		label.Text = `Caught a {def.name}!  +{Format.commas(coins)}`
		label.TextColor3 = Rarities[def.rarity].color
	else
		label.Text = "It got away..."
		label.TextColor3 = Theme.textMuted
	end
	task.delay(1.8, function()
		if not connection then
			frame.Visible = false
		end
	end)
end

function FishingOverlay.Hide()
	stopTimer()
	frame.Visible = false
end

return FishingOverlay
