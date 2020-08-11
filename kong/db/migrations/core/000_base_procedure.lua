--[[
© 2020 Nokia
Licensed under the Apache License 2.0
SPDX-License-Identifier: Apache-2.0
--]]

return {
  postgres = {
    up = [[
    ]],
  },

  cassandra = {
    up = [[
    ]],
  },

  maria = {
    up = [[
      CREATE OR REPLACE PROCEDURE `upsert_ttl`(v_primary_key_value VARCHAR(255), v_primary_uuid_value VARCHAR(36), v_primary_key_name VARCHAR(255), v_table_name VARCHAR(255), v_expire_at TIMESTAMP(6))
        BEGIN
          INSERT INTO ttls(primary_key_value, primary_uuid_value, primary_key_name, table_name, expire_at) VALUES(v_primary_key_value, v_primary_uuid_value, v_primary_key_name, v_table_name, v_expire_at) ON DUPLICATE KEY UPDATE expire_at = v_expire_at;
        END;
    ]],
  }
}