--!nonstrict
-- Builds / adopts the map and moves players between worlds.
--
-- Expected Workspace layout (every piece is optional – anything missing is
-- created at runtime from Config/Worlds, so an empty place plays out of the box):
--
--   Workspace
--   └─ Worlds                      Folder
--      └─ <WorldId>                Folder, one per entry in Config/Worlds
--         ├─ Ground                BasePart (optional, generated if missing)
--         ├─ Spawn                 SpawnLocation / BasePart (optional)
--         ├─ OreNodes              Folder of BaseParts. Attr Ores = "Stone=10,Coal=4" (optional)
--         ├─ FishingSpots          Folder of BaseParts. Attr SpotId (optional), Fish = "Minnow=10,Bass=5" (optional)
--         ├─ EggStands             Folder of BaseParts. Attr EggId (required, defaults to the world's first egg)
--         └─ Portals               Folder of BaseParts. Attr TargetWorld (required)
--
-- If a folder exists but holds no BaseParts, the defaults from Config/Worlds
-- are generated into it.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Eggs = require(Shared.Config.Eggs)
local Fish = require(Shared.Config.Fish)
local Ores = require(Shared.Config.Ores)
local RebirthConfig = require(Shared.Config.Rebirth)
local Worlds = require(Shared.Config.Worlds)
local Network = require(Shared.Network)
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)
local FishingService = require(script.Parent.FishingService)
local MiningService = require(script.Parent.MiningService)
local RebirthService = require(script.Parent.RebirthService)

local WorldService = {}

WorldService.CONTAINER_NAME = "Worlds"
WorldService.EGG_TAG = "EggStand"
WorldService.PORTAL_TAG = "Portal"

local FOLDERS = {
	ORES = "OreNodes",
	FISHING = "FishingSpots",
	EGGS = "EggStands",
	PORTALS = "Portals",
}

local spawnPoints: { [string]: Vector3 } = {}
local rng = Random.new()

local function notify(player: Player, message: string, kind: string?)
	Network.event("Notify"):FireClient(player, message, kind or "info")
end

-- Helpers --------------------------------------------------------------------

local function ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function basePartsOf(folder: Instance): { BasePart }
	local parts = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	return parts
end

-- Parses "Stone=10,Coal=4" into { Stone = 10, Coal = 4 }, dropping ids not in `valid`.
local function parseWeights(text: any, valid: { [string]: any }, context: string): { [string]: number }?
	if type(text) ~= "string" or text == "" then
		return nil
	end
	local weights = {}
	for entry in text:gmatch("[^,]+") do
		local id, weight = entry:match("^%s*([%w_]+)%s*=%s*([%d%.]+)%s*$")
		if id and valid[id] then
			weights[id] = tonumber(weight) or 1
		else
			warn(`[WorldService] ignoring "{entry}" in {context} (unknown id or bad format)`)
		end
	end
	return if next(weights) then weights else nil
end

-- Inverse of parseWeights, used so generated parts carry the same attribute a
-- designer would type by hand.
local function serializeWeights(weights: { [string]: number }): string
	local entries = {}
	for id, weight in weights do
		table.insert(entries, `{id}={weight}`)
	end
	table.sort(entries)
	return table.concat(entries, ",")
end

local function makeLabel(parent: BasePart, text: string, color: Color3?, offsetY: number?)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromScale(10, 2.5)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, offsetY or parent.Size.Y / 2 + 3, 0)
	billboard.MaxDistance = 90
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = billboard
	billboard.Parent = parent
	return billboard
end

