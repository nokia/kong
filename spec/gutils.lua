--[[
© 2020 Nokia
Licensed under the Apache License 2.0
SPDX-License-Identifier: Apache-2.0
--]]

local helpers = require "spec.helpers"
local cjson = require "cjson"
local pl_stringx = require "pl.stringx"

local my_route_id = {}

local M = {}

-- Gets route_id based on the route path
-- @param: mrp - Represents route path (my route path)
function M.get_route_id(mrp)
    return my_route_id[mrp]
end

-- Adds new service
-- @param: service_input - The new service configuration table.
-- example:
-- {
--  name = "theBestServiceEver",
--  url = "http://localhost:48080"
-- }
function M.add_service(service_input)
    local admin_client = helpers.admin_client()
    return assert(admin_client:send {
        method = "POST",
        path = "/services",
        body = service_input,
        headers = {
            ["Content-Type"] = "application/json"
        }
    })
end

-- Returns service id or nil
-- @param: service_name - The given service name (string)
function M.get_service_id(service_name)
    local admin_client = helpers.admin_client()
    local res = assert(admin_client:send {
        method = "GET",
        path = "/services",
        headers = {
            ["Content-Type"] = "application/json"
        }
    })
    local response_body_json, _ = res:read_body()
    response_body_json = pl_stringx.strip(response_body_json)

    local json = cjson.decode(response_body_json)

    for _, data in pairs(json.data) do
        if data.name == service_name then
            return data.id
        end
    end
    return nil
end

-- Adds new route
-- @param: service_id - Represents related service id the route is going to call
-- @param: path: - Represents the route path
function M.add_route(service_id, paths)
    local admin_client = helpers.admin_client()
    local response = assert(admin_client:send {
        method = "POST",
        path = "/routes",
        body = {
            service = {
                id = service_id
            },
            paths = paths
        },
        headers = {
            ["Content-Type"] = "application/json"
        }
    })
    local response_body_json, _ = response:read_body()
    response_body_json = pl_stringx.strip(response_body_json)

    local response_body = cjson.decode(response_body_json)
    my_route_id[paths] = response_body.id

    return response
end

-- Adds new route for given host
-- @param: service_id - Represents related service id the route is going to call
-- @param: path: - Represents the route host
function M.add_route_per_host(service_id, hosts)
    local admin_client = helpers.admin_client()
    local response = assert(admin_client:send {
        method = "POST",
        path = "/routes",
        body = {
            service = {
                id = service_id
            },
            hosts = hosts
        },
        headers = {
            ["Content-Type"] = "application/json"
        }
    })
    local response_body_json, _ = response:read_body()
    response_body_json = pl_stringx.strip(response_body_json)

    local response_body = cjson.decode(response_body_json)
    my_route_id[hosts] = response_body.id

    return response
end

-- Removes give route
-- @param: route_id - Represents the route to be removed
function M.remove_route(route_id)
    local admin_client = helpers.admin_client()
    return assert(admin_client:send {
        method = "DELETE",
        path = string.format("/routes/%s", route_id)
    })
end

-- Removes given service
-- @param: service_input - represents the service to be removed
function M.remove_service(service_input)
    local admin_client = helpers.admin_client()
    return assert(admin_client:send {
        method = "DELETE",
        path = string.format("/services/%s", service_input.name)
    })
end

-- Adds new plugin
-- @param: plugin_name - the name of the plugin to be added
-- @param: plugin_config - the config schema of the plugin to be added
-- @param: route_id - the route id the plugin will be added for
-- @param: service_id - the service id the plugin will be added for
-- @param: consumer_id - the costomer id the plugin will be added for
function M.add_plugin(plugin_name, plugin_config, route_id, service_id, consumer_id)
    local route = route_id and { id = route_id } or nil
    local service = service_id and { id = service_id } or nil
    local consumer = consumer_id and { id = consumer_id } or nil
    local admin_client = helpers.admin_client()
    return assert(admin_client:send {
        method = "POST",
        path = "/plugins",
        body = {
            name = plugin_name,
            config = plugin_config,
            route = route,
            service = service,
            consumer = consumer,
        },
        headers = {
            ["Content-Type"] = "application/json"
        }
    })
end

-- Removes the plugin
-- @param: plugin_id - the id of the plugin to be removed
function M.remove_plugin(plugin_id)
    local admin_client = helpers.admin_client()
    return assert(admin_client:send {
        method = "DELETE",
        path = string.format("/plugins/%s", plugin_id)
    })
end

-- Adds global plugin
-- @param: plugin_name - the name of the plugin to be added
-- @param: plugin_config - the config schema of the plugin to be added
function M.add_plugin_globally(plugin_name, plugin_config)
    local admin_client = helpers.admin_client()
    return assert(admin_client:send {
        method = "POST",
        path = "/plugins",
        body = {
            name = plugin_name,
            config = plugin_config
        },
        headers = {
            ["Content-Type"] = "application/json"
        }
    })
end

-- Removes the given global plugin
-- @params: plugin_name - the name of the global plugin to be removed
function M.remove_global_plugin(plugin_name)
    local admin_client = helpers.admin_client()
    local plugin_id = M.get_global_plugin_id(plugin_name)
    return assert(admin_client:send {
        method = "DELETE",
        path = string.format("/plugins/%s", plugin_id),
        headers = {
            ["Content-Type"] = "application/json"
        }
    })
end

-- Returns the given plugin id assigned to given route id
-- @params: mrp - the route path the plugin is assigned to
-- @params: name - plugin name
function M.get_plugin_id(name)
    local admin_client = helpers.admin_client()
    local res = assert(admin_client:send {
        method = "GET",
        path = "/plugins"
    })
    local response_body_json, _ = res:read_body()
    response_body_json = pl_stringx.strip(response_body_json)
    local json = cjson.decode(response_body_json)

    for _, data in pairs(json.data) do
        if data.name == name and data.id ~= nil then
            return data.id
        end
    end
    return nil
end

-- Returns given global plugin id
-- @params: plugin_name - the global plugin name
function M.get_global_plugin_id(plugin_name)
    local admin_client = helpers.admin_client()
    local res = assert(admin_client:send {
        method = "GET",
        path = "/plugins"
    })
    local response_body_json, _ = res:read_body()
    response_body_json = pl_stringx.strip(response_body_json)
    local json = cjson.decode(response_body_json)

    for _, data in pairs(json.data) do
        if data.route_id == nil and data.id ~= nil and data.name == plugin_name then
            return data.id
        end
    end
    return nil
end

function M.clean_database(tables)
    helpers.get_db_utils(nil, tables)
end

function M.is_null(result)
    if (result == nil or "userdata: NULL" == tostring(result)) then
        return true
    end
    return false
end

return M
