--[[
© 2020 Nokia
Licensed under the Apache License 2.0
SPDX-License-Identifier: Apache-2.0
--]]

local openssl_x509 = require "openssl.x509"
local now = ngx.now

local _M = {}

function _M.validate_cert_expiration_date(cert, conf)
    if type(conf.validate_certs_warn_before) ~= "number" or conf.validate_certs_warn_before < 1 then
        error ("validate_certs_warn_before must be a number larger then 1")
    end

    local x509cert = openssl_x509.new(cert)
    local _, valid_to = x509cert:getLifetime()
    local serial = x509cert:getSerial()

    if valid_to < now() then
        return true, valid_to, "has expired", serial
    elseif valid_to < now() + (24 * conf.validate_certs_warn_before * 60 * 60) then
        return true, valid_to, "will expire", serial
    end
    return false, valid_to, nil, nil
end

return _M