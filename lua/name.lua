-- http://stackoverflow.com/a/10387949/521032
local function read_all (file)
    local f = io.open(file, "rb")
    local content = f:read("*all")
    f:close()
    return content
end

local function split_lines (string)
	local res = {}
	for s in string:gmatch '[^\n]+' do
		res [#res + 1] = s
	end
	return res
end

local function capitalize (string)
	local a, b = string:match '^(.)(.*)$'
	return a:upper()..b:lower()
end

local first, last = read_all (Lucid.Home..'names/popular-both-first.txt'), read_all (Lucid.Home..'names/popular-last.txt')

first, last = split_lines (first), split_lines (last)
first, last = _.shuffle (first), _.shuffle (last)

local function name (target)
	if type (target) == 'table' then
		local mt, converter, address = getmetatable (target)
		if mt then
			converter, mt.__tostring = mt.__tostring, nil
			address = tostring (target):match '0x(.+)$'
			mt.__tostring = converter
		else
			address = tostring (target):match '0x(.+)$'
		end
		return name (tonumber (address, 16)) -- ..' (0x'..address..')'
	elseif type (target) == 'number' and target == math.floor (target) then
		local res_first, res_last = capitalize (first [math.fmod (target, #first) + 1]), {}
		target = math.floor (target / #first)
		while target > 0 do
			res_last [#res_last + 1] = capitalize (last [math.fmod (target, #last) + 1])
			target = math.floor (target / #last)
		end
		return #res_last == 0 and res_first or res_first..' '.._.join (res_last, '-')
	end
end

return name

-- to test: print (name (math.floor (math.random (0, 100000000000000))))