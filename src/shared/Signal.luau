--[[
	Signal
	Small dependency-free event object. Services use it to talk to each
	other without reaching for BindableEvents (which copy their args).
]]

local Signal = {}
Signal.__index = Signal

export type Connection = {
	Disconnect: (Connection) -> (),
}

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(handler: (...any) -> ())
	assert(type(handler) == "function", "Signal:Connect expects a function")

	local handlers = self._handlers
	table.insert(handlers, handler)

	local connection = {}

	function connection:Disconnect()
		local index = table.find(handlers, handler)
		if index then
			table.remove(handlers, index)
		end
	end

	return connection
end

function Signal:Fire(...)
	-- Iterate a copy so handlers may disconnect themselves safely.
	local snapshot = table.clone(self._handlers)
	for _, handler in ipairs(snapshot) do
		local ok, err = pcall(handler, ...)
		if not ok then
			warn("[Signal] handler error: " .. tostring(err))
		end
	end
end

function Signal:DisconnectAll()
	table.clear(self._handlers)
end

return Signal
