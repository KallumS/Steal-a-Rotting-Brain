--[[
	AttackController
	Asks the server for a claw swing on click, tap or gamepad X, and
	throws a quick arm animation so the swing reads locally. The server
	decides whether anything was actually hit.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local AttackController = {}

local ACTION_NAME = "ZombieClaw"

local player = Players.LocalPlayer
local attackRemote: RemoteEvent
local nextSwing = 0

-- Nudge the right arm forward so the swing has some weight to it.
local function animateSwing()
	local character = player.Character
	if not character then
		return
	end

	local shoulder = character:FindFirstChild("RightShoulder", true)
	if shoulder and shoulder:IsA("Motor6D") then
		local original = shoulder.C0
		TweenService:Create(shoulder, TweenInfo.new(0.12), { C0 = original * CFrame.Angles(0, 0, math.rad(-70)) })
			:Play()
		task.delay(0.14, function()
			if shoulder.Parent then
				TweenService:Create(shoulder, TweenInfo.new(0.18), { C0 = original }):Play()
			end
		end)
	end
end

function AttackController:Swing()
	local now = os.clock()
	if now < nextSwing then
		return
	end
	nextSwing = now + Config.Combat.Cooldown

	animateSwing()
	attackRemote:FireServer()
end

function AttackController:Init()
	attackRemote = Remotes.Event("Attack")
end

function AttackController:Start()
	-- Touch button for mobile, plus mouse and gamepad bindings.
	ContextActionService:BindAction(ACTION_NAME, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			self:Swing()
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.ButtonX)

	ContextActionService:SetTitle(ACTION_NAME, "CLAW")
	ContextActionService:SetPosition(ACTION_NAME, UDim2.new(1, -170, 1, -170))

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:Swing()
		end
	end)
end

return AttackController
