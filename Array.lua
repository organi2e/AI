local Set = require('./AI/USER_AI/Set')
local Array = {}
Array.new = function(class, array)
 local empty = {}
 return setmetatable(type(array) == type(empty) and array or empty, {__index=class, __tostring=class.tostring, __add=function(a, b) local array = Array:new() a:forEach(function(v) array:push(v) end) b:forEach(function(v) array:push(v) end) return array end})
end
Array.range = function(class, v, e, i)
 local array = class:new()
 if v and e and i then
  for k = v, e, i do array:push(k) end
 elseif v and e then
  for k = v, e do array:push(k) end
 elseif v then 
  for k = 1, v do array:push(k) end
 end
 return array
end
Array.clone = function(self)
 return Array:new({unpack(self)})
end
Array.getSize = table.getn
Array.isEmpty = function(self)
 return self:getSize() == 0
end
Array.getFirst = function(self)
 return self[1]
end
Array.getLast = function(self)
 return self[#self]
end
Array.getMaximumElement = function(self, closure)
 local element = nil
 local maximum = nil
 local measure = closure or function(v) return v end
 self:forEach(function(value, index)
  local score = measure(value, index)
  if score and ( not maximum or score > maximum ) then
   element, maximum = value, score
  end
 end)
 return element, maximum
end
Array.getMinimumElement = function(self, closure)
 local element = nil
 local minimum = nil
 local measure = closure or function(v) return v end
 self:forEach(function(value, index)
  local score = measure(value, index)
  if score and ( not minimum or score < minimum ) then
   element, minimum = value, score
  end
 end)
 return element, minimum
end
Array.any = function(self, closure)
 assert(type(closure)==type(assert))
 for index, value in ipairs(self) do
  if closure(value, index) then
   return true
  end   
 end
end
Array.all = function(self, closure)
 return not self:any(function(value, index)
  return not closure(value, index)
 end)
end
Array.map = function(self, closure)
 assert(type(closure)==type(assert))
 local array = Array:new()
 self:forEach(function(value, index)
  array:push(closure(value, index)) -- hackable design
 end)
 return array
end
Array.filter = function(self, closure)
 assert(type(closure)==type(assert))
 local array = Array:new()
 self:forEach(function(value, index)
  if closure(value, index) then
   array:push(value)
  end
 end)
 return array
end
Array.reduce = function(self, initial, closure)
 assert(type(closure)==type(assert))
 local result = initial
 self:forEach(function(value, index)
  result = closure(result, value, index)
 end)
 return result
end
Array.sort = function(self, cmp)
 table.sort(self, cmp or function(a, b) return a < b end)
 return self
end
Array.sorted = function(self, cmp)
 return self:clone():sort(cmp)
end
Array.forEach = function(self, closure)
 assert(type(closure)==type(assert))
 for index = 1, #self do
  closure(self[index], index)
 end
 return self
end
Array.push = table.insert
Array.pop = table.remove
Array.enque = function(self, value)
 return self:push(1, value)
end
Array.tostring = function(self, visit)
 local check = visit or Set:new()
 local index = check:index(self)
 if index then
  return string.format('<table %d>', index)
 else
  local result = nil
  local index = check:insert(self)
  table.foreach(self, function(index, value)
   result = ( result and result .. ', ' or '' ) .. ( type(value) == type(self) and getmetatable(value).__tostring or tostring ) ( value, check )
  end)
  return string.format('Array<table %d> {%s}', index, result or '')
 end
end
return Array