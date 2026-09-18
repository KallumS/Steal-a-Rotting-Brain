--[[
	EffectController
	One-shot feedback for the Effect remote: a sound plus, for hits, a
	quick red vignette. Sounds come from the sound files that ship with
	the Roblox client, so nothing needs uploading.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local UiKit = require(script.Parent.Parent.UiKit)

local EffectController = {}

local CLICK = "rbxasset://sounds/switch3.wav"
local PING = "rbxasset://sounds/electronicpingshort.wav"

local EFFECTS = {
	purchase = { Sound = CLICK, Volume = 0.5, Pitch = 1.1 },
	steal = { Sound = PING, Volume = 0.6, Pitch = 0.8 },
	deposit = { Sound = PING, Volume = 0.6, Pitch = 1.25 },
	lost = { Sound = PING, Volume = 0.7, Pitch = 0.55, Flash = Color3.fromRGB(255, 70, 70) },
	returned = { Sound = PING, Volume = 0.6, Pitch = 1.4 },
	lock = { Sound = CLICK, Volume = 0.6, Pitch = 0.7 },
	unlock = { Sound = CLICK, Volume = 0.5, Pitch = 1.4 },
	swing = { Sound = CLICK, Volume = 0.35, Pitch = 1.6 },
	hit = { Sound = PING, Volume = 0.7, Pitch = 0.65, Flash = Color3.fromRGB(255, 90, 90) },
	rebirth = { Sound = PING, Volume = 0.8, Pitch = 1.6, Flash = Color3.fromRGB(190, 140, 255) },
}

local player = Players.LocalPlayer
local vignette: Frame

local function play(spec)
	local sound = Instance.new("Sound")
	sound.SoundId = spec.Sound
	sound.Volume = spec.Volume or 0.5
	sound.PlaybackSpeed = spec.Pitch or 1
	sound.Parent = SoundService

	-- Fire and forget; the sound cleans itself up.
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
	task.delay(4, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local function flash(color: Color3)
	vignette.BackgroundColor3 = color
	vignette.BackgroundTransparency = 0.55
	TweenService:Create(vignette, TweenInfo.new(0.55), { BackgroundTransparency = 1 }):Play()
end

function EffectController:Init()
	local screen = UiKit.new("ScreenGui", {
		Name = "RotEffects",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = -1,
		Parent = player:WaitForChild("PlayerGui"),
	})

	vignette = UiKit.new("Frame", {
		Name = "Vignette",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 70, 70),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = screen,
	})
end

function EffectController:Start()
	Remotes.Event("Effect").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end

		local spec = EFFECTS[payload.Kind]
		if not spec then
			return
		end

		if spec.Sound then
			play(spec)
		end
		if spec.Flash then
			flash(spec.Flash)
		end
	end)
end

return EffectController
