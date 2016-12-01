local CONFIG = require "MyConfig"
local UTIL = require "MyUtil"

local function execute_degrade(error_codes, upstream_addr)
    if type(error_codes) ~= "string" then return end
    local error_codes = UTIL.split(error_codes, ",")
    for _, error_code in pairs(error_codes) do
        if tonumber(error_code) == tonumber(ngx.var.status) then
            CONFIG.DEGRADE(upstream_addr)
        end
    end
end

local function main()
    local up_config = CONFIG.UPSTREAM_CACHE:get(
        CONFIG.UPSTREAM_CACHE_KEY)
    if not up_config then return end

    local upstream_addr = ngx.var.upstream_addr
    for _, upstreams in pairs(up_config) do
        for _, upstream in pairs(upstreams) do
            if upstream_addr == upstream.address then
                execute_degrade(upstream.errorcodes, upstream_addr)
            end
        end
    end
end

main()
