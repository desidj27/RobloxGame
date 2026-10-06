--!nonstrict
-- Client side of the mining minigame. Pressing the prompt on an ore node
-- toggles auto-swinging: the client sends one MineHit per swing cooldown while
-- the player stays in range and the node is alive. Health bars are drawn from
-- the attributes the server mirrors onto each node.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Ores = require(Shared.Config.Ores)
local Rarities = require(Shared.Config.Rarities)
local Network = require(Shared.Network)
local Signal = require(Shared.Util.Signal)
local Format = require(Shared.Util.Format)

local MiningController = {}

MiningController.NODE_TAG = "OreNode"
MiningController.TargetChanged = Signal.new() -- (part | nil)
MiningController.Broke = Signal.new() -- (oreId, coins, richVein)

local player = Players.LocalPlayer
local activeNode: BasePart? = nil
local swingThread: thread? = nil

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root.Position
end

local function inRange(part: BasePart): boolean
	local pos = rootPosition()
	return pos ~= nil and (pos - part.Position).Magnitude <= GameConfig.MINE_INTERACT_RANGE + part.Size.X
end

local function stopMining()
	if swingThread then
		task.cancel(swingThread)
		swingThread = nil
	end
	if activeNode then
		activeNode = nil
		MiningController.TargetChanged:Fire(nil)
	end
end

local function startMining(part: BasePart)
	stopMining()
	activeNode = part
	MiningController.TargetChanged:Fire(part)
	swingThread = task.spawn(function()
		while activeNode == part do
			if part:GetAttribute("Depleted") or not inRange(part) or not part:IsDescendantOf(workspace) then
				break
			end
			Network.event("MineHit"):FireServer(part.Name)
			task.wait(GameConfig.MINE_SWING_COOLDOWN)
		end
		if activeNode == part then
			activeNode = nil
			MiningController.TargetChanged:Fire(nil)
		end
		swingThread = nil
	end)
end

-- Health bar --------------------------------------------------------------

local function attachHealthBar(part: BasePart)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBar"
	billboard.Size = UDim2.fromScale(7, 1.6)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, part.Size.Y / 2 + 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 60

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0.55, 0)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextStrokeTransparency = 0.5
	name.Parent = billboard

	local track = Instance.new("Frame")
	track.Position = UDim2.new(0, 0, 0.6, 0)
	track.Size = UDim2.new(1, 0, 0.35, 0)
	track.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	track.BorderSizePixel = 0
	track.Parent = billboard
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 220, 110)
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local function refresh()
		local oreId = part:GetAttribute("OreId")
		local ore = oreId and Ores[oreId]
		local health = part:GetAttribute("Health") or 0
		local maxHealth = part:GetAttribute("MaxHealth") or 1
		local depleted = part:GetAttribute("Depleted")
		billboard.Enabled = not depleted and ore ~= nil
		if ore then
			name.Text = `{ore.name}  ·  {Format.stat(health)}/{Format.stat(maxHealth)}`
			name.TextColor3 = Rarities[ore.rarity].color
		end
		local alpha = math.clamp(health / math.max(1, maxHealth), 0, 1)
		TweenService:Create(fill, TweenInfo.new(0.15), { Size = UDim2.fromScale(alpha, 1) }):Play()
	end

	part:GetAttributeChangedSignal("Health"):Connect(refresh)
	part:GetAttributeChangedSignal("OreId"):Connect(refresh)
	part:GetAttributeChangedSignal("Depleted"):Connect(refresh)
	refresh()
	billboard.Parent = part
end

local function hookNode(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	attachHealthBar(part)
	local prompt = part:FindFirstChildOfClass("ProximityPrompt") or part:WaitForChild("ProximityPrompt", 5)
	if prompt then
		prompt.Triggered:Connect(function()
			if activeNode == part then
				stopMining()
			else
				startMining(part)
			end
		end)
	end
end

-- Damage numbers ------------------------------------------------------------

local function popDamage(part: BasePart, text: string, color: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(4, 1.2)
	billboard.StudsOffsetWorldSpace = Vector3.new(math.random(-15, 15) / 10, part.Size.Y / 2 + 1, 0)
	billboard.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard
	billboard.Parent = part
	TweenService:Create(billboard, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = billboard.StudsOffsetWorldSpace + Vector3.new(0, 3, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.7), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.75, function()
		billboard:Destroy()
	end)
end

function MiningController.GetTarget(): BasePart?
	return activeNode
end

function MiningController.Init()
	for _, part in CollectionService:GetTagged(MiningController.NODE_TAG) do
		task.spawn(hookNode, part)
	end
	CollectionService:GetInstanceAddedSignal(MiningController.NODE_TAG):Connect(hookNode)

	Network.event("MiningHit").OnClientEvent:Connect(function(nodeName, damage, crit)
		local part = activeNode
		if part and part.Name == nodeName then
			local text = if crit then `CRIT {Format.stat(damage)}` else Format.stat(damage)
			popDamage(part, text, if crit then Color3.fromRGB(255, 200, 60) else Color3.new(1, 1, 1))
		end
	end)

	Network.event("MiningBroke").OnClientEvent:Connect(function(nodeName, oreId, coins, richVein)
		MiningController.Broke:Fire(oreId, coins, richVein)
		local part = activeNode
		if part and part.Name == nodeName then
			stopMining()
		end
	end)

	player.CharacterAdded:Connect(stopMining)
end

return MiningController