local function newPart(name: string, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- World pieces -------------------------------------------------------------------

local function setupGround(def, folder: Folder): Vector3
	local ground = folder:FindFirstChild("Ground")
	if ground and ground:IsA("BasePart") then
		-- Hand-placed map: treat the top centre of the ground as the world origin.
		return ground.Position + Vector3.new(0, ground.Size.Y / 2, 0)
	end
	ground = newPart("Ground", folder)
	ground.Size = def.groundSize
	ground.Position = def.origin + Vector3.new(0, -def.groundSize.Y / 2, 0)
	ground.Color = def.groundColor
	ground.Material = Enum.Material.Grass
	return def.origin
end

local function setupSpawn(def, folder: Folder, origin: Vector3)
	local spawn = folder:FindFirstChild("Spawn")
	if spawn and spawn:IsA("BasePart") then
		spawnPoints[def.id] = spawn.Position + Vector3.new(0, spawn.Size.Y / 2, 0)
		return
	end
	if def.requiredRebirths == 0 then
		local location = Instance.new("SpawnLocation")
		location.Name = "Spawn"
		location.Anchored = true
		location.Size = Vector3.new(12, 1, 12)
		location.Position = origin + Vector3.new(0, 0.5, 0)
		location.Color = Color3.fromRGB(230, 230, 230)
		location.Material = Enum.Material.SmoothPlastic
		location.Duration = 0
		location.Parent = folder
	end
	spawnPoints[def.id] = origin + def.spawnOffset
end

local function setupSign(def, folder: Folder, origin: Vector3)
	if folder:FindFirstChild("Sign") then
		return
	end
	local sign = newPart("Sign", folder)
	sign.CanCollide = false
	sign.Transparency = 1
	sign.Size = Vector3.new(1, 1, 1)
	sign.Position = origin + Vector3.new(0, 14, 0)
	makeLabel(sign, def.name, def.currency.color, 0).Size = UDim2.fromScale(20, 5)
end

local function setupOreNodes(def, folder: Folder, origin: Vector3)
	local nodesFolder = ensureFolder(folder, FOLDERS.ORES)
	local parts = basePartsOf(nodesFolder)

	if #parts == 0 then
		for _, spawn in def.oreSpawns do
			local part = newPart("OreNode", nodesFolder)
			part.Position = origin + spawn.position + Vector3.new(0, 2, 0)
			part.Orientation = Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(0, 360), rng:NextNumber(-10, 10))
			part:SetAttribute("Ores", serializeWeights(spawn.ores))
			table.insert(parts, part)
		end
	end

	for _, part in parts do
		local weights = parseWeights(part:GetAttribute("Ores"), Ores, part:GetFullName()) or def.defaultOres
		MiningService.RegisterNode(def.id, part, weights)
	end
end

local function setupFishingSpots(def, folder: Folder, origin: Vector3)
	local spotsFolder = ensureFolder(folder, FOLDERS.FISHING)
	local parts = basePartsOf(spotsFolder)

	if #parts == 0 then
		for _, spot in def.fishingSpots do
			local part = newPart(spot.id, spotsFolder)
			part.CanCollide = false
			part.Size = spot.size
			part.Position = origin + spot.position
			part.Color = Color3.fromRGB(50, 120, 220)
			part.Material = Enum.Material.Glass
			part.Transparency = 0.35
			part:SetAttribute("Fish", serializeWeights(spot.fish))
			part:SetAttribute("SpotId", spot.id)
			table.insert(parts, part)
		end
	end

	for _, part in parts do
		local spotId = part:GetAttribute("SpotId")
		if type(spotId) ~= "string" or spotId == "" then
			spotId = `{def.id}_{part.Name}`
		end
		local weights = parseWeights(part:GetAttribute("Fish"), Fish, part:GetFullName()) or def.defaultFish
		FishingService.RegisterSpot(def.id, spotId, part, weights)
		if not part:FindFirstChild("Label") then
			makeLabel(part, "Fishing", Color3.fromRGB(150, 200, 255), 4)
		end
	end
end

local function firstEggFor(worldId: string): string?
	local ids = {}
	for id, egg in Eggs do
		if egg.worldId == worldId then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids[1]
end

local function setupEggStands(def, folder: Folder, origin: Vector3)
	local standsFolder = ensureFolder(folder, FOLDERS.EGGS)
	local parts = basePartsOf(standsFolder)

	if #parts == 0 then
		for _, stand in def.eggStands do
			local egg = Eggs[stand.eggId]
			local part = newPart(`EggStand_{stand.eggId}`, standsFolder)
			part.Shape = Enum.PartType.Ball
			part.Size = Vector3.new(5, 5, 5)
			part.Position = origin + stand.position + Vector3.new(0, 3, 0)
			part.Color = egg.color
			part.Material = Enum.Material.SmoothPlastic
			part:SetAttribute("EggId", stand.eggId)
			table.insert(parts, part)
		end
	end

	for _, part in parts do
		local eggId = part:GetAttribute("EggId")
		if not Eggs[eggId] then
			eggId = firstEggFor(def.id)
			if not eggId then
				warn(`[WorldService] {part:GetFullName()} has no valid EggId and {def.id} has no eggs`)
				continue
			end
			part:SetAttribute("EggId", eggId)
		end
		local egg = Eggs[eggId]
		part.Anchored = true
		local prompt = part:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
		prompt.ActionText = "Open egg"
		prompt.ObjectText = `{egg.name} ({Format.commas(egg.cost)} {def.currency.name})`
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
		CollectionService:AddTag(part, WorldService.EGG_TAG)
		if not part:FindFirstChild("Label") then
			makeLabel(part, egg.name, egg.color)
		end
	end
