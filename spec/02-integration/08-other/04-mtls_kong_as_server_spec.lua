--[[
© 2020 Nokia
Licensed under the Apache License 2.0
SPDX-License-Identifier: Apache-2.0
--]]

-- Note that we have to split certificate related tests into several lua scripts, as helpers once loaded
-- executes series of configuration steps, so it is not enough to restart kong with the other configuration.
os.execute("mkdir -p /opt/kong/busted/certs")
os.execute("cp spec/02-integration/08-other/config/mtls_RootCA.pem /opt/kong/busted/certs/")
os.execute("cp spec/02-integration/08-other/config/mtls.pem /opt/kong/busted/certs/")
os.execute("cp spec/02-integration/08-other/config/mtls.key /opt/kong/busted/certs/")

local helpers = require "spec.helpers"
local gutils = require "spec.gutils"

local services = {}
local route_paths = {}

local function init()
    services[1] = {
        name = "myservice",
        url = "https://localhost:9443/mtlsTestRoute"
    }
    services[2] = {
        name = "mtlsTestServer",
        url = "http://localhost:15555/get"
    }
    route_paths[1] = {
        [1] = "/myServiceRoute"
    }
    route_paths[2] = {
        [1] = "/mtlsTestRoute"
    }
end

describe("Verify client to Kong mTLS scenario (Kong as a server)", function()
    local proxy_ssl_client
    local proxy_client

    setup(function()
        init()
        helpers.prepare_prefix()
        assert(helpers.start_kong({
            nginx_conf = "spec/02-integration/08-other/config/nginx_for_mtls.template",
            kong_conf = "spec/02-integration/08-other/config/mtls.conf"
        }))
        local response = gutils.add_service(services[1])
        assert.res_status(201, response)
        response = gutils.add_service(services[2])
        assert.res_status(201, response)
        local service1_id = gutils.get_service_id(services[1].name)
        local service2_id = gutils.get_service_id(services[2].name)
        response = gutils.add_route(service1_id, route_paths[1])
        assert.res_status(201, response)
        response = gutils.add_route(service2_id, route_paths[2])
        assert.res_status(201, response)
    end)

    teardown(function()
        gutils.clean_database({ "services", "routes", "plugins" })
        helpers.stop_kong()
        os.execute("rm -rf /opt/kong/busted")
    end)

    before_each(function()
        proxy_ssl_client = helpers.proxy_ssl_client()
        proxy_client = helpers.proxy_client()
    end)

    after_each(function()
        if proxy_ssl_client then
            proxy_ssl_client:close()
        end
        if proxy_client then
            proxy_client:close()
        end
    end)

    -- The purpose of this test is to verify Kong as a server mTLS proxy interface, so Kong verifies client certificate.
    -- Note, that Kong talks to itself, so in fact we test Kong as a Client as well, since Kong acts as a client as well.
    -- The reason for this is that resty.http client doesn't support mTLS so cannot be used directly to test sunny day
    -- scenario.
    -- The sunny day scenario is following:
    -- Kong is triggered with resty.http client (via HTTP)
    -- Kong handles request and sends to the upstream via HTTPS (to itself in fact - proxy interface, route: /mtlsTestRoute)
    -- Kong gets request and verifies client certificate
    it("Kong expects valid and trusted client certificate", function()
        local res = assert(proxy_client:send {
            method = "GET",
            path = "/myServiceRoute"
        }
        )
        assert.res_status(200, res)
    end)

    -- The proxy_ssl_client doesn't support mTLS, so it is good candidate to test mTLS Kong proxy interface
    -- rainy day scenario. We expect the request to fail, as no client certificate is sent.
    it("Kong expects valid and trusted client certificate - rainy day scenario", function()
        local res = assert(proxy_ssl_client:send {
            method = "GET",
            path = "/myServiceRoute"
        }
        )
        assert.res_status(400, res)
        assert.match("No required SSL certificate was sent", res:read_body())
    end)
end)
