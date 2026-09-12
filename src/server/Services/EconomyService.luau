--[[
	EconomyService
	Owns cash: passive income from graveyards, spending, leaderstats and
	the once-a-second state push that drives the client HUD.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local EconomyService = {}

local stateRemote: RemoteEvent

local function ensureLeaderstats(player: Player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end

	local cash = stats:FindFirstChild("Cash")
	if not cash then
		cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Parent = stats
	end

	local rebirths = stats:FindFirstChild("Rebirths")
	if not rebirths then
		rebirths = Instance.new("IntValue")
		rebirths.Name = "Rebirths"
		rebirths.Parent = stats
	end

	return cash :: IntValue, rebirths :: IntValue
end

function EconomyService:Init()
	stateRemote = Remotes.Event("StateUpdate")
end

--------------------------------------------------------------------
-- Cash
--------------------------------------------------------------------

function EconomyService:GetCash(player: Player): number
	local profile = self.Services.DataService:Get(player)
	return profile and profile.Cash or 0
end

function EconomyService:AddCash(player: Player, amount: number)
	local profile = self.Services.DataService:Get(player)
	if not profile or amount == 0 then
		return
	end

	profile.Cash = math.max(0, profile.Cash + amount)
	if amount > 0 then
		profile.TotalEarned += amount
	end
end

function EconomyService:TrySpend(player: Player, amount: number): boolean
	local profile = self.Services.DataService:Get(player)
	if not profile or profile.Cash < amount then
		return false
	end

	profile.Cash -= amount
	return true
end

function EconomyService:SetCash(player: Player, amount: number)
	local profile = self.Services.DataService:Get(player)
	if profile then
		profile.Cash = math.max(0, amount)
	end
end

--------------------------------------------------------------------
-- Income
--------------------------------------------------------------------

-- Cash per second, including the permanent rebirth multiplier.
function EconomyService:GetIncomePerSecond(player: Player): number
	local profile = self.Services.DataService:Get(player)
	if not profile then
		return 0
	end

	local plot = self.Services.PlotService:GetPlotByOwner(player)
	if not plot then
		return 0
	end

	return self.Services.PlotService:GetPlotIncome(plot) * Config.IncomeMultiplier(profile.Rebirths)
end

--------------------------------------------------------------------
-- State replication
--------------------------------------------------------------------

function EconomyService:BuildState(player: Player)
	local profile = self.Services.DataService:Get(player)
	if not profile then
		return nil
	end

	local plotService = self.Services.PlotService
	local plot = plotService:GetPlotByOwner(player)
	local carried = self.Services.StealService:GetCarriedRecord(player)

	return {
		Cash = math.floor(profile.Cash),
		Income = self:GetIncomePerSecond(player),
		Rebirths = profile.Rebirths,
		RebirthRequirement = Config.RebirthRequirement(profile.Rebirths),
		IncomeMultiplier = Config.IncomeMultiplier(profile.Rebirths),
		MaxRebirths = Config.Rebirth.MaxRebirths,
		Brains = plot and plotService:CountBrains(plot) or 0,
		Slots = Config.SlotCount,
		PlotIndex = plot and plot.Index or nil,
		Locked = plot and plot.Locked or false,
		LockRemaining = plot and plotService:GetLockRemaining(plot) or 0,
		LockCooldown = plot and plotService:GetLockCooldownRemaining(plot) or 0,
		LockDuration = Config.LockDuration(profile.Rebirths),
		Carrying = carried and self.Services.BrainService:GetDisplayName(carried) or nil,
		Stats = profile.Stats,
		SaveDisabled = profile.SaveDisabled or false,
	}
end

function EconomyService:PushState(player: Player)
	local state = self:BuildState(player)
	if not state then
		return
	end

	local cash, rebirths = ensureLeaderstats(player)
	cash.Value = math.clamp(state.Cash, 0, 2 ^ 31 - 1)
	rebirths.Value = state.Rebirths

	stateRemote:FireClient(player, state)
end

function EconomyService:PushAll()
	for _, player in ipairs(Players:GetPlayers()) do
		self:PushState(player)
	end
end

function EconomyService:Start()
	self.Services.DataService.ProfileLoaded:Connect(function(player)
		ensureLeaderstats(player)
		self:PushState(player)
	end)

	-- Passive income + HUD refresh.
	task.spawn(function()
		local interval = Config.Economy.IncomeInterval
		while true do
			task.wait(interval)

			for _, player in ipairs(Players:GetPlayers()) do
				local profile = self.Services.DataService:Get(player)
				if profile then
					local income = self:GetIncomePerSecond(player)
					if income > 0 then
						self:AddCash(player, income * interval)
					end
					self:PushState(player)
				end
			end
		end
	end)
end

return EconomyService
