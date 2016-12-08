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
    local n = pars.i_n
    local delta = 0
    local bias = pars.i_bias

    local enc = ''

    local codepoints = { utf8.codepoint(str, 1, -1) }

    for _,v in ipairs(codepoints) do
        enc = enc .. ((v >= 0 and v < 128) and utf8.char(v) or '')
    end

    local basic_count = #enc
    local iter = basic_count

    if basic_count > 0 then enc = enc .. '-' end

    while iter < #codepoints do
        local m = 0x200000
        for _,v in ipairs(codepoints) do
            m = (v >= n and v < m) and v or m
        end

        delta = delta + (m - n) * (iter + 1)
        n = m
        for _,c in ipairs(codepoints) do
            delta = delta + (c < n and 1 or 0)
            if c == n then
                local q = delta
                k = pars.base
                while true do
                    local t = (k <= bias)             and pars.tmin or
                              (k >= bias + pars.tmax) and pars.tmax or (k - bias)
                    if q < t then break end
                    local char = math.floor(t + ((q - t) % (pars.base - t)))
                    enc = enc .. utf8.char(digittochar(char))
                    q = math.floor((q - t) / (pars.base - t))
                    k = k + pars.base
                end
                enc = enc .. utf8.char(digittochar(q))
                bias = adapt(delta, iter + 1, iter == basic_count)
                delta = 0
                iter = iter + 1
            end
        end
        delta = delta + 1
        n = n + 1
    end

    return enc
end

self.decode = function (str)
end

return self
