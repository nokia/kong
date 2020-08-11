return {
  postgres = {
    up = [[
    ]],

    teardown = function(connector)
      assert(connector:connect_migrations())
      assert(connector:query [[
        DROP INDEX IF EXISTS "oauth2_authorization_api_id_idx";
        DROP INDEX IF EXISTS "oauth2_tokens_api_id_idx";


        DO $$
        BEGIN
          ALTER TABLE IF EXISTS ONLY "oauth2_authorization_codes" DROP "api_id";
        EXCEPTION WHEN UNDEFINED_COLUMN THEN
          -- Do nothing, accept existing state
        END$$;


        DO $$
        BEGIN
          ALTER TABLE IF EXISTS ONLY "oauth2_tokens" DROP "api_id";
        EXCEPTION WHEN UNDEFINED_COLUMN THEN
          -- Do nothing, accept existing state
        END$$;
      ]])
    end,
  },

  cassandra = {
    up = [[
    ]],

    teardown = function(connector)
      assert(connector:connect_migrations())
      assert(connector:query([[
        DROP INDEX IF EXISTS oauth2_authorization_codes_api_id_idx;
        DROP INDEX IF EXISTS oauth2_tokens_api_id_idx;


        ALTER TABLE oauth2_authorization_codes DROP api_id;
        ALTER TABLE oauth2_tokens DROP api_id;
      ]]))
    end,
  },

  maria = {
    up = [[
    ]],

    teardown = function(connector)
      assert(connector:connect_migrations())
      assert(connector:query [[
        BEGIN NOT ATOMIC
        DECLARE `no_such_table` CONDITION FOR SQLSTATE '42S02';
        DECLARE EXIT HANDLER FOR `no_such_table`
          BEGIN
            -- Do nothing, accept existing state
          END;
        ALTER TABLE `oauth2_authorization_codes` DROP FOREIGN KEY IF EXISTS `oauth2_authorization_codes_api_id_fk`;
        ALTER TABLE `oauth2_authorization_codes` DROP COLUMN IF EXISTS `api_id`;
        END;


        BEGIN NOT ATOMIC
        DECLARE `no_such_table` CONDITION FOR SQLSTATE '42S02';
        DECLARE EXIT HANDLER FOR `no_such_table`
          BEGIN
            -- Do nothing, accept existing state
          END;
        ALTER TABLE `oauth2_tokens` DROP FOREIGN KEY IF EXISTS `oauth2_tokens_api_id_fk`;
        ALTER TABLE `oauth2_tokens` DROP COLUMN IF EXISTS `api_id`;
        END;
      ]])
    end,
  },
}
