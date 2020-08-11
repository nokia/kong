--[[
© 2020 Nokia
Licensed under the Apache License 2.0
SPDX-License-Identifier: Apache-2.0
--]]

local mysql        = require "nokia.resty.mysql"
local maria_utils  = require "kong.tools.maria.utils"
local cjson        = require "cjson"
local logger       = require "kong.cmd.utils.log"
local pgmoon       = require "pgmoon"
local arrays       = require "pgmoon.arrays"
local stringx      = require "pl.stringx"


local setmetatable = setmetatable
local encode_array = arrays.encode_array
local tonumber     = tonumber
local tostring     = tostring
local concat       = table.concat
local ipairs       = ipairs
local pairs        = pairs
local error        = error
local floor        = math.floor
local type         = type
local ngx          = ngx
local timer_every  = ngx.timer.every
local update_time  = ngx.update_time
local get_phase    = ngx.get_phase
local null         = ngx.null
local now          = ngx.now
local log          = ngx.log
local match        = string.match
local fmt          = string.format
local sub          = string.sub
local gsub         = string.gsub
local len          = string.len
local next         = next


local WARN                          = ngx.WARN
local SQL_INFORMATION_SCHEMA_TABLES = [[
SELECT table_name
  FROM information_schema.tables
 WHERE table_schema = database();
]]
local PROTECTED_TABLES = {
  schema_migrations = true,
  schema_meta       = true,
  locks             = true,
}


local function now_updated()
  update_time()
  return now()
end


