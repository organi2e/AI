local Store = {}
function Store:save(tbl, p)
 local file, err = io.open(p, 'wb')
 if err then
  return _, err
 else
  local toescape = function(s)
   return string.format('%q', s)
  end
  local charS, charE = '\t', '\n'
  local tables, lookup = {tbl}, {[tbl]=1}
  file:write('return {'..charE)
  for idx, t in ipairs(tables) do
   file:write('--Table: {'..idx..'}'..charE)
   file:write('{'..charE)
   local thandled = {}
   for i, v in ipairs(t) do
    thandled[i] = true
    if type(v) == type({}) then
     if not lookup[v] then
      table.insert(tables, v)
      lookup[v] = #tables
     end
     file:write(charS..'{'..lookup[v]..'},'..charE)
    elseif type(v) == type(p) then
     file:write(charS..toescape(v)..','..charE)
    elseif type(v) == type(0) then
     file:write(charS..tostring(v)..','..charE)
    end
   end
   for i, v in pairs(t) do
    if not thandled[i] then
     local str = ''
     if type(i) == type({}) then
      if not lookup[i] then
       table.insert(tables, i)
       lookup[i] = #tables
      end
      str = charS..'[{'..lookup[i]..'}]='
     elseif type(i) == type(p) then
      str = charS..'['..toescape(i)..']='
     elseif type(i) == type(0) then
      str = charS..'['..tostring(i)..']='
     end
     if str ~= '' then
      if type(v) == type({}) then
       if not lookup[v] then
        table.insert(tables, v)
        lookup[v] = #tables
       end
       file:write(str..'{'..lookup[v]..'},'..charE)
      elseif type(v) == type(p) then
       file:write(str..toescape(v)..','..charE)
      elseif type(v) == type(0) then
       file:write(str..tostring(v)..','..charE)
      end
     end
    end
   end
   file:write('},'..charE)
  end
  file:write('}')
  file:close()
  return self
 end
end
function Store:load(path)
 local factory, err = loadfile(path)
 if err then
  return _, err
 else
  local cache = factory()
  for idx, tbl in ipairs(cache) do
   local ref = {}
   for index, value in pairs(tbl) do
    if type(value) == type({}) then
     assert(#value == 1)
     tbl[index] = cache[value[1]]
    end
    if type(index) == type({}) then
     ref[index] = cache[index[1]]
    end
   end
   for k, v in pairs(ref) do
    tbl[v], tbl[k] = tbl[k], nil
   end
  end
  return cache[1]
 end
end
return Store