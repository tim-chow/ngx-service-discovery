local CONFIG = require "MyConfig"
local _M = {}

function _M.choice(upstreams)
    if #upstreams <= 0 then return false, "invalid upstreams" end

    local total_weight = 0
    for _, upstream in pairs(upstreams) do
        total_weight = total_weight + (upstream.weight or 1)
    end

    local current = CONFIG.HOST_COUNTER()
    local where = current % total_weight
    where = where == 0 and total_weight or where
    --ngx.header["Where"] = tostring(where)
    ngx.header["Current"] = ngx.worker.pid() .. "-" .. current
    --ngx.header["Total-Weight"] = total_weight .. ""
    for _, upstream in pairs(upstreams) do
        if where - (upstream.weight or 1) <= 0 then
            return upstream.address
        else
            where = where - (upstream.weight or 1)
        end
    end
    -- XXX: unreachable
    return upstreams[1].address 
end

return _M

