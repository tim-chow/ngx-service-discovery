local redis = require "resty.redis"
local CONFIG = require "MyConfig"

local _M = {
    __VERSION__ = "1.0"
}

local function _make_red_conn(host, port, password, timeout, channel)
    ngx.log(ngx.ERR, "_make_red_conn() is invoked...")
    local host = host or "127.0.0.1"
    local port = tonumber(port) or 6379
    local timeout = tonumber(timeout)
    if type(timeout) == "number" and timeout < 0 then
        error("invalid timeout", 2)
    end
    if type(channel) ~= "string" then
        error("invalid channel", 2)
    end

    local red = redis:new()
    if timeout then red:set_timeout(timeout) end

    local ok, err = red:connect(host, port)
    if not ok or err then return nil, 1, err end

    if type(password) == "string" then
        local ok, err = red:auth(password)
        if not ok then
            red:close()
            return nil, 2, err
        end
    end

    local ok, err = red:psubscribe(channel)
    if not ok then
        red:close()
        return nil, 3, err
    end

    return red
end

local function make_red_conn()
    return _make_red_conn(
        CONFIG.REDIS_ADVICE_HOST,
        CONFIG.REDIS_ADVICE_PORT,
        CONFIG.REDIS_ADVICE_PASSWORD,
        CONFIG.REDIS_ADVICE_CONNECT_TIMEOUT,
        CONFIG.REDIS_ADVICE_CHANNEL)
end

function _M.hold()
    local red = make_red_conn()
    local function _do_deal(read)
        if read == false then return red:close() end

        red:set_timeout(CONFIG.REDIS_ADVICE_TIMEOUT)
        local res, err = red:read_reply()
        if res then return res[4] end
        if err == "timeout" then return nil, "timeout" end

        red = make_red_conn() or red
        return res, err
    end
    return _do_deal
end

return _M

