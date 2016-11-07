local http = require "resty.http"

local CONFIG = require "MyConfig"
local UTIL = require "MyUtil"

local unpack = table.unpack or unpack
local ngx_thread_spawn = ngx.thread.spawn
local ngx_thread_wait = ngx.thread.wait
local split = UTIL.split

local _M = {
    __VERSION__ = "2.0"
}

local function _make_request(upstream)
    local httpc = http.new()
    httpc:set_timeout(
        tonumber(upstream.checktimeout) or 
        CONFIG.HTTP_DEFAULT_CHECK_TIMEOUT)

    local address = split(upstream.address, ":")
    local ok, err = httpc:connect(address[1],
        tonumber(address[2]) or 80)
    if not ok then return false, err end

    local res, err = httpc:request{
        method="GET",
        path=upstream.checkpath or CONFIG.HTTP_DEFAULT_CHECK_PATH,
        headers={
            Host=upstream.host,
        } 
    }
    httpc:set_keepalive()
    return res, err
end

local function _execute_health_check(upstream)
    local res, err = _make_request(upstream)
    if res and res.status == 200 then
        CONFIG.CLEAR_HEALTH_STATUS(upstream.address)
    else
        ngx.log(ngx.ERR, upstream.address..
            " is bad, because "..tostring(err))
        CONFIG.INCR_HEALTH_STATUS(upstream.address)
    end
end

function _M.execute_health_check(upstreams)
    local threads = {}
    for _, upstream in pairs(upstreams) do
        table.insert(threads,
            ngx_thread_spawn(
                _execute_health_check, upstream))
        if #threads >= CONFIG.HTTP_CHECK_THREAD_COUNT then
            ngx_thread_wait(threads[1])
            table.remove(threads, 1)
        end
    end
    if #threads > 0 then
        ngx_thread_wait(unpack(threads))
    end
end

return _M

