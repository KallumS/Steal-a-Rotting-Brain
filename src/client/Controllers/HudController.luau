--[[
	HudController
	Builds the on-screen HUD and keeps it in step with the state the
	server pushes once a second. Cash is interpolated between pushes so
	the counter ticks up smoothly instead of jumping.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local UiKit = require(script.Parent.Parent.UiKit)

local HudController = {}

local palette = UiKit.Palette
local player = Players.LocalPlayer

local state = nil
local stateReceivedAt = 0
local displayedCash = 0

local ui = {}

local function buildCashPanel(parent: Instance)
	local panel = UiKit.panel({
		Name = "CashPanel",
		Position = UDim2.new(0, 16, 0, 16),
		Size = UDim2.fromOffset(268, 96),
		Parent = parent,
	})

	ui.CashLabel = UiKit.label({
		Name = "Cash",
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 0, 44),
		Font = Enum.Font.LuckiestGuy,
		TextSize = 38,
		TextColor3 = palette.Accent,
		Text = "$0",
		Parent = panel,
	})

	ui.IncomeLabel = UiKit.label({
		Name = "Income",
		Position = UDim2.fromOffset(16, 54),
		Size = UDim2.new(1, -32, 0, 20),
		TextSize = 16,
		TextColor3 = palette.Text,
		Text = "+$0/s",
		Parent = panel,
	})

	ui.MultiplierLabel = UiKit.label({
		Name = "Multiplier",
		Position = UDim2.fromOffset(16, 72),
		Size = UDim2.new(1, -32, 0, 18),
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = palette.Dim,
		Text = "rebirth bonus x1.00",
		Parent = panel,
	})
end

local function buildRebirthPanel(parent: Instance)
	local panel = UiKit.panel({
		Name = "RebirthPanel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(286, 92),
		Parent = parent,
	})

	ui.RebirthTitle = UiKit.label({
		Name = "Title",
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 0, 24),
		Font = Enum.Font.LuckiestGuy,
		TextSize = 22,
		TextColor3 = palette.Purple,
		Text = "REBIRTH 0",
		Parent = panel,
	})

	local track = UiKit.new("Frame", {
		Name = "Track",
		Position = UDim2.fromOffset(16, 42),
		Size = UDim2.new(1, -32, 0, 14),
		BackgroundColor3 = Color3.fromRGB(40, 44, 40),
		BorderSizePixel = 0,
		Parent = panel,
	})
	UiKit.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })

	ui.RebirthFill = UiKit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = palette.Purple,
		BorderSizePixel = 0,
		Parent = track,
	})
	UiKit.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ui.RebirthFill })

	ui.RebirthProgress = UiKit.label({
		Name = "Progress",
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.new(1, -32, 0, 20),
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = palette.Dim,
		Text = "$0 / $1M to rebirth",
		Parent = panel,
	})
end

local function buildGatePanel(parent: Instance)
	local panel = UiKit.panel({
		Name = "GatePanel",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(268, 88),
		Parent = parent,
	})

	ui.GateStatus = UiKit.label({
		Name = "Status",
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 0, 24),
		Font = Enum.Font.LuckiestGuy,
		TextSize = 20,
		TextColor3 = palette.Accent,
		Text = "GATE OPEN",
		Parent = panel,
	})

	ui.GateDetail = UiKit.label({
		Name = "Detail",
		Position = UDim2.fromOffset(16, 36),
		Size = UDim2.new(1, -32, 0, 20),
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = palette.Dim,
		Text = "Use the pad inside your gate to lock it",
		TextWrapped = true,
		Parent = panel,
	})

	ui.BrainsLabel = UiKit.label({
		Name = "Brains",
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.new(1, -32, 0, 20),
		TextSize = 15,
		TextColor3 = palette.Text,
		Text = `0 / {Config.SlotCount} graves filled`,
		Parent = panel,
	})
end

local function buildCarryBanner(parent: Instance)
	local panel = UiKit.panel({
		Name = "CarryBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(440, 54),
		BackgroundColor3 = Color3.fromRGB(48, 16, 16),
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = parent,
	})

	ui.CarryBanner = panel
	ui.CarryLabel = UiKit.label({
		Name = "Text",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 26),
		Font = Enum.Font.LuckiestGuy,
		TextSize = 20,
		TextColor3 = palette.Danger,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "CARRYING",
		Parent = panel,
	})
	ui.CarryHint = UiKit.label({
		Name = "Hint",
		Position = UDim2.fromOffset(12, 30),
		Size = UDim2.new(1, -24, 0, 18),
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = palette.Dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Run it into your own graveyard to keep it",
		Parent = panel,
	})
