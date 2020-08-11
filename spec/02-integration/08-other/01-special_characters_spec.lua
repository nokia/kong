--[[
© 2020 Nokia
Licensed under the Apache License 2.0
SPDX-License-Identifier: Apache-2.0
--]]

local helpers = require "spec.helpers"
local cjson = require "cjson"
local gutils = require "spec.gutils"

local services = {}
local route_paths = {}
local plugin_name
local oauth2_config

local function init()
    services[1] = {
        name = "ouath2Test",
        url = "http://localhost:40000/referenceService"
    }
    route_paths[1] = {
        [1] = "/[as]bc.*/.+a/.?a/\b\n\r\t",
        [2] = "/[as]bc.*/.+a/.?a/!@#$%^&()`~-_={}|;:/,<>",
        [3] = "/[as]bc.*/.+a/.?a/!@#$%^&()`~-_={}|;:/,<\">",
        [4] = "/[as]bc.*/.+a/.?a/!@#$%^&()`~-_={}|;:/,<\\>",
    }
    plugin_name = "oauth2"
    oauth2_config = {
        provision_key = "!@#$%^&*()`~-_=+[]{}\b\n\r\t\"\\|\\\\;:',./<>?//",
        enable_authorization_code = true
    }
end

local function create_service()
    local response = gutils.add_service(services[1])
    local response_body_json = assert.res_status(201, response)
    local response_body = cjson.decode(response_body_json)
    return response_body.id
end

describe("Verify special characters in routes and plugins", function()
    local admin_client, proxy_client

    setup(function()
        init()
        helpers.prepare_prefix()
        assert(helpers.start_kong())
        admin_client = helpers.admin_client()
    end)

    teardown(function()
        if admin_client then
            admin_client:close()
        end
        helpers.stop_kong()
    end)

    before_each(function()
        proxy_client = helpers.proxy_client()

    end)

    after_each(function()
        if proxy_client then
            proxy_client:close()
        end
        gutils.clean_database({"services", "routes", "plugins"})
    end)

    it("should contain special characters in a plugin field", function()
        local response = gutils.add_plugin(plugin_name, oauth2_config)
        local response_body_json = assert.res_status(201, response)
        local response_body = cjson.decode(response_body_json)
        assert.are.equal(oauth2_config.provision_key, response_body.config.provision_key)
    end)

    it("should contain special characters in a route field", function()
        local service_id = create_service()
        local response = gutils.add_route(service_id, route_paths[1])
        local response_body_json = assert.res_status(201, response)
        local response_body = cjson.decode(response_body_json)
        assert.are.equal(#route_paths[1], #response_body.paths)
        for i = 1, #route_paths[1] do
            assert.are.equal(route_paths[1][i], response_body.paths[i])
        end
    end)
end)
