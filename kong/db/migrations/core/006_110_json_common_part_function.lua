--[[
© 2020 Nokia
Licensed under the Apache License 2.0
SPDX-License-Identifier: Apache-2.0
--]]

return {
  postgres = {
    up = [[
    ]]
  },

  cassandra = {
    up = [[
    ]]
  },

  maria = {
    up = [[
      CREATE OR REPLACE FUNCTION `JSON_CONTAINS_COMMON_PART` (resource1 JSON, resource2 JSON)
      RETURNS INTEGER
        BEGIN
          DECLARE item TEXT;
          DECLARE found, i INTEGER DEFAULT 0;

          compare: WHILE i < JSON_LENGTH(resource2) DO
            SELECT JSON_EXTRACT(resource2, CONCAT('$[',i,']')) INTO item;
            SELECT JSON_CONTAINS(resource1, item) INTO found;
            SET i := i + 1;
            IF found = 1 THEN
              LEAVE compare;
            END IF;
          END WHILE compare;
          RETURN found;
        END;
    ]]
  },
}