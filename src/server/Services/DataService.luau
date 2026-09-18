--[[
	DataService
	Loads, holds and saves player profiles. Other services never touch
	DataStores directly: they read the live profile table and register
	a save hook if they own data that needs serialising first.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Signal)

local STORE_NAME = "RottingBrains_Profiles_v1"
local KEY_PREFIX = "player_"
local LOAD_ATTEMPTS = 4
local SAVE_ATTEMPTS = 3

local DataService = {}

DataService.ProfileLoaded = Signal.new()
DataService.ProfileReleased = Signal.new()

local profiles: { [Player]: any } = {}
local saveHooks: { (Player, any) -> () } = {}
local store: DataStore? = nil

local function defaultProfile()
	return {
		Cash = Config.Currency.StartingCash,
		Rebirths = 0,
		TotalEarned = 0,
		Slots = {}, -- { { Slot = n, BrainId = s, VariantId = s, ColorIndex = n } }
		Stats = {
			Purchased = 0,
			Stolen = 0,
			Lost = 0,
			Rebirths = 0,
		},
		SaveDisabled = false,
	}
end

-- Fill in anything a stored profile is missing (new fields, old saves).
local function reconcile(data: any)
	local template = defaultProfile()

	if type(data) ~= "table" then
		return template
	end

	for key, value in pairs(template) do
		if data[key] == nil then
			data[key] = value
		elseif key == "Stats" and type(data.Stats) == "table" then
			for statKey, statValue in pairs(template.Stats) do
				if data.Stats[statKey] == nil then
					data.Stats[statKey] = statValue
				end
			end
		end
	end

	if type(data.Slots) ~= "table" then
		data.Slots = {}
	end

	data.Cash = math.max(0, tonumber(data.Cash) or 0)
	data.Rebirths = math.clamp(math.floor(tonumber(data.Rebirths) or 0), 0, Config.Rebirth.MaxRebirths)
	data.SaveDisabled = false

	return data
end

-- Only plain, serialisable fields go to the DataStore.
local function serialize(profile: any)
	local slots = {}
	for _, entry in ipairs(profile.Slots) do
		table.insert(slots, {
			Slot = entry.Slot,
			BrainId = entry.BrainId,
			VariantId = entry.VariantId,
			ColorIndex = entry.ColorIndex,
		})
	end

	return {
		Cash = math.floor(profile.Cash),
		Rebirths = profile.Rebirths,
		TotalEarned = math.floor(profile.TotalEarned),
		Slots = slots,
		Stats = {
			Purchased = profile.Stats.Purchased,
			Stolen = profile.Stats.Stolen,
			Lost = profile.Stats.Lost,
			Rebirths = profile.Stats.Rebirths,
		},
	}
end

local function loadProfile(player: Player)
	if not store then
		local profile = defaultProfile()
		profile.SaveDisabled = true
		return profile
	end

	local key = KEY_PREFIX .. player.UserId

	for attempt = 1, LOAD_ATTEMPTS do
		local ok, result = pcall(function()
			return (store :: DataStore):GetAsync(key)
		end)

		if ok then
			return reconcile(result)
		end

		warn(`[DataService] load attempt {attempt} failed for {player.Name}: {result}`)
		if attempt < LOAD_ATTEMPTS then
			task.wait(2 ^ attempt)
		end
	end

	-- Give them a playable session, but never overwrite the real save.
	local profile = defaultProfile()
	profile.SaveDisabled = true
	return profile
end

function DataService:RegisterSaveHook(hook: (Player, any) -> ())
	table.insert(saveHooks, hook)
end

function DataService:Get(player: Player)
	return profiles[player]
end

function DataService:IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function DataService:Save(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end

	for _, hook in ipairs(saveHooks) do
		local ok, err = pcall(hook, player, profile)
		if not ok then
			warn(`[DataService] save hook error for {player.Name}: {err}`)
		end
	end

	if profile.SaveDisabled or not store then
		return
	end

	local payload = serialize(profile)
	local key = KEY_PREFIX .. player.UserId

	for attempt = 1, SAVE_ATTEMPTS do
		local ok, err = pcall(function()
			(store :: DataStore):SetAsync(key, payload, { player.UserId })
		end)

		if ok then
			return
		end

		warn(`[DataService] save attempt {attempt} failed for {player.Name}: {err}`)
		if attempt < SAVE_ATTEMPTS then
			task.wait(2 ^ attempt)
		end
	end
end

function DataService:Release(player: Player)
	self:Save(player)
	profiles[player] = nil
	DataService.ProfileReleased:Fire(player)
end

function DataService:Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)

	if ok then
		store = result
	else
		warn("[DataService] DataStores unavailable, running with temporary profiles: " .. tostring(result))
	end
end

function DataService:Start()
	-- Autosave loop.
	task.spawn(function()
		while true do
			task.wait(Config.Economy.AutosaveInterval)
			for player in pairs(profiles) do
				task.spawn(function()
					self:Save(player)
				end)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		for player in pairs(profiles) do
			self:Save(player)
		end
	end)
end

--[[
	Called by the bootstrap once every service has started, so nobody
	misses the ProfileLoaded signal for a player who was already here.
]]
function DataService:BeginSessions()
	local function onPlayerAdded(player: Player)
		local profile = loadProfile(player)

		-- They may have left while we were waiting on the DataStore.
		if not player:IsDescendantOf(Players) then
			return
		end

		profiles[player] = profile
		DataService.ProfileLoaded:Fire(player, profile)

		if profile.SaveDisabled then
			warn(`[DataService] {player.Name} is playing on a temporary profile`)
		end
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		self:Release(player)
	end)
end

return DataService