end

local function setupPortals(def, folder: Folder, origin: Vector3)
	local portalsFolder = ensureFolder(folder, FOLDERS.PORTALS)
	local parts = basePartsOf(portalsFolder)

	if #parts == 0 then
		for _, portal in def.portals do
			local target = Worlds[portal.targetWorld]
			local part = newPart(`Portal_{portal.targetWorld}`, portalsFolder)
			part.CanCollide = false
			part.Size = Vector3.new(8, 12, 1)
			part.Position = origin + portal.position + Vector3.new(0, 6, 0)
			part.Color = target.currency.color
			part.Material = Enum.Material.Neon
			part.Transparency = 0.3
			part:SetAttribute("TargetWorld", portal.targetWorld)
			table.insert(parts, part)
		end
	end

	for _, part in parts do
		local targetId = part:GetAttribute("TargetWorld")
		local target = Worlds[targetId]
		if not target then
			warn(`[WorldService] {part:GetFullName()} needs a TargetWorld attribute naming a world in Config/Worlds`)
			continue
		end
		part.Anchored = true
		local prompt = part:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
		prompt.ActionText = "Travel"
		prompt.ObjectText = if target.requiredRebirths > 0
			then `{target.name} (Rebirth {target.requiredRebirths}+)`
			else target.name
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
		prompt.Triggered:Connect(function(player)
			WorldService.Teleport(player, targetId)
		end)
		CollectionService:AddTag(part, WorldService.PORTAL_TAG)
		if not part:FindFirstChild("Label") then
			makeLabel(part, `To {target.name}`, target.currency.color)
		end
	end
end

local function setupWorld(def, container: Folder)
	local folder = ensureFolder(container, def.id)
	local origin = setupGround(def, folder)
	setupSpawn(def, folder, origin)
	setupSign(def, folder, origin)
	setupOreNodes(def, folder, origin)
	setupFishingSpots(def, folder, origin)
	setupEggStands(def, folder, origin)
	setupPortals(def, folder, origin)
end

-- Teleporting ----------------------------------------------------------------

local function moveCharacter(player: Player, worldId: string)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local spawnPos = spawnPoints[worldId]
	if root and spawnPos then
		root.CFrame = CFrame.new(spawnPos + Vector3.new(0, 3, 0))
	end
end

function WorldService.Teleport(player: Player, worldId: string)
	local def = Worlds[worldId]
	local profile = DataService.Get(player)
	if not def or not profile then
		return
	end
	if profile.rebirths < def.requiredRebirths then
		notify(player, `{def.name} unlocks at Rebirth {def.requiredRebirths}`, "error")
		return
	end
	if profile.currentWorld ~= worldId then
		profile.currentWorld = worldId
		DataService.MarkDirty(player)
	end
	moveCharacter(player, worldId)
	notify(player, `Welcome to {def.name}`, "info")
end

-- Lifecycle --------------------------------------------------------------------

function WorldService.Init()
	local container = ensureFolder(Workspace, WorldService.CONTAINER_NAME)

	local ordered = {}
	for _, def in Worlds do
		table.insert(ordered, def)
	end
	table.sort(ordered, function(a, b)
		return a.order < b.order
	end)
	for _, def in ordered do
		setupWorld(def, container)
	end
end

function WorldService.Start()
	local function onCharacter(player: Player)
		local profile = DataService.WaitFor(player)
		if profile and profile.currentWorld ~= RebirthConfig.HOME_WORLD then
			task.wait(0.1)
			moveCharacter(player, profile.currentWorld)
		end
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			onCharacter(player)
		end)
	end)

	RebirthService.OnRebirth:Connect(function(player)
		moveCharacter(player, RebirthConfig.HOME_WORLD)
	end)
end

return WorldService
