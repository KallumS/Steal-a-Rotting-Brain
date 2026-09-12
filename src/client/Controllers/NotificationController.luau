--[[
	NotificationController
	Stack of short-lived toasts above the bottom of the screen, fed by
	the Notify remote.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local UiKit = require(script.Parent.Parent.UiKit)

local NotificationController = {}

local MAX_VISIBLE = 4
local LIFETIME = 4.5

local palette = UiKit.Palette
local player = Players.LocalPlayer

local container: Frame
local active: { Frame } = {}

local KIND_COLORS = {
	info = palette.Text,
	good = palette.Accent,
	bad = palette.Danger,
}

function NotificationController:Push(text: string, kind: string?)
	local color = KIND_COLORS[kind or "info"] or palette.Text

	local toast = UiKit.panel({
		Name = "Toast",
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 0.2,
	}, {})

	local label = UiKit.label({
		Name = "Text",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 1, 0),
		TextSize = 15,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = text,
	})
	label.Parent = toast

	toast.Parent = container
	table.insert(active, toast)

	while #active > MAX_VISIBLE do
		local oldest = table.remove(active, 1)
		if oldest then
			oldest:Destroy()
		end
	end

	-- Slide in, then fade out and clean up.
	toast.BackgroundTransparency = 1
	label.TextTransparency = 1
	TweenService:Create(toast, TweenInfo.new(0.18), { BackgroundTransparency = 0.2 }):Play()
	TweenService:Create(label, TweenInfo.new(0.18), { TextTransparency = 0 }):Play()

	task.delay(LIFETIME, function()
		if not toast.Parent then
			return
		end

		local fade = TweenInfo.new(0.4)
		TweenService:Create(toast, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()

		task.delay(0.45, function()
			local index = table.find(active, toast)
			if index then
				table.remove(active, index)
			end
			toast:Destroy()
		end)
	end)
end

function NotificationController:Init()
	local screen = UiKit.new("ScreenGui", {
		Name = "RotToasts",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		Parent = player:WaitForChild("PlayerGui"),
	})

	container = UiKit.new("Frame", {
		Name = "Container",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -130),
		Size = UDim2.fromOffset(470, 180),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		UiKit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})
end

function NotificationController:Start()
	Remotes.Event("Notify").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.Text) == "string" then
			self:Push(payload.Text, payload.Kind)
		end
	end)
end

return NotificationController
