--!strict
-- Minimal connection/signal implementation used for in-process events.

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({ _handlers = {} :: { [number]: (T...) -> () } }, Signal)
	return (self :: any) :: Signal<T...>
end

function Signal:Connect(handler)
	local handlers = self._handlers
	local index = #handlers + 1
	handlers[index] = handler
	local connection = { Connected = true }
	function connection.Disconnect(conn)
		if not conn.Connected then
			return
		end
		conn.Connected = false
		for i, existing in handlers do
			if existing == handler then
				table.remove(handlers, i)
				break
			end
		end
	end
	return connection
end

function Signal:Once(handler)
	local connection: Connection? = nil
	connection = self:Connect(function(...)
		if connection then
			connection:Disconnect()
		end
		handler(...)
	end)
	return connection :: Connection
end

function Signal:Fire(...)
	for _, handler in table.clone(self._handlers) do
		task.spawn(handler, ...)
	end
end

function Signal:Destroy()
	table.clear(self._handlers)
end

return Signal