end

local function buildControlsPanel(parent: Instance)
	local panel = UiKit.panel({
		Name = "ControlsPanel",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(278, 142),
		Parent = parent,
	})

	UiKit.label({
		Name = "Title",
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -32, 0, 18),
		Font = Enum.Font.LuckiestGuy,
		TextSize = 16,
		TextColor3 = palette.Gold,
		Text = "HOW TO ROT",
		Parent = panel,
	})

	local lines = {
		"Hold E on the belt to buy a brain",
		"Hold E on a rival's grave to steal it",
		"Hold X on your own brain to scrap it",
		"Click / tap to claw a thief",
		"Lock your gate, rebirth at the crypt",
	}

	for index, text in ipairs(lines) do
		UiKit.label({
			Name = "Line" .. index,
			Position = UDim2.fromOffset(16, 8 + index * 22),
			Size = UDim2.new(1, -32, 0, 20),
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextColor3 = palette.Dim,
			Text = "- " .. text,
			Parent = panel,
		})
	end
end

--------------------------------------------------------------------

local function refresh()
	if not state then
		return
	end

	ui.IncomeLabel.Text = `+{Format.Cash(state.Income)}/s`
	ui.MultiplierLabel.Text = string.format("rebirth bonus x%.2f", state.IncomeMultiplier)

	ui.RebirthTitle.Text = `REBIRTH {state.Rebirths}`
	local requirement = math.max(1, state.RebirthRequirement)
	local progress = math.clamp(state.Cash / requirement, 0, 1)
	ui.RebirthFill.Size = UDim2.fromScale(progress, 1)

	if state.Rebirths >= state.MaxRebirths then
		ui.RebirthProgress.Text = "max rebirths reached"
	else
		ui.RebirthProgress.Text = `{Format.Cash(state.Cash)} / {Format.Cash(requirement)} to rebirth`
	end

	ui.BrainsLabel.Text = `{state.Brains} / {state.Slots} graves filled`

	if state.Locked then
		ui.GateStatus.Text = `GATE LOCKED {Format.Clock(state.LockRemaining)}`
		ui.GateStatus.TextColor3 = palette.Danger
		ui.GateDetail.Text = "Nobody can steal from you right now"
	elseif state.LockCooldown > 0 then
		ui.GateStatus.Text = "GATE RECHARGING"
		ui.GateStatus.TextColor3 = palette.Gold
		ui.GateDetail.Text = `Lockable again in {Format.Clock(state.LockCooldown)}`
	else
		ui.GateStatus.Text = "GATE OPEN"
		ui.GateStatus.TextColor3 = palette.Accent
		ui.GateDetail.Text = `Lock pad shuts it for {Format.Clock(state.LockDuration)}`
	end

	if state.Carrying then
		ui.CarryBanner.Visible = true
		ui.CarryLabel.Text = `CARRYING {string.upper(state.Carrying)}`
	else
		ui.CarryBanner.Visible = false
	end
end

function HudController:GetState()
	return state
end

function HudController:Init()
	local screen = UiKit.new("ScreenGui", {
		Name = "RotHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	self.ScreenGui = screen

	buildCashPanel(screen)
	buildRebirthPanel(screen)
	buildGatePanel(screen)
	buildCarryBanner(screen)
	buildControlsPanel(screen)
end

function HudController:Start()
	Remotes.Event("StateUpdate").OnClientEvent:Connect(function(newState)
		local firstPush = state == nil
		state = newState
		stateReceivedAt = os.clock()

		if firstPush then
			displayedCash = newState.Cash
		end

		refresh()
	end)

	-- Smooth the cash counter between server pushes.
	RunService.RenderStepped:Connect(function(deltaTime)
		if not state then
			return
		end

		local predicted = state.Cash + state.Income * (os.clock() - stateReceivedAt)
		displayedCash += (predicted - displayedCash) * math.min(1, deltaTime * 8)
		ui.CashLabel.Text = Format.Cash(displayedCash)
	end)
end

return HudController
