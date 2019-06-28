local EIRA          = 48
local BAYERI        = 49
local SERA          = 50
local DIETER        = 51
local ELEANOR       = 52

local critic = nil
local order = nil
local agent = nil

function AI(id)

 -- allocate critic
 if not critic then
  critic = require('./AI/USER_AI/Critic'):new()
  critic:restore()
 end
 
 -- allocate order
 if not order then
  order = require('./AI/USER_AI/Order'):new()
  order:restore()
 end
 
 -- allocate actor
 if not agent then
  local homuntype = GetV(V_HOMUNTYPE, id)
  if not homuntype then
   -- nil
  elseif homuntype == SERA then
   agent = require('./AI/USER_AI/VANSER'):new()
   agent:restore()
  else
   -- nil
  end
 end
 
 -- main routine
 if critic and order and agent then
  local env = critic:observe(id)
  local cmd = order:observe(id, env)
  critic:execute(env, cmd)
  agent:execute(cmd)
  agent:routine(env)
 end
end