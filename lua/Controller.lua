-- Emitter? Controller?

local queue = (require (Lucid.Home..'lib/deque')):new()

class 'Controller'

-- function Controller:__init()
-- 	self._events = { send = {}, receive = {} }
-- end

local function bind_event (name, sender, receiver, handler)
	local e = {
		name 		= name,
		sender 		= sender,
		receiver 	= receiver,
		handler 	= handler,
		bound		= true,
	}

	_.init (sender, '_events', 'send', name) [e] = e
	if receiver then
		_.init (receiver, '_events', 'receive', name) [e] = e
	end
	sender:trigger ('subscribe:'..name, e)
end

local function unbind_event (e)
	if not e.bound then return end

	local events

	events = _.get (e, 'sender', '_events', 'send', e.name)
	if events then
		events [e] = nil
		if _.is_empty (events) then
			e.sender._events.send [e.name] = nil
		end
	end

	events = _.get (e, 'receiver', '_events', 'receive', e.name)
	if events then
		events [e] = nil
		if _.is_empty (events) then
			e.receiver._events.receive [e.name] = nil
		end
	end

	e.bound = false

	e.sender:trigger ('unsibscribe:'..e.name, e)
end

local function unbind_events (name, sender, receiver, handler)
	local events = _.get (sender or receiver, '_events', by_sender and 'send' or 'receive', name)
	if not events then return end

	local iter = name and pairs or coroutine.wrap (function (events)
		for name, subevents in pairs (events) do
			for e in pairs (subevents) do
				coroutine.yield (e)
			end
		end
	end)

	-- this could be broken if unbinding event and removing respective structures messes the iterators
	-- need to test this and probably reimplement, probably by collecting results from the iterator first
	_.each (iter (events), unbind_event)
end

function Controller:on (name, receiver, handler)
	if type (receiver) == 'function' then
		receiver, handler = nil, receiver
	elseif type (handler) == 'string' and type (receiver) == 'table' then
		handler = receiver [handler]
	end

	bind_event (name, self, receiver, handler)
	return self
end

function Controller:listen_to (sender, name, handler)
	if type (handler) == 'function' then
		local member = handler
		handler = function (...)
			return member (self, ...)
		end
	end

	bind_event (name, sender, self, handler)
	return self
end

function Controller:off (...)
	local name, receiver, handler

	for __, arg in ipairs {...} do
		local t = type (arg)
		if not name and (handler or not receiver) and t == 'string' then
			name = arg
		elseif not receiver and t == 'table' then
			receiver = arg
		elseif not handler and t == 'function' then
			handler = arg
		elseif not handler and receiver and t == 'string' and type (receiver [arg]) == 'function' then
			handler = receiver [arg]
		else
			assert (false, 'Invalid arguments to the :off() function')
		end
	end

	unbind_events (name, self, receiver, handler)
	return self
end

function Controller:stop_listening (...)
	local name, sender, handler

	for __, arg in ipairs {...} do
		local t = type (arg)
		if not name and t == 'string' then
			name = arg
		elseif name and not handler and t == 'string' and self [arg] then
			handler = self [arg]
		elseif not sender and t == 'table' then
			sender = arg
		elseif not handler and t == 'function' then
			handler = arg
		else
			assert (false, 'Invalid arguments to :stop_listening()')
		end
	end

	unbind_events (name, sender, self, handler)
	return self
end

function Controller:trigger (name, ...)
	if _.get (self._events, 'send', name) then
		for e in pairs (self._events.send [name]) do
			queue:push_right {e, {...}}
		end
	end

	local sup, sub = name:match '^(.+):([^:]+)$'
	if not sub then return self end
	return self:trigger (sup, sub, ...)
end

-- defer executing method or an arbitrary function until the current event queue has flushed
function Controller:defer (method, ...)
	local call = Controller:is_parent (self) and {self [method], self, ...} or {self, method, ...}
	queue:push_right {false, call}
end

function Controller:__destroy()
	return self:trigger ('destroy'):off()
	-- trigger the 'destroy' event, then drop all the other event handlers
	-- 'destroy' is a special event and will be received by the listeners even after :off()
	-- but all other events will be dropped and won't be received, because child destructors
	-- may mess up the object, leading to worse bugs than a few unreceived events
	--
	-- if you want the events to be received, instead of calling :destroy(), call :defer ('destroy') -
	-- that would delay the destructor until the event queue is cleared out
end

function Controller:inspect_events()
	local iter = coroutine.wrap (function() 
		coroutine.yield ('send', 'to', 'receiver')
		coroutine.yield ('receive', 'from', 'sender')
	end)

	print (tostring (self)..':')
	for what, pronoun, target in iter do
		local events = _.get (self, '_events', what)
		if events then
			for name, events in pairs (self._events [what]) do
				for event in pairs (events) do
					print (what..'s', name, pronoun, event [target])
				end
			end
		end
	end
end

function Controller.loop()
	for e in _.curry (queue.pop_left, queue) do
		local event, args = unpack (e)
		if not event then
			args [1] (_.shift_identities (args))
		elseif event.bound or event.name == 'destroy' then
			if event.receiver then
				event.handler (event.receiver, event.sender, unpack (args))
			else
				event.handler (event.sender, unpack (args))
			end
		end
	end
end