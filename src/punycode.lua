self = {}

local pars =
  { base         = 36
  , tmin         = 1
  , tmax         = 26
  , skew         = 38
  , damp         = 700
  , initial_bias = 72
  , initial_n    = 128
  , delimiter    = 45
  }

local chartodigit = function (int)
    return (int >= 0x41 and int <= 0x5a) and int - 0x41 or
           (int >= 0x61 and int <= 0x7a) and int - 0x61 or
           (int >= 0x30 and int <= 0x39) and int - 0x16 or int
end

local digittochar = function (int)
    return (int >=  0 and int <= 25) and int + 0x61 or
           (int >= 26 and int <= 35) and int + 0x16 or int
end

local len = function (tbl)
    return #tbl + (tbl[0] and 1 or 0)
end

local adapt = function (delta, numpoints, firsttime)
    delta = math.floor(delta / (firsttime and pars.damp or 2))
    delta = math.floor(delta + delta / numpoints)
    local k = 0
    while delta > math.floor((pars.base - pars.tmin) * pars.tmax / 2) do
        delta = math.floor(delta / (pars.base - pars.tmin))
        k = math.floor(k + pars.base)
    end

    return math.floor(k + (pars.base - pars.tmin + 1) * delta / (delta + pars.skew))
end

self.encode = function (str)
    local n = pars.initial_n
    local delta = 0
    local bias = pars.initial_bias

    local codepoints = { utf8.codepoint(str, 1, -1) }
    for c = 0, #codepoints - 1 do
        codepoints[c] = codepoints[c + 1]
    end
    codepoints[#codepoints] = nil

    local target = {}
    for c = 0, #codepoints do
        local v = codepoints[c]
        if v >= 0 and v < 128 and utf8.char(v) then
            target[len(target)] = v
        end
    end

    local basic_count = len(target)
    local h = basic_count

    if basic_count > 0 then target[#target + 1] = pars.delimiter end

    while h < #codepoints do
        local m = 0x200000
        for c = 0, #codepoints do
            local v = codepoints[c]
            m = (v >= n and v < m) and v or m
        end

        delta = delta + (m - n) * (h + 1)
        n = m
        for c = 0, #codepoints do
            delta = delta + (c < n and 1 or 0)
            if c == n then
                local q = delta
                k = pars.base

                while true do
                    local t = (k <= bias)             and pars.tmin or
                              (k >= bias + pars.tmax) and pars.tmax or (k - bias)
                    if q < t then break end
                    local char = math.floor(t + ((q - t) % (pars.base - t)))
                    target[len(target)] = utf8.char(digittochar(char))
                    q = math.floor((q - t) / (pars.base - t))
                    k = k + pars.base
                end

                target[len(target)] = utf8.char(digittochar(q))
                bias = adapt(delta, h + 1, h == basic_count)
                delta = 0
                h = h + 1
            end
        end

        delta = delta + 1
        n = n + 1
    end

    local enc = ''
    for k = 0, #target do
        enc = enc .. utf8.char(target[k])
    end

    return enc
end

self.decode = function (str)

    local codepoints = { utf8.codepoint(str, 1, -1) }
    for c = 0, #codepoints - 1 do
        codepoints[c] = codepoints[c + 1]
    end
    codepoints[#codepoints] = nil

    local last_delim = 0
    for c = 1, #codepoints do
        last_delim = (codepoints[c] == pars.delimiter and c > last_delim) and c or last_delim
    end

    local target = {}
    if last_delim ~= 0 then
        for c = 0, last_delim - 1 do
            target[len(target)] = codepoints[c]
        end
    end

    local n = pars.initial_n
    local i = 0
    local bias = pars.initial_bias

    local consumed = last_delim > 0 and last_delim + 1 or 0
    while consumed < #codepoints do
        local old_i = i
        local w = 1
        for k = pars.base, 18446744073709551615, pars.base do
            local digit = chartodigit(codepoints[consumed])
            consumed = consumed + 1
            i = math.floor(i + digit * w)
            local t = (k <= bias)             and pars.tmin or
                      (k >= bias + pars.tmax) and pars.tmax or (k - bias)
            if digit < t then break end
            w = math.floor(w * (pars.base - t))
        end

        local length = len(target) + 1

        bias = adapt(i - old_i, length, old_i == 0)
        n = math.floor(n + i / length)
        i = math.floor(i % length)
        if i == 0 then
            table.insert(target, 1, n)
            local tmp = target[0]
            target[0] = target[1]
            target[1] = tmp
        else
            table.insert(target, i, n)
        end
        i = i + 1
    end

    local dec = ''
    for k = 0, #target do
        dec = dec .. utf8.char(target[k])
    end

    return dec
end

return self
