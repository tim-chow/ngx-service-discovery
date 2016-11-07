local lrucache = require "resty.lrucache"
local _CONFIG = {}

local _dc_cache = lrucache.new(1)
local _upstream_cache = lrucache.new(1)
if not _dc_cache or not _upstream_cache then
    error("create cache failed")
end

local _mt = {
    __index={ 
        DATA_CENTER="DATA_CENTER-dc1",
        NODE_TYPE="NODE_TYPE-default";

        -- NGINX Worker configuration
        DC_CACHE=_dc_cache,
        DC_CACHE_KEY="__DC_CACHE_KEY__",
        UPSTREAM_CACHE=_upstream_cache,
        UPSTREAM_CACHE_KEY="__UPSTREAM_CACHE_KEY__",
        POLL_INTERVAL=0.2,
        BALANCE_ALG="RR";

        REGISTER_CENTER="RedisRegisterCenter",
        -- Redis Register configuration
        REDIS_REGISTER_HOST="127.0.0.1",
        REDIS_REGISTER_PORT=6379,
        REDIS_REGISTER_PASSWORD="e839fcfe725611e5:123456_78a1A",
        REDIS_REGISTER_DB=6,
        REDIS_REGISTER_TIMEOUT=1000, --unit: ms
        REDIS_REGISTER_MAX_IDLE_TIME=10000, --unit: ms
        REDIS_REGISTER_POOL_SIZE=2;

        HEALTH_CHECK_MODULE="HTTPHealthCheck",
        HEALTH_CHECK_POLL_INTERVAL=0.2,
        -- HTTP Health Check configuration
        HTTP_DEFAULT_CHECK_TIMEOUT=3*1000, --unit: ms
        HTTP_DEFAULT_CHECK_PATH="/checkstatus",
        HTTP_CHECK_THREAD_COUNT=20,

        ADVICE_CENTER="RedisAdviceCenter",
        -- Redis Advice configuration
        REDIS_ADVICE_HOST="127.0.0.1",
        REDIS_ADVICE_PORT=6379,
        REDIS_ADVICE_PASSWORD="e839fcfe725611e5:123456_78a1A",
        REDIS_ADVICE_CHANNEL="/dubbo/*",
        REDIS_ADVICE_CONNECT_TIMEOUT=10*60*1000, --unit: ms
        REDIS_ADVICE_RECONNECT_DELAY=0.2,
        REDIS_ADVICE_TIMEOUT=6*1000, --unit: ms
    },
    __metatable="permission denied",
    __newindex=function() end,
}



local _host_counter_cache = ngx.shared["HOST_ACCESS_COUNT"]
local _update_upstreams_lock = ngx.shared["LOCK_FOR_UPDATING_UPSTREAMS"]
local _health_check_cache = ngx.shared["HEALTH_CHECK_STATUS"]
local MAX_FAILES = 3

local function _get_host_counter_cache_key()
    return ngx.var.host.."@"..ngx.worker.pid()
end
function _CONFIG.HOST_COUNTER()
    return _host_counter_cache:incr(
        _get_host_counter_cache_key(), 1, 0) or 10086
end

local function _get_update_upstreams_lock_name()
    return "LOCK_FOR_UPDATING_UPSTREAMS".."@"..ngx.worker.pid()
end
function _CONFIG.UPSTREAMS_LOCK(unlock)
    local lockname = _get_update_upstreams_lock_name()
    if unlock then
        return _update_upstreams_lock:delete(lockname)
    end

    local ok, err = _update_upstreams_lock:safe_add(
        lockname, os.time().."", 6) -- XXX: expired time
    if ok then return true end
    if err == "exists" then
        return false, 1, err
    else
        return false, 2, err
    end
end

local function _get_health_check_cache_key(address)
    return address.."@"..ngx.worker.pid()
end
function _CONFIG.INCR_HEALTH_STATUS(address)
    local key = _get_health_check_cache_key(address)
    return _health_check_cache:incr(key, 1, 0)
end
function _CONFIG.CLEAR_HEALTH_STATUS(address)
    return _health_check_cache:delete(
            _get_health_check_cache_key(address))
end
function _CONFIG.IS_UPSTREAM_OK(address)
    return (_health_check_cache:get(
                _get_health_check_cache_key(
                    address)) or -1) <= MAX_FAILES
end

setmetatable(_CONFIG, _mt)
return _CONFIG

