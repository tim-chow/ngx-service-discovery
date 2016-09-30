local balancer = require "ngx.balancer"
local CONFIG = require "MyConfig"
local BASE_BALANCER = require "BaseBalancer"
local unpack = table.unpack or unpack

--TODO: judge abtest here
local function is_abtest()
    return false
end

local function balance(host, uri, kick, balance_alg)
    local target, backup, abtest = BASE_BALANCER.available_upstreams(
        host, uri, kick)

    local args = {target, backup, {}}
    if is_abtest() then
        args = {{}, {}, abtest}
    end
    
    local ip, port = BASE_BALANCER.choice_upstream(balance_alg, unpack(args))
    if not ip then
        ngx.header["Err-Msg"] = port
        return ngx.exit(500)
    end

    local ok, err = balancer.set_current_peer(ip, port)
    if not ok then
        ngx.header["Err-Msg"] = "set peer "..ip..":"..port.." failed"
        return ngx.exit(500)
    end
end

balance(ngx.var.host, ngx.var.uri, true, CONFIG.BALANCE_ALG)

