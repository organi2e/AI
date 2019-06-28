local Set = {}
Set.new = function(class)
 return setmetatable({}, {__index=class, __tostring=class.tostring})
end
Set.insert = function(self, value)
 self[value] = self[value] or ( self:count() + 1 )
 return self[value]
end
Set.remove = function(self, value)
 self[value] = nil
end
Set.count = function(self)
 local count = 0
 table.foreach(self, function()
  count = count + 1
 end)
 return count
end
Set.index = function(self, value)
 return self[value]
end
Set.tostring = function(self, visit)
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
  return string.format('Set<table %d> {%s}', index, result or '')
 end
end
return Set