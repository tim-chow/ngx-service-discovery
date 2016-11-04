local redis = require "resty.redis"

local _M = {
    __VERSION__ = "2.0"
}

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

local function parseQueryString(str)
    local pos, result = 1, {}

    while pos <= #str do
        local s, e = string.find(str, "&", pos)
        if s then
            substr = string.sub(str, pos, s-1)
            pos = e + 1
        else
            substr = string.sub(str, pos, #str)
            pos = #str+1
        end

        if #substr > 0 then
            local si, ei = string.find(substr, "=")
            if not si then
                result[substr] = true
            else
                result[string.sub(substr, 1, si-1)] = string.sub(substr, ei+1)
            end
        end
    end
    return result
end

function _M.parseURL(url)
    if type(url) ~= "string" then
        error("invalid url", 2)
    end
    local parseResult, pos = {}, 1

    -- parse schema
    local s, e, schema = string.find(url, "(.-)://", pos)
    if s == pos then
        parseResult.schema = schema
        pos = e + 1
    else 
        parseResult.schema = ""
    end

    -- parse auth
    local s, e, user, password = string.find(url,
        "([%w%d%.%-%+_=]-):([%w%d%.%-%+_=]-)@", pos)
    if s == pos then 
        parseResult.user = user
        parseResult.password = password
        pos = e + 1
    end

    -- parse host
    local s, e, host= string.find(url, "([%w%d%-%.]+[%w%d%-]+)", pos)
    if s == pos then 
        parseResult.host = host
        pos = e + 1
    end

    -- parse port
    local s, e, port = string.find(url, ":(%d+)", pos)
    if s == pos then
        parseResult.port = port
        pos = e + 1
    end

    -- parse fragment
    local s, e, fragment = string.find(url, "#(.-)$", pos)
    if s then
        parseResult.fragment = fragment
        url = string.sub(url, 1, s-1)
    end

    -- parse query string
    local s, e, query_string = string.find(url, "%?(.*)$", pos)
    if s then
        parseResult.query_string = parseQueryString(query_string or "")
        url = string.sub(url, 1, s-1)
    end

    -- parse path
    if string.sub(url, pos, pos) ~= "/" then
        return parseResult
    end
    parseResult.path = string.sub(url, pos, #url)
    return parseResult
end

_M.split = split
_M.myrandom = myrandom
return _M

