-- Copyright (c) 2009 Marcus Irven
--  
-- Permission is hereby granted, free of charge, to any person
-- obtaining a copy of this software and associated documentation
-- files (the "Software"), to deal in the Software without
-- restriction, including without limitation the rights to use,
-- copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the
-- Software is furnished to do so, subject to the following
-- conditions:
--  
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--  
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
-- OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
-- NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
-- HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
-- WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
-- OTHER DEALINGS IN THE SOFTWARE.

--- Underscore is a set of utility functions for dealing with 
-- iterators, arrays, tables, and functions.

local Underscore = { funcs = {} }
Underscore.__index = Underscore

function Underscore.__call(_, value)
	return Underscore:new(value)
end

function Underscore:new(value, chained)
	return setmetatable({ _val = value, chained = chained or false }, self)
end

function Underscore.iter(list_or_iter)
	if type(list_or_iter) == "function" then return list_or_iter end
	
	return coroutine.wrap(function() 
		for i=1,#list_or_iter do
			coroutine.yield(list_or_iter[i])
		end
	end)
end

function Underscore.callback (value)
	return value == nil and Underscore.identity or type (value) == 'function' and value or function (v) return v [value] end
end

function Underscore.range(start_i, end_i, step)
	if end_i == nil then
		end_i = start_i
		start_i = 1
	end
	step = step or 1
	local range_iter = coroutine.wrap(function() 
		for i=start_i, end_i, step do
			coroutine.yield(i)
		end
	end)
	return Underscore:new(range_iter)
end

--- Identity function. This function looks useless, but is used throughout Underscore as a default.
-- @name _.identity
-- @param value any object
-- @return value
-- @usage _.identity("foo")
-- => "foo"
function Underscore.identity (value)
	return value
end

function Underscore.identities (...)
	return ...
end

-- notice the evil magic: colon instead of a dot here
-- creates a dummy 'self' variable that is magically discarded immediately
function Underscore:shift_identities (...)
	return ...
end
Underscore.shiftIdentities = Underscore.shift_identities

function Underscore.constant (value)
	return function()
		return value
	end
end

function Underscore.constants (...)
	val = {...}
	return function()
		return unpack (val)
	end
end

function Underscore.multiply (value, count)
	if count == 0 then return end
	return value, Underscore.multiply (value, count - 1)
end

function Underscore.void() end

-- chaining

function Underscore:chain()
	self.chained = true
	return self
end

function Underscore:value()
	return self._val
end

-- iter

function Underscore.funcs.append (target, ...)
	i = table.getn (target)
	for __, source in ipairs {...} do
		for j = 1, table.getn (source) do
			i = i + 1
			target [i] = source [j]
		end
	end
	return target
end

function Underscore.funcs.each(target, func)
	for k, v in pairs (target) do
		func (k, v)
	end
	return target
end

