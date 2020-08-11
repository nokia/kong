--[[
© 2020 Nokia
Licensed under the Apache License 2.0
SPDX-License-Identifier: Apache-2.0
--]]

local utils  = require "kong.tools.utils"
local mutils = require "kong.tools.maria.utils"


local max          = math.max
local fmt          = string.format
local null         = ngx.null
local concat       = table.concat
local setmetatable = setmetatable
local new_tab
do
    local ok
    ok, new_tab = pcall(require, "table.new")
    if not ok then
        new_tab = function(narr, nrec) return {} end
    end
end


local INSERT_QUERY = [[
 BEGIN NOT ATOMIC
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
        -- Do nothing, accept existing state
        END;
    INSERT INTO cluster_events(id, node_id, at, nbf, expire_at, channel, data)
    VALUES(%s, %s, FROM_UNIXTIME(%f), FROM_UNIXTIME(%s), FROM_UNIXTIME(%s), %s, %s);
    DELETE FROM `cluster_events` WHERE `expire_at` <= NOW(6);
 END;
]]

local SELECT_INTERVAL_QUERY = [[
SELECT id, node_id, channel, data,
       UNIX_TIMESTAMP(at) as at,
       UNIX_TIMESTAMP(nbf) as nbf
FROM cluster_events
WHERE channel IN (%s)
  AND at >  FROM_UNIXTIME(%f)
  AND at <= FROM_UNIXTIME(%f)
]]


local _M = {}
local mt = { __index = _M }


function _M.new(db, page_size, event_ttl)
    local self  = {
        db        = db.connector,
        --page_size = page_size,
        event_ttl = event_ttl,
    }

    return setmetatable(self, mt)
end


function _M.should_use_polling()
    return true
end


function _M:insert(node_id, channel, at, data, nbf)
    local expire_at = max(at + self.event_ttl, at)

    if not nbf then
        nbf = "NULL"
    end

  local pg_id      = mutils.escape_literal(nil, utils.uuid())
  local pg_node_id = mutils.escape_literal(nil, node_id)
  local pg_channel = mutils.escape_literal(nil, channel)
  local pg_data    = mutils.escape_literal(nil, data)

    local q = fmt(INSERT_QUERY, pg_id, pg_node_id, at, nbf, expire_at,
            pg_channel, pg_data)

    local res, err = self.db:query(q)
    if not res then
        return nil, "could not insert invalidation row: " .. err
    end

    return true
end


function _M:select_interval(channels, min_at, max_at)
    local n_chans = #channels
    local pg_channels = new_tab(n_chans, 0)

    for i = 1, n_chans do
      pg_channels[i] = mutils.escape_literal(nil, channels[i])
    end

    local q = fmt(SELECT_INTERVAL_QUERY, concat(pg_channels, ","), min_at,
            max_at)

    local ran

    -- TODO: implement pagination for this strategy as
    -- well.
    --
    -- we need to behave like lua-cassandra's iteration:
    -- provide an iterator that enters the loop, with a
    -- page = 0 argument if there is no first page, and a
    -- page = 1 argument with the fetched rows elsewise

    return function(_, p_rows)
        if ran then
            return nil
        end

        local res, err = self.db:query(q)
        if not res then
            return nil, err
        end

        local len = #res
        for i = 1, len do
            local row = res[i]
            if row.nbf == null then
                row.nbf = nil
            end
        end

        local page = len > 0 and 1 or 0

        ran = true

        return res, err, page
    end
end


function _M:truncate_events()
    return self.db:query("TRUNCATE cluster_events")
end


return _M