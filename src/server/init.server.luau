--[[
	Steal a Rotting Brain -- server bootstrap

	Services are plain modules with optional :Init() and :Start()
	methods. Every service gets the whole service table injected, so
	they can call each other without circular requires.

	Init runs in order and must not yield: it is where state is built.
	Start runs in order afterwards and may connect events and spawn
	loops. Player sessions only begin once everything is started.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

-- Create the remotes before any client can ask for them.
Remotes.Init()

local SERVICE_ORDER = {
	"DataService",
	"FeedbackService",
	"WorldBuilder",
	"PlotService",
	"BrainService",
	"EconomyService",
	"ConveyorService",
	"StealService",
	"CombatService",
	"ZombieService",
	"RebirthService",
	"LeaderboardService",
}

local servicesFolder = script:WaitForChild("Services")
local services = {}

for _, name in ipairs(SERVICE_ORDER) do
	local module = servicesFolder:FindFirstChild(name)
	assert(module, `missing service module "{name}"`)

	local service = require(module)
	service.Name = name
	service.Services = services
	services[name] = service
end

for _, name in ipairs(SERVICE_ORDER) do
	local service = services[name]
	if service.Init then
		local started = os.clock()
		service:Init()
		local elapsed = (os.clock() - started) * 1000
		if elapsed > 50 then
			print(string.format("[Bootstrap] %s:Init took %.0fms", name, elapsed))
		end
	end
end

for _, name in ipairs(SERVICE_ORDER) do
	local service = services[name]
	if service.Start then
		service:Start()
	end
end

services.DataService:BeginSessions()

print("[Steal a Rotting Brain] server ready")
