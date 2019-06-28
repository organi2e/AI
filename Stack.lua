local Set = require('./AI/USER_AI/Set')
local Stack = {}
Stack.new = function(class)
 return setmetatable({}, {__index=class, __tostring=class.tostring})
end
Stack.enque = function(self, value)
 table.insert(self, 1, value)
end
Stack.deque = table.remove
Stack.push = table.insert
Stack.pop = table.remove
Stack.tostring = function(self, visit)
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
  return string.format('Stack<table %d> {%s}', index, result or '')
 end
end
return Stack