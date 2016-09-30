local CONFIG = require "MyConfig"
local UTIL = require "MyUtil"
local _M = {}

local function filter_upstreams(upstreams, host, uri, kick)
    local result = {}
    for _, upstream in pairs(upstreams) do
        if (host == 
            upstream.hostname) and ngx.re.match(uri,
            upstream.uripattern) then
            if not kick or CONFIG.IS_UPSTREAM_OK(upstream.address) then
                table.insert(result, upstream)
            end
        end
    end
    return result
end

local function _deal_address(address)
    local address = UTIL.split(address, ":")
    return address[1], tonumber(address[2]) or 80
end

function _M.choice_upstream(balance_alg, first_upstreams,
        second_upstreams, third_upstreams)
    for _, upstreams in pairs{first_upstreams,
            second_upstreams, third_upstreams} do
        if #upstreams > 0 then
            local address, err = require("BalanceAlgorithm_"
                ..balance_alg).choice(upstreams)
            if address then return _deal_address(address) end
        end
    end
    return false, "there are no active upstreams"
end

function _M.available_upstreams(...)
    local dc_config = CONFIG.DC_CACHE:get(CONFIG.DC_CACHE_KEY)
    local up_config = CONFIG.UPSTREAM_CACHE:get(CONFIG.UPSTREAM_CACHE_KEY)
    local target_upstreams = filter_upstreams(
            up_config[dc_config.target] or {}, ...)
    local backup_upstreams = filter_upstreams(
            up_config[dc_config.backup] or {}, ...)
    local abtest_upstreams = filter_upstreams(
            up_config[dc_config.abtest] or {}, ...)
    return target_upstreams, backup_upstreams, abtest_upstreams
end

return _M

