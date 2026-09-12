--[[
	ConveyorService
	Rolls fresh brains onto the central belt, slides them along, sells
	them to whoever hits the prompt first, and scraps anything that
	reaches the incinerator at the far end.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local ConveyorService = {}

local entries: { any } = {}
local brainPool: { { Brain: any, Weight: number } } = {}
local brainWeightTotal = 0
local variantWeightTotal = 0
local beltFolder: Folder

local function rollBrain()
	local roll = math.random() * brainWeightTotal
	local cursor = 0
	for _, entry in ipairs(brainPool) do
		cursor += entry.Weight
		if roll <= cursor then
			return entry.Brain
		end
	end
	return brainPool[1].Brain
end

local function rollVariant()
	local roll = math.random() * variantWeightTotal
	local cursor = 0
	for _, variant in ipairs(Config.Variants) do
		cursor += variant.Weight
		if roll <= cursor then
			return variant
		end
	end
	return Config.Variants[1]
end

--------------------------------------------------------------------
-- Spawning
--------------------------------------------------------------------

function ConveyorService:Spawn()
	if #entries >= Config.Conveyor.MaxOnBelt then
		return
	end

	local brain = rollBrain()
	local variant = rollVariant()

	local record = self.Services.BrainService:NewRecord(brain.Id, variant.Id)
	local price = self.Services.BrainService:GetPrice(record)
	local conveyor = self.Services.WorldBuilder.Conveyor

	local spawnPosition = conveyor.StartPosition
		+ Vector3.new(0, self.Services.BrainService:GetHeightOffset(record), 0)
	local model = self.Services.BrainService:PlaceAt(record, CFrame.new(spawnPosition), beltFolder)
	record.Location = "conveyor"

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = `Buy {Format.Cash(price)}`
	prompt.ObjectText = self.Services.BrainService:GetDisplayName(record)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Conveyor.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart

	local entry = {
		Record = record,
		Model = model,
		Prompt = prompt,
		Distance = 0,
		Price = price,
		HeightOffset = self.Services.BrainService:GetHeightOffset(record),
		Purchased = false,
	}

	prompt.Triggered:Connect(function(player)
		self:TryPurchase(player, entry)
	end)

	table.insert(entries, entry)

	-- Shout about the good stuff.
	local rarity = Config.GetRarity(brain.Rarity)
	if variant.Id ~= "Standard" or rarity.Order >= Config.Rarities.Legendary.Order then
		self.Services.FeedbackService:NotifyAll(
			`{self.Services.BrainService:GetDisplayName(record)} is on the belt -- {Format.Cash(price)}!`,
			"info"
		)
	end
end

--------------------------------------------------------------------
-- Buying
--------------------------------------------------------------------

local function removeEntry(entry: any)
	local index = table.find(entries, entry)
	if index then
		table.remove(entries, index)
	end
end

function ConveyorService:TryPurchase(player: Player, entry: any)
	if entry.Purchased then
		return
	end

	local feedback = self.Services.FeedbackService
	local profile = self.Services.DataService:Get(player)
	if not profile then
		return
	end

	local plot = self.Services.PlotService:GetPlotByOwner(player)
	if not plot then
		feedback:Notify(player, "You have no graveyard to put that in.", "bad")
		return
	end

	if not self.Services.PlotService:GetFreeSlotIndex(plot) then
		feedback:Notify(player, "Your graveyard is full! Rebirth or make room.", "bad")
		return
	end

	if profile.Cash < entry.Price then
		feedback:Notify(
			player,
			`Need {Format.Cash(entry.Price - profile.Cash)} more for that one.`,
			"bad"
		)
		return
	end

	if not self.Services.EconomyService:TrySpend(player, entry.Price) then
		return
	end

	entry.Purchased = true
	entry.Prompt:Destroy()
	removeEntry(entry)

	local record = entry.Record
	local slotIndex = self.Services.BrainService:PlaceInFreeSlot(plot, record)
	if not slotIndex then
		-- Should not happen, but never eat someone's cash.
		self.Services.EconomyService:AddCash(player, entry.Price)
		self.Services.BrainService:DestroyRecord(record)
		feedback:Notify(player, "Placement failed, you were refunded.", "bad")
		return
	end

	profile.Stats.Purchased += 1

	feedback:Notify(
		player,
		`Bought {self.Services.BrainService:GetDisplayName(record)} (+{Format.Cash(self.Services.BrainService:GetIncome(record))}/s)`,
		"good"
	)
	feedback:Effect(player, "purchase", { Rarity = self.Services.BrainService:GetRarity(record) })
	self.Services.EconomyService:PushState(player)
end

--------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------

function ConveyorService:Init()
	for _, brain in ipairs(Config.Brains) do
		local weight = Config.GetRarity(brain.Rarity).Weight
		table.insert(brainPool, { Brain = brain, Weight = weight })
		brainWeightTotal += weight
	end

	for _, variant in ipairs(Config.Variants) do
		variantWeightTotal += variant.Weight
	end
end

function ConveyorService:Start()
	local conveyor = self.Services.WorldBuilder.Conveyor

	beltFolder = Instance.new("Folder")
	beltFolder.Name = "BeltBrains"
	beltFolder.Parent = conveyor.Model

	task.spawn(function()
		-- Start the belt half full so the first player has something to buy.
		for _ = 1, 3 do
			self:Spawn()
			task.wait(Config.Conveyor.SpawnInterval / 2)
		end

		while true do
			task.wait(Config.Conveyor.SpawnInterval)
			if #Players:GetPlayers() > 0 then
				self:Spawn()
			end
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime

		for index = #entries, 1, -1 do
			local entry = entries[index]
			entry.Distance += Config.Conveyor.Speed * deltaTime

			if entry.Distance >= conveyor.Length then
				-- Scrapped at the incinerator.
				self.Services.BrainService:DestroyRecord(entry.Record)
				table.remove(entries, index)
			elseif entry.Model.PrimaryPart then
				local position = conveyor.StartPosition + conveyor.Direction * entry.Distance
				local bob = math.sin(elapsed * 2 + entry.Distance * 0.2) * 0.25
				entry.Model:PivotTo(
					CFrame.new(position + Vector3.new(0, bob + entry.HeightOffset, 0))
						* CFrame.Angles(0, elapsed * 0.8, 0)
				)
			end
		end
	end)
end

return ConveyorService
