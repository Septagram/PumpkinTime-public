class 'Model' : extends 'Controller'

local next_id = 1
local valid_attributes, own_attributes = { [Model] = {} }, { [Model] = {} }
local all_models = setmetatable ({}, { __mode = 'v' })

-- note that when extending Model, you'd often want to:
--
--	MyModel.__preinit = _.shift_identities
--
-- this line passes the attributes argument through to the original model constructor,
-- initializing the model attributes

function Model:__index (key, index)
	local attribute = valid_attributes [index.__class] [key]
	if attribute then
		local get = attribute.getter
		if get then
			return (get (self))
		else
			return rawget (self, '_attributes') [key]
		end
	end
	return index [key]
end

function Model:__init (attributes)
	all_models [next_id] = self
	next_id, self._attributes, self._collections, self._views = next_id + 1, { id = next_id }, {}, {}
	attributes = attributes or {}
	for name, value in pairs (_.pluck (valid_attributes [self.__class], 'default')) do
		if attributes [name] == nil then
			attributes [name] = value
		end
	end
	self:set (attributes)
	-- performance? or fuck it?
end

function Model:__extend()
	for watcher, attribute_member in pairs { __aget = 'getter', __aset = 'setter' } do
		self.__descriptor [watcher] = _.member_write_watcher (self, function (self, attribute, fn)
			local descriptor = own_attributes [self] [attribute]
			assert (descriptor, self.__classname..' does not have an attribute "'..attribute..'"')
			descriptor [attribute_member] = fn
		end)
	end

	self.__descriptor.a = setmetatable ({}, {
		__index = function (accessor, key)
			if own_attributes [self] [key] then
				return own_attributes [self] [key]
			elseif valid_attributes [self] [key] then
				return _.read_only (valid_attributes [self] [key])
			else
				self:add_attribute (key)
				return own_attributes [self] [key]
			end
		end,

		__newindex = function (accessor, key, value)
			if own_attributes [self] then
				self.a [key].default = value
			elseif not valid_attributes [self] then
				self:add_attribute (_.extend (value, { name = key }))
			else
				assert (false, 'Model ', self.__classname, ' doesn\'t own attribute "', key, '"')
			end
		end,
	})

	own_attributes [self] = {}
	self:_update_valid_attributes()
	self.__preinit = _.shift_identities
end

function Model:__newindex (key, value)
	local old_value = self [key]
	if old_value == value then return end
	local attribute = valid_attributes [self.__class] [key]
	if attribute then
		local a_set, a_type = attribute.setter, attribute.type
		if a_set then
			a_set (self, value)
		elseif a_type == 'any' then
			self._attributes [key] = value
		elseif a_type == 'container' then
			local a = self._attributes
			if old_value then
				old_value:remove (self)
			end
			a [key] = value
			if value then
				value:add (self)
			end
		else
			assert (false, 'Invalid attribute type: ', self.__classname, '.', key, ':', a_type)
		end
		self:trigger ('change:'..key, value, old_value)
	else
		rawset (self, key, value)
	end
end

function Model:attributes (output)
	if not output then
		output = {}
	else
		_.clear (output)
	end

	for k in pairs (valid_attributes [self.__class]) do
		output [k] = self [k]
	end

	return output
end

function Model.__classonly:add_attribute (attribute, ...)
	if not attribute then return self end
	assert (Model:is_parent (self))
	assert (not valid_attributes [self] [attribute],
		'Model '..self.__classname..' already has attribute "'..attribute..'"')
	local attr_name, attr_type
	if type (attribute) == 'string' then
		attr_name, attr_type = attribute:match '^([^:]+):(.*)$'
		attr_name = attr_name or attribute
		attribute = {
			name = attr_name,
			type = attr_type or 'any',
		}
	else
		assert (attribute.name, 'An attribute must have a name ('..self.__classname..' model)')
		attr_name = attribute.name
	end
	own_attributes [self] [attr_name] = attribute
	self:_update_valid_attributes()
	return self:add_attribute (...)
end

function Model.__classonly:attributes (...)
	assert (Model:is_parent (self))
	assert (not own_attributes [self] or _.is_empty (own_attributes [self]),
		'You can only set the list of attributes at model initialization')
	return self:add_attribute (...)
end

function Model.__classonly:attribute (name)
	return own_attributes [self] [name] or _.read_only (valid_attributes [self] [name],
		'Attribute "'..name..'" belongs to another model and cannot be modified from the model "'..self.__classname..'"')
end

Model.set = _.extend

function Model:__tostring()
	return '['..self.__classname:gsub ('_(%w)', function (l) return ' '..l:lower() end)..' '..name (self.id)..' - '..self.id..']'
end

function Model:valid_attributes()
	return _.keys (valid_attributes [self.__class])
end

function Model:own_attributes()
	return _.keys (own_attributes [self.__class])
end

function Model.__classonly:defaults (values)
	if not values then
		return _.pluck (valid_attributes [self], 'default')
	else
		local my_attributes = own_attributes [self]
		for name, value in pairs (values) do
			assert (my_attributes [name], 'Model "'..self.__classname..'" doesn\'t own an attribute "'..name..'"')
			my_attributes [name].default = value
		end
	end
end

function Model.by_id (id)
	return all_models [id]
end

function Model.__classonly:_update_valid_attributes()
	valid_attributes [self] = _.extend ({}, _.recurse (self, function (fn, Class)
		if not Class then return end
		if not own_attributes [Class] then return fn (Class.__super) end
		return own_attributes [Class], fn (Class.__super)
	end))

	for __, child in self:child_classes_iter() do
		child:_update_valid_attributes()
	end
end

Model:__extend()
Model:add_attribute 'id'
Model.__aset.id = _.void

-- function Model:owned_by (Collection_Class, attribute)
-- 	self.__class.__aset [attribute] = function (self, collection)
-- 		assert (collection == nil or Collection_Class:is_parent (collection))
-- 		
-- 		local old = self [attribute]
-- 		if old == collection then return end
-- 
-- 		if old then
-- 			old:remove (self)
-- 		end
-- 
-- 		self._attributes [attribute] = collection
-- 
-- 		if collection then
-- 			collection:add (self)
-- 		end
-- 	end
-- end

function Model.__classonly.inspect_all_events()
	for id, model in pairs (all_models) do
		model:inspect_events()
	end
end