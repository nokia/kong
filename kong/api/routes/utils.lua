--[[
© 2020 Nokia
Licensed under the Apache License 2.0
SPDX-License-Identifier: Apache-2.0
--]]

local kong = kong
local ngx = ngx

return {
    ["/utils/database"] = {
        GET = function(self, db, helpers)
            local database = kong.configuration.database
            if database == "cassandra" then
                local body = {}
                local peers = kong.db.connector.cluster:get_peers()
                if type(peers) == "table" then
                    for index, peer in ipairs(peers) do
                        body[index] = {
                            host = peer.host,
                            up = peer.up,
                            release_version = peer.release_version
                        }
                    end
                end
                return kong.response.exit(ngx.HTTP_OK, body)
            else
                local body = "Not implemented for a " .. tostring(database) .. " database"
                return kong.response.exit(ngx.HTTP_METHOD_NOT_IMPLEMENTED, { message = body })
            end
        end
    },
    ["/utils/openapi"] = {
        GET = function(self, db, helpers)
            local file = io.open(kong.configuration.prefix .. "/admin_api_spec.yaml", "r")
            local body = file:read("*all")
            file:close()
            local headers = {}
            headers["Content-Type"] = "text/plain"
            return kong.response.exit(ngx.HTTP_OK, body, headers)
        end
    },
}