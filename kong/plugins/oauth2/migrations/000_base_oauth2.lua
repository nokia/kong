return {
  postgres = {
    up = [[
      CREATE TABLE IF NOT EXISTS "oauth2_credentials" (
        "id"             UUID                         PRIMARY KEY,
        "created_at"     TIMESTAMP WITHOUT TIME ZONE  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "name"           TEXT,
        "consumer_id"    UUID                         REFERENCES "consumers" ("id") ON DELETE CASCADE,
        "client_id"      TEXT                         UNIQUE,
        "client_secret"  TEXT,
        "redirect_uri"   TEXT
      );

      CREATE INDEX IF NOT EXISTS "oauth2_credentials_consumer_idx" ON "oauth2_credentials" ("consumer_id");
      CREATE INDEX IF NOT EXISTS "oauth2_credentials_secret_idx"   ON "oauth2_credentials" ("client_secret");



      CREATE TABLE IF NOT EXISTS "oauth2_authorization_codes" (
        "id"                    UUID                         PRIMARY KEY,
        "created_at"            TIMESTAMP WITHOUT TIME ZONE  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "credential_id"         UUID                         REFERENCES "oauth2_credentials" ("id") ON DELETE CASCADE,
        "service_id"            UUID                         REFERENCES "services" ("id") ON DELETE CASCADE,
        "api_id"                UUID                         REFERENCES "apis" ("id") ON DELETE CASCADE,
        "code"                  TEXT                         UNIQUE,
        "authenticated_userid"  TEXT,
        "scope"                 TEXT
      );

      CREATE INDEX IF NOT EXISTS "oauth2_authorization_userid_idx" ON "oauth2_authorization_codes" ("authenticated_userid");



      CREATE TABLE IF NOT EXISTS "oauth2_tokens" (
        "id"                    UUID                         PRIMARY KEY,
        "created_at"            TIMESTAMP WITHOUT TIME ZONE  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "credential_id"         UUID                         REFERENCES "oauth2_credentials" ("id") ON DELETE CASCADE,
        "service_id"            UUID                         REFERENCES "services" ("id") ON DELETE CASCADE,
        "api_id"                UUID                         REFERENCES "apis" ("id") ON DELETE CASCADE,
        "access_token"          TEXT                         UNIQUE,
        "refresh_token"         TEXT                         UNIQUE,
        "token_type"            TEXT,
        "expires_in"            INTEGER,
        "authenticated_userid"  TEXT,
        "scope"                 TEXT
      );

      CREATE INDEX IF NOT EXISTS "oauth2_token_userid_idx" ON "oauth2_tokens" ("authenticated_userid");
    ]],
  },

  cassandra = {
    up = [[
      CREATE TABLE IF NOT EXISTS oauth2_credentials(
        id            uuid PRIMARY KEY,
        created_at    timestamp,
        consumer_id   uuid,
        client_id     text,
        client_secret text,
        name          text,
        redirect_uri  text
      );
      CREATE INDEX IF NOT EXISTS ON oauth2_credentials(client_id);
      CREATE INDEX IF NOT EXISTS ON oauth2_credentials(consumer_id);
      CREATE INDEX IF NOT EXISTS ON oauth2_credentials(client_secret);



      CREATE TABLE IF NOT EXISTS oauth2_authorization_codes(
        id                   uuid PRIMARY KEY,
        created_at           timestamp,
        service_id           uuid,
        api_id               uuid,
        credential_id        uuid,
        authenticated_userid text,
        code                 text,
        scope                text
      ) WITH default_time_to_live = 300;
      CREATE INDEX IF NOT EXISTS ON oauth2_authorization_codes(code);
      CREATE INDEX IF NOT EXISTS ON oauth2_authorization_codes(api_id);
      CREATE INDEX IF NOT EXISTS ON oauth2_authorization_codes(service_id);
      CREATE INDEX IF NOT EXISTS ON oauth2_authorization_codes(credential_id);
      CREATE INDEX IF NOT EXISTS ON oauth2_authorization_codes(authenticated_userid);



      CREATE TABLE IF NOT EXISTS oauth2_tokens(
        id                   uuid PRIMARY KEY,
        created_at           timestamp,
        service_id           uuid,
        api_id               uuid,
        credential_id        uuid,
        access_token         text,
        authenticated_userid text,
        refresh_token        text,
        scope                text,
        token_type           text,
        expires_in           int
      );
      CREATE INDEX IF NOT EXISTS ON oauth2_tokens(api_id);
      CREATE INDEX IF NOT EXISTS ON oauth2_tokens(service_id);
      CREATE INDEX IF NOT EXISTS ON oauth2_tokens(access_token);
      CREATE INDEX IF NOT EXISTS ON oauth2_tokens(refresh_token);
      CREATE INDEX IF NOT EXISTS ON oauth2_tokens(credential_id);
      CREATE INDEX IF NOT EXISTS ON oauth2_tokens(authenticated_userid);
    ]],
  },

  maria = {
    up = [[
      CREATE TABLE IF NOT EXISTS `oauth2_credentials` (
        `id`             VARCHAR(36),
        `created_at`     TIMESTAMP(0)   DEFAULT NOW(0),
        `name`           TEXT,
        `consumer_id`    VARCHAR(36),
        `client_id`      VARCHAR(255),
        `client_secret`  TEXT,
        `redirect_uri`   TEXT,

        PRIMARY KEY (`id`),
        FOREIGN KEY (`consumer_id`) REFERENCES `consumers` (`id`) ON DELETE CASCADE,
        UNIQUE  KEY (`client_id`)
      ) ENGINE = InnoDB DEFAULT CHARSET = utf8;



      CREATE TABLE IF NOT EXISTS `oauth2_authorization_codes` (
        `id`                    VARCHAR(36),
        `created_at`            TIMESTAMP(0)   DEFAULT NOW(0),
        `credential_id`         VARCHAR(36),
        `service_id`            VARCHAR(36),
        `api_id`                VARCHAR(36),
        `code`                  TEXT,
        `sha2_code`             CHAR(64)       DEFAULT SHA2(code, 256),
        `authenticated_userid`  VARCHAR(255),
        `scope`                 TEXT,

        PRIMARY KEY (`id`),
        FOREIGN KEY (`credential_id`)  REFERENCES `oauth2_credentials` (`id`)  ON DELETE CASCADE,
        FOREIGN KEY (`service_id`)     REFERENCES `services` (`id`)            ON DELETE CASCADE,
        CONSTRAINT `oauth2_authorization_codes_api_id_fk` FOREIGN KEY (`api_id`) REFERENCES `apis` (`id`) ON DELETE CASCADE,
        UNIQUE  KEY (`sha2_code`)
      ) ENGINE = InnoDB DEFAULT CHARSET = utf8;

      CREATE INDEX IF NOT EXISTS `oauth2_authorization_codes_authenticated_userid_idx` ON `oauth2_authorization_codes` (`authenticated_userid`);



      CREATE TABLE IF NOT EXISTS `oauth2_tokens` (
        `id`                    VARCHAR(36),
        `created_at`            TIMESTAMP(0)   DEFAULT NOW(0),
        `credential_id`         VARCHAR(36),
        `service_id`            VARCHAR(36),
        `api_id`                VARCHAR(36),
        `access_token`          TEXT,
        `sha2_access_token`     CHAR(64)       DEFAULT SHA2(access_token, 256),
        `refresh_token`         TEXT,
        `sha2_refresh_token`    CHAR(64)       DEFAULT SHA2(refresh_token, 256),
        `token_type`            TEXT,
        `expires_in`            INTEGER,
        `authenticated_userid`  VARCHAR(255),
        `scope`                 TEXT,

        PRIMARY KEY (`id`),
        FOREIGN KEY (`credential_id`)  REFERENCES `oauth2_credentials` (`id`)  ON DELETE CASCADE,
        FOREIGN KEY (`service_id`)     REFERENCES `services` (`id`)            ON DELETE CASCADE,
        CONSTRAINT `oauth2_tokens_api_id_fk` FOREIGN KEY (`api_id`) REFERENCES `apis` (`id`) ON DELETE CASCADE,
        UNIQUE  KEY (`sha2_access_token`),
        UNIQUE  KEY (`sha2_refresh_token`)
      ) ENGINE = InnoDB DEFAULT CHARSET = utf8;

      CREATE INDEX IF NOT EXISTS `oauth2_tokens_authenticated_userid_idx` ON `oauth2_tokens` (`authenticated_userid`);
    ]],
  },
}
