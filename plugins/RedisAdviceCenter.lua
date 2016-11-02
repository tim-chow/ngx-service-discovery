local UTIL = require "MyUtil"
local CONFIG = require "MyConfig"

local _M = {
    __VERSION__ = "1.0"
}


local function _do_read()
    while true do
        local read_reply, code, err = UTIL.subscribe(
            CONFIG.REDIS_ADVICE_HOST,
            CONFIG.REDIS_ADVICE_PORT,
            CONFIG.REDIS_ADVICE_PASSWORD,
            CONFIG.REDIS_ADVICE_CHANNEL,
            CONFIG.REDIS_ADVICE_TIMEOUT)
        if read_reply then return read_reply end
        ngx.log(ngx.ERR, "UTIL.subscribe failed, code:"..code..", err:"..err)
        ngx.sleep(CONFIG.REDIS_ADVICE_RECONNECT_DELAY)
    end
end

function _M.hold()
    local read_reply = _do_read()
    local function _do_deal(read)
        if read == false then
            return pcall(read_reply, false)
        end
        while true do
            local message, err = read_reply()
            if message then
                return message[3]
            else
                ngx.log(ngx.ERR, "reconnecting, because: "..err)
                read_reply = _do_read()
            end 
        end
    end
    return _do_deal
end

return _M

