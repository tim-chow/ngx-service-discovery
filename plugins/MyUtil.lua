local _M = {}

local function split(source, pattern)
    local pos = 0 
    local result = {}
    while true do
        local s, e = string.find(source, pattern, pos)
        if not s then break end 
        table.insert(result, string.sub(source, pos, s-1))
        pos = e + 1 
    end 
    if pos <= string.len(source) then
        table.insert(result, string.sub(source, pos, string.len(source)))
    elseif pos == string.len(source) + 1 then
        table.insert(result, "") 
    end 
    return result
end

local function myrandom(...)
    math.randomseed(tostring(os.time()):reverse():sub(1, 6))
    return math.random(...)
end

_M.split = split
_M.myrandom = myrandom
return _M