function Underscore.funcs.map(list, func)
	local mapped = {}
	for i in Underscore.iter(list) do
		mapped[#mapped+1] = func(i)
	end	
	return mapped
end

function Underscore.funcs.map_values (list, func)
	local res, nv = {}
	for k, v in pairs (list) do -- TODO: implement a proper key-value pairs iterator (_.flip to flip iterator)
		res [k] = func (v, k)
	end
	return res
end

function Underscore.funcs.map_all (list, func)
	local res, nk, nv = {}
	for k, v in pairs (list) do -- TODO: implement a proper key-value pairs iterator (_.flip to flip iterator)
		nv, nk = func (v, k)
		res [nk] = nv
	end
	return res
end

function Underscore.funcs.index_by (list, func)
	func = Underscore.callback (func)
	local res = {}
	for k, i in pairs (list) do
		res [func (i)] = i
	end
	return res
end

function Underscore.funcs.reduce(list, memo, func)	
	for i in Underscore.iter(list) do
		memo = func(memo, i)
	end	
	return memo
end

function Underscore.funcs.detect(list, func)
	for i in Underscore.iter(list) do
		if func(i) then return i end
	end	
	return nil	
end

function Underscore.funcs.select(list, func)
	local selected = {}
	for i in Underscore.iter(list) do
		if func(i) then selected[#selected+1] = i end
	end
	return selected
end

function Underscore.funcs.filter_values (target, func)
	local res = {}
	for k, v in pairs (target) do
		if func (v, k) then
			res [k] = v
		end
	end
	return res
end

function Underscore.funcs.reject(list, func)
	local selected = {}
	for i in Underscore.iter(list) do
		if not func(i) then selected[#selected+1] = i end
	end
	return selected
end

function Underscore.funcs.all(list, func)
	func = func or Underscore.identity
	
	-- TODO what should happen with an empty list?
	for i in Underscore.iter(list) do
		if not func(i) then return false end
	end
	return true
end

function Underscore.funcs.any(list, func)
	func = func or Underscore.identity

	-- TODO what should happen with an empty list?	
	for i in Underscore.iter(list) do
		if func(i) then return true end
	end	
	return false
end

function Underscore.funcs.include(list, value)
	for i in Underscore.iter(list) do
		if i == value then return true end
	end	
	return false
end

function Underscore.funcs.invoke(list, function_name, ...)
	local args = {...}
	Underscore.funcs.each(list, function(i) i[function_name](i, unpack(args)) end)
	return list
end

function Underscore.funcs.pluck (list, property_name)
	return Underscore.funcs.map_values(list, function(i) return i[property_name] end)
end

function Underscore.funcs.min(list, func)
	func = func or Underscore.identity
	
	return Underscore.funcs.reduce(list, { item = nil, value = nil }, function(min, item) 
		if min.item == nil then
			min.item = item
			min.value = func(item)
		else
			local value = func(item)
			if value < min.value then
				min.item = item
				min.value = value
			end
		end
		return min
	end).item
end

function Underscore.funcs.max(list, func)
	func = func or Underscore.identity
	
	return Underscore.funcs.reduce(list, { item = nil, value = nil }, function(max, item) 
		if max.item == nil then
			max.item = item
			max.value = func(item)
		else
			local value = func(item)
			if value > max.value then
				max.item = item
				max.value = value
			end
		end
		return max
	end).item
end

function Underscore.funcs.read_only (table, ignore_write, error_message)
	if type (ignore_write) == 'string' then
		ignore_write, error_message = error_message, ignore_write
	end
	return setmetatable ({}, {
		__index = table,
		__newindex = ignore_write and Underscore.void or
			function() assert (false, error_message or 'Write attempt on readonly table '..name (table)) end,
	})
end

function Underscore.funcs.write_watcher (table, callback)
	if not callback then
		table, callback = {}, table
	end

	local res = setmetatable ({}, {
		__call = Underscore.constant (table),
		__index = table,
		__newindex = function (self, key, value)
			local old_value
			old_value, table [key] = table [key], value
			callback (self, key, value, old_value)
		end,
	})

	return res
end

function Underscore.funcs.member_write_watcher (object, table, callback)
	if not callback then
		table, callback = {}, table
	end

	callback = Underscore.wrap (callback, function (callback, self, k, v)
		return callback (object, k, v)
	end)

	return Underscore.write_watcher (table, callback)
end

function Underscore.funcs.to_array(list)
	local array = {}
	for i in Underscore.iter(list) do
		array[#array+1] = i
	end	
	return array
end

function Underscore.funcs.reverse(list)
	local reversed = {}
	for i in Underscore.iter(list) do
		table.insert(reversed, 1, i)
	end	
	return reversed
end

function Underscore.funcs.sort(iter, comparison_func)
	local array = iter
	if type(iter) == "function" then
		array = Underscore.funcs.to_array(iter)
	end
	table.sort(array, comparison_func)
	return array
end

-- arrays

function Underscore.funcs.first(array, n)
	if n == nil then
		return array[1]
	else
		local first = {}
		n = math.min(n,#array)
		for i=1,n do
			first[i] = array[i]			
		end
		return first
	end
end

function Underscore.funcs.rest(array, index)
	index = index or 2
	local rest = {}
	for i=index,#array do
		rest[#rest+1] = array[i]
	end
	return rest
end

function Underscore.funcs.slice(array, start_index, length)
	local sliced_array = {}
	
	start_index = math.max(start_index, 1)
	local end_index = math.min(start_index+length-1, #array)
	for i=start_index, end_index do
		sliced_array[#sliced_array+1] = array[i]
	end
	return sliced_array
end

function Underscore.funcs.flatten(array)
	local all = {}
	
	for ele in Underscore.iter(array) do
		if type(ele) == "table" then
			local flattened_element = Underscore.funcs.flatten(ele)
			Underscore.funcs.each(flattened_element, function(e) all[#all+1] = e end)
		else
			all[#all+1] = ele
		end
	end
	return all
end

function Underscore.funcs.push(array, item)
	table.insert(array, item)
	return array
end

function Underscore.funcs.pop(array)
	return table.remove(array)
end

function Underscore.funcs.shift(array)
	return table.remove(array, 1)
end

function Underscore.funcs.unshift(array, item)
	table.insert(array, 1, item)
	return array
end

function Underscore.funcs.join(array, separator)
	return table.concat(array, separator)
end

-- http://snippets.luacode.org/snippets/Shuffle_array_145
function Underscore.funcs.shuffle (array)
	local n, order, res = #array, {}, {}
	 
	for i=1,n do order[i] = { rnd = math.random(), idx = i } end
	table.sort(order, function(a,b) return a.rnd < b.rnd end)
	for i=1,n do res[i] = array[order[i].idx] end
	return res
end

-- objects

function Underscore.funcs.object (keys, values)
	local res, values_iter = {}, Underscore.iter (values)
	for k in Underscore.iter (keys) do
		res [k] = values_iter()
	end
	return res
end

function Underscore.funcs.collect_values (...)
	local res = {}
	for k, v in ... do
		res [k] = v
	end
	return res
end

function Underscore.funcs.keys(obj)
	local keys = {}
	for k,v in pairs(obj) do
		keys[#keys+1] = k
	end
	return keys
end

function Underscore.funcs.values(obj)
	local values = {}
	for k,v in pairs(obj) do
		values[#values+1] = v
	end
	return values
end

function Underscore.funcs.extend (destination, ...)
	for __, source in ipairs {...} do
		for k,v in pairs (source) do
			destination [k] = v
		end	
	end
	return destination
end

function Underscore.funcs.defaults (destination, ...)
	for __, source in ipairs {...} do
		for k,v in pairs (source) do
			if destination [k] == nil then
				destination [k] = v
			end
		end
	end
	return destination
end

function Underscore.funcs.clear (target)
	for k in pairs (target) do
		target [k] = nil
	end
	return target
end

function Underscore.funcs.is_empty (obj)
	return next(obj) == nil
end

-- Originally based on penlight's deepcompare() -- http://luaforge.net/projects/penlight/
function Underscore.funcs.is_equal(o1, o2, ignore_mt)
	local ty1 = type(o1)
	local ty2 = type(o2)
	if ty1 ~= ty2 then return false end
	
	-- non-table types can be directly compared
	if ty1 ~= 'table' then return o1 == o2 end
	
	-- as well as tables which have the metamethod __eq
	local mt = getmetatable(o1)
	if not ignore_mt and mt and mt.__eq then return o1 == o2 end
	
	local is_equal = Underscore.funcs.is_equal
	
	for k1,v1 in pairs(o1) do
		local v2 = o2[k1]
		if v2 == nil or not is_equal(v1,v2, ignore_mt) then return false end
	end
	for k2,v2 in pairs(o2) do
		local v1 = o1[k2]
		if v1 == nil then return false end
	end
	return true
end

function Underscore.funcs.get (obj, ...)
	for i, key in ipairs {...} do
		if obj == nil then
			return obj
		elseif key ~= nil then
			obj = obj [key]
		end
	end
	return obj
end

function Underscore.funcs.init (obj, ...)
	for i, key in ipairs {...} do
		if obj [key] then
			obj = obj [key]
		else
			obj, obj [key] = _.multiply ({}, 2)
		end
	end

	return obj
end

-- functions

function Underscore.funcs.recurse (...)
	local args = {...}
	local fn = args [#args]
	local function callee (...)
		return fn (callee, ...)
	end
	args [#args] = nil
	return callee (unpack (args))
end

function Underscore.funcs.scope (...)
	local args = {...}
	local func = args [#args]
	args [#args] = nil
	return func (unpack (args))
end

function Underscore.funcs.compose(...)
	local function call_funcs(funcs, ...)
		if #funcs > 1 then
			return funcs[1](call_funcs(_.rest(funcs), ...))
		else
			return funcs[1](...)
		end
	end
	
	local funcs = {...}
	return function(...)
		return call_funcs(funcs, ...)
	end
end

function Underscore.funcs.wrap (func, wrapper)
	return function(...)
		return wrapper(func, ...)
	end
end

function Underscore.funcs.curry (func, ...)
	if #{...} == 1 then
		local argument = ...
		return function (...)
			return func (argument, ...)
		end
	else
		local args = {...}
		return function (...)
			return func (unpack (_.append ({}, args, {...})))
		end
	end
end

function Underscore.funcs.curry_right (func, ...)
	local args = {...}
	return function (...)
		return func (unpack (_.append ({...}, args)))
	end
end

-- BROKEN because I don't understand Lua iterators
function Underscore.funcs.curry_any (func, args)
	return function (...)
		local new_args, i, iter, arg, __ = {}, 1, ipairs {...}
		repeat
			if args [i] then
				new_args [i] = args [i]
			else
				__, arg = iter()
				new_args [i] = arg
			end
			i = i + 1
		until arg == nil
		return func (unpack (new_args))
	end
end

function Underscore.funcs.lock_args (func)
	return function()
		return func()
	end
end

function Underscore.functions() 
	return Underscore.keys(Underscore.funcs)
end

-- add aliases
Underscore.methods = Underscore.functions

Underscore.funcs.for_each = Underscore.funcs.each
Underscore.funcs.collect = Underscore.funcs.map
Underscore.funcs.inject = Underscore.funcs.reduce
Underscore.funcs.foldl = Underscore.funcs.reduce
Underscore.funcs.filter = Underscore.funcs.select
Underscore.funcs.every = Underscore.funcs.all
Underscore.funcs.some = Underscore.funcs.any
Underscore.funcs.head = Underscore.funcs.first
Underscore.funcs.tail = Underscore.funcs.rest

local function wrap_functions_for_oo_support()
	local function value_and_chained (value_or_self)
		local chained = false
		if getmetatable (value_or_self) == Underscore then 
			chained = value_or_self.chained
			value_or_self = value_or_self._val 
		end
		return value_or_self, chained
	end

	local function value_or_wrap (chained, ...)
		if chained then return Underscore:new (Underscore.identity (...), true) end
		return ...
	end

	for fn, func in pairs(Underscore.funcs) do
		Underscore[fn] = function(obj_or_self, ...)
			local obj, chained = value_and_chained(obj_or_self)	
			return value_or_wrap (chained, func(obj, ...))
			-- TODO: here the order of arguments was changed to let Underscore
			-- functions return multiple values
		end

		if fn:match '_[^_]' then
			Underscore [fn:gsub ('_([^_])([^_]+)', function (first, others) return first:upper()..others end)] = Underscore [fn]
		end
	end
end

wrap_functions_for_oo_support()

return Underscore:new()
