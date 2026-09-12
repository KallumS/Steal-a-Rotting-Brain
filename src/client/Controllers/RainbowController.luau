--[[
	RainbowController
	Cycles the hue of rainbow brains. Purely cosmetic, so it runs on the
	client where it costs the server nothing.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tags = require(ReplicatedStorage:WaitForChild("Shared").Tags)

local RainbowController = {}

local UPDATE_RATE = 1 / 20
local CYCLE_SPEED = 0.28

local tracked: { [Model]: number } = {}

local function hashOffset(model: Model): number
	local uid = model:GetAttribute("Uid")
	local text = type(uid) == "string" and uid or model.Name

	local sum = 0
	for index = 1, #text do
		sum += string.byte(text, index) * index
	end
	return (sum % 100) / 100
end

function RainbowController:Init() end

function RainbowController:Start()
	for _, model in ipairs(CollectionService:GetTagged(Tags.AnimatedBrain)) do
		if model:IsA("Model") then
			tracked[model] = hashOffset(model)
		end
	end

	CollectionService:GetInstanceAddedSignal(Tags.AnimatedBrain):Connect(function(instance)
		if instance:IsA("Model") then
			tracked[instance] = hashOffset(instance)
		end
	end)

	CollectionService:GetInstanceRemovedSignal(Tags.AnimatedBrain):Connect(function(instance)
		tracked[instance :: Model] = nil
	end)

	local accumulator = 0
	RunService.RenderStepped:Connect(function(deltaTime)
		accumulator += deltaTime
		if accumulator < UPDATE_RATE then
			return
		end
		accumulator = 0

		local now = os.clock()
		for model, offset in pairs(tracked) do
			if not model.Parent then
				tracked[model] = nil
				continue
			end

			local hue = (now * CYCLE_SPEED + offset) % 1
			local color = Color3.fromHSV(hue, 0.75, 1)

			for _, descendant in ipairs(model:GetChildren()) do
				if descendant:IsA("BasePart") then
					descendant.Color = color
				end
			end
		end
	end)
end

return RainbowController
