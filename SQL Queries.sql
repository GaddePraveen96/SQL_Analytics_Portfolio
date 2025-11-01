-- Use MySQL 8+, InnoDB, utf8mb4 to avoid collation pain
CREATE TABLE stg_awards (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  s_no INT NULL,
  assembly_number VARCHAR (120) NULL, -- e.g., "55th Assembly"
  YEAR INT NULL,
  title VARCHAR (50) NULL, -- Prof., Dr., etc.
  NAME VARCHAR (200) NULL,
  gender VARCHAR (20) NULL,
  affiliation VARCHAR (300) NULL,
  country VARCHAR (120) NULL,
  email VARCHAR (200) NULL,
  presentation_type VARCHAR (150) NULL, -- e.g., "IAAM Fellow Lecture"
  award_certificate_type VARCHAR (180) NULL, -- from "Award (Certificate Type)"
  certificate_number VARCHAR (100) NULL,
  SESSION VARCHAR (200) NULL, -- program/session name
  session_topic VARCHAR (300) NULL, -- area of research source
  paper_title VARCHAR (600) NULL, -- if present in your sheet
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_country (country),
  KEY idx_award_type (award_certificate_type),
  KEY idx_email (email),
  KEY idx_affiliation (affiliation)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
ALTER TABLE stg_awards MODIFY assembly_number VARCHAR (150) NULL,
MODIFY title VARCHAR (100) NULL, -- was 50 → too small
MODIFY NAME VARCHAR (255) NULL,
MODIFY gender VARCHAR (20) NULL,
MODIFY affiliation VARCHAR (500) NULL, -- org names get long
MODIFY country VARCHAR (120) NULL,
MODIFY email VARCHAR (255) NULL,
MODIFY presentation_type VARCHAR (200) NULL,
MODIFY award_certificate_type VARCHAR (200) NULL, -- contains variants ("Appreciation", etc.)
MODIFY certificate_number VARCHAR (120) NULL,
MODIFY SESSION VARCHAR (200) NULL,
MODIFY session_topic TEXT NULL, -- free-text topics
MODIFY paper_title TEXT NULL; -- titles can be very long
UPDATE stg_awards
SET YEAR = 2023
WHERE
  assembly_number = '57th AMC';
UPDATE stg_awards
SET YEAR = 2025
WHERE
  assembly_number = '64th AMC';
UPDATE stg_awards
SET YEAR = 2025
WHERE
  assembly_number = 'Ningbo conference';
UPDATE stg_awards
SET YEAR = 2025
WHERE
  assembly_number = 'Advanced Materials Lecture Series';
  
-- 1) Countries
CREATE TABLE
IF NOT EXISTS dim_country (country_id INT PRIMARY KEY AUTO_INCREMENT, country_name VARCHAR (120) NOT NULL, UNIQUE KEY uk_country_name (country_name)) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;
  INSERT IGNORE INTO dim_country (country_name) SELECT DISTINCT
    TRIM(country)
  FROM
    stg_awards
  WHERE
    TRIM(country) <> ''
    AND country IS NOT NULL;
    
  -- 2) Affiliations (tie to country)
  CREATE TABLE
  IF NOT EXISTS dim_affiliation (
      affiliation_id INT PRIMARY KEY AUTO_INCREMENT,
      affiliation_name VARCHAR (500) NOT NULL,
      country_id INT NOT NULL,
      UNIQUE KEY uk_aff_country (affiliation_name, country_id),
      CONSTRAINT fk_aff_country FOREIGN KEY (country_id) REFERENCES dim_country (country_id)
    ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;
    INSERT IGNORE INTO dim_affiliation (affiliation_name, country_id) SELECT DISTINCT
      TRIM(affiliation) AS affiliation_name,
      c.country_id
    FROM
      stg_awards s
      JOIN dim_country c ON c.country_name = TRIM(s.country)
    WHERE
      TRIM(s.affiliation) <> ''
      AND s.affiliation IS NOT NULL;
      
    -- 3) Authors (email is natural key)
    CREATE TABLE
    IF NOT EXISTS dim_author (
        author_id INT PRIMARY KEY AUTO_INCREMENT,
        full_name VARCHAR (255) NOT NULL,
        email VARCHAR (255) NOT NULL,
        UNIQUE KEY uk_author_email (email)
      ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;
      INSERT IGNORE INTO dim_author (full_name, email) SELECT DISTINCT
        TRIM(NAME) AS full_name,
        LOWER(TRIM(email)) AS email
      FROM
        stg_awards
      WHERE
        TRIM(email) <> ''
        AND email IS NOT NULL;
        
      -- 4) Award types (code-able)
      CREATE TABLE
      IF NOT EXISTS dim_award_type (
          award_type_id INT PRIMARY KEY AUTO_INCREMENT,
          award_code VARCHAR (32) NOT NULL,
          award_name VARCHAR (200) NOT NULL,
          UNIQUE KEY uk_award_name (award_name),
          UNIQUE KEY uk_award_code (award_code)
        ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;
        
        -- seed from distinct names; temporary code = auto id, then set code cleanly
        INSERT IGNORE INTO dim_award_type (award_code, award_name) SELECT DISTINCT
          'PENDING',
          TRIM(award_certificate_type)
        FROM
          stg_awards
        WHERE
          TRIM(award_certificate_type) <> ''
          AND award_certificate_type IS NOT NULL;
          
        -- give stable codes like AWD001, AWD002...
        UPDATE dim_award_type
        SET award_code = CONCAT('AWD', LPAD(award_type_id, 3, '0'))
        WHERE
          award_code = 'PENDING';
        CREATE TABLE
        IF NOT EXISTS fact_award (
            award_id BIGINT PRIMARY KEY AUTO_INCREMENT,
            author_id INT NOT NULL,
            affiliation_id INT NOT NULL,
            country_id INT NOT NULL,
            award_type_id INT NOT NULL,
            assembly_number VARCHAR (150) NULL,
            YEAR INT NULL,
            SESSION VARCHAR (200) NULL,
            session_topic TEXT NULL,
            presentation_type VARCHAR (200) NULL,
            certificate_number VARCHAR (120) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            KEY idx_country (country_id),
            KEY idx_award_type (award_type_id),
            KEY idx_author (author_id),
            KEY idx_aff (affiliation_id),
            CONSTRAINT fk_fa_author FOREIGN KEY (author_id) REFERENCES dim_author (author_id),
            CONSTRAINT fk_fa_aff FOREIGN KEY (affiliation_id) REFERENCES dim_affiliation (affiliation_id),
            CONSTRAINT fk_fa_country FOREIGN KEY (country_id) REFERENCES dim_country (country_id),
            CONSTRAINT fk_fa_award FOREIGN KEY (award_type_id) REFERENCES dim_award_type (award_type_id)
          ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;
          INSERT INTO fact_award (author_id, affiliation_id, country_id, award_type_id, assembly_number, YEAR, SESSION, session_topic, presentation_type, certificate_number) SELECT
            a.author_id,
            af.affiliation_id,
            c.country_id,
            atp.award_type_id,
            TRIM(s.assembly_number),
            s.YEAR,
            NULLIF(TRIM(s.SESSION), ''),
            NULLIF(TRIM(s.session_topic), ''),
            NULLIF(TRIM(s.presentation_type), ''),
            NULLIF(TRIM(s.certificate_number), '')
          FROM
            stg_awards s
            JOIN dim_country c ON c.country_name = TRIM(s.country)
            JOIN dim_affiliation af ON af.affiliation_name = TRIM(s.affiliation)
            AND af.country_id = c.country_id
            JOIN dim_author a ON a.email = LOWER(TRIM(s.email))
            JOIN dim_award_type atp ON atp.award_name = TRIM(s.award_certificate_type);
            
          -- Insert only the missing award names
          INSERT INTO dim_award_type (award_code, award_name) SELECT
            CONCAT('AWD_', SUBSTRING(MD5(x.award_name), 1, 8)) AS award_code, -- unique & stable
            x.award_name
          FROM
            (
              SELECT
                MIN(TRIM(award_certificate_type)) AS award_name
              FROM
                stg_awards
              WHERE
                award_certificate_type IS NOT NULL
                AND TRIM(award_certificate_type) <> ''
              GROUP BY
                LOWER(TRIM(award_certificate_type))
            ) AS x
            LEFT JOIN dim_award_type d ON LOWER(d.award_name) = LOWER(x.award_name)
          WHERE
            d.award_type_id IS NULL
          ORDER BY
            x.award_name;
            
          -- 1A) Build a deduped people list with email_norm
          DROP TEMPORARY TABLE
          IF EXISTS tmp_people;
            CREATE TEMPORARY TABLE tmp_people AS SELECT DISTINCT
              TRIM(NAME) AS full_name,
              CASE
                WHEN email IS NULL
                  OR TRIM(email) = ''
                  OR email NOT LIKE '%@%' THEN
                  CONCAT(
                    LOWER(REPLACE(TRIM(NAME), ' ', '')),
                    '|',
                    SUBSTRING(
                      MD5(
                        CONCAT(
                          LOWER(TRIM(NAME)),
                          '|',
                          LOWER(TRIM(affiliation)),
                          '|',
                          LOWER(TRIM(country))
                        )
                      ),
                      1,
                      10
                    ),
                    '@pseudo'
                  )
                ELSE
                  LOWER(TRIM(email))
              END AS email_norm
            FROM
              stg_awards;
              
            -- 1B) Upsert authors (email is the natural key)
            INSERT IGNORE INTO dim_author (full_name, email) SELECT
              p.full_name,
              p.email_norm
            FROM
              tmp_people p;
            TRUNCATE fact_award;
            INSERT INTO fact_award (author_id, affiliation_id, country_id, award_type_id, assembly_number, YEAR, SESSION, session_topic, presentation_type, certificate_number) SELECT
              a.author_id,
              af.affiliation_id,
              c.country_id,
              atp.award_type_id,
              TRIM(s.assembly_number),
              s.YEAR,
              NULLIF(TRIM(s.SESSION), ''),
              NULLIF(TRIM(s.session_topic), ''),
              NULLIF(TRIM(s.presentation_type), ''),
              NULLIF(TRIM(s.certificate_number), '')
            FROM
              stg_awards s
              JOIN dim_country c ON c.country_name = TRIM(s.country)
              JOIN dim_affiliation af ON af.affiliation_name = TRIM(s.affiliation)
              AND af.country_id = c.country_id
              JOIN dim_award_type atp ON atp.award_name = TRIM(s.award_certificate_type)
              JOIN dim_author a ON a.email = (
                CASE
                  WHEN s.email IS NULL
                    OR TRIM(s.email) = ''
                    OR s.email NOT LIKE '%@%' THEN
                    CONCAT(
                      LOWER(REPLACE(TRIM(s.NAME), ' ', '')),
                      '|',
                      SUBSTRING(
                        MD5(
                          CONCAT(
                            LOWER(TRIM(s.NAME)),
                            '|',
                            LOWER(TRIM(s.affiliation)),
                            '|',
                            LOWER(TRIM(s.country))
                          )
                        ),
                        1,
                        10
                      ),
                      '@pseudo'
                    )
                  ELSE
                    LOWER(TRIM(s.email))
                END
              );
            -- Should be close to staging count (minus truly unmappable rows)
            SELECT
              COUNT(*) AS fact_rows
            FROM
              fact_award;
            SELECT
              COUNT(*) AS stg_rows
            FROM
              stg_awards
            WHERE
              award_certificate_type IS NOT NULL
              AND TRIM(award_certificate_type) <> '';
            -- Award name parity check
            SELECT
              atp.award_name,
              COUNT(*) AS fact_cnt
            FROM
              fact_award f
              JOIN dim_award_type atp ON atp.award_type_id = f.award_type_id
            GROUP BY
              atp.award_name
            ORDER BY
              fact_cnt DESC;
            -- Any authors with a pseudo email? (expected: yes, but not crazy high)
            SELECT
              COUNT(*)
            FROM
              dim_author
            WHERE
              email LIKE '%@pseudo';
            -- Your earlier insight (should look sane now)
            SELECT
              c.country_name AS country,
              af.affiliation_name AS affiliation,
              COUNT(DISTINCT a.author_id) AS unique_awardees
            FROM
              fact_award f
              JOIN dim_country c ON c.country_id = f.country_id
              JOIN dim_affiliation af ON af.affiliation_id = f.affiliation_id
              JOIN dim_author a ON a.author_id = f.author_id
            GROUP BY
              c.country_name,
              af.affiliation_name
            ORDER BY
              c.country_name ASC,
              unique_awardees DESC,
              af.affiliation_name ASC;
            -- Authors per your Excel (staging)
            SELECT
              COUNT(
                DISTINCT
                CASE
                  WHEN email IS NULL
                    OR TRIM(email) = ''
                    OR email NOT LIKE '%@%' THEN
                    CONCAT(
                      LOWER(REPLACE(TRIM(NAME), ' ', '')),
                      '|',
                      SUBSTRING(
                        MD5(
                          CONCAT(
                            LOWER(TRIM(NAME)),
                            '|',
                            LOWER(TRIM(affiliation)),
                            '|',
                            LOWER(TRIM(country))
                          )
                        ),
                        1,
                        10
                      ),
                      '@pseudo'
                    )
                  ELSE
                    LOWER(TRIM(email))
                END
              ) AS authors_in_staging
            FROM
              stg_awards;
            SELECT
              COUNT(*) AS authors_in_dim_author
            FROM
              dim_author;
            -- A) Distinct raw rows vs distinct people
            SELECT
              COUNT(*) AS rows_total,
              COUNT(DISTINCT LOWER(TRIM(email))) AS distinct_real_emails,
              COUNT(
                DISTINCT
                CASE
                  WHEN email IS NULL
                    OR TRIM(email) = ''
                    OR email NOT LIKE '%@%' THEN
                    CONCAT(
                      LOWER(REPLACE(TRIM(NAME), ' ', '')),
                      '|',
                      SUBSTRING(
                        MD5(
                          CONCAT(
                            LOWER(TRIM(NAME)),
                            '|',
                            LOWER(TRIM(affiliation)),
                            '|',
                            LOWER(TRIM(country))
                          )
                        ),
                        1,
                        10
                      ),
                      '@pseudo'
                    )
                  ELSE
                    LOWER(TRIM(email))
                END
              ) AS distinct_people_norm
            FROM
              stg_awards;
            -- B) Which identities repeat the most (top 20)
            WITH pid AS (
              SELECT
                CASE
                  WHEN
                    email IS NULL
                    OR TRIM(email) = ''
                    OR email NOT LIKE '%@%' THEN
                    CONCAT(
                      LOWER(REPLACE(TRIM(NAME), ' ', '')),
                      '|',
                      SUBSTRING(
                        MD5(
                          CONCAT(
                            LOWER(TRIM(NAME)),
                            '|',
                            LOWER(TRIM(affiliation)),
                            '|',
                            LOWER(TRIM(country))
                          )
                        ),
                        1,
                        10
                      ),
                      '@pseudo'
                    )
                  ELSE
                    LOWER(TRIM(email))
                END AS email_norm,
                NAME,
                affiliation,
                country
              FROM
                stg_awards
            ) SELECT
              email_norm,
              MIN(NAME) AS sample_name,
              MIN(affiliation) AS sample_affiliation,
              MIN(country) AS sample_country,
              COUNT(*) AS rows_for_person
            FROM
              pid
            GROUP BY
              email_norm
            ORDER BY
              rows_for_person DESC
              LIMIT 20;
            SHOW CREATE TABLE dim_author;
            SHOW INDEX
            FROM
              dim_author;
            ALTER TABLE dim_author ADD COLUMN email_raw VARCHAR (255) NULL,
            ADD COLUMN email_norm VARCHAR (255) NULL,
            ADD COLUMN email_is_pseudo TINYINT (1) NOT NULL DEFAULT 0;
            UPDATE dim_author
            SET email_raw = NULLIF(TRIM(email), ''),
            email_norm =
            CASE
              WHEN email IS NOT NULL
                AND TRIM(email) <> ''
                AND email LIKE '%@%' THEN
                LOWER(TRIM(email))
              ELSE
                CONCAT(
                  LOWER(REPLACE(COALESCE(NULLIF(TRIM(full_name), ''), 'unknown'), ' ', '')),
                  '|',
                  SUBSTRING(
                    MD5(
                      CONCAT(LOWER(COALESCE(NULLIF(TRIM(full_name), ''), 'unknown')), '|', 'unknown_affiliation', '|', 'unknown_country')
                    ),
                    1,
                    10
                  ),
                  '@pseudo'
                )
            END,
            email_is_pseudo =
            CASE
              WHEN email IS NOT NULL
                AND TRIM(email) <> ''
                AND email LIKE '%@%' THEN
                0
              ELSE
                1
            END;
            ALTER TABLE dim_author DROP COLUMN email;
            DROP TEMPORARY TABLE
            IF EXISTS tmp_people;
              CREATE TEMPORARY TABLE tmp_people AS SELECT
                -- identity key: 1 row per person
                CASE
                  WHEN email IS NOT NULL
                    AND TRIM(email) <> ''
                    AND email LIKE '%@%' THEN
                    LOWER(TRIM(email))
                  ELSE
                    CONCAT(
                      LOWER(REPLACE(COALESCE(NULLIF(TRIM(NAME), ''), 'unknown'), ' ', '')),
                      '|',
                      SUBSTRING(
                        MD5(
                          CONCAT(
                            LOWER(COALESCE(NULLIF(TRIM(NAME), ''), 'unknown')),
                            '|',
                            LOWER(COALESCE(NULLIF(TRIM(affiliation), ''), 'unknown')),
                            '|',
                            LOWER(COALESCE(NULLIF(TRIM(country), ''), 'unknown'))
                          )
                        ),
                        1,
                        10
                      ),
                      '@pseudo'
                    )
                END AS email_norm,
                MIN(COALESCE(NULLIF(TRIM(NAME), ''), 'Unknown')) AS full_name,
                -- keep a real email if any exists for this identity
                MAX(CASE WHEN email IS NOT NULL AND TRIM(email) <> '' AND email LIKE '%@%' THEN LOWER(TRIM(email)) END) AS email_raw,
                CASE
                  WHEN MAX(email IS NOT NULL AND TRIM(email) <> '' AND email LIKE '%@%') = 1 THEN
                    0
                  ELSE
                    1
                END AS email_is_pseudo
              FROM
                stg_awards
              GROUP BY
                1;
              -- belt-and-suspenders: no blanks
              DELETE
              FROM
                tmp_people
              WHERE
                email_norm IS NULL
                OR email_norm = '';
              DROP TEMPORARY TABLE
              IF EXISTS tmp_people;
                CREATE TEMPORARY TABLE tmp_people AS SELECT
                  -- stable identity: real email (lowercased) else deterministic pseudo from name|affiliation|country
                  CASE
                    WHEN s.email IS NOT NULL
                      AND TRIM(s.email) <> ''
                      AND s.email LIKE '%@%' THEN
                      LOWER(TRIM(s.email))
                    ELSE
                      CONCAT(
                        LOWER(REPLACE(COALESCE(NULLIF(TRIM(s.NAME), ''), 'unknown'), ' ', '')),
                        '|',
                        SUBSTRING(
                          MD5(
                            CONCAT(
                              LOWER(COALESCE(NULLIF(TRIM(s.NAME), ''), 'unknown')),
                              '|',
                              LOWER(COALESCE(NULLIF(TRIM(s.affiliation), ''), 'unknown')),
                              '|',
                              LOWER(COALESCE(NULLIF(TRIM(s.country), ''), 'unknown'))
                            )
                          ),
                          1,
                          10
                        ),
                        '@pseudo'
                      )
                  END AS email_norm,
                  MIN(COALESCE(NULLIF(TRIM(s.NAME), ''), 'Unknown')) AS full_name,
                  MAX(
                    CASE
                      WHEN s.email IS NOT NULL
                        AND TRIM(s.email) <> ''
                        AND s.email LIKE '%@%' THEN
                        LOWER(TRIM(s.email))
                    END
                  ) AS email_raw,
                  CASE
                    WHEN MAX(s.email IS NOT NULL AND TRIM(s.email) <> '' AND s.email LIKE '%@%') = 1 THEN
                      0
                    ELSE
                      1
                  END AS email_is_pseudo
                FROM
                  stg_awards s
                GROUP BY
                  1;
                DELETE
                FROM
                  tmp_people
                WHERE
                  email_norm IS NULL
                  OR email_norm = '';
                UPDATE dim_author a
                JOIN tmp_people p ON a.email_norm = p.email_norm
                SET a.full_name = p.full_name,
                a.email_raw = COALESCE(p.email_raw, a.email_raw),
                a.email_is_pseudo = p.email_is_pseudo;
                INSERT INTO dim_author (full_name, email_raw, email_norm, email_is_pseudo) SELECT
                  p.full_name,
                  p.email_raw,
                  p.email_norm,
                  p.email_is_pseudo
                FROM
                  tmp_people p
                  LEFT JOIN dim_author a ON a.email_norm = p.email_norm
                WHERE
                  a.author_id IS NULL;
                ALTER TABLE dim_author MODIFY email_norm VARCHAR (255) NOT NULL;
                -- MySQL 8+ only; skip if your server rejects CHECK
                ALTER TABLE dim_author ADD CONSTRAINT chk_email_norm_not_empty CHECK (email_norm <> '');
                -- Create the unique key NOW (it will succeed because we de-duped above)
                ALTER TABLE dim_author ADD UNIQUE KEY uk_email_norm (email_norm);
                SELECT
                  COUNT(*) AS AUTHORS
                FROM
                  dim_author; -- expect ~1052
                SELECT
                  COUNT(*) AS blanks
                FROM
                  dim_author
                WHERE
                  email_norm IS NULL
                  OR email_norm = ''; -- must be 0
                INSERT INTO fact_award (author_id, affiliation_id, country_id, award_type_id, assembly_number, YEAR, SESSION, session_topic, presentation_type, certificate_number) SELECT
                  a.author_id,
                  af.affiliation_id,
                  c.country_id,
                  atp.award_type_id,
                  TRIM(s.assembly_number),
                  s.YEAR,
                  NULLIF(TRIM(s.SESSION), ''),
                  NULLIF(TRIM(s.session_topic), ''),
                  NULLIF(TRIM(s.presentation_type), ''),
                  NULLIF(TRIM(s.certificate_number), '')
                FROM
                  stg_awards s
                  JOIN dim_country c ON c.country_name = TRIM(LOWER(s.country))
                  JOIN dim_affiliation af ON af.affiliation_name = TRIM(s.affiliation)
                  AND af.country_id = c.country_id
                  JOIN dim_award_type atp ON LOWER(atp.award_name) = LOWER(TRIM(s.award_certificate_type))
                  JOIN dim_author a ON a.email_norm = (
                    CASE
                      WHEN s.email IS NOT NULL
                        AND TRIM(s.email) <> ''
                        AND s.email LIKE '%@%' THEN
                        LOWER(TRIM(s.email))
                      ELSE
                        CONCAT(
                          LOWER(REPLACE(COALESCE(NULLIF(TRIM(s.NAME), ''), 'unknown'), ' ', '')),
                          '|',
                          SUBSTRING(
                            MD5(
                              CONCAT(
                                LOWER(COALESCE(NULLIF(TRIM(s.NAME), ''), 'unknown')),
                                '|',
                                LOWER(COALESCE(NULLIF(TRIM(s.affiliation), ''), 'unknown')),
                                '|',
                                LOWER(COALESCE(NULLIF(TRIM(s.country), ''), 'unknown'))
                              )
                            ),
                            1,
                            10
                          ),
                          '@pseudo'
                        )
                    END
                  )
                  LEFT JOIN fact_award f2 ON f2.author_id = a.author_id
                  AND f2.affiliation_id = af.affiliation_id
                  AND f2.country_id = c.country_id
                  AND f2.award_type_id = atp.award_type_id
                  AND COALESCE(f2.certificate_number, '') = COALESCE(TRIM(s.certificate_number), '')
                WHERE
                  f2.award_id IS NULL;
                SELECT
                  COUNT(*) AS fact_rows
                FROM
                  fact_award; -- target ≈ 1209
                SELECT
                  COUNT(DISTINCT author_id) AS authors_in_fact
                FROM
                  fact_award; -- target ≈ 1052
                WITH s AS (
                  SELECT
                    s.*,
                    -- normalized author key (real email else pseudo)
                    CASE
                      WHEN s.email IS NOT NULL
                        AND TRIM(s.email) <> ''
                        AND s.email LIKE '%@%' THEN
                        LOWER(TRIM(s.email))
                      ELSE
                        CONCAT(
                          LOWER(REPLACE(COALESCE(NULLIF(TRIM(s.NAME), ''), 'unknown'), ' ', '')),
                          '|',
                          SUBSTRING(
                            MD5(
                              CONCAT(
                                LOWER(COALESCE(NULLIF(TRIM(s.NAME), ''), 'unknown')),
                                '|',
                                LOWER(COALESCE(NULLIF(TRIM(s.affiliation), ''), 'unknown')),
                                '|',
                                LOWER(COALESCE(NULLIF(TRIM(s.country), ''), 'unknown'))
                              )
                            ),
                            1,
                            10
                          ),
                          '@pseudo'
                        )
                    END AS email_norm,
                    LOWER(TRIM(s.country)) AS country_norm,
                    TRIM(s.affiliation) AS affiliation_norm,
                    LOWER(TRIM(s.award_certificate_type)) AS award_norm
                  FROM
                    stg_awards s
                ),
                j AS (
                  SELECT
                    s.*,
                    c.country_id,
                    af.affiliation_id,
                    atp.award_type_id,
                    a.author_id
                  FROM
                    s
                    LEFT JOIN dim_country c ON LOWER(TRIM(c.country_name)) = s.country_norm
                    LEFT JOIN dim_affiliation af ON TRIM(af.affiliation_name) = s.affiliation_norm
                    AND af.country_id = c.country_id
                    LEFT JOIN dim_award_type atp ON LOWER(TRIM(atp.award_name)) = s.award_norm
                    LEFT JOIN dim_author a ON a.email_norm = s.email_norm
                ) SELECT
                  COUNT(*) AS total_staging_rows,
                  SUM(country_id IS NULL) AS missing_country,
                  SUM(affiliation_id IS NULL) AS missing_affiliation,
                  SUM(award_type_id IS NULL) AS missing_award_type,
                  SUM(author_id IS NULL) AS missing_author,
                  SUM(country_id IS NOT NULL AND affiliation_id IS NOT NULL AND award_type_id IS NOT NULL AND author_id IS NOT NULL) AS rows_ready_for_fact
                FROM
                  j;
                SELECT
                  s.*
                FROM
                  stg_awards s
                  LEFT JOIN dim_country c ON LOWER(TRIM(c.country_name)) = LOWER(TRIM(s.country))
                  LEFT JOIN dim_affiliation af ON TRIM(af.affiliation_name) = TRIM(s.affiliation)
                  AND af.country_id = c.country_id
                  LEFT JOIN dim_award_type atp ON LOWER(TRIM(atp.award_name)) = LOWER(TRIM(s.award_certificate_type))
                  LEFT JOIN dim_author a ON a.email_norm = (
                    CASE
                      WHEN s.email IS NOT NULL
                        AND TRIM(s.email) <> ''
                        AND s.email LIKE '%@%' THEN
                        LOWER(TRIM(s.email))
                      ELSE
                        CONCAT(
                          LOWER(REPLACE(COALESCE(NULLIF(TRIM(s.NAME), ''), 'unknown'), ' ', '')),
                          '|',
                          SUBSTRING(
                            MD5(
                              CONCAT(
                                LOWER(COALESCE(NULLIF(TRIM(s.NAME), ''), 'unknown')),
                                '|',
                                LOWER(COALESCE(NULLIF(TRIM(s.affiliation), ''), 'unknown')),
                                '|',
                                LOWER(COALESCE(NULLIF(TRIM(s.country), ''), 'unknown'))
                              )
                            ),
                            1,
                            10
                          ),
                          '@pseudo'
                        )
                    END
                  )
                  LEFT JOIN fact_award f ON f.author_id = a.author_id
                  AND f.affiliation_id = af.affiliation_id
                  AND f.country_id = c.country_id
                  AND f.award_type_id = atp.award_type_id
                  AND COALESCE(f.certificate_number, '') = COALESCE(TRIM(s.certificate_number), '')
                WHERE
                  f.award_id IS NULL;
                DROP TEMPORARY TABLE
                IF EXISTS tmp_missing18;
                  CREATE TEMPORARY TABLE tmp_missing18 AS SELECT
                    s.id AS stg_id,
                    s.NAME,
                    s.email,
                    s.affiliation,
                    s.country,
                    s.award_certificate_type,
                    s.certificate_number,
                    -- normalized keys used for joining
                    CASE
                      WHEN s.email IS NOT NULL
                        AND TRIM(s.email) <> ''
                        AND s.email LIKE '%@%' THEN
                        LOWER(TRIM(s.email))
                      ELSE
                        CONCAT(
                          LOWER(REPLACE(COALESCE(NULLIF(TRIM(s.NAME), ''), 'unknown'), ' ', '')),
                          '|',
                          SUBSTRING(
                            MD5(
                              CONCAT(
                                LOWER(COALESCE(NULLIF(TRIM(s.NAME), ''), 'unknown')),
                                '|',
                                LOWER(COALESCE(NULLIF(TRIM(s.affiliation), ''), 'unknown')),
                                '|',
                                LOWER(COALESCE(NULLIF(TRIM(s.country), ''), 'unknown'))
                              )
                            ),
                            1,
                            10
                          ),
                          '@pseudo'
                        )
                    END AS email_norm,
                    LOWER(TRIM(s.country)) AS country_norm,
                    TRIM(s.affiliation) AS affiliation_norm,
                    LOWER(TRIM(s.award_certificate_type)) AS award_norm
                  FROM
                    stg_awards s
                    LEFT JOIN dim_country c ON LOWER(TRIM(c.country_name)) = LOWER(TRIM(s.country))
                    LEFT JOIN dim_affiliation af ON TRIM(af.affiliation_name) = TRIM(s.affiliation)
                    AND af.country_id = c.country_id
                    LEFT JOIN dim_award_type atp ON LOWER(TRIM(atp.award_name)) = LOWER(TRIM(s.award_certificate_type))
                    LEFT JOIN dim_author a ON a.email_norm = (
                      CASE
                        WHEN s.email IS NOT NULL
                          AND TRIM(s.email) <> ''
                          AND s.email LIKE '%@%' THEN
                          LOWER(TRIM(s.email))
                        ELSE
                          CONCAT(
                            LOWER(REPLACE(COALESCE(NULLIF(TRIM(s.NAME), ''), 'unknown'), ' ', '')),
                            '|',
                            SUBSTRING(
                              MD5(
                                CONCAT(
                                  LOWER(COALESCE(NULLIF(TRIM(s.NAME), ''), 'unknown')),
                                  '|',
                                  LOWER(COALESCE(NULLIF(TRIM(s.affiliation), ''), 'unknown')),
                                  '|',
                                  LOWER(COALESCE(NULLIF(TRIM(s.country), ''), 'unknown'))
                                )
                              ),
                              1,
                              10
                            ),
                            '@pseudo'
                          )
                      END
                    )
                    LEFT JOIN fact_award f ON f.author_id = a.author_id
                    AND f.affiliation_id = af.affiliation_id
                    AND f.country_id = c.country_id
                    AND f.award_type_id = atp.award_type_id
                    AND COALESCE(f.certificate_number, '') = COALESCE(TRIM(s.certificate_number), '')
                  WHERE
                    f.award_id IS NULL;
                  SELECT
                    COUNT(*) AS total_missing,
                    SUM(c.country_id IS NULL) AS missing_country,
                    SUM(af.affiliation_id IS NULL) AS missing_affiliation,
                    SUM(atp.award_type_id IS NULL) AS missing_award_type,
                    SUM(a.author_id IS NULL) AS missing_author
                  FROM
                    tmp_missing18 m
                    LEFT JOIN dim_country c ON c.country_name = m.country_norm
                    LEFT JOIN dim_award_type atp ON LOWER(TRIM(atp.award_name)) = m.award_norm
                    LEFT JOIN dim_author a ON a.email_norm = m.email_norm
                    LEFT JOIN dim_affiliation af ON TRIM(af.affiliation_name) = m.affiliation_norm
                    AND af.country_id = c.country_id;
                  -- Award names still not matching (should print ~17)
                  SELECT
                    m.award_norm AS missing_award
                  FROM
                    tmp_missing18 m
                    LEFT JOIN (
                      SELECT DISTINCT
                        REGEXP_REPLACE (
                          REPLACE(REPLACE(LOWER(TRIM(award_name)), CHAR(160), ''), CHAR(194), ''),
                          '\\s+',
                          ' '
                        ) AS award_norm2
                      FROM
                        dim_award_type
                    ) d ON d.award_norm2 = m.award_norm
                  WHERE
                    d.award_norm2 IS NULL
                  GROUP BY
                    m.award_norm;
                  -- Country not matching
                  SELECT DISTINCT
                    m.country_norm AS missing_country
                  FROM
                    tmp_missing18 m
                    LEFT JOIN (SELECT country_name AS country_norm2 FROM dim_country) c ON c.country_norm2 = m.country_norm
                  WHERE
                    c.country_norm2 IS NULL;
                  -- Affiliation not matching (by country)
                  SELECT
                    m.country_norm,
                    m.affiliation_norm AS missing_affiliation
                  FROM
                    tmp_missing18 m
                    LEFT JOIN dim_country c ON c.country_name = m.country_norm
                    LEFT JOIN dim_affiliation af ON TRIM(af.affiliation_name) = REGEXP_REPLACE (
                      REPLACE(REPLACE(TRIM(m.affiliation_norm), CHAR(160), ''), CHAR(194), ''),
                      '\\s+',
                      ' '
                    )
                    AND af.country_id = c.country_id
                  WHERE
                    af.affiliation_id IS NULL
                  GROUP BY
                    m.country_norm,
                    m.affiliation_norm;
                  -- Replace NBSPs (UTF-8 0xC2A0 and latin1 0xA0), tabs, then squeeze spaces.
                  -- Use this wherever you compare strings.
                  -- Example: NORM(TRIM(s.affiliation))  -> paste the body inline.
                  -- NORM(expr) ==>
                  LOWER(
                    TRIM(
                      REPLACE(
                        REPLACE(
                          REPLACE(REPLACE(expr, CONVERT(0xC2A0 USING utf8mb4), ' '), -- UTF-8 NBSP
                            CONVERT(0xA0 USING utf8mb4), ' '), -- latin1 NBSP
                          '\t',
                          ' '
                        ), -- tabs
                        '  ',
                        ' '
                      ) -- run 3–4 times to squeeze
                    )
                  ) SELECT
                    c.country_name AS country,
                    af.affiliation_name AS affiliation,
                    COUNT(DISTINCT f.author_id) AS total_awardees
                  FROM
                    fact_award f
                    JOIN dim_country c ON c.country_id = f.country_id
                    JOIN dim_affiliation af ON af.affiliation_id = f.affiliation_id
                  GROUP BY
                    c.country_name,
                    af.affiliation_name
                  ORDER BY
                    total_awardees DESC,
                    c.country_name ASC;
                  SELECT
                    c.country_name AS country,
                    COUNT(f.award_id) AS total_awards,
                    COUNT(DISTINCT f.author_id) AS unique_awardees
                  FROM
                    fact_award f
                    JOIN dim_country c ON c.country_id = f.country_id
                  GROUP BY
                    c.country_name
                  ORDER BY
                    total_awards DESC;
                  SELECT
                    f.award_id,
                    a.full_name AS author_name,
                    a.email_norm AS email,
                    af.affiliation_name AS affiliation,
                    c.country_name AS country,
                    atp.award_name AS award_type,
                    f.session_topic AS research_area,
                    f.assembly_number,
                    f.YEAR,
                    f.presentation_type
                  FROM
                    fact_award f
                    JOIN dim_author a ON a.author_id = f.author_id
                    JOIN dim_country c ON c.country_id = f.country_id
                    JOIN dim_affiliation af ON af.affiliation_id = f.affiliation_id
                    JOIN dim_award_type atp ON atp.award_type_id = f.award_type_id
                  ORDER BY
                    c.country_name ASC,
                    atp.award_name ASC;
                  SELECT
                    c.country_name AS country,
                    COUNT(DISTINCT f.award_id) AS total_awards,
                    GROUP_CONCAT(DISTINCT a.full_name ORDER BY a.full_name SEPARATOR ', ') AS AUTHORS,
                    GROUP_CONCAT(DISTINCT a.email_norm ORDER BY a.email_norm SEPARATOR ', ') AS emails,
                    GROUP_CONCAT(DISTINCT f.session_topic ORDER BY f.session_topic SEPARATOR ', ') AS research_areas
                  FROM
                    fact_award f
                    JOIN dim_author a ON a.author_id = f.author_id
                    JOIN dim_country c ON c.country_id = f.country_id
                    JOIN dim_affiliation af ON af.affiliation_id = f.affiliation_id
                    JOIN dim_award_type atp ON atp.award_type_id = f.award_type_id
                  GROUP BY
                    c.country_name
                  ORDER BY
                    total_awards DESC,
                    c.country_name ASC;
                  SELECT
                    c.country_name AS country,
                    a.full_name AS author_name,
                    a.email_norm AS email,
                    GROUP_CONCAT(DISTINCT f.session_topic ORDER BY f.session_topic SEPARATOR ', ') AS research_areas,
                    COUNT(DISTINCT f.award_id) AS total_awards
                  FROM
                    fact_award f
                    JOIN dim_author a ON a.author_id = f.author_id
                    JOIN dim_country c ON c.country_id = f.country_id
                    JOIN dim_affiliation af ON af.affiliation_id = f.affiliation_id
                    JOIN dim_award_type atp ON atp.award_type_id = f.award_type_id
                  GROUP BY
                    c.country_name,
                    a.full_name,
                    a.email_norm
                  ORDER BY
                    c.country_name ASC,
                    total_awards DESC,
                    a.full_name ASC;
                  -- Affiliations in China ranked by number of unique awardees
                  WITH china AS (
                    SELECT
                      f.award_id,
                      a.author_id,
                      a.full_name,
                      a.email_norm,
                      af.affiliation_id,
                      af.affiliation_name,
                      atp.award_name,
                      f.session_topic AS research_area,
                      f.YEAR
                    FROM
                      fact_award f
                      JOIN dim_author a ON a.author_id = f.author_id
                      JOIN dim_country c ON c.country_id = f.country_id
                      JOIN dim_affiliation af ON af.affiliation_id = f.affiliation_id
                      JOIN dim_award_type atp ON atp.award_type_id = f.award_type_id
                    WHERE
                      c.country_name = 'China'
                  ) SELECT
                    affiliation_name,
                    COUNT(DISTINCT author_id) AS awardees,
                    COUNT(DISTINCT award_id) AS awards,
                    MIN(YEAR) AS first_year,
                    MAX(YEAR) AS last_year,
                    -- quick flavor: top research areas
                    GROUP_CONCAT(DISTINCT research_area ORDER BY research_area SEPARATOR ', ') AS research_areas,
                    -- optional: most common award names (trim if long)
                    GROUP_CONCAT(DISTINCT award_name ORDER BY award_name SEPARATOR ', ') AS award_names
                  FROM
                    china
                  GROUP BY
                    affiliation_id,
                    affiliation_name
                  ORDER BY
                    awardees DESC,
                    awards DESC,
                    affiliation_name ASC;
                  SELECT
                    af.affiliation_name,
                    atp.award_name,
                    f.session_topic AS research_area,
                    a.full_name AS author_name,
                    COALESCE(a.email_norm, '') AS email,
                    f.YEAR,
                    f.presentation_type
                  FROM
                    fact_award f
                    JOIN dim_author a ON a.author_id = f.author_id
                    JOIN dim_country c ON c.country_id = f.country_id
                    JOIN dim_affiliation af ON af.affiliation_id = f.affiliation_id
                    JOIN dim_award_type atp ON atp.award_type_id = f.award_type_id
                  WHERE
                    c.country_name = 'China'
                  ORDER BY
                    af.affiliation_name ASC,
                    atp.award_name ASC,
                    a.full_name ASC,
                    f.YEAR DESC;
                  WITH china_awards AS (
                    SELECT
                      af.affiliation_name,
                      a.full_name AS author_name,
                      a.email_norm AS email,
                      atp.award_name,
                      f.session_topic AS research_area,
                      f.YEAR,
                      f.presentation_type
                    FROM
                      fact_award f
                      JOIN dim_author a ON a.author_id = f.author_id
                      JOIN dim_country c ON c.country_id = f.country_id
                      JOIN dim_affiliation af ON af.affiliation_id = f.affiliation_id
                      JOIN dim_award_type atp ON atp.award_type_id = f.award_type_id
                    WHERE
                      c.country_name = 'China'
                  ) SELECT
                    ca.affiliation_name,
                    COUNT(DISTINCT ca.award_name) AS total_awards,
                    GROUP_CONCAT(DISTINCT ca.author_name ORDER BY ca.author_name SEPARATOR ', ') AS AUTHORS,
                    GROUP_CONCAT(DISTINCT ca.email ORDER BY ca.email SEPARATOR ', ') AS emails,
                    GROUP_CONCAT(DISTINCT ca.research_area ORDER BY ca.research_area SEPARATOR ', ') AS research_areas,
                    GROUP_CONCAT(DISTINCT ca.award_name ORDER BY ca.award_name SEPARATOR ', ') AS award_names
                  FROM
                    china_awards ca
                  GROUP BY
                    ca.affiliation_name
                  ORDER BY
                    total_awards DESC,
                    ca.affiliation_name ASC;
                  WITH china_awards AS (
                    SELECT
                      af.affiliation_name,
                      a.full_name AS author_name,
                      a.email_norm AS email,
                      atp.award_name,
                      f.session_topic AS research_area,
                      f.YEAR,
                      f.presentation_type
                    FROM
                      fact_award f
                      JOIN dim_author a ON a.author_id = f.author_id
                      JOIN dim_country c ON c.country_id = f.country_id
                      JOIN dim_affiliation af ON af.affiliation_id = f.affiliation_id
                      JOIN dim_award_type atp ON atp.award_type_id = f.award_type_id
                    WHERE
                      c.country_name = 'China'
                  ) SELECT
                    ca.affiliation_name,
                    COUNT(ca.award_name) AS total_awards,
                    GROUP_CONCAT(ca.author_name ORDER BY ca.author_name SEPARATOR ', ') AS AUTHORS,
                    GROUP_CONCAT(ca.email ORDER BY ca.email SEPARATOR ', ') AS emails,
                    GROUP_CONCAT(ca.research_area ORDER BY ca.research_area SEPARATOR ', ') AS research_areas,
                    GROUP_CONCAT(ca.award_name ORDER BY ca.award_name SEPARATOR ', ') AS award_names
                  FROM
                    china_awards ca
                  GROUP BY
                    ca.affiliation_name
                  ORDER BY
                    total_awards DESC,
                    ca.affiliation_name ASC;
                  SELECT
                    af.affiliation_name,
                    atp.award_name,
                    f.session_topic AS research_area,
                    a.full_name AS author_name,
                    COALESCE(a.email_norm, '') AS email,
                    f.YEAR,
                    f.presentation_type
                  FROM
                    fact_award f
                    JOIN dim_author a ON a.author_id = f.author_id
                    JOIN dim_country c ON c.country_id = f.country_id
                    JOIN dim_affiliation af ON af.affiliation_id = f.affiliation_id
                    JOIN dim_award_type atp ON atp.award_type_id = f.award_type_id
                  WHERE
                    c.country_name = 'China'
                    AND af.affiliation_name = 'Tsinghua University' -- example
                  ORDER BY
                    f.YEAR DESC,
                    atp.award_name ASC,
                    a.full_name ASC;