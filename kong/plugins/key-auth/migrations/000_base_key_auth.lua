return {
  postgres = {
    up = [[
      CREATE TABLE IF NOT EXISTS "keyauth_credentials" (
        "id"           UUID                         PRIMARY KEY,
        "created_at"   TIMESTAMP WITHOUT TIME ZONE  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "consumer_id"  UUID                         REFERENCES "consumers" ("id") ON DELETE CASCADE,
        "key"          TEXT                         UNIQUE
      );

      CREATE INDEX IF NOT EXISTS "keyauth_consumer_idx" ON "keyauth_credentials" ("consumer_id");
    ]],
  },

  cassandra = {
    up = [[
      CREATE TABLE IF NOT EXISTS keyauth_credentials(
        id          uuid PRIMARY KEY,
        created_at  timestamp,
        consumer_id uuid,
        key         text
      );
      CREATE INDEX IF NOT EXISTS ON keyauth_credentials(key);
      CREATE INDEX IF NOT EXISTS ON keyauth_credentials(consumer_id);
    ]],
  },

  maria = {
    up = [[
      CREATE TABLE IF NOT EXISTS `keyauth_credentials` (
        `id`           VARCHAR(36),
        `created_at`   TIMESTAMP(0)   DEFAULT NOW(0),
        `consumer_id`  VARCHAR(36),
        `key`          VARCHAR(255),

        PRIMARY KEY (`id`),
        FOREIGN KEY (`consumer_id`) REFERENCES `consumers` (`id`) ON DELETE CASCADE,
        UNIQUE  KEY (`key`)
      ) ENGINE = InnoDB DEFAULT CHARSET = utf8;
    ]],
  },
}
