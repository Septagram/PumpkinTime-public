-- make a basic class creation function instead of this bullshit?
local Class, Base = {}, {}
local classes = { [setmetatable (Base, Class)] = {
	key			= Base,
	children	= {},
	metatable	= {},
	descriptor 	= {
		__classname	= 'Base',
		__init		= _.extend,
		__destroy 	= function() self.is_destroyed, self.__destroy = true, _.void end,
	},
} }

local special_properties = _.indexBy {'classname', 'super', 'preinit', 'init', 'destroy'}

function Class:__index (k)
	return classes [self].class_index [k]
end

function Class:__newindex (k, v)
	local desc = classes [self].descriptor
	if special_properties [k:sub (3)] then
		local old = desc [k]
		desc [k] = v
		Class ['update_'..k:sub (3)] (classes [self], old)
		Class.update_metatable (classes [self], k == '__preinit' and 'init' or k ~= '__super' and k:sub (3) or nil)
	else
		desc [k] = v
		Class.update_metatable (classes [self], false)
	end
end

function Class:__call (...)
	local res = setmetatable ({}, classes [self].metatable)
	res:__init (...)
	return res
end

function Class:__tostring()
	return 'Class '..self.__classname
end

function Class:update_classname (old)
	if old then
		_G [old] = nil
	end
	assert (not Base.is_class (_G [self.descriptor.__classname]), 'Class '..self.descriptor.__classname..' already exists')
	_G [self.descriptor.__classname] = self.key
end

function Class:update_super (old)
	-- make sure super is a class, keep in mind that nil == Base
	-- remove ourselves from previous super's children
	-- add ourselves to new super's children
	self.descriptor.__super = self.descriptor.__super or Base
	assert (Base.is (self.descriptor.__super))
	if old then
		classes [old].children [self.key] = nil
	end
	classes [self.descriptor.__super].children [self.key] = self.key
	if self.descriptor.__super.__extend then
		Class.update_metatable (self, false)
		self.descriptor.__super.__extend (self.key)
	end
end

function Class:update_init()
	if not self.descriptor.__super then
		self.__init = self.descriptor.__init
	else
		-- find parent with constructor
		local parent = classes [self.descriptor.__super]
		while parent and not parent.key.__owninit do
			parent = classes [parent.descriptor.__super]
		end

		local parent_init, init, preinit = parent and parent.__init, self.descriptor.__init, self.descriptor.__preinit
		local cname = self.descriptor.__classname

		local preinit_status = not preinit and 'none' or type (preinit) == 'function' and 'custom' or 'constant'
		if preinit and type (preinit) ~= 'function' then
			preinit = _.curry (_.identities, preinit)
		end

		local init_status = not init and 'none' or type (init) == 'function' and 'custom' or 'extend'
		if init and type (init) ~= 'function' then
			local init_table = init
			init = function (self, ...)
				return _.extend (self, init_table, ...)
			end
		end

		if preinit or init then
			function self:__init (...)
				if parent_init then
					if not preinit then
						if not init then
							return parent_init (self, ...)
						else
							parent_init (self)
						end
					else
						parent_init (self, preinit (self, ...))
					end
				end

				if init then
					return init (self, ...)
				end
			end
		else
			self.__init = nil
		end
	end
end
Class.update_preinit = Class.update_init

function Class:update_destroy()
	-- put the destructor initialization from below here
	if not self.descriptor.__destroy then
		self.__destroy = nil
	elseif not self.descriptor.__super then
		self.__destroy = self.descriptor.__destroy
	else
		local destroy, parent = self.descriptor.__destroy, self.descriptor.__super
		function self:__destroy()
			destroy (self)
			return parent.__destroy (self)
		end
	end
end

function Class:update_metatable (special)
	if special == nil then
		Class.update_init (self)
		Class.update_destroy (self)
		special = 'all'
	end

	special =
		special == 'all' 		and { init = true, destroy = true } or
		special == 'destroy'	and { destroy = true } or
		special == 'init' 		and { init = true } or false

	for __, mt_type in ipairs {'class', 'instance'} do
		self [mt_type..'_index'] = _.defaults ({}, Class._index_components (self, mt_type))
	end

	local index = self.instance_index
	index.__class, index.__classindex = self.key, index
	index.__preinit = self.descriptor.__preinit
	
	local real_index = index
	if index.__index then 
		local i = index.__index
		real_index = function (self, k) return i (self, k, index) end
	end
	
	_.clear (self.metatable)
	_.defaults (self.metatable, { __index = real_index }, _.filter_values (index, function (v, k)
		return type (k) == 'string' and k:match '^__'
	end))

	_.recurse (self.key, function (fn, class)
		if class.__super then
			fn (class.__super)
		end

		if class.__updatemt then
			return class.__updatemt (self.key, self.metatable)
		end
	end)

	for child in pairs (self.children) do
		for k in special do
			Class ['update_'..k] (classes [child])
		end
		Class.update_metatable (classes [child], special)
	end
end

function Class:_index_components (index_type)
	local special = {
		__class			= self.key,
		__init 			= self.__init,
		__destroy		= self.__destroy,
		__owninit		= self.descriptor.__init,
		__owndestroy	= self.descriptor.__destroy,
		__descriptor	= self.descriptor,
	}
	if self.descriptor.__super then
		return	special, self.descriptor ['__'..index_type..'only'] (), self.descriptor,
				Class._index_components (classes [self.descriptor.__super], index_type)
	else
		return 	special, self.descriptor ['__'..index_type..'only'] (), self.descriptor
	end
end

-- TODO: write out the Base methods, try writing the metatable the usual way

-- make a basic class creation function instead of this bullshit?
for __, member in ipairs {'__classonly', '__instanceonly'} do
	classes [Base].descriptor [member] = _.member_write_watcher (classes [Base], Class.update_metatable)
end

Class.update_metatable (classes [Base])

function class (name)
	local class = { children = {}, key = {}, descriptor = {}, metatable = {} }
	class.descriptor.__classonly = _.member_write_watcher (class, Class.update_metatable)
	class.descriptor.__instanceonly = _.member_write_watcher (class, Class.update_metatable)
	classes [setmetatable (class.key, Class)] = class
	class.key.__classname = name
	class.key.__super = Base
	return class.key
end

function Base.__classonly:extends (class)
	if type (class) ~= 'table' then
		class = _G [class]
	end
	assert (self.is_class (class), 'Parent of '..self.__classname..' is not a class')
	self.__super = class
	return self
end

function Base:force_update_metatable()
	Class.update_metatable (classes [self])
	return self
end

function Base:is (class)
	if type (self) ~= 'table' then
		return false
	elseif type (class) == 'table' then
		return Base.is_class (class) and class:is_parent (self)
	elseif not class or type (class) == 'string' then
		return Base.is_class (self.__class) and (not class or self.__classname == class or self.__super and self.__super:is (class)) 
	end
	return false
end

function Base.__classonly:is_parent (object)
	if type (object) ~= 'table' then
		return false
	else
		return object.__class == self or self.is_class (object.__super) and self:is_parent (object.__super)
	end
end

function Base.__classonly:child_classes_iter()
	return coroutine.wrap (function()
		for class in pairs (classes [self].children) do
			coroutine.yield (class.__classname, class)
		end
	end)
end

function Base:is_class()
	return not not classes [self]
end

Base.__instanceonly.is_class = _.constant (false)

function Base:__tostring()
	return name (self)..' ('..self.__classname..')'
end

return class, Base