local balancer = require "ngx.balancer"
local CONFIG = require "MyConfig"
local BASE_BALANCER = require "BaseBalancer"
local unpack = table.unpack or unpack

--TODO: judge abtest here
local function is_abtest()
    return false
end

local function balance(host, uri, kick, balance_alg, max_retries)
    local state_name, status_code = balancer.get_last_failure()
    if type(state_name) == "string" then
        ngx.log(ngx.ERR, "proxy request failed, because "..
            "state_name: "..state_name..", status_code: "..
            tostring(status_code))
    end
    if type(max_retries) == "number" and max_retries > 0 then
        local ok, err = balancer.set_more_tries(1) --XXX
        if not ok then
            ngx.log(ngx.ERR, "set_more_tries"..
                " failed, because: "..tostring(err))
            --return ngx.exit(500)
        end
    end


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

balance(ngx.var.host, ngx.var.uri, 
    CONFIG.HEALTH_CHECK_MODULE and true or false,
    CONFIG.BALANCE_ALG, CONFIG.MAX_RETRIES)

