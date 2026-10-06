--!nonstrict
-- Player profile persistence. Uses a plain DataStore in live servers and an
-- in-memory mock in Studio (or when the DataStore API is unavailable), so the
-- game is fully playable in a Studio test session with no API access.
--
-- Public API:
--   DataService.Get(player) -> Profile?             (nil until loaded)
--   DataService.WaitFor(player, timeout?) -> Profile?
--   DataService.MarkDirty(player)                   (replicate + save later)
--   DataService.ProfileLoaded : Signal<Player, Profile>

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Rebirth = require(Shared.Config.Rebirth)
local Network = require(Shared.Network)
local Signal = require(Shared.Util.Signal)
local TableUtil = require(Shared.Util.TableUtil)
local Types = require(Shared.Types)

type Profile = Types.Profile

local DataService = {}
DataService.ProfileLoaded = Signal.new()

local profiles: { [Player]: Profile } = {}
local dirty: { [Player]: boolean } = {}
local saveable: { [Player]: boolean } = {}

local PROFILE_TEMPLATE: Profile = {
	version = GameConfig.DATA_VERSION,
	coins = {},
	rebirths = 0,
	currentWorld = Rebirth.HOME_WORLD,
	stats = {
		OresMined = 0,
		FishCaught = 0,
		EggsHatched = 0,
		RareFinds = 0,
	},
	lifetime = {
		CoinsEarned = 0,
		OresMined = 0,
		FishCaught = 0,
		EggsHatched = 0,
		Rebirths = 0,
	},
	pets = {},
	equipped = {},
}

-- Store backend --------------------------------------------------------------

local MockStore = {}
MockStore.__index = MockStore

function MockStore.new()
	return setmetatable({ data = {} }, MockStore)
end

function MockStore:GetAsync(key: string)
	return self.data[key]
end

function MockStore:SetAsync(key: string, value: any)
	self.data[key] = value
end

local store
local usingMock = false

local function resolveStore()
	if RunService:IsStudio() then
		usingMock = true
		store = MockStore.new()
		warn("[DataService] Studio detected: using in-memory mock DataStore (progress is not saved)")
		return
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		usingMock = true
		store = MockStore.new()
		warn("[DataService] DataStore unavailable, using mock:", result)
	end
end

local function keyFor(player: Player): string
	return `player_{player.UserId}`
end

-- Load / save ----------------------------------------------------------------

local function freshProfile(): Profile
	return TableUtil.deepCopy(PROFILE_TEMPLATE)
end

local function load(player: Player)
	local key = keyFor(player)
	local ok, data = pcall(function()
		return store:GetAsync(key)
	end)

	local profile: Profile
	if ok then
		if type(data) == "table" then
			profile = data
			TableUtil.reconcile(profile, PROFILE_TEMPLATE)
			profile.version = GameConfig.DATA_VERSION
		else
			profile = freshProfile()
		end
		saveable[player] = true
	else
		-- Never overwrite real data with a fresh profile if the load failed.
		warn(`[DataService] failed to load {player.Name}: {data}`)
		profile = freshProfile()
		saveable[player] = false
	end

	if not player:IsDescendantOf(Players) then
		return
	end

	profiles[player] = profile
	DataService.ProfileLoaded:Fire(player, profile)
	DataService.Replicate(player)
end

local function save(player: Player)
	local profile = profiles[player]
	if not profile or not saveable[player] then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync(keyFor(player), profile)
	end)
	if ok then
		dirty[player] = nil
	else
		warn(`[DataService] failed to save {player.Name}: {err}`)
	end
end

-- Public API -----------------------------------------------------------------

function DataService.Get(player: Player): Profile?
	return profiles[player]
end

function DataService.WaitFor(player: Player, timeout: number?): Profile?
	local deadline = os.clock() + (timeout or 10)
	while not profiles[player] and os.clock() < deadline and player:IsDescendantOf(Players) do
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService.Replicate(player: Player)
	local profile = profiles[player]
	if profile then
		Network.event("ProfileChanged"):FireClient(player, profile)
	end
end

function DataService.MarkDirty(player: Player)
	dirty[player] = true
	DataService.Replicate(player)
end

function DataService.IsUsingMock(): boolean
	return usingMock
end

-- Lifecycle ------------------------------------------------------------------

function DataService.Init()
	resolveStore()

	Network.func("GetProfile").OnServerInvoke = function(player: Player)
		return DataService.WaitFor(player)
	end
end

function DataService.Start()
	local function onPlayerAdded(player: Player)
		task.spawn(load, player)
	end

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)

	Players.PlayerRemoving:Connect(function(player: Player)
		save(player)
		profiles[player] = nil
		dirty[player] = nil
		saveable[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(GameConfig.AUTOSAVE_INTERVAL)
			for player in dirty do
				save(player)
			end
		end
	end)

	game:BindToClose(function()
		if usingMock then
			return
		end
		for player in profiles do
			save(player)
		end
	end)
end

return DataService
