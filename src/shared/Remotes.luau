--[[
	Remotes
	Creates (server) and resolves (client) the handful of RemoteEvents
	the game needs. All gameplay decisions stay on the server, so the
	client only sends input and receives state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local EVENT_NAMES = {
	"StateUpdate", -- server -> client: cash, income, lock timers, carry status
	"Notify", -- server -> client: toast message
	"Effect", -- server -> client: one-shot feedback (sound / flash)
	"Attack", -- client -> server: zombie swing
}

local Remotes = {}

local cache = {}

-- Server-side setup. Call once, before players can join.
function Remotes.Init()
	assert(RunService:IsServer(), "Remotes.Init must run on the server")

	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end

	for _, name in ipairs(EVENT_NAMES) do
		if not folder:FindFirstChild(name) then
			local event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		end
	end

	return folder
end

function Remotes.Event(name: string): RemoteEvent
	assert(table.find(EVENT_NAMES, name), `unknown remote "{name}"`)

	local cached = cache[name]
	if cached then
		return cached
	end

	local folder
	if RunService:IsServer() then
		folder = Remotes.Init()
	else
		folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 30)
		assert(folder, "Remotes folder never replicated")
	end

	local event = folder:WaitForChild(name, 30)
	assert(event, `remote "{name}" never replicated`)

	cache[name] = event
	return event
end

return Remotes
