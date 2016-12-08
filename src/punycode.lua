self = {}

local pars =
  { base   = 36
  , tmin   = 1
  , tmax   = 26
  , skew   = 70
  , damp   = 700
  , i_bias = 72
  , i_n    = 128
  }

local chartodigit = function (int)
    adj = (int >= 0x41 and int <= 0x5a) and int - 0x41 or
          (int >= 0x61 and int <= 0x7a) and int - 0x61 or
          (int >= 0x30 and int <= 0x39) and int - 0x16 or int

    return adj
end

local digittochar = function (int)
    adj = (int >=  0 and int <= 25) and int + 0x61 or
          (int >= 26 and int <= 35) and int + 0x16 or int

    return adj
end

local adapt = function (delta, numpoints, firsttime)
    delta = delta / (firsttime and pars.damp or 2)
    delta = delta + delta / numpoints
    local k = 0
    while delta > ((pars.base - pars.tmin) * pars.tmax) / 2 do
        delta = delta / (pars.base - pars.tmin)
        k = k + pars.base
    end

    return k + (((pars.base - pars.tmin + 1) * delta) / (delta + pars.skew))
end

self.encode = function (str)
end

self.decode = function (str)
end

return self
