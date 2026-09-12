--[[
	PlotService
	Hands out graveyards, tracks what sits in each grave slot, and owns
	the gate-locking rules. It is the source of truth for "who owns what"
	and "can this brain be stolen right now".
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Signal = require(Shared.Signal)

local PlotService = {}

PlotService.LockChanged = Signal.new() -- (plot)
PlotService.SlotChanged = Signal.new() -- (plot, slotIndex, record?)
PlotService.PlotAssigned = Signal.new() -- (player, plot)

local plots: { any } = {}
local plotsByOwner: { [Player]: any } = {}

--------------------------------------------------------------------
-- Lookups
--------------------------------------------------------------------

function PlotService:GetPlots()
	return plots
end

function PlotService:GetPlotByIndex(index: number)
	return plots[index]
end

function PlotService:GetPlotByOwner(player: Player)
	return plotsByOwner[player]
end

-- Which graveyard, if any, contains this world position.
function PlotService:GetPlotAt(position: Vector3)
	for _, plot in ipairs(plots) do
		if self:IsInside(plot, position) then
			return plot
		end
	end
	return nil
end

function PlotService:IsInside(plot: any, position: Vector3): boolean
	local localPosition = plot.CFrame:PointToObjectSpace(position)
	local half = Config.Plot.Size / 2 - Config.Plot.BoundsPadding

	return math.abs(localPosition.X) <= half
		and math.abs(localPosition.Z) <= half
		and localPosition.Y > -8
		and localPosition.Y < 40
end

function PlotService:GetFreeSlotIndex(plot: any): number?
	for index = 1, Config.SlotCount do
		if not plot.Slots[index].Record then
			return index
		end
	end
	return nil
end

function PlotService:CountBrains(plot: any): number
	local count = 0
	for index = 1, Config.SlotCount do
		if plot.Slots[index].Record then
			count += 1
		end
	end
	return count
end

-- Base income per second, before the owner's rebirth multiplier.
function PlotService:GetPlotIncome(plot: any): number
	local total = 0
	for index = 1, Config.SlotCount do
		local record = plot.Slots[index].Record
		if record then
			total += Config.BrainIncome(record.BrainId, record.VariantId)
		end
	end
	return total
end

--------------------------------------------------------------------
-- Slots
--------------------------------------------------------------------

function PlotService:SetSlotRecord(plot: any, slotIndex: number, record: any?)
	local slot = plot.Slots[slotIndex]
	if not slot then
		return
	end

	slot.Record = record

	local brain = record and Config.GetBrain(record.BrainId)
	if record and brain then
		local rarity = Config.GetRarity(brain.Rarity)
		slot.Label.Text = string.format(
			"%s\n%s/s",
			self.Services.BrainService:GetDisplayName(record),
			Format.Cash(Config.BrainIncome(record.BrainId, record.VariantId))
		)
		slot.Label.TextColor3 = rarity.Color
		slot.Label.TextTransparency = 0
		slot.Light.Color = rarity.Color
		slot.Light.Brightness = 2
	else
		slot.Label.Text = `GRAVE {slotIndex}`
		slot.Label.TextColor3 = Color3.fromRGB(140, 140, 140)
		slot.Label.TextTransparency = 0.25
		slot.Light.Brightness = 0
	end

	self:UpdateSign(plot)
	PlotService.SlotChanged:Fire(plot, slotIndex, record)
end

function PlotService:SerializeSlots(plot: any)
	local list = {}
	for index = 1, Config.SlotCount do
		local record = plot.Slots[index].Record
		if record then
			table.insert(list, {
				Slot = index,
				BrainId = record.BrainId,
				VariantId = record.VariantId,
				ColorIndex = record.ColorIndex,
			})
		end
	end
	return list
end

--------------------------------------------------------------------
-- Signs
--------------------------------------------------------------------

function PlotService:UpdateSign(plot: any)
	local sign = plot.Sign
	local owner = plot.Owner

	if not owner then
		sign.Owner.Text = `GRAVEYARD {plot.Index}`
		sign.Owner.TextColor3 = Color3.fromRGB(150, 150, 150)
		sign.Income.Text = "$0/s"
		sign.Brains.Text = `0 / {Config.SlotCount} brains`
		sign.Status.Text = "UNCLAIMED"
		sign.Status.TextColor3 = Color3.fromRGB(160, 160, 160)
		return
	end

	local profile = self.Services.DataService:Get(owner)
	local multiplier = profile and Config.IncomeMultiplier(profile.Rebirths) or 1

	sign.Owner.Text = string.upper(owner.DisplayName) .. "'S ROT FARM"
	sign.Owner.TextColor3 = Color3.fromRGB(150, 220, 140)
	sign.Income.Text = Format.Cash(self:GetPlotIncome(plot) * multiplier) .. "/s"
	sign.Brains.Text = `{self:CountBrains(plot)} / {Config.SlotCount} brains`

	if plot.Locked then
		sign.Status.Text = `LOCKED {Format.Clock(self:GetLockRemaining(plot))}`
		sign.Status.TextColor3 = Color3.fromRGB(255, 110, 110)
	else
		sign.Status.Text = "OPEN -- STEAL ME"
		sign.Status.TextColor3 = Color3.fromRGB(150, 220, 140)
	end
end

--------------------------------------------------------------------
-- Assignment
--------------------------------------------------------------------

function PlotService:AssignPlot(player: Player)
	if plotsByOwner[player] then
		return plotsByOwner[player]
	end

	local plot = nil
	for _, candidate in ipairs(plots) do
		if not candidate.Owner then
			plot = candidate
			break
		end
	end

	if not plot then
		self.Services.FeedbackService:Notify(player, "Every graveyard is taken! Try another server.", "bad")
		return nil
	end

	plot.Owner = player
	plotsByOwner[player] = plot
	self:SetLocked(plot, false, true)
	self:UpdateSign(plot)

	-- Put the brains they logged off with back on their podiums.
	local profile = self.Services.DataService:Get(player)
	if profile then
		for _, entry in ipairs(profile.Slots) do
			local slotIndex = tonumber(entry.Slot)
			if slotIndex and slotIndex >= 1 and slotIndex <= Config.SlotCount and Config.GetBrain(entry.BrainId) then
				if not plot.Slots[slotIndex].Record then
					local record = self.Services.BrainService:NewRecord(entry.BrainId, entry.VariantId, entry.ColorIndex)
					self.Services.BrainService:PlaceInSlot(plot, slotIndex, record)
				end
			end
		end
	end

	PlotService.PlotAssigned:Fire(player, plot)
	self.Services.FeedbackService:Notify(player, `Graveyard {plot.Index} is yours. Go buy some rot!`, "good")

	return plot
end

function PlotService:ReleasePlot(player: Player)
	local plot = plotsByOwner[player]
	if not plot then
		return
	end

	-- Snapshot before tearing the models down so the save is accurate.
	local profile = self.Services.DataService:Get(player)
	if profile then
		profile.Slots = self:SerializeSlots(plot)
	end

	for index = 1, Config.SlotCount do
		local record = plot.Slots[index].Record
		if record then
			self.Services.BrainService:DestroyRecord(record)
			self:SetSlotRecord(plot, index, nil)
		end
	end

	plot.Owner = nil
	plotsByOwner[player] = nil
	self:SetLocked(plot, false, true)
	self:UpdateSign(plot)
end

--------------------------------------------------------------------
-- Gate locking
--------------------------------------------------------------------

function PlotService:GetLockRemaining(plot: any): number
	if not plot.Locked then
		return 0
	end
	return math.max(0, plot.LockExpiresAt - os.clock())
end

function PlotService:GetLockCooldownRemaining(plot: any): number
	return math.max(0, plot.LockAvailableAt - os.clock())
end

function PlotService:IsLocked(plot: any): boolean
	return plot.Locked == true
end

-- Shove anyone who isn't the owner out through the gate before it shuts.
local function evictIntruders(self: any, plot: any)
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= plot.Owner then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and self:IsInside(plot, root.Position) then
				local exit = plot.CFrame * CFrame.new(0, 4, -(Config.Plot.Size / 2 + 8))
				character:PivotTo(CFrame.new(exit.Position))
				self.Services.FeedbackService:Notify(player, "The gate slammed shut. Get out!", "bad")
			end
		end
	end
end

function PlotService:SetLocked(plot: any, locked: boolean, silent: boolean?)
	plot.Locked = locked

	if locked then
		local profile = plot.Owner and self.Services.DataService:Get(plot.Owner)
		local duration = Config.LockDuration(profile and profile.Rebirths or 0)
		plot.LockExpiresAt = os.clock() + duration
		evictIntruders(self, plot)

		plot.Gate.Transparency = 0.35
		plot.Gate.CanCollide = true
		plot.LockLight.Color = Color3.fromRGB(255, 90, 90)
	else
		plot.LockExpiresAt = 0
		if not silent then
			plot.LockAvailableAt = os.clock() + Config.Lock.Cooldown
		end

		plot.Gate.Transparency = 1
		plot.Gate.CanCollide = false
		plot.LockLight.Color = Color3.fromRGB(120, 255, 140)
	end

	self:UpdateSign(plot)
	PlotService.LockChanged:Fire(plot)
end

function PlotService:TryToggleLock(player: Player)
	local plot = plotsByOwner[player]
	if not plot then
		self.Services.FeedbackService:Notify(player, "You don't own a graveyard yet.", "bad")
		return
	end

	if plot.Locked then
		self:SetLocked(plot, false)
		self.Services.FeedbackService:Notify(player, "Gate opened. Thieves welcome.", "info")
		self.Services.FeedbackService:Effect(player, "unlock")
		return
	end

	local cooldown = self:GetLockCooldownRemaining(plot)
	if cooldown > 0 then
		self.Services.FeedbackService:Notify(player, `Gate is recharging -- {Format.Clock(cooldown)} left.`, "bad")
		return
	end

	self:SetLocked(plot, true)

	local profile = self.Services.DataService:Get(player)
	local duration = Config.LockDuration(profile and profile.Rebirths or 0)
	self.Services.FeedbackService:Notify(player, `Gate locked for {Format.Clock(duration)}.`, "good")
	self.Services.FeedbackService:Effect(player, "lock")
end

--------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------

local function refreshLockPad(self: any, plot: any)
	local remaining = self:GetLockRemaining(plot)
	local cooldown = self:GetLockCooldownRemaining(plot)
	local prompt = plot.LockPrompt

	if plot.Locked then
		plot.LockLabel.Text = `LOCKED {Format.Clock(remaining)}`
		plot.LockLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
		plot.LockLight.Brightness = 2.5
		prompt.ActionText = "Open gate"
	elseif cooldown > 0 then
		plot.LockLabel.Text = `RECHARGING {Format.Clock(cooldown)}`
		plot.LockLabel.TextColor3 = Color3.fromRGB(200, 170, 120)
		plot.LockLight.Brightness = 0.6
		prompt.ActionText = "Recharging"
	else
		plot.LockLabel.Text = "LOCK GATE"
		plot.LockLabel.TextColor3 = Color3.fromRGB(150, 220, 140)
		plot.LockLight.Brightness = 1.4
		prompt.ActionText = "Lock gate"
	end
end

function PlotService:Init()
	for index, descriptor in ipairs(self.Services.WorldBuilder.Plots) do
		local slots = {}
		for slotIndex, slot in ipairs(descriptor.Slots) do
			slots[slotIndex] = {
				Index = slotIndex,
				Anchor = slot.Anchor,
				Podium = slot.Podium,
				Slab = slot.Slab,
				Light = slot.Light,
				Label = slot.Label,
				Record = nil,
			}
		end

		plots[index] = {
			Index = index,
			Model = descriptor.Model,
			CFrame = descriptor.CFrame,
			Floor = descriptor.Floor,
			Gate = descriptor.Gate,
			LockPad = descriptor.LockPad,
			LockLight = descriptor.LockLight,
			LockLabel = descriptor.LockLabel,
			Sign = descriptor.Sign,
			Slots = slots,
			Owner = nil,
			Locked = false,
			LockExpiresAt = 0,
			LockAvailableAt = 0,
		}
	end
end

function PlotService:Start()
	for _, plot in ipairs(plots) do
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "LockPrompt"
		prompt.ActionText = "Lock gate"
		prompt.ObjectText = "Gate Control"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = plot.LockPad

		plot.LockPrompt = prompt

		prompt.Triggered:Connect(function(player)
			if player == plot.Owner then
				self:TryToggleLock(player)
			else
				self.Services.FeedbackService:Notify(player, "That gate isn't yours.", "bad")
			end
		end)

		self:UpdateSign(plot)
		refreshLockPad(self, plot)
	end

	self.Services.DataService.ProfileLoaded:Connect(function(player)
		self:AssignPlot(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:ReleasePlot(player)
	end)

	-- Keep the profile's slot list current for autosaves.
	self.Services.DataService:RegisterSaveHook(function(player, profile)
		local plot = plotsByOwner[player]
		if plot then
			profile.Slots = self:SerializeSlots(plot)
		end
	end)

	-- Gate timers and sign refresh.
	task.spawn(function()
		local signTick = 0
		while true do
			task.wait(0.25)
			signTick += 0.25

			for _, plot in ipairs(plots) do
				if plot.Locked and self:GetLockRemaining(plot) <= 0 then
					self:SetLocked(plot, false)
					if plot.Owner then
						self.Services.FeedbackService:Notify(plot.Owner, "Your gate expired and swung open!", "bad")
					end
				end
				refreshLockPad(self, plot)

				if signTick >= 1 then
					self:UpdateSign(plot)
				end
			end

			if signTick >= 1 then
				signTick = 0
			end
		end
	end)
end

return PlotService
