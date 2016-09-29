local CONFIG = require "MyConfig"
local HEALTH_CHECK = require "HealthCheck"
local register_center = require(CONFIG.REGISTER_CENTER)
local get_datacenter_config = register_center.get_datacenter_config
local get_upstream_config = register_center.get_upstream_config
local get_config, health_check

health_check = function(premature)
    if premature then return end

    local up_config = CONFIG.UPSTREAM_CACHE:get(
        CONFIG.UPSTREAM_CACHE_KEY)
    if up_config then
        local upstreams = {}
        for dc, dc_upstreams in pairs(up_config) do
            for _, upstream in pairs(dc_upstreams) do
                table.insert(upstreams, upstream)
            end
        end
        pcall(HEALTH_CHECK.execute_health_check, upstreams)
    end
    ngx.timer.at(CONFIG.HEALTH_CHECK_POLL_INTERVAL, health_check)
end

get_config = function(premature)
    if premature then return end

    local status, dc_config, code, msg = pcall(get_datacenter_config)
    if status and dc_config then
        CONFIG.DC_CACHE:set(CONFIG.DC_CACHE_KEY, dc_config)
        local status, up_config, code, msg = pcall(
            get_upstream_config, dc_config)
        if status and up_config then
            --ngx.log(ngx.ERR, "up_config")
            CONFIG.UPSTREAM_CACHE:set(CONFIG.UPSTREAM_CACHE_KEY, up_config)
        end
    end
    ngx.timer.at(CONFIG.POLL_INTERVAL, get_config)
end

ngx.timer.at(0, get_config)
ngx.timer.at(0, health_check)

