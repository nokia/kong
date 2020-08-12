--[[
© 2020 Nokia
Licensed under the Apache License 2.0
SPDX-License-Identifier: Apache-2.0
--]]

-- Note that we have to split certificate related tests into several lua scripts, as helpers once loaded
-- executes series of configuration steps, so it is not enough to restart kong with the other configuration.
os.execute("mkdir -p /opt/kong/busted/certs")
os.execute("cp spec/02-integration/08-other/config/mtls_RootCA.pem /opt/kong/busted/certs/")
os.execute("cp spec/02-integration/08-other/config/mtls.key /opt/kong/busted/certs/")
os.execute("cp spec/02-integration/08-other/config/mtls.pem /opt/kong/busted/certs/")

-- This test verifies Kong to Client mTLS, as well as Client to Kong mTLS.
-- Note, that Kong talks to itself, so the flow is following:
-- Kong is triggered with resty.http client (via HTTP)
-- Kong handles request and sends to the upstream (to itself in fact)
-- Kong gets request and verifies client certificate. Since it talks to itself, the client is Kong as well, so
-- we test Kong as a Client as well as Kong as a server in the same test. :)

local helpers = require "spec.helpers"
local gutils = require "spec.gutils"

local services = {}
local route_paths = {}

local function init()
    services[1] = {
        name = "mtlsTest",
        url = "https://localhost:9444"
    }
    route_paths[1] = {
        [1] = "/myservice1"
    }
end

describe("Verify kong to upstream mTLS scenario", function()
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
        local service_id = gutils.get_service_id(services[1].name)
        response = gutils.add_route(service_id, route_paths[1])
        assert.res_status(201, response)
    end)

    teardown(function()
        gutils.clean_database({ "services", "routes", "plugins" })
        helpers.stop_kong()
        os.execute("rm -rf /opt/kong/busted")
    end)

    before_each(function()
        proxy_client = helpers.proxy_client()
    end)

    after_each(function()
        if proxy_client then
            proxy_client:close()
        end
    end)

    it("Kong sends valid and trusted client certificate - upstream configured with mTLS", function()
        local res = assert(proxy_client:send {
            method = "GET",
            path = "/myservice1"
        }
        )
        assert.res_status(200, res)
    end)
end)
