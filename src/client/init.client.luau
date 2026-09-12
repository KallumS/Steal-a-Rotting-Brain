--[[
	Steal a Rotting Brain -- client bootstrap

	Controllers follow the same Init/Start contract as the server
	services. Nothing here makes gameplay decisions: the client draws
	state it is given and forwards input.
]]

local controllersFolder = script:WaitForChild("Controllers")

local CONTROLLER_ORDER = {
	"HudController",
	"NotificationController",
	"EffectController",
	"AttackController",
	"RainbowController",
}

local controllers = {}

for _, name in ipairs(CONTROLLER_ORDER) do
	local module = controllersFolder:FindFirstChild(name)
	assert(module, `missing controller module "{name}"`)

	local controller = require(module)
	controller.Name = name
	controller.Controllers = controllers
	controllers[name] = controller
end

for _, name in ipairs(CONTROLLER_ORDER) do
	local controller = controllers[name]
	if controller.Init then
		controller:Init()
	end
end

for _, name in ipairs(CONTROLLER_ORDER) do
	local controller = controllers[name]
	if controller.Start then
		controller:Start()
	end
end