--TODO #NotStarted
local function visit(k, n, m, s)
  if m[k] == 0 then return 1 end
  if m[k] == 1 then return end
  m[k] = 0
  local f = n[k]
  for i=1, #f do
    if visit(f[i], n, m, s) then return 1 end
  end
  m[k] = 1
  s[#s+1] = k
end


--TODO #NotStarted
local tsort = {}
tsort.__index = tsort


--TODO #NotStarted
function tsort.new()
  return setmetatable({ n = {} }, tsort)
end


--TODO #NotStarted
function tsort:add(...)
  local p = { ... }
  local c = #p
  if c == 0 then return self end
  if c == 1 then
    p = p[1]
    if type(p) == "table" then
      c = #p
    else
      p = { p }
    end
  end
  local n = self.n
  for i=1, c do
    local f = p[i]
    if n[f] == nil then n[f] = {} end
  end
  for i=2, c, 1 do
    local f = p[i]
    local t = p[i-1]
    local o = n[f]
    o[#o+1] = t
  end
  return self
end


--TODO #NotStarted
function tsort:sort()
  local n  = self.n
  local s = {}
  local m  = {}
  for k in pairs(n) do
    if m[k] == nil then
      if visit(k, n, m, s) then
        return nil, "There is a circular dependency in the graph. It is not possible to derive a topological sort."
      end
    end
  end
  return s
end


local function iterator(rows)
  local i = 0
  return function()
    i = i + 1
    return rows[i]
  end
end


local setkeepalive


local function connect(config)
  local phase  = get_phase()
  if phase == "init" or phase == "init_worker" or ngx.IS_CLI then
    -- Force LuaSocket usage in the CLI in order to allow for self-signed
    -- certificates to be trusted (via opts.cafile) in the resty-cli
    -- interpreter (no way to set lua_ssl_trusted_certificate).
    config.socket_type = "luasocket"
  else
    config.socket_type = "nginx"
  end

  local connection, connection_err = mysql:new(config.socket_type)
  if not connection then
    return nil, connection_err
  end

  connection.convert_null = true
  connection.NULL         = null

  connection:set_timeout(config.timeout)

  local ok, err = connection:connect(config)
  if not ok then
    return nil, err
  end

  if connection.sock:getreusedtimes() == 0 then
    ok, err = connection:query("SET time_zone = '+00:00';");
    if not ok then
      setkeepalive(connection)
      return nil, err
    end
  end

  return connection
end


setkeepalive = function(connection, config)
  if not connection or not connection.sock then
    return true
  end

  local ok, err
  if connection.sock_type == "luasocket" then
    ok, err = connection:close()
  else
    ok, err = connection:set_keepalive(config.socket_keepalive_timeout,
                                       config.socket_pool_size)
  end

  if not ok then
    return nil, err
  end

  return true
end


local _mt = {}


_mt.__index = _mt


-- Connections are not stored at a DAO level due to driver limitations.
-- They are stored in a pool of connections provided by a nginx socket instead.
-- This method is designed to return the connection stored at the DAO level.
-- Because of that, it returns nil.
function _mt:get_stored_connection()
  return nil
end


function _mt:init()
  local res, err = self:query("SELECT version() AS server_version_num;")
  local ver = res and res[1] and res[1].server_version_num
  if not ver then
    return nil, "failed to retrieve server_version_num: " .. err
  end

  local version_parts = stringx.split(ver, ".")
  if version_parts[3] then
    local third_part = stringx.split(version_parts[3], "-")
    self.major_version = fmt("%u.%u", version_parts[1], version_parts[2])
    self.major_minor_version = fmt("%u.%u.%u", version_parts[1],
                                   version_parts[2], third_part[1])
  else
    local second_part = stringx.split(version_parts[2], "-")
    self.major_version       = tostring(version_parts[1])
    self.major_minor_version = fmt("%u.%u", version_parts[1], second_part[1])
  end

  return true
end


--TODO #NotStarted
function _mt:init_worker(strategies)
  if ngx.worker.id() == 0 then
    local graph
    local found = false

    for _, strategy in pairs(strategies) do
      local schema = strategy.schema
      if schema.ttl then
        if not found then
          graph = tsort.new()
          found = true
        end

        local name = schema.name
        graph:add(name)
        for _, field in schema:each_field() do
          if field.type == "foreign" and field.schema.ttl then
            graph:add(name, field.schema.name)
          end
        end
      end
    end

    if not found then
      return true
    end

    local sorted_strategies = graph:sort()
    local ttl_escaped = self:escape_identifier("ttl")
    local cleanup_statement = {}
    for i, table_name in ipairs(sorted_strategies) do
      cleanup_statement[i] = concat {
        "  DELETE FROM ",
        self:escape_identifier(table_name),
        " WHERE ",
        ttl_escaped,
        " < NOW(6);"
      }
    end

    cleanup_statement = concat({
      "BEGIN NOT ATOMIC",
      concat(cleanup_statement, "\n"),
      "END;"
    }, "\n")

    return timer_every(60, function(premature)
      if premature then
        return
      end

      local ok, err = self:query(cleanup_statement)
      if not ok then
        if err then
          log(WARN, "unable to clean expired rows from postgres database (", err, ")")
        else
          log(WARN, "unable to clean expired rows from postgres database")
        end
      end
    end)
  end

  return true
end


function _mt:infos()
  local db_ver
  if self.major_minor_version then
    db_ver = match(self.major_minor_version, "^(%d+%.%d+)")
  end

  return {
    strategy  = "MariaDB",
    db_name   = self.config.database,
    db_schema = self.config.schema,
    db_desc   = "database",
    db_ver    = db_ver or "unknown",
  }
end


function _mt:connect()
  return connect(self.config)
end


function _mt:connect_migrations()
  return self:connect()
end


-- Connections are not stored at a DAO level due to driver limitations.
-- They are stored in a pool of connections provided by a nginx socket instead.
-- This method is designed to operate on the connection stored at the DAO level.
-- Because of that, the following method always returns true unless you pass
-- the connection to close.
function _mt:close(conn)
  if not conn then
    return true
  end

  local _, err = conn:close()

  self:store_connection(nil)

  if err then
    return nil, err
  end

  return true
end


-- Connections are not stored at a DAO level due to driver limitations.
-- They are stored in a pool of connections provided by a nginx socket instead.
-- This method is designed to operate on the connection stored at the DAO level.
-- Because of that, the following method always returns true unless you pass
-- the connection to close.
function _mt:setkeepalive(conn)
  if not conn then
    return true
  end

  local _, err = setkeepalive(conn, self.config)

  self:store_connection(nil)

  if err then
    return nil, err
  end

  return true
end


function _mt:query(sql)
  local connection, err = connect(self.config)
  if not connection then
    return nil, err
  end

  local res, err, err_code, sql_state = connection:query(sql)
  setkeepalive(connection, self.config)

  if res then
    return res
  end

  return nil, err, err_code, sql_state
end


--TODO #NotStarted
function _mt:iterate(sql)
  local res, err, err_code, sql_state = self:query(sql)
  if not res then
    local failed = false
    return function()
      if not failed then
        failed = true
        return false, err, err_code, sql_state
      end
      -- return error only once to avoid infinite loop
      return nil
    end
  end

  if res == true then
    return iterator { true }
  end

  return iterator(res)
end


function _mt:reset()
  local database = self:escape_identifier(self.config.database)

  local ok, err = self:query(concat {
    "BEGIN NOT ATOMIC\n",
    "DROP DATABASE IF EXISTS " .. database .. ";\n",
    "CREATE DATABASE IF NOT EXISTS " .. database .. ";\n",
    "END;\n",
  })

  if not ok then
    return nil, err
  end

  return true
end


function _mt:truncate()
  local i, table_names = 0, {}

  for row in self:iterate(SQL_INFORMATION_SCHEMA_TABLES) do
    local table_name = row.table_name
    if not PROTECTED_TABLES[table_name] then
      i = i + 1
      table_names[i] = self:escape_identifier(table_name)
    end
  end

  if i == 0 then
    return true
  end

  -- MariaDB takes single table name for 'TRUNCATE_TABLE' statement
  -- so it is required to prepare 'TRUNCATE_TABLE' statement for each table
  local truncate_statements = {}
  for index, table_name in ipairs(table_names) do
    truncate_statements[index] = "TRUNCATE TABLE " .. table_name .. ";"
  end

  local truncate_statement  = concat {
    "SET FOREIGN_KEY_CHECKS = 0; ",
    concat(truncate_statements, " "),
    " SET FOREIGN_KEY_CHECKS = 1;"
  }

  local ok, err = self:query(truncate_statement)
  if not ok then
    return nil, err
  end

  return true
end


function _mt:truncate_table(table_name)
  local database = self.config.database
  local truncate_statement = concat {
    "CALL truncate_table(",
    self:escape_literal(table_name), ", ",
    self:escape_literal(database), "); "
  }

  local ok, err = self:query(truncate_statement)
  if not ok then
    return nil, err
  end

  return true
end


function _mt:setup_locks(_, _)
  logger.debug("creating 'locks' table if not existing...")

  local ok, err = self:query([[
BEGIN NOT ATOMIC
  CREATE TABLE IF NOT EXISTS locks (
    `key`    VARCHAR(255),
    `owner`  TEXT,
    `ttl`    TIMESTAMP(6) NULL DEFAULT NULL,
    PRIMARY KEY (`key`)
  ) ENGINE = InnoDB DEFAULT CHARSET = utf8;
  CREATE INDEX IF NOT EXISTS `locks_ttl_idx` ON `locks` (`ttl`);
END;]])

  if not ok then
    return nil, err
  end

  logger.debug("successfully created 'locks' table")

  return true
end


function _mt:insert_lock(key, ttl, owner)
  local ttl_escaped = concat {
    "FROM_UNIXTIME(",
    self:escape_literal(tonumber(fmt("%.3f", now_updated() + ttl))),
    ")"
  }

  local sql = concat { "BEGIN NOT ATOMIC\n",
    "  DECLARE `duplicate_entry` CONDITION FOR SQLSTATE '23000';\n",
    "  DECLARE EXIT HANDLER FOR `duplicate_entry`\n",
    "  BEGIN\n",
    "  -- Do nothing, accept existing state\n",
    "  END;\n",
    "  DELETE FROM `locks`\n",
    "        WHERE `ttl` < NOW(6);\n",
    "  INSERT INTO `locks` (`key`, `owner`, `ttl`)\n",
    "       VALUES (", self:escape_literal(key),   ", ",
    self:escape_literal(owner), ", ",
    ttl_escaped, ");\n",
    "END;"
  }

  local res, err = self:query(sql)
  if not res then
    return nil, err
  end

  if res.affected_rows == 1 then
    return true
  end

  return false
end


function _mt:read_lock(key)
  local sql = concat {
    "SELECT *\n",
    "  FROM `locks`\n",
    " WHERE `key` = ", self:escape_literal(key), "\n",
    "   AND `ttl` >= NOW(6)\n",
    " LIMIT 1;"
  }

  local res, err = self:query(sql)
  if not res then
    return nil, err
  end

  return res[1] ~= nil
end


function _mt:remove_lock(key, owner)
  local sql = concat {
    "DELETE FROM `locks`\n",
    "      WHERE `key`   = ", self:escape_literal(key), "\n",
    "   AND `owner` = ", self:escape_literal(owner), ";"
  }

  local res, err = self:query(sql)
  if not res then
    return nil, err
  end

  return true
end


function _mt:schema_migrations()
  local has_schema_meta_table
  for row in self:iterate(SQL_INFORMATION_SCHEMA_TABLES) do
    local table_name = row.table_name
    if table_name == "schema_meta" then
      has_schema_meta_table = true
      break
    end
  end

  if not has_schema_meta_table then
    -- database, but no schema_meta: needs bootstrap
    return nil
  end

  local rows, err = self:query(concat({
    "SELECT *\n",
    "  FROM `schema_meta`\n",
    " WHERE `key` = ",  self:escape_literal("schema_meta"), ";"
  }))

  if not rows then
    return nil, err
  end

  for _, row in ipairs(rows) do
    if type(row.executed) == "string" then
      row.executed = cjson.decode(row.executed)
    end
    if type(row.pending) == "string" then
      row.pending = cjson.decode(row.pending)
    end
    if row.executed == null then
      row.executed = nil
    end
    if row.pending == null then
      row.pending = nil
    end
  end

  -- no migrations: is bootstrapped but not migrated
  -- migrations: has some migrations
  return rows
end


function _mt:schema_bootstrap(kong_config, default_locks_ttl)
  -- create schema meta table if not exists

  logger.debug("creating 'schema_meta' table if not existing...")

  local res, err = self:query([[
    CREATE TABLE IF NOT EXISTS `schema_meta` (
      `key`            VARCHAR(255),
      `subsystem`      VARCHAR(255),
      `last_executed`  TEXT,
      `executed`       JSON,
      `pending`        JSON,

      PRIMARY KEY (`key`, `subsystem`)
    );]])

  if not res then
    return nil, err
  end

  logger.debug("successfully created 'schema_meta' table")

  local ok
  ok, err = self:setup_locks(default_locks_ttl, true)
  if not ok then
    return nil, err
  end

  return true
end


function _mt:schema_reset()
  return self:reset()
end


-- Due to the 1303 error code from MariaDB all procedures/functions/triggers needs to be located in separate files
-- where "BEGIN NOT ATOMIC" clause should not be added
local function is_stored_routine(name)
  local stored_routines = {
    "000_base_procedure",
    "003_100_to_110_triggers",
    "004_110_tags_select_procedures",
    "005_110_truncate_table_procedures",
    "006_110_json_common_part_function",
    "rate_limiting_013_to_000_base_drop_procedures",
    "response_rate_limiting_013_to_000_base_drop_procedures",
    "13_to_000_base_drop_procedures"
  }

  for _, stored_routine_name in ipairs(stored_routines) do
    if stored_routine_name == name then
      return true
    end
  end
  return false
end


function _mt:run_up_migration(name, up_sql)
  if type(name) ~= "string" then
    error("name must be a string", 2)
  end

  if type(up_sql) ~= "string" then
    error("up_sql must be a string", 2)
  end

  -- Some of up_sqls contain ';' instead of SQL to execute. Postgres has not
  -- got any problem with that and returns true at the end, but Maria throws an
  -- error. Because of that, if the up_sql variable contains the semicolon or
  -- it is empty at all, method returns true to break executing rest of code.
  local up_sql_without_white_spaces = gsub(up_sql, "%s+", "")
  if up_sql_without_white_spaces == ";" or len(up_sql_without_white_spaces) == 0 then
    return true
  end

  local sql = stringx.strip(up_sql)
  if sub(sql, -1) ~= ";" then
    sql = sql .. ";"
  end

  if not is_stored_routine(name) then
    sql = concat {
      "BEGIN NOT ATOMIC\n",
      sql, "\n",
      "END;\n",
    }
  end

  local res, err = self:query(sql)
  if not res then
    self:query("ROLLBACK;")
    return nil, err
  end

  return true
end


function _mt:record_migration(subsystem, name, state)
  if type(subsystem) ~= "string" then
    error("subsystem must be a string", 2)
  end

  if type(name) ~= "string" then
    error("name must be a string", 2)
  end

  local key_escaped  = self:escape_literal("schema_meta")
  local subsystem_escaped = self:escape_literal(subsystem)
  local name_escaped = self:escape_literal(name)

  local executed_content, pending_content
  local migrations, err = self:schema_migrations()

  for _, row in ipairs(migrations) do
    if row.subsystem == subsystem then
      executed_content = row.executed
      pending_content = row.pending
      break
    end
  end

  local json_array_append = function(column_name, value, executed_or_pending)
    if executed_or_pending then
      return string.format("JSON_ARRAY_APPEND(schema_meta.%s, '$', %s)",
                           column_name, value)
    else
      return string.format("JSON_ARRAY(%s)", value)
    end
  end

  local json_remove = function(column_name, index)
    return string.format("JSON_REMOVE(schema_meta.%s, '$[%d]')",
                         column_name, index)
  end

  local sql, executed, pending
  if state == "executed" then
    executed = json_array_append("executed", name_escaped, executed_content)
    sql = concat({
      "INSERT INTO `schema_meta` (`key`, `subsystem`, `last_executed`, `executed`)\n",
      "     VALUES (", key_escaped, ", ", subsystem_escaped, ", ", name_escaped, ", ", executed, ")\n",
      "ON DUPLICATE KEY UPDATE\n",
      "            last_executed = ", name_escaped, ",\n",
      "            executed = ", executed, ";",
    })

  elseif state == "pending" then
    pending = json_array_append("pending", name_escaped, pending_content)
    sql = concat({
      "INSERT INTO `schema_meta` (`key`, `subsystem`, `pending`)\n",
      "     VALUES (", key_escaped, ", ", subsystem_escaped, ", ", pending, ")\n",
      "ON DUPLICATE KEY UPDATE pending = ", pending, ";"
    })

  elseif state == "teardown" then
    executed = json_array_append("executed", name_escaped, executed_content)
    pending = json_remove("pending", 0)
    sql = concat({
      "INSERT INTO `schema_meta` (`key`, `subsystem`, `last_executed`, `executed`)\n",
      "     VALUES (", key_escaped, ", ", subsystem_escaped, ", ", name_escaped, ", ", executed, ")\n",
      "ON DUPLICATE KEY UPDATE\n",
      "            last_executed = ", name_escaped, ",\n",
      "            executed = ", executed, ",\n",
      "            pending  = ", pending, ";",
    })

  else
    error("unknown 'state' argument: " .. tostring(state))
  end

  local res, err = self:query(sql)
  if not res then
    return nil, err
  end

  return true
end


local function append_migration_statement(self, id, name)
  local res, err = self:query(concat {
    "SELECT *",
    " FROM `schema_migrations`",
    " WHERE `id` = " .. id, ";"
  })
  if not res then
    return nil, err
  elseif next(res) then
    return string.format("JSON_ARRAY_APPEND(schema_migrations.migrations, '$', %s)", name)
  else
    return string.format("JSON_ARRAY(%s)", name)
  end
end


function _mt:record_legacy_migration(id, name)
  id = self:escape_literal(id)
  name = self:escape_literal(name)
  local migrations_statement, err = append_migration_statement(self, id, name)
  if not migrations_statement then
    return nil, err
  end
  local sql = concat {
    "UPDATE `schema_migrations`",
    " SET `migrations` = " .. migrations_statement,
    " WHERE `id` = " .. id, ";"
  }
  local res, err = self:query(sql)
  if not res then
    return nil, err
  end
  return true
end


function _mt:are_014_apis_present()
  local res, err = self:query("SELECT * FROM apis;")

  if not res then
    return nil, err
  elseif next(res) then
    return true
  end
  return false
end


function _mt:is_014()
 local res = {}

 local needed_migrations = {
   ["core"] = {
     "2015-01-12-175310_skeleton",
     "2015-01-12-175310_init_schema",
     "2015-11-23-817313_nodes",
     "2016-02-29-142793_ttls",
     "2016-09-05-212515_retries",
     "2016-09-16-141423_upstreams",
     "2016-12-14-172100_move_ssl_certs_to_core",
     "2016-11-11-151900_new_apis_router_1",
     "2016-11-11-151900_new_apis_router_2",
     "2016-11-11-151900_new_apis_router_3",
     "2016-01-25-103600_unique_custom_id",
     "2017-01-24-132600_upstream_timeouts",
     "2017-01-24-132600_upstream_timeouts_2",
     "2017-03-27-132300_anonymous",
     "2017-04-18-153000_unique_plugins_id",
     "2017-04-18-153000_unique_plugins_id_2",
     "2017-05-19-180200_cluster_events",
     "2017-05-19-173100_remove_nodes_table",
     "2017-06-16-283123_ttl_indexes",
     "2017-07-28-225000_balancer_orderlist_remove",
     "2017-10-02-173400_apis_created_at_ms_precision",
     "2017-11-07-192000_upstream_healthchecks",
     "2017-10-27-134100_consistent_hashing_1",
     "2017-11-07-192100_upstream_healthchecks_2",
     "2017-10-27-134100_consistent_hashing_2",
     "2017-09-14-121200_routes_and_services",
     "2017-10-25-180700_plugins_routes_and_services",
     "2018-03-27-123400_prepare_certs_and_snis",
     "2018-03-27-125400_fill_in_snis_ids",
     "2018-03-27-130400_make_ids_primary_keys_in_snis",
     "2018-05-17-173100_hash_on_cookie",
   },
   ["response-transformer"] = {
     "2016-05-04-160000_resp_trans_schema_changes",
   },
   ["jwt"] = {
     "2015-06-09-jwt-auth",
     "2016-03-07-jwt-alg",
     "2017-05-22-jwt_secret_not_unique",
     "2017-07-31-120200_jwt-auth_preflight_default",
     "2017-10-25-211200_jwt_cookie_names_default",
     "2018-03-15-150000_jwt_maximum_expiration",
   },
   ["ip-restriction"] = {
     "2016-05-24-remove-cache",
   },
   ["statsd"] = {
     "2017-06-09-160000_statsd_schema_changes",
   },
   ["cors"] = {
     "2017-03-14_multiple_orgins",
   },
   ["basic-auth"] = {
     "2015-08-03-132400_init_basicauth",
     "2017-01-25-180400_unique_username",
   },
   ["key-auth"] = {
     "2015-07-31-172400_init_keyauth",
     "2017-07-31-120200_key-auth_preflight_default",
   },
   ["ldap-auth"] = {
     "2017-10-23-150900_header_type_default",
   },
   ["hmac-auth"] = {
     "2015-09-16-132400_init_hmacauth",
     "2017-06-21-132400_init_hmacauth",
   },
   ["datadog"] = {
     "2017-06-09-160000_datadog_schema_changes",
   },
   ["tcp-log"] = {
     "2017-12-13-120000_tcp-log_tls",
   },
   ["acl"] = {
     "2015-08-25-841841_init_acl",
   },
   ["response-ratelimiting"] = {
     "2015-08-03-132400_init_response_ratelimiting",
     "2016-08-04-321512_response-rate-limiting_policies",
     "2017-12-19-120000_add_route_and_service_id_to_response_ratelimiting",
   },
   ["request-transformer"] = {
     "2016-05-04-160000_req_trans_schema_changes",
   },
   ["rate-limiting"] = {
     "2015-08-03-132400_init_ratelimiting",
     "2016-07-25-471385_ratelimiting_policies",
     "2017-11-30-120000_add_route_and_service_id",
   },
   ["oauth2"] = {
     "2015-08-03-132400_init_oauth2",
     "2016-07-15-oauth2_code_credential_id",
     "2016-12-22-283949_serialize_redirect_uri",
     "2016-09-19-oauth2_api_id",
     "2016-12-15-set_global_credentials",
     "2017-04-24-oauth2_client_secret_not_unique",
     "2017-10-19-set_auth_header_name_default",
     "2017-10-11-oauth2_new_refresh_token_ttl_config_value",
     "2018-01-09-oauth2_pg_add_service_id",
   },
 }

 local rows, err = self:query([[
   SELECT `TABLE_NAME` AS `name` FROM `information_schema`.`TABLES` WHERE `TABLE_NAME` = 'schema_migrations' AND `TABLE_SCHEMA` = DATABASE();
 ]])
 if err then
   return nil, err
 end

 if not rows or not rows[1] or rows[1].name ~= "schema_migrations" then
   -- no trace of legacy migrations: above 0.14
   return res
 end

 local schema_migrations_rows, err = self:query([[
   SELECT `id`, `migrations` FROM `schema_migrations`;
 ]])
 if err then
   return nil, err
 end

 if not schema_migrations_rows then
   -- empty legacy migrations: invalid state
   res.invalid_state = true
   return res
 end

 local schema_migrations = {}
 for i = 1, #schema_migrations_rows do
   local row = schema_migrations_rows[i]
   schema_migrations[row.id] = maria_utils.decode_json(row.migrations)
 end

 for name, migrations in pairs(needed_migrations) do
   local current_migrations = schema_migrations[name]
   if not current_migrations then
     -- missing all migrations for a component: below 0.14
     res.invalid_state = true
     res.missing_component = name
     return res
   end

   for _, needed_migration in ipairs(migrations) do
     local found

     for _, current_migration in ipairs(current_migrations) do
       if current_migration == needed_migration then
         found = true
         break
       end
     end

     if not found then
       -- missing at least one migration for a component: below 0.14
       res.invalid_state = true
       res.missing_component = name
       res.missing_migration = needed_migration
       return res
     end
   end
 end

 -- all migrations match: 0.14 install
 res.is_014 = true

 return res
end


local _M = {}


function _M.new(kong_config)
  local config = {
    host                     = kong_config.maria_host,
    port                     = kong_config.maria_port,
    timeout                  = kong_config.maria_timeout,
    user                     = kong_config.maria_user,
    password                 = kong_config.maria_password,
    database                 = kong_config.maria_database,
    schema                   = kong_config.maria_schema or "",
    ssl                      = kong_config.maria_ssl,
    ssl_verify               = kong_config.maria_ssl_verify,
    cafile                   = kong_config.lua_ssl_trusted_certificate,
    socket_pool_size         = kong_config.maria_socket_pool_size,
    socket_keepalive_timeout = kong_config.maria_socket_keepalive_timeout,
    max_packet_size          = 1024*1024,
  }

  local db, db_err = mysql:new()
  if not db then
    return nil, db_err
  end

  db:set_timeout(config.timeout)

  return setmetatable({
    config            = config,
    escape_identifier = maria_utils.escape_identifier,
    escape_literal    = maria_utils.escape_literal,
  }, _mt)
end


return _M
