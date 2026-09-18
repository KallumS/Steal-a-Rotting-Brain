--[[
	RebirthService
	Hold the prompt at the Crypt of Rebirth once you are rich enough and
	you trade every brain you own -- and your cash -- for a permanent
	income multiplier and a longer gate lock.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local RebirthService = {}

function RebirthService:TryRebirth(player: Player)
	local feedback = self.Services.FeedbackService
	local profile = self.Services.DataService:Get(player)
	if not profile then
		return
	end

	if profile.Rebirths >= Config.Rebirth.MaxRebirths then
		feedback:Notify(player, "You have maxed out rebirths. Legend.", "info")
		return
	end

	local requirement = Config.RebirthRequirement(profile.Rebirths)
	if profile.Cash < requirement then
		feedback:Notify(
			player,
			`Rebirth {profile.Rebirths + 1} needs {Format.Cash(requirement)} -- you are {Format.Cash(requirement - profile.Cash)} short.`,
			"bad"
		)
		return
	end

	local plot = self.Services.PlotService:GetPlotByOwner(player)
	if not plot then
		feedback:Notify(player, "You need a graveyard before you can rebirth.", "bad")
		return
	end

	-- Anything in their hands goes back to its owner first.
	if self.Services.StealService:IsCarrying(player) then
		self.Services.StealService:ReturnCarried(player, "rebirth")
	end

	-- Wipe the graveyard.
	for slotIndex = 1, Config.SlotCount do
		local record = plot.Slots[slotIndex].Record
		if record then
			self.Services.BrainService:RemoveFromSlot(plot, slotIndex)
			self.Services.BrainService:DestroyRecord(record)
		end
	end

	profile.Rebirths += 1
	profile.Stats.Rebirths += 1
	profile.Slots = {}
	self.Services.EconomyService:SetCash(player, Config.Currency.StartingCash)

	local multiplier = Config.IncomeMultiplier(profile.Rebirths)
	local lockDuration = Config.LockDuration(profile.Rebirths)

	self.Services.ZombieService:RefreshNametag(player)
	self.Services.PlotService:UpdateSign(plot)
	self.Services.EconomyService:PushState(player)

	feedback:Effect(player, "rebirth")
	feedback:Notify(
		player,
		`REBIRTH {profile.Rebirths}! Income x{string.format("%.2f", multiplier)}, gate lock {Format.Clock(lockDuration)}.`,
		"good"
	)
	feedback:NotifyAll(`{player.DisplayName} hit Rebirth {profile.Rebirths}!`, "info")

	task.spawn(function()
		self.Services.DataService:Save(player)
	end)
end

function RebirthService:Init() end

function RebirthService:Start()
	local shrine = self.Services.WorldBuilder.Shrine

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RebirthPrompt"
	prompt.ActionText = "Rebirth"
	prompt.ObjectText = "Crypt of Rebirth"
	prompt.HoldDuration = 1.5
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = shrine.PromptPart

	prompt.Triggered:Connect(function(player)
		local ok, err = pcall(function()
			self:TryRebirth(player)
		end)
		if not ok then
			warn(`[RebirthService] rebirth error for {player.Name}: {err}`)
		end
	end)

	shrine.Detail.Text = string.format(
		"First rebirth: %s  |  +%d%% income and +%ds lock each time",
		Format.Cash(Config.Rebirth.BaseRequirement),
		math.floor(Config.Rebirth.IncomeMultiplierPerRebirth * 100),
		Config.Lock.DurationPerRebirth
	)
end

return RebirthService
