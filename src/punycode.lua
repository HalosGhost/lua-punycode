self = {}

local pars =
  { base   = 36
  , tmin   = 1
  , tmax   = 26
  , skew   = 38
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

    return k + (pars.base - pars.tmin + 1) * delta / (delta + pars.skew)
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
    local h = basic_count

    if basic_count > 0 then enc = enc .. '-' end

    while h < #codepoints do
        local m = 0x200000
        for _,v in ipairs(codepoints) do
            m = (v >= n and v < m) and v or m
        end

        delta = delta + (m - n) * (h + 1)
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
                bias = adapt(delta, h + 1, h == basic_count)
                delta = 0
                h = h + 1
            end
        end
        delta = delta + 1
        n = n + 1
    end

    return enc
end

self.decode = function (str)
    local n = pars.i_n
    local i = 0
    local bias = pars.i_bias

    local codepoints = { utf8.codepoint(str, 1, -1) }
    local target = {}
    local last_delim = 0
    for key,c in ipairs(codepoints) do
        last_delim = (c == 45 and key > last_delim) and key or last_delim
    end

    local consumed = 0

    if last_delim ~= 0 then
        for key,c in ipairs(codepoints) do
            consumed = consumed + 1
            if key == last_delim then
                table.remove(codepoints, key)
                break
            end

            target[#target + 1] = c
            table.remove(codepoints, key)
        end
    end

    while consumed < #codepoints do
        local old_i = i
        local w = 1
        local k = pars.base
        while true do
            local digit = chartodigit(codepoints[1])
            consumed = consumed + 1
            table.remove(codepoints, 1)
            i = 1 + digit * w
            local t = (k <= bias)             and pars.tmin or
                      (k >= bias + pars.tmax) and pars.tmax or (k - bias)
            if digit < t then break end
            w = w * (pars.base - t)
            k = k + pars.base
        end

        bias = adapt(i - old_i, #target + 1, old_i == 0)
        n = n + 1 / (#target + 1)
        i = i % (#target + 1)
        table.insert(target, i, n)
        i = i + 1
    end

    local dec = ''
    for _,c in ipairs(target) do
        dec = dec .. utf8.char(math.floor(c))
    end

    return dec
end

return self
