local json = require "cjson.safe"
local redis = require "resty.redis"

local CONFIG = require "MyConfig"
local null = ngx.null
local unpack = table.unpack or unpack
local _M = {}

local function _create_connection()
    local red = redis:new()
    red:set_timeout(CONFIG.REDIS_REGISTER_TIMEOUT)
    local ok, err = red:connect(
        CONFIG.REDIS_REGISTER_HOST,
        CONFIG.REDIS_REGISTER_PORT)
    if not ok then return false, err end

    if type(CONFIG.REDIS_REGISTER_PASSWORD) == "string" then
        local ok, err = red:auth(CONFIG.REDIS_REGISTER_PASSWORD)
        if not ok then
            red:close()
            return false, err
        end
    end
    
    local ok, err = red:select(CONFIG.REDIS_REGISTER_DB)
    if not ok then
        red:close()
        return false, err
    end

    return red
end

local function _put_conn_into_pool(red)
    local ok, err = red:set_keepalive(
        CONFIG.REDIS_REGISTER_MAX_IDLE_TIME,
        CONFIG.REDIS_REGISTER_POOL_SIZE)
    if not ok then return false, err end
    return true
end

function _M.get_datacenter_config()
    local red, err = _create_connection()
    if not red then return false, 1, err end

    local args, result, err = {"target", "backup", "abtest"}
    local full_node_name = CONFIG.NODE_TYPE.."@"..CONFIG.DATA_CENTER

    result, err = red:hmget(full_node_name, unpack(args))
    if result[1] == null then
        red:hsetnx(full_node_name, "target", CONFIG.DATA_CENTER)
        result, err = red:hmget(full_node_name, unpack(args))
    end
    if not result then return false, 2, err end
    _put_conn_into_pool(red)
    return {target=result[1],
            backup=result[2]~=null and result[2] or nil,
            abtest=result[3]~=null and result[2] or nil}
end

local function _combine_upstreams(upstreams)
    local result = {}
    for ind=1, #upstreams-1, 2 do
        local info = json.decode(upstreams[ind+1])
        info.address = upstreams[ind]
        table.insert(result, info)
    end
    return result
end

local function _all_needed_dcs(dc_config)
    local result = {}
    table.insert(result, dc_config.target)
    table.insert(result, dc_config.backup)
    table.insert(result, dc_config.abtest)
    return result
end

function _M.get_upstream_config(dc_config)
    local red, err = _create_connection()
    if not red then return false, 1, err end

    local result = {}
    for _, one_datacenter in pairs(_all_needed_dcs(dc_config)) do
        if not result[one_datacenter] then
            local upstreams, err = red:hgetall(one_datacenter)
            if not upstreams then return false, 2, err end
            result[one_datacenter] = _combine_upstreams(upstreams)
        end
    end
    _put_conn_into_pool(red)
    return result
end

local function _generate_table(upstreams)
    local result = {}
    for ind=1, #upstreams-1, 2 do
        result[upstreams[ind]] = upstreams[ind+1]
    end
    return result
end

function _M.get_blacklist_config(dc_config)
    local red, err = _create_connection()
    if not red then return false, 1, err end

    local result = {}
    for _, one_datacenter in pairs(_all_needed_dcs(dc_config)) do
        if not result[one_datacenter] then
            local hashtable = CONFIG.BLACK_LIST_PREFIX..one_datacenter
            local upstreams, err = red:hgetall(hashtable)
            if not upstreams then return false, 2, err end
            result[one_datacenter] = _generate_table(upstreams)
        end
    end
    _put_conn_into_pool(red)
    return result
end

return _M

