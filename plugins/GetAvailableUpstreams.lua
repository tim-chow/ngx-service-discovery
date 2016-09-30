local json = require "cjson.safe"
local BASE_BALANCER = require "BaseBalancer"

local function get_upstreams()
    local host, uri = ngx.var.arg_host, ngx.var.arg_uri
    if not host or not uri then
        ngx.header["Content-Type"] = "text/plain"
        ngx.say("bad argument host or uri")
        return ngx.exit(400)
    end

    local kick = true
    if ngx.var.arg_not_kick then
        kick = false
    end
    target, backup, abtest = BASE_BALANCER.available_upstreams(
        host, uri, kick)
    local result = {}
    result["target"] = target
    result["backup"] = backup
    result["abtest"] = abtest
    
    ngx.header["Content-Type"] = "application/json"
    ngx.say(json.encode(result))
end

get_upstreams()

