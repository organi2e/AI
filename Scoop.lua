local function indexof(table, obj)
 for index, value in pairs(table) do
  if obj == value then
   return index
  end
 end
end
local function val2str(obj, visit)
 if not type(obj) then
  return ''
 elseif type(obj) == type({}) then
  local stack = visit or {}
  local found = indexof(stack, obj)
  if found then
   return string.format('<table %d>', found)
  elseif getmetatable(obj) and getmetatable(obj).__tostring then
   return getmetatable(obj).__tostring(obj)
  else
   table.insert(stack, obj)
   local result = nil
   local count = #stack
   local visit = {}
   for index = 1, #obj do
	local keyval = nil
	local value = obj[index]
    if not type(index) then
	elseif type(index) == type('') then
	 keyval = string.format('%s=%s', index, val2str(value, stack))
	elseif type(index) == type(0) then
	 keyval = val2str(value, stack)
	else
	 keyval = string.format('%s=%s', val2str(index, stack), val2str(value, stack))
	end
	if keyval then
	 table.insert(visit, index)
     result = ( result and ( result..', ' ) or '' ) .. keyval
	end
   end
   table.foreach(obj, function(index, value)   
    if indexof(visit, index) then return end
    local keyval = nil
    if not type(index) then
	elseif type(index) == type('') then
	 keyval = string.format('%s=%s', index, val2str(value, stack))
	elseif type(index) == type(0) then
	 keyval = string.format('[%d]=%s', index, val2str(value, stack))
	else
	 keyval = string.format('%s=%s', val2str(index, stack), val2str(value, stack))
	end
	if keyval then
     result = ( result and ( result..', ' ) or '' ) .. keyval
	end
   end)
   return string.format('<table %d> {%s}', count, result or '')
  end
 elseif type(obj) == type(nil) then
  return 'nil'
 elseif type(obj) == type('') then
  return string.format('%q', obj)
 elseif type(obj) == type(0) then
  return string.format('%g', obj)
 else
  return string.format('<%s>', tostring(obj))
 end
end
if true then
 local a = {1,nil,3,4}
 local b = {'x','y',nil,'w'}
 local c = {a=a, b=b}
 a[6] = 20
 a[c] = b
 b[a] = setmetatable(c, a)
 c['enemy'] = math.abs
 print(val2str(a))
end
return val2str