--[[
© 2020 Nokia
Licensed under the Apache License 2.0
SPDX-License-Identifier: Apache-2.0
--]]

local cert_lifetime_validator = require "kong.tools.certificate_lifetime_validator"
local conf_loader = require "kong.conf_loader"
local helpers = require "spec.helpers"
local x509 = require "openssl.x509"
local pkey = require "openssl.pkey"
local pl_utils = require "pl.utils"
local now = ngx.now

describe("Validate certificate expiration date", function()

    it("- certificate will expire in more than 'validate_certs_warn_before' days", function()
        local conf = assert(conf_loader(helpers.test_conf_path, {
            validate_certs_warn_before = 7,
        }))

        local cert = pl_utils.readfile("spec/fixtures/kong_spec.crt")

        local certx509 = x509.new(cert)
        local _, valid_to_x509 = certx509:getLifetime()
        local not_valid, valid_to, _, serial = cert_lifetime_validator.validate_cert_expiration_date(cert, conf)

        assert.is_false(not_valid)
        assert.are.same(valid_to_x509, valid_to)
        assert.is_nil(serial)
    end)

    it("- certificate has expired", function()
        local conf = assert(conf_loader(helpers.test_conf_path, {
            validate_certs_warn_before = 7,
        }))

        local cert = pl_utils.readfile("spec/fixtures/kong_spec.crt")
        local key = pl_utils.readfile("spec/fixtures/kong_spec.key")

        local certx509 = x509.new(cert)
        local pkey = pkey.new(key)
        certx509:setLifetime(_, 1575898191)
        certx509:sign(pkey)

        local x509serial = certx509:getSerial()

        local not_valid, valid_to, expire, serial = cert_lifetime_validator.validate_cert_expiration_date(tostring(certx509), conf)

        assert.is_true(not_valid)
        assert.are.same(1575898191, valid_to)
        assert.are.same(x509serial, serial)
        assert.are.same("has expired", expire)
    end)

    it("- certificate will expire in less than 'validate_certs_warn_before' days", function()
        local conf = assert(conf_loader(helpers.test_conf_path, {
            validate_certs_warn_before = 7,
        }))

        local cert = pl_utils.readfile("spec/fixtures/kong_spec.crt")
        local key = pl_utils.readfile("spec/fixtures/kong_spec.key")

        local certx509 = x509.new(cert)
        local pkey = pkey.new(key)
        local expire_at = math.floor(now() + (24 * (conf.validate_certs_warn_before - 1) * 60 * 60))
        certx509:setLifetime(_, expire_at)
        certx509:sign(pkey)

        local x509serial = certx509:getSerial()

        local not_valid, valid_to, expire, serial = cert_lifetime_validator.validate_cert_expiration_date(tostring(certx509), conf)

        assert.is_true(not_valid)
        assert.are.same(expire_at, valid_to)
        assert.are.same(x509serial, serial)
        assert.are.same("will expire", expire)
    end)

    it("- throws an error if parameter validate_certs_warn_before has a wrong format (string)", function()
        local conf = assert(conf_loader(helpers.test_conf_path, {
            validate_certs_warn_before = "abc",
        }))

        local cert = pl_utils.readfile("spec/fixtures/kong_spec.crt")

        assert.has_error(function() cert_lifetime_validator.validate_cert_expiration_date(cert, conf) end,
                "validate_certs_warn_before must be a number larger then 1")
    end)

    it("- throws an error if parameter validate_certs_warn_before has a wrong format (negative number)", function()
        local conf = assert(conf_loader(helpers.test_conf_path, {
            validate_certs_warn_before = "-10",
        }))

        local cert = pl_utils.readfile("spec/fixtures/kong_spec.crt")

        assert.has_error(function() cert_lifetime_validator.validate_cert_expiration_date(cert, conf) end,
                "validate_certs_warn_before must be a number larger then 1")
    end)
end)