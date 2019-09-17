require('./AI/Const')

local EIRA          = 48
local BAYERI        = 49
local SERA          = 50
local DIETER        = 51
local ELEANOR       = 52

local AGENTS = {
 [SERA]='./AI/USER_AI/VANSER',
}

local critic = require('./AI/USER_AI/Critic'):new():restore()
local order = require('./AI/USER_AI/Order'):new():restore()
local agent = nil

function AI(id)
 if agent then -- main routine
  local env = critic:observe(id)
  local cmd = order:observe(id, env)
  critic:execute(env, cmd)
  agent:execute(cmd)
  agent:routine(env)
 else -- allocate actor
  local path = AGENTS[GetV(V_HOMUNTYPE, id)]
  agent = path and require(path):new():restore()
 end
end