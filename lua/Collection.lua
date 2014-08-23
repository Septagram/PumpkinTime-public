class 'Collection' : extends 'Model' : attributes ('n')

function Collection:__preinit (attributes)
	return not self.is (attributes, Model) and attributes or nil
end

function Collection:__init (attributes, ...)
	self._children = {}
	self._attributes.n = 0

	if Model:is_parent (attributes) then
		return self:add (attributes, ...)
	else
		return self:add (...)
	end
end

Collection.__aset.n = _.void

function Collection:add (model, ...)
	if not model then return self end

	if not self._children [model] then
		self._children [model] = model
		model._collections [self] = self
		self._attributes.n = self._attributes.n + 1
		model:on ('destroy', self, 'remove')
		self:trigger ('add', model)
		model:trigger ('added_to_collection', self)
	end

	return self:add (...)
end

function Collection:remove (model, ...)
	if not model then return self end

	if self._children [model] then
		self._children [model] = nil
		model._collections [self] = nil
		self._attributes.n = self._attributes.n - 1
		model:off ('destroy', self)
		self:trigger ('remove', model)
		model:trigger ('removed_from_collection', self)
	end

	return self:remove (...)
end

function Collection:has (...)
	return _.all ({...}, function (model) return self._children [model] end)
end

function Collection:__call()
	return pairs (self._children)
end