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
        POLL_INTERVAL=1,
        BALANCE_ALG="RR";
        MAX_RETRIES=5;

        REGISTER_CENTER="RedisRegisterCenter",
        -- Redis Register configuration
        REDIS_REGISTER_HOST="127.0.0.1",
        REDIS_REGISTER_PORT=6380,
        REDIS_REGISTER_PASSWORD="timchow",
        REDIS_REGISTER_DB=0,
        REDIS_REGISTER_TIMEOUT=1000, --unit: ms
        REDIS_REGISTER_MAX_IDLE_TIME=10000, --unit: ms
        REDIS_REGISTER_POOL_SIZE=2;

        HEALTH_CHECK_MODULE="HTTPHealthCheck",
        HEALTH_CHECK_POLL_INTERVAL=0.8,
        -- HTTP Health Check configuration
        HTTP_DEFAULT_CHECK_TIMEOUT=3*1000, --unit: ms
        HTTP_DEFAULT_CHECK_PATH="/checkstatus",
        HTTP_CHECK_THREAD_COUNT=25,

        ADVICE_CENTER="RedisAdviceCenter",
        -- Redis Advice configuration
        REDIS_ADVICE_HOST="127.0.0.1",
        REDIS_ADVICE_PORT=6380,
        REDIS_ADVICE_PASSWORD="timchow",
        REDIS_ADVICE_CHANNEL="/dubbo/*",
        REDIS_ADVICE_CONNECT_TIMEOUT=10*60*1000, --unit: ms
        REDIS_ADVICE_RECONNECT_DELAY=0.2,
        REDIS_ADVICE_TIMEOUT=6*1000, --unit: ms
    },
    __metatable="permission denied",
    __newindex=function() end,
}


local MAX_FAILES = 3

local _host_counter_cache = lrucache.new(100)
local _update_upstreams_lock = lrucache.new(1)
local _health_check_cache = lrucache.new(1000)
if (not _host_counter_cache or
        not _update_upstreams_lock or
        not _health_check_cache) then
    error("create cache failed")
end

function _CONFIG.HOST_COUNTER()
    local key = ngx.var.host
    local current = _host_counter_cache:get(key) or 0
    _host_counter_cache:set(key, current + 1)
    return current + 1
end

function _CONFIG.UPSTREAMS_LOCK(unlock)
    local lockname = "__LOCK_FOR_UPDATING_UPSTREAMS__"
    if unlock then
        return _update_upstreams_lock:delete(lockname)
    end

    local data = _update_upstreams_lock:get(lockname)
    if data then return false, 1 end
    _update_upstreams_lock:set(lockname, os.time().."", 6)
    return true
end

function _CONFIG.INCR_HEALTH_STATUS(address)
    local current = _health_check_cache:get(address) or 0
    _health_check_cache:set(address, current + 1)
    return current + 1
end

function _CONFIG.CLEAR_HEALTH_STATUS(address)
    return _health_check_cache:delete(address)
end
function _CONFIG.IS_UPSTREAM_OK(address)
    return (_health_check_cache:get(address) or -1) <= MAX_FAILES
end

setmetatable(_CONFIG, _mt)
return _CONFIG

