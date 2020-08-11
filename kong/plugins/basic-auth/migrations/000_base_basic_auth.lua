return {
  postgres = {
    up = [[
      CREATE TABLE IF NOT EXISTS "basicauth_credentials" (
        "id"           UUID                         PRIMARY KEY,
        "created_at"   TIMESTAMP WITHOUT TIME ZONE  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "consumer_id"  UUID                         REFERENCES "consumers" ("id") ON DELETE CASCADE,
        "username"     TEXT                         UNIQUE,
        "password"     TEXT
      );

      CREATE INDEX IF NOT EXISTS "basicauth_consumer_id_idx" ON "basicauth_credentials" ("consumer_id");
    ]],
  },

  cassandra = {
    up = [[
      CREATE TABLE IF NOT EXISTS basicauth_credentials (
        id          uuid PRIMARY KEY,
        created_at  timestamp,
        consumer_id uuid,
        password    text,
        username    text
      );
      CREATE INDEX IF NOT EXISTS ON basicauth_credentials(username);
      CREATE INDEX IF NOT EXISTS ON basicauth_credentials(consumer_id);
    ]],
  },

  maria = {
    up = [[
      CREATE TABLE IF NOT EXISTS `basicauth_credentials` (
        `id`           VARCHAR(36),
        `created_at`   TIMESTAMP(0)   DEFAULT NOW(0),
        `consumer_id`  VARCHAR(36),
        `username`     VARCHAR(255),
        `password`     TEXT,

        PRIMARY KEY (`id`),
        FOREIGN KEY (`consumer_id`) REFERENCES `consumers` (`id`) ON DELETE CASCADE,
        UNIQUE  KEY (`username`)
      ) ENGINE = InnoDB DEFAULT CHARSET = utf8;
    ]],
  },
}
