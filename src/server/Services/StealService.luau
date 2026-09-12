--[[
	StealService
	The theft half of the loop: hold the prompt on someone else's grave
	to lift their brain, carry it home (slower, and visible to everyone),
	and drop it into a free grave of your own. Dying, logging off or
	taking a claw to the face sends it straight back to its owner.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local StealService = {}

-- carriers[player] = { Record, OriginPlotIndex, OriginSlotIndex, OriginOwnerId, StartedAt, LastWarning }
local carriers: { [Player]: any } = {}

--------------------------------------------------------------------
-- Queries
--------------------------------------------------------------------

function StealService:GetCarriedRecord(player: Player)
	local carry = carriers[player]
	return carry and carry.Record or nil
end

function StealService:IsCarrying(player: Player): boolean
	return carriers[player] ~= nil
end

function StealService:GetCarriers()
	return carriers
end

--------------------------------------------------------------------
-- Prompts
--------------------------------------------------------------------

local function refreshPromptForSlot(self: any, plot: any, slotIndex: number)
	local record = plot.Slots[slotIndex].Record
	if not record or not record.Model or not record.Model.PrimaryPart then
		return
	end

	local prompt = record.Model.PrimaryPart:FindFirstChild("StealPrompt")
	if not prompt then
		return
	end

	prompt.Enabled = not plot.Locked
	prompt.ActionText = plot.Locked and "Gate locked" or "Steal"
end

--[[
	Every brain sitting on a podium gets two prompts: E to steal it
	(anyone but the owner, and only while the gate is open) and X to
	scrap it for a partial refund (the owner only).
]]
function StealService:AddBrainPrompts(plot: any, slotIndex: number, record: any)
	local model = record.Model
	if not model or not model.PrimaryPart then
		return
	end

	local core = model.PrimaryPart
	local name = self.Services.BrainService:GetDisplayName(record)

	for _, promptName in ipairs({ "StealPrompt", "ScrapPrompt" }) do
		local existing = core:FindFirstChild(promptName)
		if existing then
			existing:Destroy()
		end
	end

	local steal = Instance.new("ProximityPrompt")
	steal.Name = "StealPrompt"
	steal.ActionText = "Steal"
	steal.ObjectText = name
	steal.HoldDuration = Config.Steal.HoldDuration
	steal.MaxActivationDistance = Config.Steal.MaxActivationDistance
	steal.RequiresLineOfSight = false
	steal.KeyboardKeyCode = Enum.KeyCode.E
	steal.Enabled = not plot.Locked
	steal.Parent = core

	steal.Triggered:Connect(function(player)
		self:TrySteal(player, plot, slotIndex)
	end)

	local scrap = Instance.new("ProximityPrompt")
	scrap.Name = "ScrapPrompt"
	scrap.ActionText = `Scrap {Format.Cash(Config.BrainScrapValue(record.BrainId, record.VariantId))}`
	scrap.ObjectText = name
	scrap.HoldDuration = Config.Scrap.HoldDuration
	scrap.MaxActivationDistance = Config.Steal.MaxActivationDistance
	scrap.RequiresLineOfSight = false
	scrap.KeyboardKeyCode = Enum.KeyCode.X
	scrap.Parent = core

	scrap.Triggered:Connect(function(player)
		self:TryScrap(player, plot, slotIndex)
	end)
end

-- Owners can scrap a brain for part of its price back, so a full
-- graveyard is never a dead end.
function StealService:TryScrap(player: Player, plot: any, slotIndex: number)
	local feedback = self.Services.FeedbackService
	local record = plot.Slots[slotIndex] and plot.Slots[slotIndex].Record
	if not record then
		return
	end

	if plot.Owner ~= player then
		feedback:Notify(player, "Only the owner can scrap that.", "bad")
		return
	end

	local name = self.Services.BrainService:GetDisplayName(record)
	local refund = Config.BrainScrapValue(record.BrainId, record.VariantId)

	self.Services.BrainService:RemoveFromSlot(plot, slotIndex)
	self.Services.BrainService:DestroyRecord(record)
	self.Services.EconomyService:AddCash(player, refund)

	feedback:Notify(player, `Scrapped {name} for {Format.Cash(refund)}.`, "info")
	feedback:Effect(player, "purchase")
	self.Services.EconomyService:PushState(player)
end

--------------------------------------------------------------------
-- Stealing
--------------------------------------------------------------------

function StealService:TrySteal(thief: Player, plot: any, slotIndex: number)
	local feedback = self.Services.FeedbackService
	local record = plot.Slots[slotIndex] and plot.Slots[slotIndex].Record
	if not record then
		return
	end

	if plot.Owner == thief then
		feedback:Notify(thief, "That one is already yours.", "info")
		return
	end

	if plot.Locked then
		feedback:Notify(thief, "That graveyard is locked shut.", "bad")
		return
	end

	if carriers[thief] then
		feedback:Notify(thief, "You can only carry one brain at a time.", "bad")
		return
	end

	local thiefPlot = self.Services.PlotService:GetPlotByOwner(thief)
	if not thiefPlot then
		feedback:Notify(thief, "You need your own graveyard first.", "bad")
		return
	end

	if Config.Steal.RequireFreeSlot and not self.Services.PlotService:GetFreeSlotIndex(thiefPlot) then
		feedback:Notify(thief, "No free graves at home -- nowhere to put it.", "bad")
		return
	end

	local victim = plot.Owner

	-- Lift it.
	self.Services.BrainService:RemoveFromSlot(plot, slotIndex)
	if not self.Services.BrainService:AttachToCharacter(thief, record) then
		-- Carrier vanished mid-steal: put it back where it came from.
		self.Services.BrainService:PlaceInSlot(plot, slotIndex, record)
		return
	end

	carriers[thief] = {
		Record = record,
		OriginPlotIndex = plot.Index,
		OriginSlotIndex = slotIndex,
		OriginOwnerId = victim and victim.UserId or nil,
		StartedAt = os.clock(),
		LastWarning = 0,
	}

	local name = self.Services.BrainService:GetDisplayName(record)

	local thiefProfile = self.Services.DataService:Get(thief)
	if thiefProfile then
		thiefProfile.Stats.Stolen += 1
	end

	feedback:Notify(thief, `Grabbed {name}! Run it back to your graveyard.`, "good")
	feedback:Effect(thief, "steal")

	if victim then
		local victimProfile = self.Services.DataService:Get(victim)
		if victimProfile then
			victimProfile.Stats.Lost += 1
		end
		feedback:Notify(victim, `{thief.DisplayName} is running off with your {name}!`, "bad")
		feedback:Effect(victim, "lost")
		self.Services.EconomyService:PushState(victim)
	end

	self.Services.ZombieService:SetCarrying(thief, name)
	self.Services.ZombieService:RefreshSpeed(thief)
	self.Services.EconomyService:PushState(thief)
end

--------------------------------------------------------------------
-- Finishing a carry
--------------------------------------------------------------------

local function clearCarry(self: any, player: Player)
	carriers[player] = nil
	self.Services.ZombieService:SetCarrying(player, nil)
	self.Services.ZombieService:RefreshSpeed(player)
end

function StealService:Deposit(player: Player): boolean
	local carry = carriers[player]
	if not carry then
		return false
	end

	local plot = self.Services.PlotService:GetPlotByOwner(player)
	if not plot then
		return false
	end

	local record = carry.Record
	self.Services.BrainService:DetachFromCharacter(record)

	local slotIndex = self.Services.BrainService:PlaceInFreeSlot(plot, record)
	if not slotIndex then
		-- Keep carrying it; they need to free up a grave.
		self.Services.BrainService:AttachToCharacter(player, record)
		if os.clock() - carry.LastWarning > 6 then
			carry.LastWarning = os.clock()
			self.Services.FeedbackService:Notify(player, "No free graves -- your graveyard is full!", "bad")
		end
		return false
	end

	clearCarry(self, player)

	local name = self.Services.BrainService:GetDisplayName(record)
	self.Services.FeedbackService:Notify(
		player,
		`{name} is yours now (+{Format.Cash(self.Services.BrainService:GetIncome(record))}/s)`,
		"good"
	)
	self.Services.FeedbackService:Effect(player, "deposit")
	self.Services.EconomyService:PushState(player)

	return true
end

-- Send whatever `player` is carrying back to the graveyard it came from.
function StealService:ReturnCarried(player: Player, reason: string?)
	local carry = carriers[player]
	if not carry then
		return
	end

	local record = carry.Record
	local name = self.Services.BrainService:GetDisplayName(record)

	self.Services.BrainService:DetachFromCharacter(record)
	clearCarry(self, player)

	local originPlot = self.Services.PlotService:GetPlotByIndex(carry.OriginPlotIndex)
	local ownerStillThere = originPlot
		and originPlot.Owner
		and carry.OriginOwnerId
		and originPlot.Owner.UserId == carry.OriginOwnerId

	if ownerStillThere then
		local placed = false
		if not originPlot.Slots[carry.OriginSlotIndex].Record then
			placed = self.Services.BrainService:PlaceInSlot(originPlot, carry.OriginSlotIndex, record)
		end
		if not placed then
			placed = self.Services.BrainService:PlaceInFreeSlot(originPlot, record) ~= nil
		end

		if placed then
			self.Services.FeedbackService:Notify(originPlot.Owner, `{name} was returned to your graveyard!`, "good")
			self.Services.FeedbackService:Effect(originPlot.Owner, "returned")
			self.Services.EconomyService:PushState(originPlot.Owner)
		else
			self.Services.BrainService:DestroyRecord(record)
			self.Services.FeedbackService:Notify(originPlot.Owner, `{name} rotted away -- your graveyard was full.`, "bad")
		end
	else
		-- Nobody left to return it to.
		self.Services.BrainService:DestroyRecord(record)
	end

	if reason == "attacked" then
		self.Services.FeedbackService:Notify(player, `You dropped {name}!`, "bad")
	elseif reason == "died" then
		self.Services.FeedbackService:Notify(player, `You died and lost {name}.`, "bad")
	end

	self.Services.EconomyService:PushState(player)
end

--------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------

function StealService:Init() end

function StealService:Start()
	-- Every brain that lands on a podium becomes stealable.
	self.Services.BrainService.Placed:Connect(function(plot, slotIndex, record)
		self:AddBrainPrompts(plot, slotIndex, record)
	end)

	self.Services.PlotService.LockChanged:Connect(function(plot)
		for slotIndex = 1, Config.SlotCount do
			refreshPromptForSlot(self, plot, slotIndex)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid and humanoid:IsA("Humanoid") then
				humanoid.Died:Connect(function()
					if Config.Steal.ReturnOnDeath then
						self:ReturnCarried(player, "died")
					end
				end)
			end
		end)

		player.CharacterRemoving:Connect(function()
			if carriers[player] then
				self:ReturnCarried(player, "died")
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if carriers[player] then
			self:ReturnCarried(player, "left")
		end
		carriers[player] = nil
	end)

	-- Auto-deposit when a carrier steps into their own graveyard.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		accumulator += deltaTime
		if accumulator < 0.25 then
			return
		end
		accumulator = 0

		for player, carry in pairs(carriers) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")

			if not root then
				continue
			end

			local plot = self.Services.PlotService:GetPlotByOwner(player)
			if plot and self.Services.PlotService:IsInside(plot, (root :: BasePart).Position) then
				self:Deposit(player)
			elseif carry.Record.Location ~= "carried" then
				-- Safety net: the model lost its carry state somehow.
				self:ReturnCarried(player, "lost")
			end
		end
	end)
end

return StealService
