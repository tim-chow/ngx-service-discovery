local balancer = require "ngx.balancer"

local CONFIG = require "MyConfig"
local UTIL = require "MyUtil"
local unpack = table.unpack or unpack

local function filter_upstreams(upstreams)
    local result = {}
    for _, upstream in pairs(upstreams) do
        if (ngx.var.host == 
            upstream.hostname) and ngx.re.match(ngx.var.uri,
            upstream.uripattern) then
            -- XXX: kick off unhealth upstream
            if CONFIG.IS_UPSTREAM_OK(upstream.address) then
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

local function choice_upstream(first_upstreams, 
        second_upstreams, third_upstreams)
    local first_upstreams = filter_upstreams(first_upstreams)
    local second_upstreams = filter_upstreams(second_upstreams)
    local third_upstreams = filter_upstreams(third_upstreams)

    for _, upstreams in pairs{first_upstreams,
            second_upstreams, third_upstreams} do
        if #upstreams > 0 then
            local address, err = require("BalanceAlgorithm_"
                ..CONFIG.BALANCE_ALG).choice(upstreams)
            if address then return _deal_address(address) end
        end
    end
    return false, "there are no active upstreams"
end

--TODO: judge abtest here
local function is_abtest()
    return false
end

local function balance()
    local dc_config = CONFIG.DC_CACHE:get(CONFIG.DC_CACHE_KEY)
    local up_config = CONFIG.UPSTREAM_CACHE:get(CONFIG.UPSTREAM_CACHE_KEY)
    local target_upstreams = up_config[dc_config.target] or {}
    local backup_upstreams = up_config[dc_config.backup] or {}
    local abtest_upstreams = up_config[dc_config.abtest] or {}

    local args = {target_upstreams, backup_upstreams, {}}
    if is_abtest() then
        args = {{}, {}, abtest_upstreams}
    end
    
    local ip, port = choice_upstream(unpack(args))
    if not ip then
        ngx.header["Err-Msg"] = port
        return ngx.exit(500)
    end

    local ok, err = balancer.set_current_peer(ip, port)
    if not ok then return ngx.exit(500) end
end

balance()

