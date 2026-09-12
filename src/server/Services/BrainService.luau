--[[
	BrainService
	Creates brain records (the saved data) and their models (the physical
	thing in the world), and moves them between the three places a brain
	can live: the conveyor, a grave slot, or a zombie's hands.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainFactory = require(Shared.BrainFactory)
local Config = require(Shared.Config)
local Signal = require(Shared.Signal)

local BrainService = {}

BrainService.Placed = Signal.new() -- (plot, slotIndex, record)
BrainService.Removed = Signal.new() -- (record, plot, slotIndex)

local nextUid = 0

--------------------------------------------------------------------
-- Records
--------------------------------------------------------------------

function BrainService:NewRecord(brainId: string, variantId: string?, colorIndex: number?)
	assert(Config.GetBrain(brainId), `unknown brain "{brainId}"`)

	nextUid += 1

	return {
		Uid = string.format("brain_%d", nextUid),
		BrainId = brainId,
		VariantId = Config.GetVariant(variantId).Id,
		ColorIndex = colorIndex or math.random(#Config.StandardColors),
		Model = nil,
		Location = "none", -- "conveyor" | "slot" | "carried"
	}
end

function BrainService:GetDisplayName(record: any): string
	return BrainFactory.GetDisplayName(record)
end

function BrainService:GetIncome(record: any): number
	return Config.BrainIncome(record.BrainId, record.VariantId)
end

function BrainService:GetPrice(record: any): number
	return Config.BrainPrice(record.BrainId, record.VariantId)
end

function BrainService:GetRarity(record: any): string
	local brain = Config.GetBrain(record.BrainId)
	return brain and brain.Rarity or "Common"
end

-- Bigger brains need lifting so they rest on top of a podium rather
-- than sinking through it.
function BrainService:GetHeightOffset(record: any): number
	local brain = Config.GetBrain(record.BrainId)
	local scale = brain and brain.Scale or 1
	return (scale - 1) * 2
end

function BrainService:EnsureModel(record: any): Model
	if not record.Model or not record.Model.Parent then
		if record.Model then
			record.Model:Destroy()
		end
		record.Model = BrainFactory.Create(record)
	end
	return record.Model
end

function BrainService:DestroyRecord(record: any)
	self:ClearPrompts(record)
	if record.Model then
		record.Model:Destroy()
		record.Model = nil
	end
	record.Location = "destroyed"
end

-- Prompts belong to wherever the brain currently is, so they are always
-- rebuilt when it moves.
function BrainService:ClearPrompts(record: any)
	local model = record.Model
	if not model then
		return
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			descendant:Destroy()
		end
	end
end

--------------------------------------------------------------------
-- Grave slots
--------------------------------------------------------------------

function BrainService:PlaceInSlot(plot: any, slotIndex: number, record: any)
	local slot = plot.Slots[slotIndex]
	if not slot or slot.Record then
		return false
	end

	local model = self:EnsureModel(record)
	self:ClearPrompts(record)
	self:DetachWeld(record)

	BrainFactory.SetAnchored(model, true)
	model.Parent = plot.Model
	model:PivotTo(slot.Anchor * CFrame.new(0, self:GetHeightOffset(record), 0))

	record.Location = "slot"
	record.Plot = plot
	record.SlotIndex = slotIndex

	self.Services.PlotService:SetSlotRecord(plot, slotIndex, record)
	BrainService.Placed:Fire(plot, slotIndex, record)

	return true
end

function BrainService:PlaceInFreeSlot(plot: any, record: any): number?
	local slotIndex = self.Services.PlotService:GetFreeSlotIndex(plot)
	if not slotIndex then
		return nil
	end
	if self:PlaceInSlot(plot, slotIndex, record) then
		return slotIndex
	end
	return nil
end

function BrainService:RemoveFromSlot(plot: any, slotIndex: number)
	local slot = plot.Slots[slotIndex]
	local record = slot and slot.Record
	if not record then
		return nil
	end

	self.Services.PlotService:SetSlotRecord(plot, slotIndex, nil)
	self:ClearPrompts(record)

	record.Location = "none"
	record.Plot = nil
	record.SlotIndex = nil

	BrainService.Removed:Fire(record, plot, slotIndex)
	return record
end

--------------------------------------------------------------------
-- Carrying
--------------------------------------------------------------------

function BrainService:DetachWeld(record: any)
	if record.Weld then
		record.Weld:Destroy()
		record.Weld = nil
	end
end

-- Weld the brain above the carrier's head so it replicates for free.
function BrainService:AttachToCharacter(player: Player, record: any): boolean
	local character = player.Character
	if not character then
		return false
	end

	local anchorPart = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	if not anchorPart or not anchorPart:IsA("BasePart") then
		return false
	end

	local model = self:EnsureModel(record)
	self:ClearPrompts(record)
	self:DetachWeld(record)

	model.Parent = character
	BrainFactory.SetAnchored(model, false)
	model:PivotTo(anchorPart.CFrame * CFrame.new(0, 3.2, 0))

	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = anchorPart
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart

	record.Weld = weld
	record.Location = "carried"
	record.Carrier = player

	return true
end

function BrainService:DetachFromCharacter(record: any)
	self:DetachWeld(record)

	if record.Model then
		BrainFactory.SetAnchored(record.Model, true)
	end

	record.Location = "none"
	record.Carrier = nil
end

--------------------------------------------------------------------
-- Loose placement (conveyor and effects)
--------------------------------------------------------------------

function BrainService:PlaceAt(record: any, cframe: CFrame, parent: Instance)
	local model = self:EnsureModel(record)
	self:DetachWeld(record)
	BrainFactory.SetAnchored(model, true)
	model.Parent = parent
	model:PivotTo(cframe)
	return model
end

function BrainService:Init() end
function BrainService:Start() end

return BrainService
