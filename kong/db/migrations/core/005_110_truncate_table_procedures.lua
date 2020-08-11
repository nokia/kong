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
    ]],
  },

  maria = {
    up = [[
      CREATE OR REPLACE PROCEDURE `truncate_table` (tableName TEXT, databaseName TEXT)
        BEGIN
          SET MAX_SP_RECURSION_DEPTH = 255;
          SET FOREIGN_KEY_CHECKS = 0;
          CALL truncate_table_cascade(tableName, databaseName);
          SET FOREIGN_KEY_CHECKS = 1;
          SET MAX_SP_RECURSION_DEPTH = 0;
        END;

      CREATE OR REPLACE PROCEDURE `truncate_table_cascade` (tableName TEXT, databaseName TEXT)
        BEGIN
          DECLARE finished INTEGER DEFAULT 0;
          DEClARE referencedTablesCursor CURSOR FOR
            SELECT TABLE_NAME FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
             WHERE REFERENCED_TABLE_NAME = tableName
               AND REFERENCED_TABLE_SCHEMA = databaseName;
          DECLARE CONTINUE HANDLER FOR NOT FOUND SET finished = 1;

          SET @truncateSql = CONCAT('TRUNCATE TABLE ', tableName);
          PREPARE truncateStatement FROM @truncateSql;
          EXECUTE truncateStatement;
          DEALLOCATE PREPARE truncateStatement;

          OPEN referencedTablesCursor;
          getReferencedTables: LOOP
            FETCH referencedTablesCursor INTO tableName;
            IF finished = 1 THEN
              LEAVE getReferencedTables;
            END IF;
            CALL truncate_table_cascade(tableName, databaseName);
          END LOOP getReferencedTables;
          CLOSE referencedTablesCursor;
        END;
    ]]
  },
}