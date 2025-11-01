

#This query gives the information regarding the users registered between July 2024 to September 2025 and How many abstracts were submitted in that window and conversion rate 


WITH params AS (
  SELECT CAST('2024-07-01' AS DATE) AS start_date,
         CAST('2025-10-01' AS DATE) AS end_date
),
users_w AS (
  SELECT u.*
  FROM users u, params p
  WHERE u.created_at >= p.start_date
    AND u.created_at <  p.end_date
),
abstracts_w AS (
  SELECT a.id AS abstract_id, a.user_id, a.statusdate
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date
    AND a.statusdate <  p.end_date
),
submitters AS (
  SELECT DISTINCT user_id FROM abstracts_w
)
SELECT
  (SELECT COUNT(*)        FROM users_w)    AS total_users_in_window,
  (SELECT COUNT(*)        FROM submitters) AS users_who_submitted_in_window,
  (SELECT COUNT(*)        FROM abstracts_w)AS total_abstracts_in_window,
  ROUND(
    100.0 * (SELECT COUNT(*) FROM submitters)
          / NULLIF((SELECT COUNT(*) FROM users_w), 0), 2
  ) AS user_submission_rate_percent;



#The below query gives information regarding the details of these authors who submitted abstracts



WITH params AS (
  SELECT CAST('2024-07-01' AS DATE) AS start_date,
         CAST('2025-10-01' AS DATE) AS end_date
),
users_w AS (
  SELECT u.*
  FROM users u, params p
  WHERE u.created_at >= p.start_date
    AND u.created_at <  p.end_date
),
abstracts_w AS (
  SELECT a.id AS abstract_id, a.user_id, a.statusdate
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date
    AND a.statusdate <  p.end_date
),
per_submitter AS (
  -- counts only within the window
  SELECT
    user_id,
    COUNT(*)        AS abstracts_in_window,
    MIN(statusdate) AS first_submission,
    MAX(statusdate) AS last_submission
  FROM abstracts_w
  GROUP BY user_id
),
per_user_all_time AS (
  -- lifetime counts (no date filter)
  SELECT
    user_id,
    COUNT(*)        AS total_abstracts_all_time,
    MIN(statusdate) AS first_submission_ever,
    MAX(statusdate) AS last_submission_ever
  FROM abstract_submissions
  GROUP BY user_id
)
SELECT
  u.id AS user_id,
  CONCAT_WS(' ', u.first_name, u.last_name) AS name,
  u.email,
  u.affiliation,
  CASE WHEN u.date_of_birth IS NOT NULL
       THEN TIMESTAMPDIFF(YEAR, u.date_of_birth, (SELECT end_date FROM params))
       ELSE NULL END AS age_as_of_end,
  u.created_at,
  ps.abstracts_in_window,             -- number in the window
  pz.total_abstracts_all_time,        -- lifetime number
  ps.first_submission,
  ps.last_submission,
  pz.first_submission_ever,
  pz.last_submission_ever
FROM users_w u
JOIN per_submitter ps     ON ps.user_id = u.id     -- only users who submitted in the window
LEFT JOIN per_user_all_time pz ON pz.user_id = u.id
ORDER BY ps.last_submission DESC, u.id;




#Abstract Submission to Registration conversion

WITH params AS (
  SELECT CAST('2024-07-01' AS DATE) AS start_date,
         CAST('2025-10-01' AS DATE) AS end_date
),
submitters AS (  -- unique user+event pairs that submitted in the window
  SELECT DISTINCT a.user_id, a.event_id
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date
    AND a.statusdate <  p.end_date
),
paid_regs AS (   -- paid registrations matching those user+event pairs
  SELECT r.user_id, r.event_id, r.total_price
  FROM registrations r
  JOIN submitters s
    ON s.user_id  = r.user_id
   AND s.event_id = r.event_id
  WHERE r.status = 1                -- paid only
    AND r.currency_type = 'EUR'     -- EUR only
    AND r.total_price IS NOT NULL
)
SELECT
  (SELECT COUNT(DISTINCT user_id) FROM submitters) AS submitter_users,
  (SELECT COUNT(DISTINCT user_id) FROM paid_regs)  AS paid_users,
  ROUND(
    100.0 * (SELECT COUNT(DISTINCT user_id) FROM paid_regs)
          / NULLIF((SELECT COUNT(DISTINCT user_id) FROM submitters),0), 2
  ) AS submitter_to_paid_rate_pct,
  ROUND(COALESCE((SELECT SUM(total_price) FROM paid_regs),0), 2) AS total_revenue_EUR;
  
  




# This Query is to know how many submitted abstracts and who are paid and Unpaid users

WITH params AS (
  SELECT CAST('2024-07-01' AS DATE) AS start_date,
         CAST('2025-10-01' AS DATE) AS end_date
),
-- all submitters (user+event)
submitters AS (
  SELECT DISTINCT a.user_id, a.event_id
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date
    AND a.statusdate <  p.end_date
),
-- only paid regs for those submitters
paid_regs AS (
  SELECT r.user_id, r.event_id, r.total_price
  FROM registrations r
  JOIN submitters s
    ON s.user_id  = r.user_id
   AND s.event_id = r.event_id
  WHERE r.status = 1
    AND r.currency_type = 'EUR'
    AND r.total_price IS NOT NULL
),
-- revenue summary per paid user
user_revenue AS (
  SELECT user_id,
         COUNT(*)                  AS paid_registrations,
         ROUND(SUM(total_price),2) AS eur_revenue
  FROM paid_regs
  GROUP BY user_id
)
SELECT
  u.id AS user_id,
  CONCAT_WS(' ', u.first_name, u.last_name) AS name,
  u.email,
  u.affiliation,
  CASE WHEN u.date_of_birth IS NOT NULL
       THEN TIMESTAMPDIFF(YEAR, u.date_of_birth, (SELECT end_date FROM params))
       ELSE NULL END AS age_as_of_end,
  COALESCE(ur.paid_registrations, 0) AS paid_registrations,
  COALESCE(ur.eur_revenue, 0.00)     AS eur_revenue,
  CASE WHEN ur.user_id IS NULL THEN 0 ELSE 1 END AS is_paid
FROM (SELECT DISTINCT user_id FROM submitters) s
JOIN users u        ON u.id = s.user_id
LEFT JOIN user_revenue ur ON ur.user_id = u.id
ORDER BY is_paid DESC, eur_revenue DESC, u.id;





WITH params AS (
  SELECT CAST('2025-01-01' AS DATE) AS start_date,
         CAST('2025-10-01' AS DATE) AS end_date
),
-- all submitters (user+event) in given window
submitters AS (
  SELECT DISTINCT a.user_id, a.event_id
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date
    AND a.statusdate <  p.end_date
)
SELECT
  r.id            AS registration_id,
  r.user_id,
  CONCAT_WS(' ', u.first_name, u.last_name) AS name,
  u.email,
  u.affiliation,
  r.event_id,
  r.total_price,
  r.currency_type,
  r.sendinvoice,
  r.status,
  r.created_at,
  r.updated_at
FROM registrations r
JOIN submitters s
  ON s.user_id  = r.user_id
 AND s.event_id = r.event_id
JOIN users u
  ON u.id = r.user_id
WHERE r.sendinvoice = 1
  AND r.status = 0
ORDER BY r.created_at DESC;






# This Query is to know who are the paid users

WITH params AS (
  SELECT CAST('2024-07-01' AS DATE) AS start_date,
         CAST('2025-10-01' AS DATE) AS end_date
),
submitters AS (
  SELECT DISTINCT a.user_id, a.event_id
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date
    AND a.statusdate <  p.end_date
),
paid_regs AS (
  SELECT r.user_id, r.event_id, r.total_price
  FROM registrations r
  JOIN submitters s
    ON s.user_id  = r.user_id
   AND s.event_id = r.event_id
  WHERE r.status = 1
    AND r.currency_type = 'EUR'
    AND r.total_price IS NOT NULL
),
user_revenue AS (
  SELECT user_id,
         COUNT(*)                   AS paid_registrations,
         ROUND(SUM(total_price),2)  AS eur_revenue
  FROM paid_regs
  GROUP BY user_id
)
SELECT
  u.id AS user_id,
  CONCAT_WS(' ', u.first_name, u.last_name) AS name,
  u.email,
  u.affiliation,
  CASE WHEN u.date_of_birth IS NOT NULL
       THEN TIMESTAMPDIFF(YEAR, u.date_of_birth, (SELECT end_date FROM params))
       ELSE NULL END AS age_as_of_end,
  ur.paid_registrations,
  ur.eur_revenue
FROM user_revenue ur            -- << base is paid users
JOIN users u ON u.id = ur.user_id
ORDER BY ur.eur_revenue DESC, ur.paid_registrations DESC, u.id;





#The below query shows the total abstracts submitted and who are paid and unpaid users along with event names


WITH params AS (
  SELECT CAST('2024-07-01' AS DATE) AS start_date,
         CAST('2025-10-01' AS DATE) AS end_date
),
-- All submitter user+event pairs in the window
submitters AS (
  SELECT DISTINCT a.user_id, a.event_id
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date
    AND a.statusdate <  p.end_date
),
-- Paid registrations for those same user+event pairs (EUR only)
paid_regs AS (
  SELECT r.user_id, r.event_id, r.total_price
  FROM registrations r
  JOIN submitters s
    ON s.user_id  = r.user_id
   AND s.event_id = r.event_id
  WHERE r.status = 1
    AND r.currency_type = 'EUR'
    AND r.total_price IS NOT NULL
),
-- Revenue per paid user
user_revenue AS (
  SELECT user_id,
         COUNT(*)                  AS paid_registrations,
         ROUND(SUM(total_price),2) AS eur_revenue
  FROM paid_regs
  GROUP BY user_id
),
-- Event lists (submitted vs. attended/paid)
submitted_events AS (
  SELECT
    s.user_id,
    GROUP_CONCAT(DISTINCT s.event_id ORDER BY s.event_id)               AS submitted_event_ids,
    GROUP_CONCAT(DISTINCT COALESCE(e.name, CONCAT('Event#',e.id)) ORDER BY e.id)
      AS submitted_event_names
  FROM submitters s
  LEFT JOIN events e ON e.id = s.event_id
  GROUP BY s.user_id
),
paid_events AS (
  SELECT
    p.user_id,
    GROUP_CONCAT(DISTINCT p.event_id ORDER BY p.event_id)               AS paid_event_ids,
    GROUP_CONCAT(DISTINCT COALESCE(e.name, CONCAT('Event#',e.id)) ORDER BY e.id)
      AS paid_event_names
  FROM paid_regs p
  LEFT JOIN events e ON e.id = p.event_id
  GROUP BY p.user_id
)
SELECT
  u.id AS user_id,
  CONCAT_WS(' ', u.first_name, u.last_name) AS name,
  u.email,
  u.affiliation,
  c.name AS country,  -- ✅ proper country name from countries table
  CASE WHEN u.date_of_birth IS NOT NULL
       THEN TIMESTAMPDIFF(YEAR, u.date_of_birth, (SELECT end_date FROM params))
       ELSE NULL END AS age_as_of_end,
  COALESCE(ur.paid_registrations, 0) AS paid_registrations,
  COALESCE(ur.eur_revenue, 0.00)     AS eur_revenue,
  CASE WHEN ur.user_id IS NULL THEN 0 ELSE 1 END AS is_paid,
  se.submitted_event_ids,
  se.submitted_event_names,
  pe.paid_event_ids,
  pe.paid_event_names
FROM (SELECT DISTINCT user_id FROM submitters) su
JOIN users u              ON u.id = su.user_id
LEFT JOIN countries c     ON c.id = u.country_id   -- ✅ proper FK join
LEFT JOIN user_revenue ur ON ur.user_id = u.id
LEFT JOIN submitted_events se ON se.user_id = u.id
LEFT JOIN paid_events pe      ON pe.user_id = u.id
ORDER BY is_paid DESC, eur_revenue DESC, u.id;





# This below Query Shows country wise conversion rates

WITH params AS (
  SELECT CAST('2024-07-01' AS DATE) AS start_date,
         CAST('2025-10-01' AS DATE) AS end_date
),
-- all users who submitted in the window
submitter_users AS (
  SELECT DISTINCT a.user_id
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date
    AND a.statusdate <  p.end_date
),
-- user -> country name
user_country AS (
  SELECT u.id AS user_id,
         COALESCE(c.name, 'Unknown') AS country_name
  FROM users u
  LEFT JOIN countries c ON c.id = u.country_id
),
-- paid registrations (EUR) by those submitters, matched by user+event
paid_regs AS (
  SELECT r.user_id, r.event_id, r.total_price
  FROM registrations r
  JOIN (
    SELECT DISTINCT a.user_id, a.event_id
    FROM abstract_submissions a, params p
    WHERE a.statusdate >= p.start_date
      AND a.statusdate <  p.end_date
  ) s ON s.user_id = r.user_id AND s.event_id = r.event_id
  WHERE r.status = 1
    AND r.currency_type = 'EUR'
    AND r.total_price IS NOT NULL
  -- Optional: also require payment happened in the same window
  -- AND r.sendinvoicedate >= (SELECT start_date FROM params)
  -- AND r.sendinvoicedate <  (SELECT end_date   FROM params)
)
SELECT
  uc.country_name,
  COUNT(DISTINCT su.user_id)                    AS submitter_users,
  COUNT(DISTINCT pr.user_id)                    AS paid_users,
  ROUND(100.0 * COUNT(DISTINCT pr.user_id)
        / NULLIF(COUNT(DISTINCT su.user_id),0), 2) AS conversion_pct,
  ROUND(COALESCE(SUM(pr.total_price),0), 2)     AS revenue_EUR,
  ROUND(COALESCE(AVG(pr.total_price),0), 2)     AS avg_ticket_EUR
FROM user_country uc
LEFT JOIN submitter_users su ON su.user_id = uc.user_id
LEFT JOIN paid_regs pr        ON pr.user_id = uc.user_id
GROUP BY uc.country_name
HAVING COUNT(DISTINCT su.user_id) > 0   -- only countries with submitters
ORDER BY revenue_EUR DESC, conversion_pct DESC, uc.country_name;





#The below Query is to know event wise and country wise revenues

WITH params AS (
  SELECT CAST('2024-07-01' AS DATE) AS start_date,
         CAST('2025-10-01' AS DATE) AS end_date
),
-- All user+event pairs from abstract submissions in window
submitters AS (
  SELECT DISTINCT a.user_id, a.event_id
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date
    AND a.statusdate <  p.end_date
),
-- Paid registrations (EUR only) for those user+event pairs
paid_regs AS (
  SELECT r.user_id, r.event_id, r.total_price
  FROM registrations r
  JOIN submitters s
    ON s.user_id  = r.user_id
   AND s.event_id = r.event_id
  WHERE r.status = 1
    AND r.currency_type = 'EUR'
    AND r.total_price IS NOT NULL
),
-- Add country info for users
user_country AS (
  SELECT u.id AS user_id,
         u.country_id,
         COALESCE(c.name, 'Unknown') AS country_name
  FROM users u
  LEFT JOIN countries c ON c.id = u.country_id
)
SELECT
  uc.country_name,
  e.id   AS event_id,
  e.name AS event_name,
  COUNT(DISTINCT s.user_id) AS submitter_users,
  COUNT(DISTINCT pr.user_id) AS paid_users,
  ROUND(100.0 * COUNT(DISTINCT pr.user_id)
        / NULLIF(COUNT(DISTINCT s.user_id),0), 2) AS conversion_pct,
  ROUND(COALESCE(SUM(pr.total_price),0), 2) AS revenue_EUR,
  ROUND(COALESCE(AVG(pr.total_price),0), 2) AS avg_ticket_EUR
FROM submitters s
JOIN user_country uc ON uc.user_id = s.user_id
JOIN events e        ON e.id = s.event_id
LEFT JOIN paid_regs pr
       ON pr.user_id = s.user_id AND pr.event_id = s.event_id
GROUP BY uc.country_name, e.id, e.name
HAVING COUNT(DISTINCT s.user_id) > 0
ORDER BY revenue_EUR DESC, uc.country_name, e.id;



# The Below Query shows Affiliation wise conversion rates

WITH params AS (
  SELECT CAST('2024-07-01' AS DATE) AS start_date,
         CAST('2025-10-01' AS DATE) AS end_date
),
submitters AS (
  SELECT DISTINCT a.user_id, a.event_id
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date
    AND a.statusdate <  p.end_date
),
paid_regs AS (
  SELECT r.user_id, r.event_id, r.total_price
  FROM registrations r
  JOIN submitters s
    ON s.user_id = r.user_id
   AND s.event_id = r.event_id
  WHERE r.status = 1
    AND r.currency_type = 'EUR'
    AND r.total_price IS NOT NULL
),
user_country_aff AS (
  SELECT u.id AS user_id,
         u.affiliation,
         COALESCE(c.name, 'Unknown') AS country_name
  FROM users u
  LEFT JOIN countries c ON c.id = u.country_id
)
SELECT
  uca.affiliation,
  uca.country_name,
  COUNT(DISTINCT pr.user_id)     AS paid_users,
  ROUND(SUM(pr.total_price), 2)  AS revenue_EUR
FROM paid_regs pr
JOIN user_country_aff uca ON uca.user_id = pr.user_id
GROUP BY uca.affiliation, uca.country_name
HAVING COUNT(DISTINCT pr.user_id) > 0
ORDER BY revenue_EUR DESC, paid_users DESC, uca.affiliation;




# The below Query gives country wise, event wise and Affiliation wise Conversion rates

WITH params AS (
  SELECT CAST('2024-07-01' AS DATE) AS start_date,
         CAST('2025-10-01' AS DATE) AS end_date
),
-- All abstract submitters in the window
submitters AS (
  SELECT DISTINCT a.user_id, a.event_id
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date
    AND a.statusdate <  p.end_date
),
-- Paid registrations for those submitters (EUR only)
paid_regs AS (
  SELECT r.user_id, r.event_id, r.total_price
  FROM registrations r
  JOIN submitters s
    ON s.user_id = r.user_id
   AND s.event_id = r.event_id
  WHERE r.status = 1
    AND r.currency_type = 'EUR'
    AND r.total_price IS NOT NULL
),
-- User affiliation + country
user_country_aff AS (
  SELECT u.id AS user_id,
         u.affiliation,
         COALESCE(c.name, 'Unknown') AS country_name
  FROM users u
  LEFT JOIN countries c ON c.id = u.country_id
)
SELECT
  uca.affiliation,
  uca.country_name,
  e.id   AS event_id,
  e.name AS event_name,
  COUNT(DISTINCT pr.user_id)    AS paid_users,
  ROUND(SUM(pr.total_price),2)  AS revenue_EUR,
  ROUND(AVG(pr.total_price),2)  AS avg_ticket_EUR
FROM paid_regs pr
JOIN user_country_aff uca ON uca.user_id = pr.user_id
JOIN events e             ON e.id = pr.event_id
GROUP BY uca.affiliation, uca.country_name, e.id, e.name
HAVING COUNT(DISTINCT pr.user_id) > 0
ORDER BY revenue_EUR DESC, paid_users DESC, uca.affiliation, e.id;









WITH params AS (
  SELECT CAST('2024-07-01' AS DATE) AS start_date,
         CAST('2025-10-01' AS DATE) AS end_date
),
-- All abstract submitters in the window
submitters AS (
  SELECT DISTINCT a.user_id, a.event_id
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date
    AND a.statusdate <  p.end_date
),
-- Paid registrations for those submitters (EUR only)
paid_regs AS (
  SELECT r.user_id, r.event_id, r.total_price
  FROM registrations r
  JOIN submitters s
    ON s.user_id = r.user_id
   AND s.event_id = r.event_id
  WHERE r.status = 1
    AND r.currency_type = 'EUR'
    AND r.total_price IS NOT NULL
),
-- User affiliation + country
user_country_aff AS (
  SELECT u.id AS user_id,
         u.affiliation,
         COALESCE(c.name, 'Unknown') AS country_name
  FROM users u
  LEFT JOIN countries c ON c.id = u.country_id
),
-- Per affiliation+country+event
aff_event AS (
  SELECT
    uca.affiliation,
    uca.country_name,
    e.id   AS event_id,
    e.name AS event_name,
    COUNT(DISTINCT pr.user_id)   AS paid_users,
    ROUND(SUM(pr.total_price),2) AS revenue_EUR,
    ROUND(AVG(pr.total_price),2) AS avg_ticket_EUR
  FROM paid_regs pr
  JOIN user_country_aff uca ON uca.user_id = pr.user_id
  JOIN events e             ON e.id = pr.event_id
  GROUP BY uca.affiliation, uca.country_name, e.id, e.name
),
-- Per affiliation+country (rollup across all events)
aff_total AS (
  SELECT
    uca.affiliation,
    uca.country_name,
    COUNT(DISTINCT pr.user_id)   AS paid_users_total,
    ROUND(SUM(pr.total_price),2) AS revenue_total_EUR,
    ROUND(AVG(pr.total_price),2) AS avg_ticket_total_EUR
  FROM paid_regs pr
  JOIN user_country_aff uca ON uca.user_id = pr.user_id
  GROUP BY uca.affiliation, uca.country_name
)
-- Union both granular + rollup
SELECT
  a.affiliation,
  a.country_name,
  at.paid_users_total,
  at.revenue_total_EUR,
  at.avg_ticket_total_EUR,
  ae.event_id,
  ae.event_name,
  ae.paid_users,
  ae.revenue_EUR,
  ae.avg_ticket_EUR
FROM aff_event ae
JOIN aff_total at
  ON at.affiliation = ae.affiliation
 AND at.country_name = ae.country_name
JOIN (SELECT DISTINCT affiliation, country_name FROM aff_total) a
  ON a.affiliation = ae.affiliation AND a.country_name = ae.country_name
ORDER BY at.revenue_total_EUR DESC, at.paid_users_total DESC, a.affiliation, ae.event_id;




#Granular view of paid_users and submitted_users



WITH params AS (
  SELECT CAST('2024-07-01' AS DATE) AS start_date,
         CAST('2025-10-01' AS DATE) AS end_date
),
-- All abstract submitters in the window
submitters AS (
  SELECT DISTINCT a.user_id, a.event_id
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date
    AND a.statusdate <  p.end_date
),
-- Paid registrations for those submitters (EUR only)
paid_regs AS (
  SELECT r.user_id, r.event_id, r.total_price
  FROM registrations r
  JOIN submitters s
    ON s.user_id = r.user_id
   AND s.event_id = r.event_id
  WHERE r.status = 1
    AND r.currency_type = 'EUR'
    AND r.total_price IS NOT NULL
),
-- User affiliation + country
user_country_aff AS (
  SELECT u.id AS user_id,
         u.affiliation,
         COALESCE(c.name, 'Unknown') AS country_name
  FROM users u
  LEFT JOIN countries c ON c.id = u.country_id
),
-- Per affiliation + country + event
aff_event AS (
  SELECT
    uca.country_name,
    uca.affiliation,
    e.id   AS event_id,
    e.name AS event_name,
    COUNT(DISTINCT pr.user_id)   AS paid_users,
    ROUND(SUM(pr.total_price),2) AS revenue_EUR,
    ROUND(AVG(pr.total_price),2) AS avg_ticket_EUR
  FROM paid_regs pr
  JOIN user_country_aff uca ON uca.user_id = pr.user_id
  JOIN events e             ON e.id = pr.event_id
  GROUP BY uca.country_name, uca.affiliation, e.id, e.name
),
-- Per affiliation + country (rollup)
aff_total AS (
  SELECT
    uca.country_name,
    uca.affiliation,
    COUNT(DISTINCT pr.user_id)   AS paid_users_total,
    ROUND(SUM(pr.total_price),2) AS revenue_total_EUR,
    ROUND(AVG(pr.total_price),2) AS avg_ticket_total_EUR
  FROM paid_regs pr
  JOIN user_country_aff uca ON uca.user_id = pr.user_id
  GROUP BY uca.country_name, uca.affiliation
),
-- Per country rollup (all affiliations combined)
country_total AS (
  SELECT
    uca.country_name,
    COUNT(DISTINCT pr.user_id)   AS paid_users_country,
    ROUND(SUM(pr.total_price),2) AS revenue_country_EUR,
    ROUND(AVG(pr.total_price),2) AS avg_ticket_country_EUR
  FROM paid_regs pr
  JOIN user_country_aff uca ON uca.user_id = pr.user_id
  GROUP BY uca.country_name
)
-- Final unified report
SELECT
  ct.country_name,
  at.affiliation,
  at.paid_users_total,
  at.revenue_total_EUR,
  at.avg_ticket_total_EUR,
  ae.event_id,
  ae.event_name,
  ae.paid_users,
  ae.revenue_EUR,
  ae.avg_ticket_EUR,
  ct.paid_users_country,
  ct.revenue_country_EUR,
  ct.avg_ticket_country_EUR
FROM aff_event ae
JOIN aff_total at
  ON at.country_name = ae.country_name
 AND at.affiliation  = ae.affiliation
JOIN country_total ct
  ON ct.country_name = ae.country_name
ORDER BY ct.revenue_country_EUR DESC,
         at.revenue_total_EUR DESC,
         ae.revenue_EUR DESC,
         at.affiliation, ae.event_id;






WITH params AS (
  SELECT CAST('2024-07-01' AS DATE) AS start_date,
         CAST('2025-10-01' AS DATE) AS end_date
),
-- All user+event pairs from abstract submissions in window
submitters AS (
  SELECT DISTINCT a.user_id, a.event_id
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date
    AND a.statusdate <  p.end_date
),
-- Distinct submitter users (any event) in window
submitter_users AS (
  SELECT DISTINCT user_id
  FROM submitters
),
-- Paid registrations (EUR only) for those user+event pairs
paid_regs AS (
  SELECT r.user_id, r.event_id, r.total_price
  FROM registrations r
  JOIN submitters s
    ON s.user_id  = r.user_id
   AND s.event_id = r.event_id
  WHERE r.status = 1
    AND r.currency_type = 'EUR'
    AND r.total_price IS NOT NULL
),
-- User -> Country
user_country AS (
  SELECT u.id AS user_id,
         COALESCE(c.name, 'Unknown') AS country_name
  FROM users u
  LEFT JOIN countries c ON c.id = u.country_id
),
-- Submitter counts per country
country_submit AS (
  SELECT uc.country_name,
         COUNT(DISTINCT su.user_id) AS submitter_users
  FROM user_country uc
  JOIN submitter_users su ON su.user_id = uc.user_id
  GROUP BY uc.country_name
),
-- Paid user + revenue per country
country_paid AS (
  SELECT uc.country_name,
         COUNT(DISTINCT pr.user_id)   AS paid_users,
         ROUND(SUM(pr.total_price),2) AS revenue_EUR,
         ROUND(AVG(pr.total_price),2) AS avg_ticket_EUR
  FROM paid_regs pr
  JOIN user_country uc ON uc.user_id = pr.user_id
  GROUP BY uc.country_name
),
-- Final per-country rollup (submitters + paid + conversion + revenue)
country_total AS (
  SELECT
    cs.country_name,
    cs.submitter_users,
    COALESCE(cp.paid_users, 0)     AS paid_users,
    CASE WHEN cs.submitter_users > 0
         THEN ROUND(100.0 * COALESCE(cp.paid_users,0) / cs.submitter_users, 2)
         ELSE 0 END                AS conversion_pct,
    COALESCE(cp.revenue_EUR, 0.00) AS revenue_EUR,
    COALESCE(cp.avg_ticket_EUR, 0) AS avg_ticket_EUR
  FROM country_submit cs
  LEFT JOIN country_paid cp
    ON cp.country_name = cs.country_name
)
-- === GRAND TOTAL + per-country rows ===
SELECT
  'ALL COUNTRIES' AS country_name,
  su_total        AS submitter_users,
  pu_total        AS paid_users,
  ROUND(100.0 * pu_total / NULLIF(su_total,0), 2) AS conversion_pct,
  ROUND(rev_total, 2) AS revenue_EUR,
  ROUND(avg_ticket_total, 2) AS avg_ticket_EUR
FROM (
  SELECT COUNT(DISTINCT user_id) AS su_total FROM submitter_users
) su
CROSS JOIN (
  SELECT COUNT(DISTINCT user_id) AS pu_total,
         SUM(total_price)        AS rev_total,
         AVG(total_price)        AS avg_ticket_total
  FROM paid_regs
) pr

UNION ALL

SELECT
  country_name,
  submitter_users,
  paid_users,
  conversion_pct,
  revenue_EUR,
  avg_ticket_EUR
FROM country_total

ORDER BY (country_name = 'ALL COUNTRIES') DESC,
         revenue_EUR DESC,
         conversion_pct DESC,
         country_name;







-- =========================
-- Global knobs (safe to keep)
-- =========================
SET SESSION group_concat_max_len = 100000;

-- ------------------------------------------------------------
-- TABLE 1: Country × Event insights (pricing + targeting core)
-- ------------------------------------------------------------
-- DROP TABLE IF EXISTS marketing_geo_event_insights_jul2024_sep2025;
CREATE TABLE marketing_geo_event_insights_jul2024_sep2025 AS
WITH
params AS (
  SELECT
    CAST('2024-07-01' AS DATE) AS start_date,
    CAST('2025-10-01' AS DATE) AS end_exclusive,
    'EUR' AS currency_code
),
abs_w AS (
  SELECT a.user_id, a.event_id, a.statusdate
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date
    AND a.statusdate <  p.end_exclusive
),
submitters AS (
  SELECT DISTINCT user_id, event_id FROM abs_w
),
user_dim AS (
  SELECT u.id AS user_id,
         COALESCE(c.name,'Unknown') AS country_name,
         COALESCE(NULLIF(TRIM(u.affiliation),''), 'Unknown') AS affiliation
  FROM users u
  LEFT JOIN countries c ON c.id = u.country_id
),
sub_agg AS (
  SELECT ud.country_name, s.event_id,
         COUNT(DISTINCT s.user_id) AS submitter_users
  FROM submitters s
  JOIN user_dim ud ON ud.user_id = s.user_id
  GROUP BY ud.country_name, s.event_id
),
paid_regs_raw AS (
  SELECT r.user_id, r.event_id, r.total_price
  FROM registrations r
  JOIN submitters s
    ON s.user_id  = r.user_id
   AND s.event_id = r.event_id
  JOIN params p
  WHERE r.status = 1
    AND r.total_price IS NOT NULL
    AND r.currency_type = p.currency_code
  -- Optional payment date filter:
  --  AND r.sendinvoicedate >= p.start_date
  --  AND r.sendinvoicedate <  p.end_exclusive
),
paid_agg AS (
  SELECT ud.country_name, pr.event_id,
         COUNT(*)                                  AS registrations_count,
         COUNT(DISTINCT pr.user_id)                AS paid_users,
         ROUND(SUM(pr.total_price),2)              AS revenue_EUR,
         ROUND(AVG(pr.total_price),2)              AS avg_ticket_EUR,
         ROUND(MIN(pr.total_price),2)              AS min_ticket_EUR,
         ROUND(MAX(pr.total_price),2)              AS max_ticket_EUR,
         ROUND(STDDEV_POP(pr.total_price),2)       AS stddev_ticket_EUR
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  GROUP BY ud.country_name, pr.event_id
),
first_abs_ever AS (
  SELECT user_id, MIN(statusdate) AS first_abs_date
  FROM abstract_submissions
  GROUP BY user_id
),
paid_user_cohort AS (
  SELECT ud.country_name, pr.event_id,
         SUM(CASE WHEN fa.first_abs_date <  (SELECT start_date FROM params) THEN 1 ELSE 0 END) AS returning_paid_users,
         SUM(CASE WHEN fa.first_abs_date >= (SELECT start_date FROM params) THEN 1 ELSE 0 END) AS new_paid_users
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  JOIN first_abs_ever fa ON fa.user_id = pr.user_id
  GROUP BY ud.country_name, pr.event_id
),
aff_stats AS (
  SELECT ud.country_name, pr.event_id, ud.affiliation,
         COUNT(DISTINCT pr.user_id) AS paid_users_aff,
         ROUND(SUM(pr.total_price),2) AS revenue_aff_EUR
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  WHERE ud.affiliation <> 'Unknown'
  GROUP BY ud.country_name, pr.event_id, ud.affiliation
),
aff_rank_paid AS (
  SELECT country_name, event_id, affiliation, paid_users_aff, revenue_aff_EUR,
         ROW_NUMBER() OVER (PARTITION BY country_name, event_id
                            ORDER BY paid_users_aff DESC, revenue_aff_EUR DESC, affiliation) AS rn_paid
  FROM aff_stats
),
top3_paid AS (
  SELECT country_name, event_id,
         GROUP_CONCAT(CONCAT(affiliation,' (',paid_users_aff,')')
                      ORDER BY rn_paid SEPARATOR ' | ') AS top_affiliations_by_paid
  FROM aff_rank_paid
  WHERE rn_paid <= 3
  GROUP BY country_name, event_id
),
aff_rank_rev AS (
  SELECT country_name, event_id, affiliation, paid_users_aff, revenue_aff_EUR,
         ROW_NUMBER() OVER (PARTITION BY country_name, event_id
                            ORDER BY revenue_aff_EUR DESC, paid_users_aff DESC, affiliation) AS rn_rev
  FROM aff_stats
),
top3_rev AS (
  SELECT country_name, event_id,
         GROUP_CONCAT(CONCAT(affiliation,' (€', FORMAT(revenue_aff_EUR,0),')')
                      ORDER BY rn_rev SEPARATOR ' | ') AS top_affiliations_by_revenue
  FROM aff_rank_rev
  WHERE rn_rev <= 3
  GROUP BY country_name, event_id
),
base_pairs AS (
  SELECT country_name, event_id FROM sub_agg
  UNION
  SELECT country_name, event_id FROM paid_agg
)
SELECT
  bp.country_name,
  e.id   AS event_id,
  COALESCE(e.name, CONCAT('Event#',e.id)) AS event_name,

  COALESCE(sa.submitter_users,0) AS submitter_users,
  COALESCE(pa.paid_users,0)      AS paid_users,
  CASE WHEN COALESCE(sa.submitter_users,0) > 0
       THEN ROUND(100.0 * COALESCE(pa.paid_users,0) / sa.submitter_users, 2)
       ELSE 0 END                AS conversion_pct,

  COALESCE(pa.registrations_count,0) AS paid_registration_rows,
  COALESCE(pa.revenue_EUR,0.00)      AS revenue_EUR,
  COALESCE(pa.avg_ticket_EUR,0.00)   AS avg_ticket_EUR,
  COALESCE(pa.min_ticket_EUR,0.00)   AS min_ticket_EUR,
  COALESCE(pa.max_ticket_EUR,0.00)   AS max_ticket_EUR,
  COALESCE(pa.stddev_ticket_EUR,0.00) AS stddev_ticket_EUR,

  ROUND(GREATEST(COALESCE(pa.avg_ticket_EUR,0) - 0.50 * COALESCE(pa.stddev_ticket_EUR,0),
                 COALESCE(pa.min_ticket_EUR,0)), 2) AS suggested_price_floor_EUR,
  ROUND(COALESCE(pa.avg_ticket_EUR,0), 2)           AS suggested_price_target_EUR,
  ROUND(COALESCE(pa.avg_ticket_EUR,0) + 0.75 * COALESCE(pa.stddev_ticket_EUR,0), 2) AS suggested_price_premium_EUR,

  COALESCE(puc.returning_paid_users,0) AS returning_paid_users,
  COALESCE(puc.new_paid_users,0)       AS new_paid_users,

  COALESCE(t3p.top_affiliations_by_paid,    '') AS top_affiliations_by_paid,
  COALESCE(t3r.top_affiliations_by_revenue, '') AS top_affiliations_by_revenue

FROM base_pairs bp
LEFT JOIN sub_agg  sa  ON sa.country_name = bp.country_name AND sa.event_id = bp.event_id
LEFT JOIN paid_agg pa  ON pa.country_name = bp.country_name AND pa.event_id = bp.event_id
LEFT JOIN paid_user_cohort puc ON puc.country_name = bp.country_name AND puc.event_id = bp.event_id
LEFT JOIN top3_paid t3p  ON t3p.country_name = bp.country_name AND t3p.event_id = bp.event_id
LEFT JOIN top3_rev  t3r  ON t3r.country_name = bp.country_name AND t3r.event_id = bp.event_id
LEFT JOIN events e ON e.id = bp.event_id
ORDER BY revenue_EUR DESC, conversion_pct DESC, bp.country_name, e.id;

-- ------------------------------------------------------------
-- TABLE 2: Country rollup (all events combined) for exec view
-- ------------------------------------------------------------
-- DROP TABLE IF EXISTS marketing_country_insights_jul2024_sep2025;
CREATE TABLE marketing_country_insights_jul2024_sep2025 AS
WITH
params AS (
  SELECT
    CAST('2024-07-01' AS DATE) AS start_date,
    CAST('2025-10-01' AS DATE) AS end_exclusive,
    'EUR' AS currency_code
),
abs_w AS (
  SELECT a.user_id, a.event_id, a.statusdate
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date AND a.statusdate < p.end_exclusive
),
user_dim AS (
  SELECT u.id AS user_id,
         COALESCE(c.name,'Unknown') AS country_name,
         COALESCE(NULLIF(TRIM(u.affiliation),''), 'Unknown') AS affiliation_name
  FROM users u
  LEFT JOIN countries c ON c.id = u.country_id
),
country_submit AS (
  SELECT ud.country_name,
         COUNT(DISTINCT aw.user_id)  AS submitter_users,
         COUNT(DISTINCT aw.event_id) AS events_submitted
  FROM abs_w aw
  JOIN user_dim ud ON ud.user_id = aw.user_id
  GROUP BY ud.country_name
),
paid_regs_raw AS (
  SELECT r.user_id, r.event_id, r.total_price
  FROM registrations r
  JOIN (SELECT DISTINCT user_id, event_id FROM abs_w) s
    ON s.user_id = r.user_id AND s.event_id = r.event_id
  JOIN params p
  WHERE r.status = 1
    AND r.total_price IS NOT NULL
    AND r.currency_type = p.currency_code
  -- Optional payment date filter:
  --  AND r.sendinvoicedate >= p.start_date
  --  AND r.sendinvoicedate <  p.end_exclusive
),
country_paid AS (
  SELECT ud.country_name,
         COUNT(*)                            AS registrations_count,
         COUNT(DISTINCT pr.user_id)          AS paid_users,
         ROUND(SUM(pr.total_price),2)        AS revenue_EUR,
         ROUND(AVG(pr.total_price),2)        AS avg_ticket_EUR,
         ROUND(MIN(pr.total_price),2)        AS min_ticket_EUR,
         ROUND(MAX(pr.total_price),2)        AS max_ticket_EUR,
         ROUND(STDDEV_POP(pr.total_price),2) AS stddev_ticket_EUR,
         COUNT(DISTINCT pr.event_id)         AS events_paid
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  GROUP BY ud.country_name
),
first_abs_ever AS (
  SELECT user_id, MIN(statusdate) AS first_abs_date
  FROM abstract_submissions
  GROUP BY user_id
),
country_paid_cohort AS (
  SELECT ud.country_name,
         SUM(CASE WHEN fa.first_abs_date <  (SELECT start_date FROM params) THEN 1 ELSE 0 END) AS returning_paid_users,
         SUM(CASE WHEN fa.first_abs_date >= (SELECT start_date FROM params) THEN 1 ELSE 0 END) AS new_paid_users
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  JOIN first_abs_ever fa ON fa.user_id = pr.user_id
  GROUP BY ud.country_name
),
country_event_stats AS (
  SELECT ud.country_name, pr.event_id,
         COUNT(DISTINCT pr.user_id) AS paid_users_event,
         ROUND(SUM(pr.total_price),2) AS revenue_event_EUR
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  GROUP BY ud.country_name, pr.event_id
),
event_names AS (
  SELECT e.id AS event_id, COALESCE(e.name, CONCAT('Event#',e.id)) AS event_name
  FROM events e
),
rank_event_paid AS (
  SELECT ces.country_name, ces.event_id, en.event_name, ces.paid_users_event, ces.revenue_event_EUR,
         ROW_NUMBER() OVER (PARTITION BY ces.country_name ORDER BY ces.paid_users_event DESC, ces.revenue_event_EUR DESC, en.event_name) AS rn
  FROM country_event_stats ces
  JOIN event_names en ON en.event_id = ces.event_id
),
top3_events_by_paid AS (
  SELECT country_name,
         GROUP_CONCAT(CONCAT(event_name,' (',paid_users_event,')') ORDER BY rn SEPARATOR ' | ') AS top_events_by_paid
  FROM rank_event_paid
  WHERE rn <= 3
  GROUP BY country_name
),
rank_event_rev AS (
  SELECT ces.country_name, ces.event_id, en.event_name, ces.paid_users_event, ces.revenue_event_EUR,
         ROW_NUMBER() OVER (PARTITION BY ces.country_name ORDER BY ces.revenue_event_EUR DESC, ces.paid_users_event DESC, en.event_name) AS rn
  FROM country_event_stats ces
  JOIN event_names en ON en.event_id = ces.event_id
),
top3_events_by_revenue AS (
  SELECT country_name,
         GROUP_CONCAT(CONCAT(event_name,' (€', FORMAT(revenue_event_EUR,0),')') ORDER BY rn SEPARATOR ' | ') AS top_events_by_revenue
  FROM rank_event_rev
  WHERE rn <= 3
  GROUP BY country_name
),
country_keys AS (
  SELECT country_name FROM country_submit
  UNION
  SELECT country_name FROM country_paid
)
SELECT
  ck.country_name,
  COALESCE(cs.submitter_users,0) AS submitter_users,
  COALESCE(cs.events_submitted,0) AS events_submitted,
  COALESCE(cp.paid_users,0)      AS paid_users,
  CASE WHEN COALESCE(cs.submitter_users,0) > 0
       THEN ROUND(100.0 * COALESCE(cp.paid_users,0) / cs.submitter_users, 2)
       ELSE 0 END                AS conversion_pct,
  COALESCE(cp.registrations_count,0) AS paid_registration_rows,
  COALESCE(cp.revenue_EUR,0.00)      AS revenue_EUR,
  COALESCE(cp.avg_ticket_EUR,0.00)   AS avg_ticket_EUR,
  COALESCE(cp.min_ticket_EUR,0.00)   AS min_ticket_EUR,
  COALESCE(cp.max_ticket_EUR,0.00)   AS max_ticket_EUR,
  COALESCE(cp.stddev_ticket_EUR,0.00) AS stddev_ticket_EUR,
  COALESCE(cp.events_paid,0)         AS events_paid,
  ROUND(GREATEST(COALESCE(cp.avg_ticket_EUR,0) - 0.50 * COALESCE(cp.stddev_ticket_EUR,0),
                 COALESCE(cp.min_ticket_EUR,0)), 2) AS suggested_price_floor_EUR,
  ROUND(COALESCE(cp.avg_ticket_EUR,0), 2)           AS suggested_price_target_EUR,
  ROUND(COALESCE(cp.avg_ticket_EUR,0) + 0.75 * COALESCE(cp.stddev_ticket_EUR,0), 2) AS suggested_price_premium_EUR,
  COALESCE(cpc.returning_paid_users,0) AS returning_paid_users,
  COALESCE(cpc.new_paid_users,0)       AS new_paid_users,
  COALESCE(tpe.top_events_by_paid, '')    AS top_events_by_paid,
  COALESCE(tpr.top_events_by_revenue, '') AS top_events_by_revenue
FROM country_keys ck
LEFT JOIN country_submit cs       ON cs.country_name = ck.country_name
LEFT JOIN country_paid cp         ON cp.country_name = ck.country_name
LEFT JOIN country_paid_cohort cpc ON cpc.country_name = ck.country_name
LEFT JOIN top3_events_by_paid tpe ON tpe.country_name = ck.country_name
LEFT JOIN top3_events_by_revenue tpr ON tpr.country_name = ck.country_name
ORDER BY revenue_EUR DESC, conversion_pct DESC, ck.country_name;

-- ----------------------------------------------------------------
-- TABLE 3: Affiliation rollup (orgs that drive revenue & where)
-- ----------------------------------------------------------------
-- DROP TABLE IF EXISTS marketing_affiliation_insights_jul2024_sep2025;
CREATE TABLE marketing_affiliation_insights_jul2024_sep2025 AS
WITH
params AS (
  SELECT
    CAST('2024-07-01' AS DATE) AS start_date,
    CAST('2025-10-01' AS DATE) AS end_exclusive,
    'EUR' AS currency_code
),
abs_w AS (
  SELECT a.user_id, a.event_id, a.statusdate
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date AND a.statusdate < p.end_exclusive
),
user_dim AS (
  SELECT u.id AS user_id,
         COALESCE(c.name,'Unknown') AS country_name,
         COALESCE(NULLIF(TRIM(u.affiliation),''), 'Unknown') AS affiliation_name
  FROM users u
  LEFT JOIN countries c ON c.id = u.country_id
),
aff_submit AS (
  SELECT ud.affiliation_name,
         COUNT(DISTINCT aw.user_id)  AS submitter_users,
         COUNT(DISTINCT aw.event_id) AS events_submitted,
         COUNT(DISTINCT ud.country_name) AS countries_represented
  FROM abs_w aw
  JOIN user_dim ud ON ud.user_id = aw.user_id
  GROUP BY ud.affiliation_name
),
paid_regs_raw AS (
  SELECT r.user_id, r.event_id, r.total_price
  FROM registrations r
  JOIN (SELECT DISTINCT user_id, event_id FROM abs_w) s
    ON s.user_id = r.user_id AND s.event_id = r.event_id
  JOIN params p
  WHERE r.status = 1
    AND r.total_price IS NOT NULL
    AND r.currency_type = p.currency_code
  -- Optional payment date filter:
  --  AND r.sendinvoicedate >= p.start_date
  --  AND r.sendinvoicedate <  p.end_exclusive
),
aff_paid AS (
  SELECT ud.affiliation_name,
         COUNT(*)                            AS registrations_count,
         COUNT(DISTINCT pr.user_id)          AS paid_users,
         ROUND(SUM(pr.total_price),2)        AS revenue_EUR,
         ROUND(AVG(pr.total_price),2)        AS avg_ticket_EUR,
         ROUND(MIN(pr.total_price),2)        AS min_ticket_EUR,
         ROUND(MAX(pr.total_price),2)        AS max_ticket_EUR,
         ROUND(STDDEV_POP(pr.total_price),2) AS stddev_ticket_EUR,
         COUNT(DISTINCT pr.event_id)         AS events_paid,
         COUNT(DISTINCT ud.country_name)     AS countries_paid
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  GROUP BY ud.affiliation_name
),
first_abs_ever AS (
  SELECT user_id, MIN(statusdate) AS first_abs_date
  FROM abstract_submissions
  GROUP BY user_id
),
aff_paid_cohort AS (
  SELECT ud.affiliation_name,
         SUM(CASE WHEN fa.first_abs_date <  (SELECT start_date FROM params) THEN 1 ELSE 0 END) AS returning_paid_users,
         SUM(CASE WHEN fa.first_abs_date >= (SELECT start_date FROM params) THEN 1 ELSE 0 END) AS new_paid_users
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  JOIN first_abs_ever fa ON fa.user_id = pr.user_id
  GROUP BY ud.affiliation_name
),
aff_country_stats AS (
  SELECT ud.affiliation_name, ud.country_name,
         COUNT(DISTINCT pr.user_id) AS paid_users_country,
         ROUND(SUM(pr.total_price),2) AS revenue_country_EUR
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  GROUP BY ud.affiliation_name, ud.country_name
),
rank_aff_country_paid AS (
  SELECT affiliation_name, country_name, paid_users_country, revenue_country_EUR,
         ROW_NUMBER() OVER (PARTITION BY affiliation_name
                            ORDER BY paid_users_country DESC, revenue_country_EUR DESC, country_name) AS rn
  FROM aff_country_stats
),
top3_countries_by_paid AS (
  SELECT affiliation_name,
         GROUP_CONCAT(CONCAT(country_name,' (',paid_users_country,')') ORDER BY rn SEPARATOR ' | ')
           AS top_countries_by_paid
  FROM rank_aff_country_paid
  WHERE rn <= 3
  GROUP BY affiliation_name
),
rank_aff_country_rev AS (
  SELECT affiliation_name, country_name, paid_users_country, revenue_country_EUR,
         ROW_NUMBER() OVER (PARTITION BY affiliation_name
                            ORDER BY revenue_country_EUR DESC, paid_users_country DESC, country_name) AS rn
  FROM aff_country_stats
),
top3_countries_by_revenue AS (
  SELECT affiliation_name,
         GROUP_CONCAT(CONCAT(country_name,' (€', FORMAT(revenue_country_EUR,0),')')
                      ORDER BY rn SEPARATOR ' | ')
           AS top_countries_by_revenue
  FROM rank_aff_country_rev
  WHERE rn <= 3
  GROUP BY affiliation_name
),
aff_event_stats AS (
  SELECT ud.affiliation_name, pr.event_id,
         COUNT(DISTINCT pr.user_id) AS paid_users_event,
         ROUND(SUM(pr.total_price),2) AS revenue_event_EUR
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  GROUP BY ud.affiliation_name, pr.event_id
),
event_names AS (
  SELECT e.id AS event_id, COALESCE(e.name, CONCAT('Event#',e.id)) AS event_name
  FROM events e
),
rank_aff_event_paid AS (
  SELECT aes.affiliation_name, aes.event_id, en.event_name, aes.paid_users_event, aes.revenue_event_EUR,
         ROW_NUMBER() OVER (PARTITION BY aes.affiliation_name
                            ORDER BY aes.paid_users_event DESC, aes.revenue_event_EUR DESC, en.event_name) AS rn
  FROM aff_event_stats aes
  JOIN event_names en ON en.event_id = aes.event_id
),
top3_events_by_paid AS (
  SELECT affiliation_name,
         GROUP_CONCAT(CONCAT(event_name,' (',paid_users_event,')') ORDER BY rn SEPARATOR ' | ')
           AS top_events_by_paid
  FROM rank_aff_event_paid
  WHERE rn <= 3
  GROUP BY affiliation_name
),
rank_aff_event_rev AS (
  SELECT aes.affiliation_name, aes.event_id, en.event_name, aes.paid_users_event, aes.revenue_event_EUR,
         ROW_NUMBER() OVER (PARTITION BY aes.affiliation_name
                            ORDER BY aes.revenue_event_EUR DESC, aes.paid_users_event DESC, en.event_name) AS rn
  FROM aff_event_stats aes
  JOIN event_names en ON en.event_id = aes.event_id
),
top3_events_by_revenue AS (
  SELECT affiliation_name,
         GROUP_CONCAT(CONCAT(event_name,' (€', FORMAT(revenue_event_EUR,0),')')
                      ORDER BY rn SEPARATOR ' | ')
           AS top_events_by_revenue
  FROM rank_aff_event_rev
  WHERE rn <= 3
  GROUP BY affiliation_name
),
aff_keys AS (
  SELECT affiliation_name FROM aff_submit
  UNION
  SELECT affiliation_name FROM aff_paid
)
SELECT
  ak.affiliation_name AS affiliation,
  COALESCE(asb.submitter_users,0) AS submitter_users,
  COALESCE(asb.events_submitted,0) AS events_submitted,
  COALESCE(asb.countries_represented,0) AS countries_represented,
  COALESCE(ap.paid_users,0)      AS paid_users,
  CASE WHEN COALESCE(asb.submitter_users,0) > 0
       THEN ROUND(100.0 * COALESCE(ap.paid_users,0) / asb.submitter_users, 2)
       ELSE 0 END                AS conversion_pct,
  COALESCE(ap.registrations_count,0) AS paid_registration_rows,
  COALESCE(ap.revenue_EUR,0.00)      AS revenue_EUR,
  COALESCE(ap.avg_ticket_EUR,0.00)   AS avg_ticket_EUR,
  COALESCE(ap.min_ticket_EUR,0.00)   AS min_ticket_EUR,
  COALESCE(ap.max_ticket_EUR,0.00)   AS max_ticket_EUR,
  COALESCE(ap.stddev_ticket_EUR,0.00) AS stddev_ticket_EUR,
  COALESCE(ap.events_paid,0)         AS events_paid,
  COALESCE(ap.countries_paid,0)      AS countries_paid,
  ROUND(GREATEST(COALESCE(ap.avg_ticket_EUR,0) - 0.50 * COALESCE(ap.stddev_ticket_EUR,0),
                 COALESCE(ap.min_ticket_EUR,0)), 2) AS suggested_price_floor_EUR,
  ROUND(COALESCE(ap.avg_ticket_EUR,0), 2)           AS suggested_price_target_EUR,
  ROUND(COALESCE(ap.avg_ticket_EUR,0) + 0.75 * COALESCE(ap.stddev_ticket_EUR,0), 2) AS suggested_price_premium_EUR,
  COALESCE(apc.returning_paid_users,0) AS returning_paid_users,
  COALESCE(apc.new_paid_users,0)       AS new_paid_users,
  COALESCE(tc.top_countries_by_paid,    '') AS top_countries_by_paid,
  COALESCE(tr.top_countries_by_revenue, '') AS top_countries_by_revenue,
  COALESCE(te.top_events_by_paid,       '') AS top_events_by_paid,
  COALESCE(tv.top_events_by_revenue,    '') AS top_events_by_revenue
FROM aff_keys ak
LEFT JOIN aff_submit asb              ON asb.affiliation_name = ak.affiliation_name
LEFT JOIN aff_paid ap                 ON ap.affiliation_name  = ak.affiliation_name
LEFT JOIN aff_paid_cohort apc         ON apc.affiliation_name = ak.affiliation_name
LEFT JOIN top3_countries_by_paid tc   ON tc.affiliation_name = ak.affiliation_name
LEFT JOIN top3_countries_by_revenue tr ON tr.affiliation_name = ak.affiliation_name
LEFT JOIN top3_events_by_paid te      ON te.affiliation_name = ak.affiliation_name
LEFT JOIN top3_events_by_revenue tv   ON tv.affiliation_name = ak.affiliation_name
ORDER BY revenue_EUR DESC, conversion_pct DESC, affiliation;




-- Rebuild safely if needed
-- DROP TABLE IF EXISTS marketing_geo_event_insights_last12m;

CREATE TABLE marketing_geo_event_insights_last12m AS
WITH
params AS (
  SELECT
    DATE_SUB(CURDATE(), INTERVAL 1 YEAR) AS start_date,
    DATE_ADD(CURDATE(), INTERVAL 1 DAY)  AS end_exclusive,
    'EUR'                                AS currency_code      -- << change if needed
),
-- All abstracts in the last 12 months (for submitter cohort)
abs_w AS (
  SELECT a.user_id, a.event_id, a.statusdate
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date
    AND a.statusdate <  p.end_exclusive
),
-- Distinct user+event submitters in-window
submitters AS (
  SELECT DISTINCT user_id, event_id FROM abs_w
),
-- Users -> Country + Affiliation
user_dim AS (
  SELECT u.id AS user_id,
         COALESCE(c.name,'Unknown') AS country_name,
         u.affiliation
  FROM users u
  LEFT JOIN countries c ON c.id = u.country_id
),
-- Submitter aggregate per Country×Event
sub_agg AS (
  SELECT ud.country_name, s.event_id,
         COUNT(DISTINCT s.user_id) AS submitter_users
  FROM submitters s
  JOIN user_dim ud ON ud.user_id = s.user_id
  GROUP BY ud.country_name, s.event_id
),
-- Paid registrations (EUR) for those submitters (match by user+event)
paid_regs_raw AS (
  SELECT r.user_id, r.event_id, r.total_price
  FROM registrations r
  JOIN submitters s
    ON s.user_id  = r.user_id
   AND s.event_id = r.event_id
  JOIN params p
  WHERE r.status = 1
    AND r.total_price IS NOT NULL
    AND r.currency_type = p.currency_code
  -- Optional: also require payment timestamp to be in-window (uncomment & set your trusted column)
  --  AND r.sendinvoicedate >= p.start_date
  --  AND r.sendinvoicedate <  p.end_exclusive
),
-- Ticket stats per Country×Event
paid_agg AS (
  SELECT ud.country_name, pr.event_id,
         COUNT(*)                                  AS registrations_count,
         COUNT(DISTINCT pr.user_id)                AS paid_users,
         ROUND(SUM(pr.total_price),2)              AS revenue_EUR,
         ROUND(AVG(pr.total_price),2)              AS avg_ticket_EUR,
         ROUND(MIN(pr.total_price),2)              AS min_ticket_EUR,
         ROUND(MAX(pr.total_price),2)              AS max_ticket_EUR,
         ROUND(STDDEV_POP(pr.total_price),2)       AS stddev_ticket_EUR
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  GROUP BY ud.country_name, pr.event_id
),
-- First-ever submission per user (for "new vs returning")
first_abs_ever AS (
  SELECT user_id, MIN(statusdate) AS first_abs_date
  FROM abstract_submissions
  GROUP BY user_id
),
paid_user_cohort AS (
  SELECT ud.country_name, pr.event_id,
         SUM(CASE WHEN fa.first_abs_date <  (SELECT start_date FROM params) THEN 1 ELSE 0 END) AS returning_paid_users,
         SUM(CASE WHEN fa.first_abs_date >= (SELECT start_date FROM params) THEN 1 ELSE 0 END) AS new_paid_users
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  JOIN first_abs_ever fa ON fa.user_id = pr.user_id
  GROUP BY ud.country_name, pr.event_id
),
-- Affiliation contributions (paid only)
aff_stats AS (
  SELECT ud.country_name, pr.event_id, COALESCE(ud.affiliation,'') AS affiliation,
         COUNT(DISTINCT pr.user_id) AS paid_users_aff,
         ROUND(SUM(pr.total_price),2) AS revenue_aff_EUR
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  GROUP BY ud.country_name, pr.event_id, COALESCE(ud.affiliation,'')
  HAVING affiliation <> ''
),
-- Top 3 affiliations by paid count
aff_rank_paid AS (
  SELECT country_name, event_id, affiliation, paid_users_aff, revenue_aff_EUR,
         ROW_NUMBER() OVER (PARTITION BY country_name, event_id ORDER BY paid_users_aff DESC, revenue_aff_EUR DESC, affiliation) AS rn_paid
  FROM aff_stats
),
top3_paid AS (
  SELECT country_name, event_id,
         GROUP_CONCAT(CONCAT(affiliation,' (',paid_users_aff,')') ORDER BY rn_paid SEPARATOR ' | ') AS top_affiliations_by_paid
  FROM aff_rank_paid
  WHERE rn_paid <= 3
  GROUP BY country_name, event_id
),
-- Top 3 affiliations by revenue
aff_rank_rev AS (
  SELECT country_name, event_id, affiliation, paid_users_aff, revenue_aff_EUR,
         ROW_NUMBER() OVER (PARTITION BY country_name, event_id ORDER BY revenue_aff_EUR DESC, paid_users_aff DESC, affiliation) AS rn_rev
  FROM aff_stats
),
top3_rev AS (
  SELECT country_name, event_id,
         GROUP_CONCAT(CONCAT(affiliation,' (€', FORMAT(revenue_aff_EUR,0),')') ORDER BY rn_rev SEPARATOR ' | ') AS top_affiliations_by_revenue
  FROM aff_rank_rev
  WHERE rn_rev <= 3
  GROUP BY country_name, event_id
),
-- Union of keys we care about (all Country×Event pairs with submitters or paid)
base_pairs AS (
  SELECT country_name, event_id FROM sub_agg
  UNION
  SELECT country_name, event_id FROM paid_agg
)
SELECT
  bp.country_name,
  e.id   AS event_id,
  COALESCE(e.name, CONCAT('Event#',e.id)) AS event_name,

  COALESCE(sa.submitter_users,0) AS submitter_users,
  COALESCE(pa.paid_users,0)      AS paid_users,
  CASE WHEN COALESCE(sa.submitter_users,0) > 0
       THEN ROUND(100.0 * COALESCE(pa.paid_users,0) / sa.submitter_users, 2)
       ELSE 0 END                AS conversion_pct,

  COALESCE(pa.registrations_count,0) AS paid_registration_rows,
  COALESCE(pa.revenue_EUR,0.00)      AS revenue_EUR,
  COALESCE(pa.avg_ticket_EUR,0.00)   AS avg_ticket_EUR,
  COALESCE(pa.min_ticket_EUR,0.00)   AS min_ticket_EUR,
  COALESCE(pa.max_ticket_EUR,0.00)   AS max_ticket_EUR,
  COALESCE(pa.stddev_ticket_EUR,0.00) AS stddev_ticket_EUR,

  -- Price suggestions (heuristics from distribution)
  ROUND(GREATEST(COALESCE(pa.avg_ticket_EUR,0) - 0.50 * COALESCE(pa.stddev_ticket_EUR,0),
                 COALESCE(pa.min_ticket_EUR,0)), 2) AS suggested_price_floor_EUR,
  ROUND(COALESCE(pa.avg_ticket_EUR,0), 2)           AS suggested_price_target_EUR,
  ROUND(COALESCE(pa.avg_ticket_EUR,0) + 0.75 * COALESCE(pa.stddev_ticket_EUR,0), 2) AS suggested_price_premium_EUR,

  COALESCE(puc.returning_paid_users,0) AS returning_paid_users,
  COALESCE(puc.new_paid_users,0)       AS new_paid_users,

  COALESCE(t3p.top_affiliations_by_paid,     '') AS top_affiliations_by_paid,
  COALESCE(t3r.top_affiliations_by_revenue,  '') AS top_affiliations_by_revenue

FROM base_pairs bp
LEFT JOIN sub_agg  sa  ON sa.country_name = bp.country_name AND sa.event_id = bp.event_id
LEFT JOIN paid_agg pa  ON pa.country_name = bp.country_name AND pa.event_id = bp.event_id
LEFT JOIN paid_user_cohort puc ON puc.country_name = bp.country_name AND puc.event_id = bp.event_id
LEFT JOIN top3_paid t3p  ON t3p.country_name = bp.country_name AND t3p.event_id = bp.event_id
LEFT JOIN top3_rev  t3r  ON t3r.country_name = bp.country_name AND t3r.event_id = bp.event_id
LEFT JOIN events e ON e.id = bp.event_id
ORDER BY revenue_EUR DESC, conversion_pct DESC, bp.country_name, e.id;























-- DROP TABLE IF EXISTS marketing_country_insights_last12m;
CREATE TABLE marketing_country_insights_last12m AS
WITH
params AS (
  SELECT
    DATE_SUB(CURDATE(), INTERVAL 1 YEAR) AS start_date,
    DATE_ADD(CURDATE(), INTERVAL 1 DAY)  AS end_exclusive,
    'EUR'                                AS currency_code
),
-- Abstracts in last 12 months
abs_w AS (
  SELECT a.user_id, a.event_id, a.statusdate
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date AND a.statusdate < p.end_exclusive
),
-- User → Country (and Affiliation for "top affiliations")
user_dim AS (
  SELECT u.id AS user_id,
         COALESCE(c.name,'Unknown') AS country_name,
         COALESCE(NULLIF(TRIM(u.affiliation),''), 'Unknown') AS affiliation_name
  FROM users u
  LEFT JOIN countries c ON c.id = u.country_id
),
-- Submitter aggregates per country
country_submit AS (
  SELECT ud.country_name,
         COUNT(DISTINCT aw.user_id)  AS submitter_users,
         COUNT(DISTINCT aw.event_id) AS events_submitted
  FROM abs_w aw
  JOIN user_dim ud ON ud.user_id = aw.user_id
  GROUP BY ud.country_name
),
-- Paid registrations (EUR) from submitter cohort
paid_regs_raw AS (
  SELECT r.user_id, r.event_id, r.total_price
  FROM registrations r
  JOIN (SELECT DISTINCT user_id, event_id FROM abs_w) s
    ON s.user_id = r.user_id AND s.event_id = r.event_id
  JOIN params p
  WHERE r.status = 1
    AND r.total_price IS NOT NULL
    AND r.currency_type = p.currency_code
  -- Optional: also require payment date in-window (uncomment & set your trusted column)
  --  AND r.sendinvoicedate >= p.start_date
  --  AND r.sendinvoicedate <  p.end_exclusive
),
-- Ticket stats per country
country_paid AS (
  SELECT ud.country_name,
         COUNT(*)                            AS registrations_count,
         COUNT(DISTINCT pr.user_id)          AS paid_users,
         ROUND(SUM(pr.total_price),2)        AS revenue_EUR,
         ROUND(AVG(pr.total_price),2)        AS avg_ticket_EUR,
         ROUND(MIN(pr.total_price),2)        AS min_ticket_EUR,
         ROUND(MAX(pr.total_price),2)        AS max_ticket_EUR,
         ROUND(STDDEV_POP(pr.total_price),2) AS stddev_ticket_EUR,
         COUNT(DISTINCT pr.event_id)         AS events_paid
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  GROUP BY ud.country_name
),
-- New vs returning paid (based on first-ever submission)
first_abs_ever AS (
  SELECT user_id, MIN(statusdate) AS first_abs_date
  FROM abstract_submissions
  GROUP BY user_id
),
country_paid_cohort AS (
  SELECT ud.country_name,
         SUM(CASE WHEN fa.first_abs_date <  (SELECT start_date FROM params) THEN 1 ELSE 0 END) AS returning_paid_users,
         SUM(CASE WHEN fa.first_abs_date >= (SELECT start_date FROM params) THEN 1 ELSE 0 END) AS new_paid_users
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  JOIN first_abs_ever fa ON fa.user_id = pr.user_id
  GROUP BY ud.country_name
),
-- Top 3 events by paid users / revenue (per country)
country_event_stats AS (
  SELECT ud.country_name, pr.event_id,
         COUNT(DISTINCT pr.user_id) AS paid_users_event,
         ROUND(SUM(pr.total_price),2) AS revenue_event_EUR
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  GROUP BY ud.country_name, pr.event_id
),
event_names AS (
  SELECT e.id AS event_id, COALESCE(e.name, CONCAT('Event#',e.id)) AS event_name
  FROM events e
),
rank_event_paid AS (
  SELECT ces.country_name, ces.event_id, en.event_name, ces.paid_users_event, ces.revenue_event_EUR,
         ROW_NUMBER() OVER (PARTITION BY ces.country_name ORDER BY ces.paid_users_event DESC, ces.revenue_event_EUR DESC, en.event_name) AS rn
  FROM country_event_stats ces
  JOIN event_names en ON en.event_id = ces.event_id
),
top3_events_by_paid AS (
  SELECT country_name,
         GROUP_CONCAT(CONCAT(event_name,' (',paid_users_event,')') ORDER BY rn SEPARATOR ' | ') AS top_events_by_paid
  FROM rank_event_paid
  WHERE rn <= 3
  GROUP BY country_name
),
rank_event_rev AS (
  SELECT ces.country_name, ces.event_id, en.event_name, ces.paid_users_event, ces.revenue_event_EUR,
         ROW_NUMBER() OVER (PARTITION BY ces.country_name ORDER BY ces.revenue_event_EUR DESC, ces.paid_users_event DESC, en.event_name) AS rn
  FROM country_event_stats ces
  JOIN event_names en ON en.event_id = ces.event_id
),
top3_events_by_rev AS (
  SELECT country_name,
         GROUP_CONCAT(CONCAT(event_name,' (€', FORMAT(revenue_event_EUR,0),')') ORDER BY rn SEPARATOR ' | ') AS top_events_by_revenue
  FROM rank_event_rev
  WHERE rn <= 3
  GROUP BY country_name
),
-- Top 3 affiliations by paid/revenue (per country) – excludes 'Unknown'
country_aff_stats AS (
  SELECT ud.country_name, ud.affiliation_name,
         COUNT(DISTINCT pr.user_id) AS paid_users_aff,
         ROUND(SUM(pr.total_price),2) AS revenue_aff_EUR
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  WHERE ud.affiliation_name <> 'Unknown'
  GROUP BY ud.country_name, ud.affiliation_name
),
rank_aff_paid AS (
  SELECT country_name, affiliation_name, paid_users_aff, revenue_aff_EUR,
         ROW_NUMBER() OVER (PARTITION BY country_name ORDER BY paid_users_aff DESC, revenue_aff_EUR DESC, affiliation_name) AS rn
  FROM country_aff_stats
),
top3_aff_by_paid AS (
  SELECT country_name,
         GROUP_CONCAT(CONCAT(affiliation_name,' (',paid_users_aff,')') ORDER BY rn SEPARATOR ' | ') AS top_affiliations_by_paid
  FROM rank_aff_paid
  WHERE rn <= 3
  GROUP BY country_name
),
rank_aff_rev AS (
  SELECT country_name, affiliation_name, paid_users_aff, revenue_aff_EUR,
         ROW_NUMBER() OVER (PARTITION BY country_name ORDER BY revenue_aff_EUR DESC, paid_users_aff DESC, affiliation_name) AS rn
  FROM country_aff_stats
),
top3_aff_by_rev AS (
  SELECT country_name,
         GROUP_CONCAT(CONCAT(affiliation_name,' (€', FORMAT(revenue_aff_EUR,0),')') ORDER BY rn SEPARATOR ' | ') AS top_affiliations_by_revenue
  FROM rank_aff_rev
  WHERE rn <= 3
  GROUP BY country_name
),
-- Union of countries present in either side
country_keys AS (
  SELECT country_name FROM country_submit
  UNION
  SELECT country_name FROM country_paid
)
SELECT
  ck.country_name,
  COALESCE(cs.submitter_users,0) AS submitter_users,
  COALESCE(cs.events_submitted,0) AS events_submitted,
  COALESCE(cp.paid_users,0)      AS paid_users,
  CASE WHEN COALESCE(cs.submitter_users,0) > 0
       THEN ROUND(100.0 * COALESCE(cp.paid_users,0) / cs.submitter_users, 2)
       ELSE 0 END                AS conversion_pct,
  COALESCE(cp.registrations_count,0) AS paid_registration_rows,
  COALESCE(cp.revenue_EUR,0.00)      AS revenue_EUR,
  COALESCE(cp.avg_ticket_EUR,0.00)   AS avg_ticket_EUR,
  COALESCE(cp.min_ticket_EUR,0.00)   AS min_ticket_EUR,
  COALESCE(cp.max_ticket_EUR,0.00)   AS max_ticket_EUR,
  COALESCE(cp.stddev_ticket_EUR,0.00) AS stddev_ticket_EUR,
  COALESCE(cp.events_paid,0)         AS events_paid,
  -- Pricing heuristics
  ROUND(GREATEST(COALESCE(cp.avg_ticket_EUR,0) - 0.50 * COALESCE(cp.stddev_ticket_EUR,0),
                 COALESCE(cp.min_ticket_EUR,0)), 2) AS suggested_price_floor_EUR,
  ROUND(COALESCE(cp.avg_ticket_EUR,0), 2)           AS suggested_price_target_EUR,
  ROUND(COALESCE(cp.avg_ticket_EUR,0) + 0.75 * COALESCE(cp.stddev_ticket_EUR,0), 2) AS suggested_price_premium_EUR,
  -- Cohorts
  COALESCE(cpc.returning_paid_users,0) AS returning_paid_users,
  COALESCE(cpc.new_paid_users,0)       AS new_paid_users,
  -- Top lists
  COALESCE(tpe.top_events_by_paid, '')      AS top_events_by_paid,
  COALESCE(tpr.top_events_by_revenue, '')   AS top_events_by_revenue,
  COALESCE(taf.top_affiliations_by_paid, '')    AS top_affiliations_by_paid,
  COALESCE(tar.top_affiliations_by_revenue, '') AS top_affiliations_by_revenue
FROM country_keys ck
LEFT JOIN country_submit cs       ON cs.country_name = ck.country_name
LEFT JOIN country_paid cp         ON cp.country_name = ck.country_name
LEFT JOIN country_paid_cohort cpc ON cpc.country_name = ck.country_name
LEFT JOIN top3_events_by_paid tpe ON tpe.country_name = ck.country_name
LEFT JOIN top3_events_by_rev  tpr ON tpr.country_name = ck.country_name
LEFT JOIN top3_aff_by_paid    taf ON taf.country_name = ck.country_name
LEFT JOIN top3_aff_by_rev     tar ON tar.country_name = ck.country_name
ORDER BY revenue_EUR DESC, conversion_pct DESC, ck.country_name;








-- Optional: clean rebuild
-- DROP TABLE IF EXISTS marketing_affiliation_insights_last12m;

CREATE TABLE marketing_affiliation_insights_last12m AS
WITH
params AS (
  SELECT
    DATE_SUB(CURDATE(), INTERVAL 1 YEAR) AS start_date,
    DATE_ADD(CURDATE(), INTERVAL 1 DAY)  AS end_exclusive,
    'EUR'                                AS currency_code
),
abs_w AS (
  SELECT a.user_id, a.event_id, a.statusdate
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date AND a.statusdate < p.end_exclusive
),
user_dim AS (
  SELECT u.id AS user_id,
         COALESCE(c.name,'Unknown') AS country_name,
         COALESCE(NULLIF(TRIM(u.affiliation),''), 'Unknown') AS affiliation_name
  FROM users u
  LEFT JOIN countries c ON c.id = u.country_id
),
aff_submit AS (
  SELECT ud.affiliation_name,
         COUNT(DISTINCT aw.user_id)  AS submitter_users,
         COUNT(DISTINCT aw.event_id) AS events_submitted,
         COUNT(DISTINCT ud.country_name) AS countries_represented
  FROM abs_w aw
  JOIN user_dim ud ON ud.user_id = aw.user_id
  GROUP BY ud.affiliation_name
),
paid_regs_raw AS (
  SELECT r.user_id, r.event_id, r.total_price
  FROM registrations r
  JOIN (SELECT DISTINCT user_id, event_id FROM abs_w) s
    ON s.user_id = r.user_id AND s.event_id = r.event_id
  JOIN params p
  WHERE r.status = 1
    AND r.total_price IS NOT NULL
    AND r.currency_type = p.currency_code
),
aff_paid AS (
  SELECT ud.affiliation_name,
         COUNT(*)                            AS registrations_count,
         COUNT(DISTINCT pr.user_id)          AS paid_users,
         ROUND(SUM(pr.total_price),2)        AS revenue_EUR,
         ROUND(AVG(pr.total_price),2)        AS avg_ticket_EUR,
         ROUND(MIN(pr.total_price),2)        AS min_ticket_EUR,
         ROUND(MAX(pr.total_price),2)        AS max_ticket_EUR,
         ROUND(STDDEV_POP(pr.total_price),2) AS stddev_ticket_EUR,
         COUNT(DISTINCT pr.event_id)         AS events_paid,
         COUNT(DISTINCT ud.country_name)     AS countries_paid
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  GROUP BY ud.affiliation_name
),
first_abs_ever AS (
  SELECT user_id, MIN(statusdate) AS first_abs_date
  FROM abstract_submissions
  GROUP BY user_id
),
aff_paid_cohort AS (
  SELECT ud.affiliation_name,
         SUM(CASE WHEN fa.first_abs_date <  (SELECT start_date FROM params) THEN 1 ELSE 0 END) AS returning_paid_users,
         SUM(CASE WHEN fa.first_abs_date >= (SELECT start_date FROM params) THEN 1 ELSE 0 END) AS new_paid_users
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  JOIN first_abs_ever fa ON fa.user_id = pr.user_id
  GROUP BY ud.affiliation_name
),
aff_country_stats AS (
  SELECT ud.affiliation_name, ud.country_name,
         COUNT(DISTINCT pr.user_id) AS paid_users_country,
         ROUND(SUM(pr.total_price),2) AS revenue_country_EUR
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  GROUP BY ud.affiliation_name, ud.country_name
),
rank_aff_country_paid AS (
  SELECT affiliation_name, country_name, paid_users_country, revenue_country_EUR,
         ROW_NUMBER() OVER (PARTITION BY affiliation_name ORDER BY paid_users_country DESC, revenue_country_EUR DESC, country_name) AS rn
  FROM aff_country_stats
),
top3_countries_by_paid AS (
  SELECT affiliation_name,
         GROUP_CONCAT(CONCAT(country_name,' (',paid_users_country,')') ORDER BY rn SEPARATOR ' | ') AS top_countries_by_paid
  FROM rank_aff_country_paid
  WHERE rn <= 3
  GROUP BY affiliation_name
),
rank_aff_country_rev AS (
  SELECT affiliation_name, country_name, paid_users_country, revenue_country_EUR,
         ROW_NUMBER() OVER (PARTITION BY affiliation_name ORDER BY revenue_country_EUR DESC, paid_users_country DESC, country_name) AS rn
  FROM aff_country_stats
),
top3_countries_by_revenue AS (  -- 👈 exact name used below
  SELECT affiliation_name,
         GROUP_CONCAT(CONCAT(country_name,' (€', FORMAT(revenue_country_EUR,0),')') ORDER BY rn SEPARATOR ' | ') AS top_countries_by_revenue
  FROM rank_aff_country_rev
  WHERE rn <= 3
  GROUP BY affiliation_name
),
aff_event_stats AS (
  SELECT ud.affiliation_name, pr.event_id,
         COUNT(DISTINCT pr.user_id) AS paid_users_event,
         ROUND(SUM(pr.total_price),2) AS revenue_event_EUR
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  GROUP BY ud.affiliation_name, pr.event_id
),
event_names AS (
  SELECT e.id AS event_id, COALESCE(e.name, CONCAT('Event#',e.id)) AS event_name
  FROM events e
),
rank_aff_event_paid AS (
  SELECT aes.affiliation_name, aes.event_id, en.event_name, aes.paid_users_event, aes.revenue_event_EUR,
         ROW_NUMBER() OVER (PARTITION BY aes.affiliation_name ORDER BY aes.paid_users_event DESC, aes.revenue_event_EUR DESC, en.event_name) AS rn
  FROM aff_event_stats aes
  JOIN event_names en ON en.event_id = aes.event_id
),
top3_events_by_paid AS (
  SELECT affiliation_name,
         GROUP_CONCAT(CONCAT(event_name,' (',paid_users_event,')') ORDER BY rn SEPARATOR ' | ') AS top_events_by_paid
  FROM rank_aff_event_paid
  WHERE rn <= 3
  GROUP BY affiliation_name
),
rank_aff_event_rev AS (
  SELECT aes.affiliation_name, aes.event_id, en.event_name, aes.paid_users_event, aes.revenue_event_EUR,
         ROW_NUMBER() OVER (PARTITION BY aes.affiliation_name ORDER BY aes.revenue_event_EUR DESC, aes.paid_users_event DESC, en.event_name) AS rn
  FROM aff_event_stats aes
  JOIN event_names en ON en.event_id = aes.event_id
),
top3_events_by_revenue AS (
  SELECT affiliation_name,
         GROUP_CONCAT(CONCAT(event_name,' (€', FORMAT(revenue_event_EUR,0),')') ORDER BY rn SEPARATOR ' | ') AS top_events_by_revenue
  FROM rank_aff_event_rev
  WHERE rn <= 3
  GROUP BY affiliation_name
),
aff_keys AS (
  SELECT affiliation_name FROM aff_submit
  UNION
  SELECT affiliation_name FROM aff_paid
)
SELECT
  ak.affiliation_name AS affiliation,
  COALESCE(asb.submitter_users,0) AS submitter_users,
  COALESCE(asb.events_submitted,0) AS events_submitted,
  COALESCE(asb.countries_represented,0) AS countries_represented,
  COALESCE(ap.paid_users,0)      AS paid_users,
  CASE WHEN COALESCE(asb.submitter_users,0) > 0
       THEN ROUND(100.0 * COALESCE(ap.paid_users,0) / asb.submitter_users, 2)
       ELSE 0 END                AS conversion_pct,
  COALESCE(ap.registrations_count,0) AS paid_registration_rows,
  COALESCE(ap.revenue_EUR,0.00)      AS revenue_EUR,
  COALESCE(ap.avg_ticket_EUR,0.00)   AS avg_ticket_EUR,
  COALESCE(ap.min_ticket_EUR,0.00)   AS min_ticket_EUR,
  COALESCE(ap.max_ticket_EUR,0.00)   AS max_ticket_EUR,
  COALESCE(ap.stddev_ticket_EUR,0.00) AS stddev_ticket_EUR,
  COALESCE(ap.events_paid,0)         AS events_paid,
  COALESCE(ap.countries_paid,0)      AS countries_paid,
  -- Pricing heuristics
  ROUND(GREATEST(COALESCE(ap.avg_ticket_EUR,0) - 0.50 * COALESCE(ap.stddev_ticket_EUR,0),
                 COALESCE(ap.min_ticket_EUR,0)), 2) AS suggested_price_floor_EUR,
  ROUND(COALESCE(ap.avg_ticket_EUR,0), 2)           AS suggested_price_target_EUR,
  ROUND(COALESCE(ap.avg_ticket_EUR,0) + 0.75 * COALESCE(ap.stddev_ticket_EUR,0), 2) AS suggested_price_premium_EUR,
  -- Cohorts
  COALESCE(apc.returning_paid_users,0) AS returning_paid_users,
  COALESCE(apc.new_paid_users,0)       AS new_paid_users,
  -- Top lists
  COALESCE(tc.top_countries_by_paid,    '') AS top_countries_by_paid,
  COALESCE(tr.top_countries_by_revenue, '') AS top_countries_by_revenue,
  COALESCE(te.top_events_by_paid,       '') AS top_events_by_paid,
  COALESCE(tv.top_events_by_revenue,    '') AS top_events_by_revenue
FROM aff_keys ak
LEFT JOIN aff_submit asb              ON asb.affiliation_name = ak.affiliation_name
LEFT JOIN aff_paid ap                 ON ap.affiliation_name  = ak.affiliation_name
LEFT JOIN aff_paid_cohort apc         ON apc.affiliation_name = ak.affiliation_name
LEFT JOIN top3_countries_by_paid tc   ON tc.affiliation_name = ak.affiliation_name
LEFT JOIN top3_countries_by_revenue tr ON tr.affiliation_name = ak.affiliation_name
LEFT JOIN top3_events_by_paid te      ON te.affiliation_name = ak.affiliation_name
LEFT JOIN top3_events_by_revenue tv   ON tv.affiliation_name = ak.affiliation_name
ORDER BY revenue_EUR DESC, conversion_pct DESC, affiliation;





-- Rebuild safely if needed
-- DROP TABLE IF EXISTS marketing_geo_event_insights_last12m;

CREATE TABLE marketing_geo_event_insights_last12m AS
WITH
params AS (
  SELECT
    DATE_SUB(CURDATE(), INTERVAL 1 YEAR) AS start_date,
    DATE_ADD(CURDATE(), INTERVAL 1 DAY)  AS end_exclusive,
    'EUR'                                AS currency_code      -- << change if needed
),
-- All abstracts in the last 12 months (for submitter cohort)
abs_w AS (
  SELECT a.user_id, a.event_id, a.statusdate
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date
    AND a.statusdate <  p.end_exclusive
),
-- Distinct user+event submitters in-window
submitters AS (
  SELECT DISTINCT user_id, event_id FROM abs_w
),
-- Users -> Country + Affiliation
user_dim AS (
  SELECT u.id AS user_id,
         COALESCE(c.name,'Unknown') AS country_name,
         u.affiliation
  FROM users u
  LEFT JOIN countries c ON c.id = u.country_id
),
-- Submitter aggregate per Country×Event
sub_agg AS (
  SELECT ud.country_name, s.event_id,
         COUNT(DISTINCT s.user_id) AS submitter_users
  FROM submitters s
  JOIN user_dim ud ON ud.user_id = s.user_id
  GROUP BY ud.country_name, s.event_id
),
-- Paid registrations (EUR) for those submitters (match by user+event)
paid_regs_raw AS (
  SELECT r.user_id, r.event_id, r.total_price
  FROM registrations r
  JOIN submitters s
    ON s.user_id  = r.user_id
   AND s.event_id = r.event_id
  JOIN params p
  WHERE r.status = 1
    AND r.total_price IS NOT NULL
    AND r.currency_type = p.currency_code
  -- Optional: also require payment timestamp to be in-window (uncomment & set your trusted column)
  --  AND r.sendinvoicedate >= p.start_date
  --  AND r.sendinvoicedate <  p.end_exclusive
),
-- Ticket stats per Country×Event
paid_agg AS (
  SELECT ud.country_name, pr.event_id,
         COUNT(*)                                  AS registrations_count,
         COUNT(DISTINCT pr.user_id)                AS paid_users,
         ROUND(SUM(pr.total_price),2)              AS revenue_EUR,
         ROUND(AVG(pr.total_price),2)              AS avg_ticket_EUR,
         ROUND(MIN(pr.total_price),2)              AS min_ticket_EUR,
         ROUND(MAX(pr.total_price),2)              AS max_ticket_EUR,
         ROUND(STDDEV_POP(pr.total_price),2)       AS stddev_ticket_EUR
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  GROUP BY ud.country_name, pr.event_id
),
-- First-ever submission per user (for "new vs returning")
first_abs_ever AS (
  SELECT user_id, MIN(statusdate) AS first_abs_date
  FROM abstract_submissions
  GROUP BY user_id
),
paid_user_cohort AS (
  SELECT ud.country_name, pr.event_id,
         SUM(CASE WHEN fa.first_abs_date <  (SELECT start_date FROM params) THEN 1 ELSE 0 END) AS returning_paid_users,
         SUM(CASE WHEN fa.first_abs_date >= (SELECT start_date FROM params) THEN 1 ELSE 0 END) AS new_paid_users
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  JOIN first_abs_ever fa ON fa.user_id = pr.user_id
  GROUP BY ud.country_name, pr.event_id
),
-- Affiliation contributions (paid only)
aff_stats AS (
  SELECT ud.country_name, pr.event_id, COALESCE(ud.affiliation,'') AS affiliation,
         COUNT(DISTINCT pr.user_id) AS paid_users_aff,
         ROUND(SUM(pr.total_price),2) AS revenue_aff_EUR
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  GROUP BY ud.country_name, pr.event_id, COALESCE(ud.affiliation,'')
  HAVING affiliation <> ''
),
-- Top 3 affiliations by paid count
aff_rank_paid AS (
  SELECT country_name, event_id, affiliation, paid_users_aff, revenue_aff_EUR,
         ROW_NUMBER() OVER (PARTITION BY country_name, event_id ORDER BY paid_users_aff DESC, revenue_aff_EUR DESC, affiliation) AS rn_paid
  FROM aff_stats
),
top3_paid AS (
  SELECT country_name, event_id,
         GROUP_CONCAT(CONCAT(affiliation,' (',paid_users_aff,')') ORDER BY rn_paid SEPARATOR ' | ') AS top_affiliations_by_paid
  FROM aff_rank_paid
  WHERE rn_paid <= 3
  GROUP BY country_name, event_id
),
-- Top 3 affiliations by revenue
aff_rank_rev AS (
  SELECT country_name, event_id, affiliation, paid_users_aff, revenue_aff_EUR,
         ROW_NUMBER() OVER (PARTITION BY country_name, event_id ORDER BY revenue_aff_EUR DESC, paid_users_aff DESC, affiliation) AS rn_rev
  FROM aff_stats
),
top3_rev AS (
  SELECT country_name, event_id,
         GROUP_CONCAT(CONCAT(affiliation,' (€', FORMAT(revenue_aff_EUR,0),')') ORDER BY rn_rev SEPARATOR ' | ') AS top_affiliations_by_revenue
  FROM aff_rank_rev
  WHERE rn_rev <= 3
  GROUP BY country_name, event_id
),
-- Union of keys we care about (all Country×Event pairs with submitters or paid)
base_pairs AS (
  SELECT country_name, event_id FROM sub_agg
  UNION
  SELECT country_name, event_id FROM paid_agg
)
SELECT
  bp.country_name,
  e.id   AS event_id,
  COALESCE(e.name, CONCAT('Event#',e.id)) AS event_name,

  COALESCE(sa.submitter_users,0) AS submitter_users,
  COALESCE(pa.paid_users,0)      AS paid_users,
  CASE WHEN COALESCE(sa.submitter_users,0) > 0
       THEN ROUND(100.0 * COALESCE(pa.paid_users,0) / sa.submitter_users, 2)
       ELSE 0 END                AS conversion_pct,

  COALESCE(pa.registrations_count,0) AS paid_registration_rows,
  COALESCE(pa.revenue_EUR,0.00)      AS revenue_EUR,
  COALESCE(pa.avg_ticket_EUR,0.00)   AS avg_ticket_EUR,
  COALESCE(pa.min_ticket_EUR,0.00)   AS min_ticket_EUR,
  COALESCE(pa.max_ticket_EUR,0.00)   AS max_ticket_EUR,
  COALESCE(pa.stddev_ticket_EUR,0.00) AS stddev_ticket_EUR,

  -- Price suggestions (heuristics from distribution)
  ROUND(GREATEST(COALESCE(pa.avg_ticket_EUR,0) - 0.50 * COALESCE(pa.stddev_ticket_EUR,0),
                 COALESCE(pa.min_ticket_EUR,0)), 2) AS suggested_price_floor_EUR,
  ROUND(COALESCE(pa.avg_ticket_EUR,0), 2)           AS suggested_price_target_EUR,
  ROUND(COALESCE(pa.avg_ticket_EUR,0) + 0.75 * COALESCE(pa.stddev_ticket_EUR,0), 2) AS suggested_price_premium_EUR,

  COALESCE(puc.returning_paid_users,0) AS returning_paid_users,
  COALESCE(puc.new_paid_users,0)       AS new_paid_users,

  COALESCE(t3p.top_affiliations_by_paid,     '') AS top_affiliations_by_paid,
  COALESCE(t3r.top_affiliations_by_revenue,  '') AS top_affiliations_by_revenue

FROM base_pairs bp
LEFT JOIN sub_agg  sa  ON sa.country_name = bp.country_name AND sa.event_id = bp.event_id
LEFT JOIN paid_agg pa  ON pa.country_name = bp.country_name AND pa.event_id = bp.event_id
LEFT JOIN paid_user_cohort puc ON puc.country_name = bp.country_name AND puc.event_id = bp.event_id
LEFT JOIN top3_paid t3p  ON t3p.country_name = bp.country_name AND t3p.event_id = bp.event_id
LEFT JOIN top3_rev  t3r  ON t3r.country_name = bp.country_name AND t3r.event_id = bp.event_id
LEFT JOIN events e ON e.id = bp.event_id
ORDER BY revenue_EUR DESC, conversion_pct DESC, bp.country_name, e.id;























-- DROP TABLE IF EXISTS marketing_country_insights_last12m;
CREATE TABLE marketing_country_insights_last12m AS
WITH
params AS (
  SELECT
    DATE_SUB(CURDATE(), INTERVAL 1 YEAR) AS start_date,
    DATE_ADD(CURDATE(), INTERVAL 1 DAY)  AS end_exclusive,
    'EUR'                                AS currency_code
),
-- Abstracts in last 12 months
abs_w AS (
  SELECT a.user_id, a.event_id, a.statusdate
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date AND a.statusdate < p.end_exclusive
),
-- User → Country (and Affiliation for "top affiliations")
user_dim AS (
  SELECT u.id AS user_id,
         COALESCE(c.name,'Unknown') AS country_name,
         COALESCE(NULLIF(TRIM(u.affiliation),''), 'Unknown') AS affiliation_name
  FROM users u
  LEFT JOIN countries c ON c.id = u.country_id
),
-- Submitter aggregates per country
country_submit AS (
  SELECT ud.country_name,
         COUNT(DISTINCT aw.user_id)  AS submitter_users,
         COUNT(DISTINCT aw.event_id) AS events_submitted
  FROM abs_w aw
  JOIN user_dim ud ON ud.user_id = aw.user_id
  GROUP BY ud.country_name
),
-- Paid registrations (EUR) from submitter cohort
paid_regs_raw AS (
  SELECT r.user_id, r.event_id, r.total_price
  FROM registrations r
  JOIN (SELECT DISTINCT user_id, event_id FROM abs_w) s
    ON s.user_id = r.user_id AND s.event_id = r.event_id
  JOIN params p
  WHERE r.status = 1
    AND r.total_price IS NOT NULL
    AND r.currency_type = p.currency_code
  -- Optional: also require payment date in-window (uncomment & set your trusted column)
  --  AND r.sendinvoicedate >= p.start_date
  --  AND r.sendinvoicedate <  p.end_exclusive
),
-- Ticket stats per country
country_paid AS (
  SELECT ud.country_name,
         COUNT(*)                            AS registrations_count,
         COUNT(DISTINCT pr.user_id)          AS paid_users,
         ROUND(SUM(pr.total_price),2)        AS revenue_EUR,
         ROUND(AVG(pr.total_price),2)        AS avg_ticket_EUR,
         ROUND(MIN(pr.total_price),2)        AS min_ticket_EUR,
         ROUND(MAX(pr.total_price),2)        AS max_ticket_EUR,
         ROUND(STDDEV_POP(pr.total_price),2) AS stddev_ticket_EUR,
         COUNT(DISTINCT pr.event_id)         AS events_paid
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  GROUP BY ud.country_name
),
-- New vs returning paid (based on first-ever submission)
first_abs_ever AS (
  SELECT user_id, MIN(statusdate) AS first_abs_date
  FROM abstract_submissions
  GROUP BY user_id
),
country_paid_cohort AS (
  SELECT ud.country_name,
         SUM(CASE WHEN fa.first_abs_date <  (SELECT start_date FROM params) THEN 1 ELSE 0 END) AS returning_paid_users,
         SUM(CASE WHEN fa.first_abs_date >= (SELECT start_date FROM params) THEN 1 ELSE 0 END) AS new_paid_users
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  JOIN first_abs_ever fa ON fa.user_id = pr.user_id
  GROUP BY ud.country_name
),
-- Top 3 events by paid users / revenue (per country)
country_event_stats AS (
  SELECT ud.country_name, pr.event_id,
         COUNT(DISTINCT pr.user_id) AS paid_users_event,
         ROUND(SUM(pr.total_price),2) AS revenue_event_EUR
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  GROUP BY ud.country_name, pr.event_id
),
event_names AS (
  SELECT e.id AS event_id, COALESCE(e.name, CONCAT('Event#',e.id)) AS event_name
  FROM events e
),
rank_event_paid AS (
  SELECT ces.country_name, ces.event_id, en.event_name, ces.paid_users_event, ces.revenue_event_EUR,
         ROW_NUMBER() OVER (PARTITION BY ces.country_name ORDER BY ces.paid_users_event DESC, ces.revenue_event_EUR DESC, en.event_name) AS rn
  FROM country_event_stats ces
  JOIN event_names en ON en.event_id = ces.event_id
),
top3_events_by_paid AS (
  SELECT country_name,
         GROUP_CONCAT(CONCAT(event_name,' (',paid_users_event,')') ORDER BY rn SEPARATOR ' | ') AS top_events_by_paid
  FROM rank_event_paid
  WHERE rn <= 3
  GROUP BY country_name
),
rank_event_rev AS (
  SELECT ces.country_name, ces.event_id, en.event_name, ces.paid_users_event, ces.revenue_event_EUR,
         ROW_NUMBER() OVER (PARTITION BY ces.country_name ORDER BY ces.revenue_event_EUR DESC, ces.paid_users_event DESC, en.event_name) AS rn
  FROM country_event_stats ces
  JOIN event_names en ON en.event_id = ces.event_id
),
top3_events_by_rev AS (
  SELECT country_name,
         GROUP_CONCAT(CONCAT(event_name,' (€', FORMAT(revenue_event_EUR,0),')') ORDER BY rn SEPARATOR ' | ') AS top_events_by_revenue
  FROM rank_event_rev
  WHERE rn <= 3
  GROUP BY country_name
),
-- Top 3 affiliations by paid/revenue (per country) – excludes 'Unknown'
country_aff_stats AS (
  SELECT ud.country_name, ud.affiliation_name,
         COUNT(DISTINCT pr.user_id) AS paid_users_aff,
         ROUND(SUM(pr.total_price),2) AS revenue_aff_EUR
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  WHERE ud.affiliation_name <> 'Unknown'
  GROUP BY ud.country_name, ud.affiliation_name
),
rank_aff_paid AS (
  SELECT country_name, affiliation_name, paid_users_aff, revenue_aff_EUR,
         ROW_NUMBER() OVER (PARTITION BY country_name ORDER BY paid_users_aff DESC, revenue_aff_EUR DESC, affiliation_name) AS rn
  FROM country_aff_stats
),
top3_aff_by_paid AS (
  SELECT country_name,
         GROUP_CONCAT(CONCAT(affiliation_name,' (',paid_users_aff,')') ORDER BY rn SEPARATOR ' | ') AS top_affiliations_by_paid
  FROM rank_aff_paid
  WHERE rn <= 3
  GROUP BY country_name
),
rank_aff_rev AS (
  SELECT country_name, affiliation_name, paid_users_aff, revenue_aff_EUR,
         ROW_NUMBER() OVER (PARTITION BY country_name ORDER BY revenue_aff_EUR DESC, paid_users_aff DESC, affiliation_name) AS rn
  FROM country_aff_stats
),
top3_aff_by_rev AS (
  SELECT country_name,
         GROUP_CONCAT(CONCAT(affiliation_name,' (€', FORMAT(revenue_aff_EUR,0),')') ORDER BY rn SEPARATOR ' | ') AS top_affiliations_by_revenue
  FROM rank_aff_rev
  WHERE rn <= 3
  GROUP BY country_name
),
-- Union of countries present in either side
country_keys AS (
  SELECT country_name FROM country_submit
  UNION
  SELECT country_name FROM country_paid
)
SELECT
  ck.country_name,
  COALESCE(cs.submitter_users,0) AS submitter_users,
  COALESCE(cs.events_submitted,0) AS events_submitted,
  COALESCE(cp.paid_users,0)      AS paid_users,
  CASE WHEN COALESCE(cs.submitter_users,0) > 0
       THEN ROUND(100.0 * COALESCE(cp.paid_users,0) / cs.submitter_users, 2)
       ELSE 0 END                AS conversion_pct,
  COALESCE(cp.registrations_count,0) AS paid_registration_rows,
  COALESCE(cp.revenue_EUR,0.00)      AS revenue_EUR,
  COALESCE(cp.avg_ticket_EUR,0.00)   AS avg_ticket_EUR,
  COALESCE(cp.min_ticket_EUR,0.00)   AS min_ticket_EUR,
  COALESCE(cp.max_ticket_EUR,0.00)   AS max_ticket_EUR,
  COALESCE(cp.stddev_ticket_EUR,0.00) AS stddev_ticket_EUR,
  COALESCE(cp.events_paid,0)         AS events_paid,
  -- Pricing heuristics
  ROUND(GREATEST(COALESCE(cp.avg_ticket_EUR,0) - 0.50 * COALESCE(cp.stddev_ticket_EUR,0),
                 COALESCE(cp.min_ticket_EUR,0)), 2) AS suggested_price_floor_EUR,
  ROUND(COALESCE(cp.avg_ticket_EUR,0), 2)           AS suggested_price_target_EUR,
  ROUND(COALESCE(cp.avg_ticket_EUR,0) + 0.75 * COALESCE(cp.stddev_ticket_EUR,0), 2) AS suggested_price_premium_EUR,
  -- Cohorts
  COALESCE(cpc.returning_paid_users,0) AS returning_paid_users,
  COALESCE(cpc.new_paid_users,0)       AS new_paid_users,
  -- Top lists
  COALESCE(tpe.top_events_by_paid, '')      AS top_events_by_paid,
  COALESCE(tpr.top_events_by_revenue, '')   AS top_events_by_revenue,
  COALESCE(taf.top_affiliations_by_paid, '')    AS top_affiliations_by_paid,
  COALESCE(tar.top_affiliations_by_revenue, '') AS top_affiliations_by_revenue
FROM country_keys ck
LEFT JOIN country_submit cs       ON cs.country_name = ck.country_name
LEFT JOIN country_paid cp         ON cp.country_name = ck.country_name
LEFT JOIN country_paid_cohort cpc ON cpc.country_name = ck.country_name
LEFT JOIN top3_events_by_paid tpe ON tpe.country_name = ck.country_name
LEFT JOIN top3_events_by_rev  tpr ON tpr.country_name = ck.country_name
LEFT JOIN top3_aff_by_paid    taf ON taf.country_name = ck.country_name
LEFT JOIN top3_aff_by_rev     tar ON tar.country_name = ck.country_name
ORDER BY revenue_EUR DESC, conversion_pct DESC, ck.country_name;








-- Optional: clean rebuild
-- DROP TABLE IF EXISTS marketing_affiliation_insights_last12m;

CREATE TABLE marketing_affiliation_insights_last12m AS
WITH
params AS (
  SELECT
    DATE_SUB(CURDATE(), INTERVAL 1 YEAR) AS start_date,
    DATE_ADD(CURDATE(), INTERVAL 1 DAY)  AS end_exclusive,
    'EUR'                                AS currency_code
),
abs_w AS (
  SELECT a.user_id, a.event_id, a.statusdate
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date AND a.statusdate < p.end_exclusive
),
user_dim AS (
  SELECT u.id AS user_id,
         COALESCE(c.name,'Unknown') AS country_name,
         COALESCE(NULLIF(TRIM(u.affiliation),''), 'Unknown') AS affiliation_name
  FROM users u
  LEFT JOIN countries c ON c.id = u.country_id
),
aff_submit AS (
  SELECT ud.affiliation_name,
         COUNT(DISTINCT aw.user_id)  AS submitter_users,
         COUNT(DISTINCT aw.event_id) AS events_submitted,
         COUNT(DISTINCT ud.country_name) AS countries_represented
  FROM abs_w aw
  JOIN user_dim ud ON ud.user_id = aw.user_id
  GROUP BY ud.affiliation_name
),
paid_regs_raw AS (
  SELECT r.user_id, r.event_id, r.total_price
  FROM registrations r
  JOIN (SELECT DISTINCT user_id, event_id FROM abs_w) s
    ON s.user_id = r.user_id AND s.event_id = r.event_id
  JOIN params p
  WHERE r.status = 1
    AND r.total_price IS NOT NULL
    AND r.currency_type = p.currency_code
),
aff_paid AS (
  SELECT ud.affiliation_name,
         COUNT(*)                            AS registrations_count,
         COUNT(DISTINCT pr.user_id)          AS paid_users,
         ROUND(SUM(pr.total_price),2)        AS revenue_EUR,
         ROUND(AVG(pr.total_price),2)        AS avg_ticket_EUR,
         ROUND(MIN(pr.total_price),2)        AS min_ticket_EUR,
         ROUND(MAX(pr.total_price),2)        AS max_ticket_EUR,
         ROUND(STDDEV_POP(pr.total_price),2) AS stddev_ticket_EUR,
         COUNT(DISTINCT pr.event_id)         AS events_paid,
         COUNT(DISTINCT ud.country_name)     AS countries_paid
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  GROUP BY ud.affiliation_name
),
first_abs_ever AS (
  SELECT user_id, MIN(statusdate) AS first_abs_date
  FROM abstract_submissions
  GROUP BY user_id
),
aff_paid_cohort AS (
  SELECT ud.affiliation_name,
         SUM(CASE WHEN fa.first_abs_date <  (SELECT start_date FROM params) THEN 1 ELSE 0 END) AS returning_paid_users,
         SUM(CASE WHEN fa.first_abs_date >= (SELECT start_date FROM params) THEN 1 ELSE 0 END) AS new_paid_users
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  JOIN first_abs_ever fa ON fa.user_id = pr.user_id
  GROUP BY ud.affiliation_name
),
aff_country_stats AS (
  SELECT ud.affiliation_name, ud.country_name,
         COUNT(DISTINCT pr.user_id) AS paid_users_country,
         ROUND(SUM(pr.total_price),2) AS revenue_country_EUR
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  GROUP BY ud.affiliation_name, ud.country_name
),
rank_aff_country_paid AS (
  SELECT affiliation_name, country_name, paid_users_country, revenue_country_EUR,
         ROW_NUMBER() OVER (PARTITION BY affiliation_name ORDER BY paid_users_country DESC, revenue_country_EUR DESC, country_name) AS rn
  FROM aff_country_stats
),
top3_countries_by_paid AS (
  SELECT affiliation_name,
         GROUP_CONCAT(CONCAT(country_name,' (',paid_users_country,')') ORDER BY rn SEPARATOR ' | ') AS top_countries_by_paid
  FROM rank_aff_country_paid
  WHERE rn <= 3
  GROUP BY affiliation_name
),
rank_aff_country_rev AS (
  SELECT affiliation_name, country_name, paid_users_country, revenue_country_EUR,
         ROW_NUMBER() OVER (PARTITION BY affiliation_name ORDER BY revenue_country_EUR DESC, paid_users_country DESC, country_name) AS rn
  FROM aff_country_stats
),
top3_countries_by_revenue AS (  -- 👈 exact name used below
  SELECT affiliation_name,
         GROUP_CONCAT(CONCAT(country_name,' (€', FORMAT(revenue_country_EUR,0),')') ORDER BY rn SEPARATOR ' | ') AS top_countries_by_revenue
  FROM rank_aff_country_rev
  WHERE rn <= 3
  GROUP BY affiliation_name
),
aff_event_stats AS (
  SELECT ud.affiliation_name, pr.event_id,
         COUNT(DISTINCT pr.user_id) AS paid_users_event,
         ROUND(SUM(pr.total_price),2) AS revenue_event_EUR
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  GROUP BY ud.affiliation_name, pr.event_id
),
event_names AS (
  SELECT e.id AS event_id, COALESCE(e.name, CONCAT('Event#',e.id)) AS event_name
  FROM events e
),
rank_aff_event_paid AS (
  SELECT aes.affiliation_name, aes.event_id, en.event_name, aes.paid_users_event, aes.revenue_event_EUR,
         ROW_NUMBER() OVER (PARTITION BY aes.affiliation_name ORDER BY aes.paid_users_event DESC, aes.revenue_event_EUR DESC, en.event_name) AS rn
  FROM aff_event_stats aes
  JOIN event_names en ON en.event_id = aes.event_id
),
top3_events_by_paid AS (
  SELECT affiliation_name,
         GROUP_CONCAT(CONCAT(event_name,' (',paid_users_event,')') ORDER BY rn SEPARATOR ' | ') AS top_events_by_paid
  FROM rank_aff_event_paid
  WHERE rn <= 3
  GROUP BY affiliation_name
),
rank_aff_event_rev AS (
  SELECT aes.affiliation_name, aes.event_id, en.event_name, aes.paid_users_event, aes.revenue_event_EUR,
         ROW_NUMBER() OVER (PARTITION BY aes.affiliation_name ORDER BY aes.revenue_event_EUR DESC, aes.paid_users_event DESC, en.event_name) AS rn
  FROM aff_event_stats aes
  JOIN event_names en ON en.event_id = aes.event_id
),
top3_events_by_revenue AS (
  SELECT affiliation_name,
         GROUP_CONCAT(CONCAT(event_name,' (€', FORMAT(revenue_event_EUR,0),')') ORDER BY rn SEPARATOR ' | ') AS top_events_by_revenue
  FROM rank_aff_event_rev
  WHERE rn <= 3
  GROUP BY affiliation_name
),
aff_keys AS (
  SELECT affiliation_name FROM aff_submit
  UNION
  SELECT affiliation_name FROM aff_paid
)
SELECT
  ak.affiliation_name AS affiliation,
  COALESCE(asb.submitter_users,0) AS submitter_users,
  COALESCE(asb.events_submitted,0) AS events_submitted,
  COALESCE(asb.countries_represented,0) AS countries_represented,
  COALESCE(ap.paid_users,0)      AS paid_users,
  CASE WHEN COALESCE(asb.submitter_users,0) > 0
       THEN ROUND(100.0 * COALESCE(ap.paid_users,0) / asb.submitter_users, 2)
       ELSE 0 END                AS conversion_pct,
  COALESCE(ap.registrations_count,0) AS paid_registration_rows,
  COALESCE(ap.revenue_EUR,0.00)      AS revenue_EUR,
  COALESCE(ap.avg_ticket_EUR,0.00)   AS avg_ticket_EUR,
  COALESCE(ap.min_ticket_EUR,0.00)   AS min_ticket_EUR,
  COALESCE(ap.max_ticket_EUR,0.00)   AS max_ticket_EUR,
  COALESCE(ap.stddev_ticket_EUR,0.00) AS stddev_ticket_EUR,
  COALESCE(ap.events_paid,0)         AS events_paid,
  COALESCE(ap.countries_paid,0)      AS countries_paid,
  -- Pricing heuristics
  ROUND(GREATEST(COALESCE(ap.avg_ticket_EUR,0) - 0.50 * COALESCE(ap.stddev_ticket_EUR,0),
                 COALESCE(ap.min_ticket_EUR,0)), 2) AS suggested_price_floor_EUR,
  ROUND(COALESCE(ap.avg_ticket_EUR,0), 2)           AS suggested_price_target_EUR,
  ROUND(COALESCE(ap.avg_ticket_EUR,0) + 0.75 * COALESCE(ap.stddev_ticket_EUR,0), 2) AS suggested_price_premium_EUR,
  -- Cohorts
  COALESCE(apc.returning_paid_users,0) AS returning_paid_users,
  COALESCE(apc.new_paid_users,0)       AS new_paid_users,
  -- Top lists
  COALESCE(tc.top_countries_by_paid,    '') AS top_countries_by_paid,
  COALESCE(tr.top_countries_by_revenue, '') AS top_countries_by_revenue,
  COALESCE(te.top_events_by_paid,       '') AS top_events_by_paid,
  COALESCE(tv.top_events_by_revenue,    '') AS top_events_by_revenue
FROM aff_keys ak
LEFT JOIN aff_submit asb              ON asb.affiliation_name = ak.affiliation_name
LEFT JOIN aff_paid ap                 ON ap.affiliation_name  = ak.affiliation_name
LEFT JOIN aff_paid_cohort apc         ON apc.affiliation_name = ak.affiliation_name
LEFT JOIN top3_countries_by_paid tc   ON tc.affiliation_name = ak.affiliation_name
LEFT JOIN top3_countries_by_revenue tr ON tr.affiliation_name = ak.affiliation_name
LEFT JOIN top3_events_by_paid te      ON te.affiliation_name = ak.affiliation_name
LEFT JOIN top3_events_by_revenue tv   ON tv.affiliation_name = ak.affiliation_name
ORDER BY revenue_EUR DESC, conversion_pct DESC, affiliation;
















WITH params AS (
  SELECT CAST('2024-07-01' AS DATE) AS start_date,
         CAST('2025-10-01' AS DATE) AS end_date
),
users_norm AS (
  SELECT u.id AS user_id, LOWER(TRIM(u.email)) AS email_norm
  FROM users u
),
paid_regs AS (
  SELECT r.id AS registration_id,
         r.user_id,
         r.event_id,
         r.total_price,
         r.currency_type,
         r.status,
         r.updated_at AS paid_at
  FROM registrations r, params p
  WHERE r.status = 1
    AND r.currency_type = 'EUR'
    AND r.updated_at >= p.start_date
    AND r.updated_at <  p.end_date
),
emails_all AS (
  SELECT LOWER(TRIM(e.to_address)) AS email_norm,
         e.p4                      AS award_category,
         COALESCE(e.date_sent, e.date_added) AS sent_at
  FROM emails2 e
  WHERE e.p4 IS NOT NULL AND e.p4 <> ''

  UNION ALL

  SELECT LOWER(TRIM(e2.to_address)) AS email_norm,
         e2.p4                      AS award_category,
         COALESCE(e2.date_sent, e2.date_added) AS sent_at
  FROM emails2_ e2
  WHERE e2.p4 IS NOT NULL AND e2.p4 <> ''
),
emails_by_user AS (
  SELECT un.user_id, ea.award_category, ea.sent_at
  FROM emails_all ea
  JOIN users_norm un
    ON un.email_norm = ea.email_norm
),
attrib AS (
  SELECT
    pr.registration_id,
    pr.user_id,
    pr.total_price,
    ebu.award_category,
    ROW_NUMBER() OVER (
      PARTITION BY pr.registration_id
      ORDER BY ebu.sent_at DESC
    ) AS rn
  FROM paid_regs pr
  LEFT JOIN emails_by_user ebu
    ON ebu.user_id = pr.user_id
   AND ebu.sent_at <= pr.paid_at
)
SELECT
  COALESCE(award_category, 'UNKNOWN') AS award_category,
  COUNT(*)                            AS paid_registrations,
  ROUND(SUM(total_price), 2)          AS eur_revenue
FROM attrib
WHERE rn = 1
GROUP BY award_category
ORDER BY eur_revenue DESC, paid_registrations DESC;







WITH params AS (
  SELECT CAST('2024-07-01' AS DATE) AS start_date,
         CAST('2025-10-01' AS DATE) AS end_date
),

-- users with country name + normalized email
users_country AS (
  SELECT 
    u.id AS user_id,
    LOWER(TRIM(u.email)) AS email_norm,
    u.country_id,
    c.name AS country_name
  FROM users u
  LEFT JOIN countries_corrected_final c
    ON c.id = u.country_id
),

-- paid registrations (still windowed)
paid_regs AS (
  SELECT 
    r.id AS registration_id,
    r.user_id,
    r.total_price,
    r.updated_at AS paid_at
  FROM registrations r, params p
  WHERE r.status = 1
    AND r.currency_type = 'EUR'
    AND r.updated_at >= p.start_date
    AND r.updated_at <  p.end_date
),

-- all award emails from both tables, normalized (LIFETIME: no date filter)
emails_all AS (
  SELECT 
    LOWER(TRIM(e.to_address)) AS email_norm,
    e.p4                      AS award_category,
    COALESCE(e.date_sent, e.date_added) AS sent_at
  FROM emails2 e
  WHERE e.p4 IS NOT NULL AND e.p4 <> ''

  UNION ALL

  SELECT 
    LOWER(TRIM(e2.to_address)) AS email_norm,
    e2.p4                      AS award_category,
    COALESCE(e2.date_sent, e2.date_added) AS sent_at
  FROM emails2_ e2
  WHERE e2.p4 IS NOT NULL AND e2.p4 <> ''
),

-- map email rows to users (so we know country)
emails_by_user AS (
  SELECT 
    uc.user_id,
    uc.country_name,
    ea.award_category,
    ea.sent_at
  FROM emails_all ea
  JOIN users_country uc
    ON uc.email_norm = ea.email_norm
),

-- LIFETIME emails sent per award × country
emails_sent AS (
  SELECT 
    ebu.country_name,
    ebu.award_category,
    COUNT(*) AS emails_sent
  FROM emails_by_user ebu
  GROUP BY ebu.country_name, ebu.award_category
),

-- attribute each paid reg to latest award email <= paid_at (lifetime pool)
attrib AS (
  SELECT
    pr.registration_id,
    pr.user_id,
    ebu.country_name,
    ebu.award_category,
    pr.total_price,
    ROW_NUMBER() OVER (
      PARTITION BY pr.registration_id
      ORDER BY ebu.sent_at DESC
    ) AS rn
  FROM paid_regs pr
  LEFT JOIN emails_by_user ebu
    ON ebu.user_id = pr.user_id
   AND ebu.sent_at <= pr.paid_at
),

-- paid rollup per award × country (windowed)
paid_by AS (
  SELECT
    COALESCE(a.country_name, 'UNKNOWN')   AS country_name,
    COALESCE(a.award_category, 'UNKNOWN') AS award_category,
    COUNT(*)                               AS paid_registrations,
    ROUND(SUM(a.total_price), 2)           AS eur_revenue
  FROM attrib a
  WHERE a.rn = 1
  GROUP BY COALESCE(a.country_name, 'UNKNOWN'),
           COALESCE(a.award_category, 'UNKNOWN')
)

-- FULL OUTER JOIN emulation to include zeros on either side
SELECT 
  COALESCE(p.country_name, e.country_name)   AS country_name,
  COALESCE(p.award_category, e.award_category) AS award_category,
  COALESCE(e.emails_sent, 0)                 AS emails_sent_lifetime,
  COALESCE(p.paid_registrations, 0)          AS paid_registrations_window,
  COALESCE(p.eur_revenue, 0.00)              AS eur_revenue_window,
  CASE 
    WHEN COALESCE(e.emails_sent, 0) = 0 THEN NULL
    ELSE ROUND(COALESCE(p.paid_registrations, 0) / e.emails_sent * 100, 2)
  END AS conversion_pct_window_over_lifetime
FROM emails_sent e
LEFT JOIN paid_by p
  ON p.country_name = e.country_name
 AND p.award_category = e.award_category

UNION

SELECT 
  COALESCE(p.country_name, e.country_name)   AS country_name,
  COALESCE(p.award_category, e.award_category) AS award_category,
  COALESCE(e.emails_sent, 0)                 AS emails_sent_lifetime,
  COALESCE(p.paid_registrations, 0)          AS paid_registrations_window,
  COALESCE(p.eur_revenue, 0.00)              AS eur_revenue_window,
  CASE 
    WHEN COALESCE(e.emails_sent, 0) = 0 THEN NULL
    ELSE ROUND(COALESCE(p.paid_registrations, 0) / e.emails_sent * 100, 2)
  END AS conversion_pct_window_over_lifetime
FROM paid_by p
LEFT JOIN emails_sent e
  ON e.country_name = p.country_name
 AND e.award_category = p.award_category

ORDER BY country_name, eur_revenue_window DESC, paid_registrations_window DESC;








#This query gives the information regarding the users registered between July 2024 to September 2025 and How many abstracts were submitted in that window and conversion rate 


WITH params AS (
  SELECT CAST('2024-07-01' AS DATE) AS start_date,
         CAST('2025-10-01' AS DATE) AS end_date
),
users_w AS (
  SELECT u.*
  FROM users u, params p
  WHERE u.created_at >= p.start_date
    AND u.created_at <  p.end_date
),
abstracts_w AS (
  SELECT a.id AS abstract_id, a.user_id, a.statusdate
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date
    AND a.statusdate <  p.end_date
),
submitters AS (
  SELECT DISTINCT user_id FROM abstracts_w
)
SELECT
  (SELECT COUNT(*)        FROM users_w)    AS total_users_in_window,
  (SELECT COUNT(*)        FROM submitters) AS users_who_submitted_in_window,
  (SELECT COUNT(*)        FROM abstracts_w)AS total_abstracts_in_window,
  ROUND(
    100.0 * (SELECT COUNT(*) FROM submitters)
          / NULLIF((SELECT COUNT(*) FROM users_w), 0), 2
  ) AS user_submission_rate_percent;



#The below query gives information regarding the details of these authors who submitted abstracts



WITH params AS (
  SELECT CAST('2024-07-01' AS DATE) AS start_date,
         CAST('2025-10-01' AS DATE) AS end_date
),
users_w AS (
  SELECT u.*
  FROM users u, params p
  WHERE u.created_at >= p.start_date
    AND u.created_at <  p.end_date
),
abstracts_w AS (
  SELECT a.id AS abstract_id, a.user_id, a.statusdate
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date
    AND a.statusdate <  p.end_date
),
per_submitter AS (
  -- counts only within the window
  SELECT
    user_id,
    COUNT(*)        AS abstracts_in_window,
    MIN(statusdate) AS first_submission,
    MAX(statusdate) AS last_submission
  FROM abstracts_w
  GROUP BY user_id
),
per_user_all_time AS (
  -- lifetime counts (no date filter)
  SELECT
    user_id,
    COUNT(*)        AS total_abstracts_all_time,
    MIN(statusdate) AS first_submission_ever,
    MAX(statusdate) AS last_submission_ever
  FROM abstract_submissions
  GROUP BY user_id
)
SELECT
  u.id AS user_id,
  CONCAT_WS(' ', u.first_name, u.last_name) AS name,
  u.email,
  u.affiliation,
  CASE WHEN u.date_of_birth IS NOT NULL
       THEN TIMESTAMPDIFF(YEAR, u.date_of_birth, (SELECT end_date FROM params))
       ELSE NULL END AS age_as_of_end,
  u.created_at,
  ps.abstracts_in_window,             -- number in the window
  pz.total_abstracts_all_time,        -- lifetime number
  ps.first_submission,
  ps.last_submission,
  pz.first_submission_ever,
  pz.last_submission_ever
FROM users_w u
JOIN per_submitter ps     ON ps.user_id = u.id     -- only users who submitted in the window
LEFT JOIN per_user_all_time pz ON pz.user_id = u.id
ORDER BY ps.last_submission DESC, u.id;




#Abstract Submission to Registration conversion

WITH params AS (
  SELECT CAST('2024-07-01' AS DATE) AS start_date,
         CAST('2025-10-01' AS DATE) AS end_date
),
submitters AS (  -- unique user+event pairs that submitted in the window
  SELECT DISTINCT a.user_id, a.event_id
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date
    AND a.statusdate <  p.end_date
),
paid_regs AS (   -- paid registrations matching those user+event pairs
  SELECT r.user_id, r.event_id, r.total_price
  FROM registrations r
  JOIN submitters s
    ON s.user_id  = r.user_id
   AND s.event_id = r.event_id
  WHERE r.status = 1                -- paid only
    AND r.currency_type = 'EUR'     -- EUR only
    AND r.total_price IS NOT NULL
)
SELECT
  (SELECT COUNT(DISTINCT user_id) FROM submitters) AS submitter_users,
  (SELECT COUNT(DISTINCT user_id) FROM paid_regs)  AS paid_users,
  ROUND(
    100.0 * (SELECT COUNT(DISTINCT user_id) FROM paid_regs)
          / NULLIF((SELECT COUNT(DISTINCT user_id) FROM submitters),0), 2
  ) AS submitter_to_paid_rate_pct,
  ROUND(COALESCE((SELECT SUM(total_price) FROM paid_regs),0), 2) AS total_revenue_EUR;
  
  
  
-- Bulletproof pull: YES + non-empty name + from 2025-06-01 up to now
SELECT *
FROM yes_no_form
WHERE LOWER(TRIM(`response`)) = 'yes'
  AND NULLIF(TRIM(full_name), '') IS NOT NULL
  AND DATE(created_at) >= '2025-07-01'
  AND created_at < (CURRENT_DATE + INTERVAL 1 DAY);


SELECT LOWER(TRIM(`response`)) AS resp_norm, COUNT(*) cnt
FROM yes_no_form
WHERE DATE(created_at) >= '2025-07-01'
GROUP BY resp_norm
ORDER BY cnt DESC;



-- How many "yes" rows since 2025-06-01 have usable names?
SELECT
  COUNT(*)                                                         AS yes_total,
  SUM(full_name REGEXP '[^[:space:]]')                             AS yes_with_name,
  SUM(NOT (full_name REGEXP '[^[:space:]]'))                       AS yes_missing_name
FROM yes_no_form
WHERE LOWER(TRIM(response)) = 'yes'
  AND DATE(created_at) >= '2025-07-01';



WITH yes_25 AS (
  SELECT
    -- normalize email from yes_no_form
    LOWER(TRIM(
      COALESCE(
        REGEXP_SUBSTR(email, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
        email
      )
    )) AS email_norm,
    created_at AS yes_created_at
  FROM yes_no_form
  WHERE LOWER(TRIM(response)) = 'yes'
    AND created_at >= '2025-07-01'
    AND created_at < (CURRENT_DATE + INTERVAL 1 DAY)
),
users_norm AS (
  SELECT
    u.id AS user_id,
    LOWER(TRIM(u.email)) AS email_norm,
    u.first_name,
    u.last_name,
    u.email AS user_email
  FROM users u
),
abstracts_25 AS (
  SELECT
    a.id AS abstract_id,
    a.user_id,
    a.created_at AS abstract_created_at
  FROM abstract_submissions a
  WHERE a.created_at >= '2025-09-09'
    AND a.created_at < (CURRENT_DATE + INTERVAL 1 DAY)
)
SELECT
  u.user_id,
  CONCAT_WS(' ', u.first_name, u.last_name) AS name,
  u.user_email,
  y.yes_created_at,
  a.abstract_id,
  a.abstract_created_at
FROM yes_25 y
JOIN users_norm u
  ON u.email_norm = y.email_norm
JOIN abstracts_25 a
  ON a.user_id = u.user_id
ORDER BY a.abstract_created_at DESC;






WITH yes_2025 AS (
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(email, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      email
    ))) AS email_norm,
    MAX(created_at) AS yes_created_at
  FROM yes_no_form
  WHERE LOWER(TRIM(response)) = 'yes'
    AND created_at >= '2025-07-01'
    AND created_at <  '2026-01-01'
  GROUP BY 1
),
users_norm AS (
  SELECT
    u.id AS user_id,
    LOWER(TRIM(u.email)) AS email_norm
  FROM users u
),
abs_2025 AS (
  SELECT DISTINCT a.user_id
  FROM abstract_submissions a
  WHERE a.created_at >= '2025-07-01'
    AND a.created_at <  '2026-01-01'
),
mailer_union AS (
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      to_address
    ))) AS email_norm,
    NULLIF(TRIM(p1), '') AS p1,
    COALESCE(date_sent, date_added) AS ts
  FROM emails2
  UNION ALL
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      to_address
    ))) AS email_norm,
    NULLIF(TRIM(p1), '') AS p1,
    COALESCE(date_sent, date_added) AS ts
  FROM emails2_
),
name_latest AS (
  SELECT email_norm, p1
  FROM (
    SELECT
      email_norm, p1, ts,
      ROW_NUMBER() OVER (PARTITION BY email_norm ORDER BY ts DESC) AS rn
    FROM mailer_union
  ) s
  WHERE rn = 1
)
SELECT
  y.email_norm                  AS email,
  nl.p1                         AS name_from_p1,
  y.yes_created_at
FROM yes_2025 y
LEFT JOIN users_norm u ON u.email_norm = y.email_norm
LEFT JOIN abs_2025 a   ON a.user_id = u.user_id
LEFT JOIN name_latest nl ON nl.email_norm = y.email_norm
WHERE a.user_id IS NULL
ORDER BY y.yes_created_at DESC;






WITH yes_2025 AS (
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(email, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      email
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    MAX(created_at) AS yes_created_at
  FROM yes_no_form
  WHERE LOWER(TRIM(response)) COLLATE utf8mb4_unicode_ci = 'yes' COLLATE utf8mb4_unicode_ci
    AND created_at >= '2025-07-01'
    AND created_at <  '2026-01-01'
  GROUP BY 1
),
users_norm AS (
  SELECT
    u.id AS user_id,
    LOWER(TRIM(u.email)) COLLATE utf8mb4_unicode_ci AS email_norm
  FROM users u
),
abs_2025 AS (
  SELECT DISTINCT a.user_id
  FROM abstract_submissions a
  WHERE a.created_at >= '2025-07-01'
    AND a.created_at <  '2026-01-01'
),
mailer_union AS (
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      to_address
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    NULLIF(TRIM(p1), '') AS p1,
    COALESCE(date_sent, date_added) AS ts
  FROM Reminders_Jul_Aug_Campaign
),
name_latest AS (
  SELECT email_norm, p1
  FROM (
    SELECT
      email_norm, p1, ts,
      ROW_NUMBER() OVER (PARTITION BY email_norm ORDER BY ts DESC) AS rn
    FROM mailer_union
  ) s
  WHERE rn = 1
)
SELECT
  y.email_norm        AS email,
  nl.p1               AS name_from_p1,
  y.yes_created_at
FROM yes_2025 y
LEFT JOIN users_norm u  ON u.email_norm = y.email_norm
LEFT JOIN abs_2025 a    ON a.user_id = u.user_id
LEFT JOIN name_latest nl ON nl.email_norm = y.email_norm
WHERE a.user_id IS NULL
ORDER BY y.yes_created_at DESC;







WITH yes_2025 AS (
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(email, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      email
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    MAX(created_at) AS yes_created_at
  FROM yes_no_form
  WHERE LOWER(TRIM(response)) COLLATE utf8mb4_unicode_ci = 'yes' COLLATE utf8mb4_unicode_ci
    AND created_at >= '2025-07-01'
    AND created_at <  '2026-01-01'
  GROUP BY 1
),
users_norm AS (
  SELECT
    u.id AS user_id,
    LOWER(TRIM(u.email)) COLLATE utf8mb4_unicode_ci AS email_norm
  FROM users u
),
abs_2025 AS (
  SELECT DISTINCT a.user_id
  FROM abstract_submissions a
  WHERE a.created_at >= '2025-07-01'
    AND a.created_at <  '2026-01-01'
),
mailer_union AS (
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      to_address
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    NULLIF(TRIM(p1), '') AS p1,
    COALESCE(date_sent, date_added) AS ts
  FROM Reminders_Jul_Aug_Campaign

  UNION ALL

  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      to_address
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    NULLIF(TRIM(p1), '') AS p1,
    COALESCE(date_sent, date_added) AS ts
  FROM campaign_AML_01_09_2025
),
name_latest AS (
  SELECT email_norm, p1
  FROM (
    SELECT
      email_norm, p1, ts,
      ROW_NUMBER() OVER (PARTITION BY email_norm ORDER BY ts DESC) AS rn
    FROM mailer_union
  ) s
  WHERE rn = 1
)
SELECT
  y.email_norm        AS email,
  nl.p1               AS name_from_p1,
  y.yes_created_at
FROM yes_2025 y
LEFT JOIN users_norm u  ON u.email_norm = y.email_norm
LEFT JOIN abs_2025 a    ON a.user_id = u.user_id
LEFT JOIN name_latest nl ON nl.email_norm = y.email_norm
WHERE a.user_id IS NULL
ORDER BY y.yes_created_at DESC;










WITH yes_2025 AS (
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(email, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      email
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    MAX(created_at) AS yes_created_at
  FROM yes_no_form
  WHERE LOWER(TRIM(response)) COLLATE utf8mb4_unicode_ci = 'yes' COLLATE utf8mb4_unicode_ci
    AND created_at >= '2025-07-01'
    AND created_at <  '2026-01-01'
  GROUP BY 1
),
users_norm AS (
  SELECT
    u.id AS user_id,
    LOWER(TRIM(u.email)) COLLATE utf8mb4_unicode_ci AS email_norm
  FROM users u
),
abs_2025 AS (
  SELECT DISTINCT a.user_id
  FROM abstract_submissions a
  WHERE a.created_at >= '2025-07-01'
    AND a.created_at <  '2026-01-01'
),
mailer_union AS (
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      to_address
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    NULLIF(TRIM(p1), '') AS p1,
    COALESCE(date_sent, date_added) AS ts
  FROM emails3
),
name_latest AS (
  SELECT email_norm, p1
  FROM (
    SELECT
      email_norm, p1, ts,
      ROW_NUMBER() OVER (PARTITION BY email_norm ORDER BY ts DESC) AS rn
    FROM mailer_union
  ) s
  WHERE rn = 1
)
SELECT
  y.email_norm        AS email,
  nl.p1               AS name_from_p1,
  y.yes_created_at
FROM yes_2025 y
LEFT JOIN users_norm u   ON u.email_norm = y.email_norm
LEFT JOIN abs_2025 a     ON a.user_id = u.user_id
LEFT JOIN name_latest nl ON nl.email_norm = y.email_norm
WHERE a.user_id IS NULL
ORDER BY y.yes_created_at DESC;









WITH yes_2025 AS (
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(email, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      email
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    MAX(created_at) AS yes_created_at
  FROM yes_no_form
  WHERE LOWER(TRIM(response)) COLLATE utf8mb4_unicode_ci = 'yes' COLLATE utf8mb4_unicode_ci
    AND created_at >= '2025-07-01'
    AND created_at <  '2026-01-01'
  GROUP BY 1
),
users_norm AS (
  SELECT
    u.id AS user_id,
    LOWER(TRIM(u.email)) COLLATE utf8mb4_unicode_ci AS email_norm
  FROM users u
),
abs_2025 AS (
  SELECT DISTINCT a.user_id
  FROM abstract_submissions a
  WHERE a.created_at >= '2025-07-01'
    AND a.created_at <  '2026-01-01'
),
mailer_union AS (
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      to_address
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    NULLIF(TRIM(p1), '') AS p1,
    NULLIF(TRIM(p2), '') AS p2,
    COALESCE(date_sent, date_added) AS ts
  FROM emails3
),
name_latest AS (
  SELECT email_norm, p1, p2
  FROM (
    SELECT
      email_norm, p1, p2, ts,
      ROW_NUMBER() OVER (PARTITION BY email_norm ORDER BY ts DESC) AS rn
    FROM mailer_union
  ) s
  WHERE rn = 1
)
SELECT
  y.email_norm        AS email,
  nl.p1               AS name_from_p1,
  nl.p2               AS affiliation_from_p2,
  y.yes_created_at
FROM yes_2025 y
LEFT JOIN users_norm u   ON u.email_norm = y.email_norm
LEFT JOIN abs_2025 a     ON a.user_id = u.user_id
LEFT JOIN name_latest nl ON nl.email_norm = y.email_norm
WHERE a.user_id IS NULL
ORDER BY y.yes_created_at DESC;











WITH yes_2025 AS (
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(email, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      email
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    MAX(created_at) AS yes_created_at
  FROM yes_no_form
  WHERE LOWER(TRIM(response)) COLLATE utf8mb4_unicode_ci = 'yes' COLLATE utf8mb4_unicode_ci
    AND created_at >= '2025-07-01'
    AND created_at <  '2026-01-01'
  GROUP BY 1
),
users_norm AS (
  SELECT
    u.id AS user_id,
    LOWER(TRIM(u.email)) COLLATE utf8mb4_unicode_ci AS email_norm
  FROM users u
),
abs_2025 AS (
  SELECT DISTINCT a.user_id
  FROM abstract_submissions a
  WHERE a.created_at >= '2025-07-01'
    AND a.created_at <  '2026-01-01'
),
mailer_union AS (
  /* emails3 */
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      to_address
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    NULLIF(TRIM(p1), '') AS p1,
    NULLIF(TRIM(p2), '') AS p2,
    NULLIF(TRIM(p3), '') AS p3,
    COALESCE(date_sent, date_added) AS ts
  FROM emails3

  UNION ALL

  /* Reminders_Jul_Aug_Campaign */
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      to_address
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    NULLIF(TRIM(p1), '') AS p1,
    NULLIF(TRIM(p2), '') AS p2,
    NULLIF(TRIM(p3), '') AS p3,
    COALESCE(date_sent, date_added) AS ts
  FROM Reminders_Jul_Aug_Campaign

  UNION ALL

  /* campaign_AML_01_09_2025 */
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      to_address
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    NULLIF(TRIM(p1), '') AS p1,
    NULLIF(TRIM(p2), '') AS p2,
    NULLIF(TRIM(p3), '') AS p3,
    COALESCE(date_sent, date_added) AS ts
  FROM campaign_AML_01_09_2025

  UNION ALL

  /* campaign_AMF_03_09_2025 */
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      to_address
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    NULLIF(TRIM(p1), '') AS p1,
    NULLIF(TRIM(p2), '') AS p2,
    NULLIF(TRIM(p3), '') AS p3,
    COALESCE(date_sent, date_added) AS ts
  FROM campaign_AMF_03_09_2025
),
name_latest AS (
  SELECT email_norm, p1, p2, p3
  FROM (
    SELECT
      email_norm, p1, p2, p3, ts,
      ROW_NUMBER() OVER (PARTITION BY email_norm ORDER BY ts DESC) AS rn
    FROM mailer_union
  ) s
  WHERE rn = 1
)
SELECT
  y.email_norm              AS email,
  nl.p1                     AS name_from_p1,
  nl.p2                     AS affiliation_from_p2,
  nl.p3                     AS extra_from_p3,
  y.yes_created_at
FROM yes_2025 y
LEFT JOIN users_norm u    ON u.email_norm = y.email_norm
LEFT JOIN abs_2025 a      ON a.user_id = u.user_id
LEFT JOIN name_latest nl  ON nl.email_norm = y.email_norm
WHERE a.user_id IS NULL
ORDER BY y.yes_created_at DESC;










/* Optional: normalize the session so fewer surprises
SET collation_connection = 'utf8mb4_unicode_ci';
*/

WITH yes_2025 AS (
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(email, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      email
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    MAX(created_at) AS yes_created_at
  FROM yes_no_form
  WHERE LOWER(TRIM(response)) COLLATE utf8mb4_unicode_ci = 'yes' COLLATE utf8mb4_unicode_ci
    AND created_at >= '2025-07-01'
    AND created_at <  '2026-01-01'
  GROUP BY 1
),
users_norm AS (
  SELECT
    u.id AS user_id,
    LOWER(TRIM(u.email)) COLLATE utf8mb4_unicode_ci AS email_norm
  FROM users u
),
abs_2025 AS (
  SELECT DISTINCT a.user_id
  FROM abstract_submissions a
  WHERE a.created_at >= '2025-07-01'
    AND a.created_at <  '2026-01-01'
),
mailer_union AS (
  /* emails3 */
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      to_address
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    NULLIF(TRIM(p1), '') COLLATE utf8mb4_unicode_ci AS p1,
    NULLIF(TRIM(p2), '') COLLATE utf8mb4_unicode_ci AS p2,
    NULLIF(TRIM(p3), '') COLLATE utf8mb4_unicode_ci AS p3,
    CAST(COALESCE(date_sent, date_added) AS DATETIME) AS ts
  FROM emails3

  UNION ALL

  /* Reminders_Jul_Aug_Campaign */
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      to_address
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    NULLIF(TRIM(p1), '') COLLATE utf8mb4_unicode_ci AS p1,
    NULLIF(TRIM(p2), '') COLLATE utf8mb4_unicode_ci AS p2,
    NULLIF(TRIM(p3), '') COLLATE utf8mb4_unicode_ci AS p3,
    CAST(COALESCE(date_sent, date_added) AS DATETIME) AS ts
  FROM Reminders_Jul_Aug_Campaign

  UNION ALL

  /* campaign_AML_01_09_2025 */
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      to_address
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    NULLIF(TRIM(p1), '') COLLATE utf8mb4_unicode_ci AS p1,
    NULLIF(TRIM(p2), '') COLLATE utf8mb4_unicode_ci AS p2,
    NULLIF(TRIM(p3), '') COLLATE utf8mb4_unicode_ci AS p3,
    CAST(COALESCE(date_sent, date_added) AS DATETIME) AS ts
  FROM campaign_AML_01_09_2025

  UNION ALL

  /* campaign_AMF_03_09_2025 */
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      to_address
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    NULLIF(TRIM(p1), '') COLLATE utf8mb4_unicode_ci AS p1,
    NULLIF(TRIM(p2), '') COLLATE utf8mb4_unicode_ci AS p2,
    NULLIF(TRIM(p3), '') COLLATE utf8mb4_unicode_ci AS p3,
    CAST(COALESCE(date_sent, date_added) AS DATETIME) AS ts
  FROM campaign_AMF_03_09_2025

  UNION ALL

  /* emails2 */
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      to_address
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    NULLIF(TRIM(p1), '') COLLATE utf8mb4_unicode_ci AS p1,
    NULLIF(TRIM(p2), '') COLLATE utf8mb4_unicode_ci AS p2,
    NULLIF(TRIM(p3), '') COLLATE utf8mb4_unicode_ci AS p3,
    CAST(COALESCE(date_sent, date_added) AS DATETIME) AS ts
  FROM emails2

  UNION ALL

  /* emails2_ */
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      to_address
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    NULLIF(TRIM(p1), '') COLLATE utf8mb4_unicode_ci AS p1,
    NULLIF(TRIM(p2), '') COLLATE utf8mb4_unicode_ci AS p2,
    NULLIF(TRIM(p3), '') COLLATE utf8mb4_unicode_ci AS p3,
    CAST(COALESCE(date_sent, date_added) AS DATETIME) AS ts
  FROM emails2_
),
name_latest AS (
  SELECT email_norm, p1, p2, p3
  FROM (
    SELECT
      email_norm, p1, p2, p3, ts,
      ROW_NUMBER() OVER (PARTITION BY email_norm ORDER BY ts DESC) AS rn
    FROM mailer_union
  ) s
  WHERE rn = 1
)
SELECT
  y.email_norm              AS email,
  nl.p1                     AS name_from_p1,
  nl.p2                     AS affiliation_from_p2,
  nl.p3                     AS extra_from_p3,
  y.yes_created_at
FROM yes_2025 y
LEFT JOIN users_norm u    ON u.email_norm = y.email_norm
LEFT JOIN abs_2025 a      ON a.user_id = u.user_id
LEFT JOIN name_latest nl  ON nl.email_norm = y.email_norm
WHERE a.user_id IS NULL
ORDER BY y.yes_created_at DESC;








WITH yes_2025 AS (
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(email, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      email
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    MAX(created_at) AS yes_created_at
  FROM yes_no_form
  WHERE LOWER(TRIM(response)) COLLATE utf8mb4_unicode_ci = 'yes' COLLATE utf8mb4_unicode_ci
    AND created_at >= '2025-07-01'
    AND created_at <  '2026-01-01'
  GROUP BY 1
),
users_norm AS (
  SELECT
    u.id AS user_id,
    LOWER(TRIM(u.email)) COLLATE utf8mb4_unicode_ci AS email_norm
  FROM users u
),
abs_2025 AS (
  SELECT DISTINCT a.user_id
  FROM abstract_submissions a
  WHERE a.created_at >= '2025-07-01'
    AND a.created_at <  '2026-01-01'
),
mailer_union AS (
  /* emails3 */
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      to_address
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    NULLIF(TRIM(p1), '') COLLATE utf8mb4_unicode_ci AS p1,
    NULLIF(TRIM(p2), '') COLLATE utf8mb4_unicode_ci AS p2,
    NULLIF(TRIM(p3), '') COLLATE utf8mb4_unicode_ci AS p3,
    CAST(COALESCE(date_sent, date_added) AS DATETIME) AS ts
  FROM emails3

  UNION ALL

  /* Reminders_Jul_Aug_Campaign */
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      to_address
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    NULLIF(TRIM(p1), '') COLLATE utf8mb4_unicode_ci AS p1,
    NULLIF(TRIM(p2), '') COLLATE utf8mb4_unicode_ci AS p2,
    NULLIF(TRIM(p3), '') COLLATE utf8mb4_unicode_ci AS p3,
    CAST(COALESCE(date_sent, date_added) AS DATETIME) AS ts
  FROM Reminders_Jul_Aug_Campaign

  UNION ALL

  /* campaign_AML_01_09_2025 */
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      to_address
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    NULLIF(TRIM(p1), '') COLLATE utf8mb4_unicode_ci AS p1,
    NULLIF(TRIM(p2), '') COLLATE utf8mb4_unicode_ci AS p2,
    NULLIF(TRIM(p3), '') COLLATE utf8mb4_unicode_ci AS p3,
    CAST(COALESCE(date_sent, date_added) AS DATETIME) AS ts
  FROM campaign_AML_01_09_2025

  UNION ALL

  /* campaign_AMF_03_09_2025 */
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      to_address
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    NULLIF(TRIM(p1), '') COLLATE utf8mb4_unicode_ci AS p1,
    NULLIF(TRIM(p2), '') COLLATE utf8mb4_unicode_ci AS p2,
    NULLIF(TRIM(p3), '') COLLATE utf8mb4_unicode_ci AS p3,
    CAST(COALESCE(date_sent, date_added) AS DATETIME) AS ts
  FROM campaign_AMF_03_09_2025

  UNION ALL

  /* emails2 */
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      to_address
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    NULLIF(TRIM(p1), '') COLLATE utf8mb4_unicode_ci AS p1,
    NULLIF(TRIM(p2), '') COLLATE utf8mb4_unicode_ci AS p2,
    NULLIF(TRIM(p3), '') COLLATE utf8mb4_unicode_ci AS p3,
    CAST(COALESCE(date_sent, date_added) AS DATETIME) AS ts
  FROM emails2

  UNION ALL

  /* emails2_ */
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      to_address
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    NULLIF(TRIM(p1), '') COLLATE utf8mb4_unicode_ci AS p1,
    NULLIF(TRIM(p2), '') COLLATE utf8mb4_unicode_ci AS p2,
    NULLIF(TRIM(p3), '') COLLATE utf8mb4_unicode_ci AS p3,
    CAST(COALESCE(date_sent, date_added) AS DATETIME) AS ts
  FROM emails2_
),
name_latest AS (
  SELECT email_norm, p1, p2, p3
  FROM (
    SELECT
      email_norm, p1, p2, p3, ts,
      ROW_NUMBER() OVER (PARTITION BY email_norm ORDER BY ts DESC) AS rn
    FROM mailer_union
  ) s
  WHERE rn = 1
)
INSERT INTO yes_no_reminder_jul_to_sep (
  email,
  name_from_p1,
  affiliation_from_p2,
  extra_from_p3,
  yes_created_at
)
SELECT
  y.email_norm        AS email,
  nl.p1               AS name_from_p1,
  nl.p2               AS affiliation_from_p2,
  nl.p3               AS extra_from_p3,
  y.yes_created_at
FROM yes_2025 y
LEFT JOIN users_norm u   ON u.email_norm = y.email_norm
LEFT JOIN abs_2025 a     ON a.user_id = u.user_id
LEFT JOIN name_latest nl ON nl.email_norm = y.email_norm
WHERE a.user_id IS NULL;






INSERT INTO yes_no_reminder_jul_to_sep (
  email,
  name_from_p1,
  affiliation_from_p2,
  extra_from_p3,
  yes_created_at
)
SELECT
  y.email_norm                       AS email,
  nl.p1                              AS name_from_p1,
  nl.p2                              AS affiliation_from_p2,
  nl.p3                              AS extra_from_p3,
  y.yes_created_at
FROM
(
  /* YES responses in window, dedup by normalized email */
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(email, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      email
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    MAX(created_at) AS yes_created_at
  FROM yes_no_form
  WHERE LOWER(TRIM(response)) COLLATE utf8mb4_unicode_ci = 'yes'
    AND created_at >= '2025-07-01'
    AND created_at <  '2026-01-01'
  GROUP BY 1
) AS y
LEFT JOIN
(
  /* users with normalized email (for joining to abstracts) */
  SELECT
    u.id AS user_id,
    LOWER(TRIM(u.email)) COLLATE utf8mb4_unicode_ci AS email_norm
  FROM users u
) AS u
  ON u.email_norm = y.email_norm
LEFT JOIN
(
  /* abstract submitters in the same window */
  SELECT DISTINCT a.user_id
  FROM abstract_submissions a
  WHERE a.created_at >= '2025-07-01'
    AND a.created_at <  '2026-01-01'
) AS a
  ON a.user_id = u.user_id
LEFT JOIN
(
  /* latest p1/p2/p3 per email across all mailer tables */
  SELECT email_norm, p1, p2, p3
  FROM (
    SELECT
      mu.email_norm,
      mu.p1,
      mu.p2,
      mu.p3,
      mu.ts,
      ROW_NUMBER() OVER (PARTITION BY mu.email_norm ORDER BY mu.ts DESC) AS rn
    FROM (
      /* emails3 */
      SELECT
        LOWER(TRIM(COALESCE(
          REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
          to_address
        ))) COLLATE utf8mb4_unicode_ci AS email_norm,
        NULLIF(TRIM(p1), '') COLLATE utf8mb4_unicode_ci AS p1,
        NULLIF(TRIM(p2), '') COLLATE utf8mb4_unicode_ci AS p2,
        NULLIF(TRIM(p3), '') COLLATE utf8mb4_unicode_ci AS p3,
        CAST(COALESCE(date_sent, date_added) AS DATETIME) AS ts
      FROM emails3

      UNION ALL

      /* Reminders_Jul_Aug_Campaign */
      SELECT
        LOWER(TRIM(COALESCE(
          REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
          to_address
        ))) COLLATE utf8mb4_unicode_ci AS email_norm,
        NULLIF(TRIM(p1), '') COLLATE utf8mb4_unicode_ci AS p1,
        NULLIF(TRIM(p2), '') COLLATE utf8mb4_unicode_ci AS p2,
        NULLIF(TRIM(p3), '') COLLATE utf8mb4_unicode_ci AS p3,
        CAST(COALESCE(date_sent, date_added) AS DATETIME) AS ts
      FROM Reminders_Jul_Aug_Campaign

      UNION ALL

      /* campaign_AML_01_09_2025 */
      SELECT
        LOWER(TRIM(COALESCE(
          REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
          to_address
        ))) COLLATE utf8mb4_unicode_ci AS email_norm,
        NULLIF(TRIM(p1), '') COLLATE utf8mb4_unicode_ci AS p1,
        NULLIF(TRIM(p2), '') COLLATE utf8mb4_unicode_ci AS p2,
        NULLIF(TRIM(p3), '') COLLATE utf8mb4_unicode_ci AS p3,
        CAST(COALESCE(date_sent, date_added) AS DATETIME) AS ts
      FROM campaign_AML_01_09_2025

      UNION ALL

      /* campaign_AMF_03_09_2025 */
      SELECT
        LOWER(TRIM(COALESCE(
          REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
          to_address
        ))) COLLATE utf8mb4_unicode_ci AS email_norm,
        NULLIF(TRIM(p1), '') COLLATE utf8mb4_unicode_ci AS p1,
        NULLIF(TRIM(p2), '') COLLATE utf8mb4_unicode_ci AS p2,
        NULLIF(TRIM(p3), '') COLLATE utf8mb4_unicode_ci AS p3,
        CAST(COALESCE(date_sent, date_added) AS DATETIME) AS ts
      FROM campaign_AMF_03_09_2025

      UNION ALL

      /* emails2 */
      SELECT
        LOWER(TRIM(COALESCE(
          REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
          to_address
        ))) COLLATE utf8mb4_unicode_ci AS email_norm,
        NULLIF(TRIM(p1), '') COLLATE utf8mb4_unicode_ci AS p1,
        NULLIF(TRIM(p2), '') COLLATE utf8mb4_unicode_ci AS p2,
        NULLIF(TRIM(p3), '') COLLATE utf8mb4_unicode_ci AS p3,
        CAST(COALESCE(date_sent, date_added) AS DATETIME) AS ts
      FROM emails2

      UNION ALL

      /* emails2_ */
      SELECT
        LOWER(TRIM(COALESCE(
          REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
          to_address
        ))) COLLATE utf8mb4_unicode_ci AS email_norm,
        NULLIF(TRIM(p1), '') COLLATE utf8mb4_unicode_ci AS p1,
        NULLIF(TRIM(p2), '') COLLATE utf8mb4_unicode_ci AS p2,
        NULLIF(TRIM(p3), '') COLLATE utf8mb4_unicode_ci AS p3,
        CAST(COALESCE(date_sent, date_added) AS DATETIME) AS ts
      FROM emails2_
    ) AS mu
  ) AS ranked
  WHERE ranked.rn = 1
) AS nl
  ON nl.email_norm = y.email_norm
WHERE a.user_id IS NULL;






/* Create table if it doesn't exist */
CREATE TABLE IF NOT EXISTS yes_no_reminder_jul_to_sep (
  email             VARCHAR(320) COLLATE utf8mb4_unicode_ci,
  name_from_p1      TEXT COLLATE utf8mb4_unicode_ci,
  affiliation_from_p2 TEXT COLLATE utf8mb4_unicode_ci,
  extra_from_p3     TEXT COLLATE utf8mb4_unicode_ci,
  subject           TEXT COLLATE utf8mb4_unicode_ci,
  p4                TEXT COLLATE utf8mb4_unicode_ci,
  p5                TEXT COLLATE utf8mb4_unicode_ci,
  template_name     VARCHAR(255) COLLATE utf8mb4_unicode_ci,
  yes_created_at    DATETIME
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/* Insert data */
INSERT INTO yes_no_reminder_jul_to_sep (
  email,
  name_from_p1,
  affiliation_from_p2,
  extra_from_p3,
  subject,
  p4,
  p5,
  template_name,
  yes_created_at
)
SELECT
  y.email_norm                       AS email,
  nl.p1                              AS name_from_p1,
  nl.p2                              AS affiliation_from_p2,
  nl.p3                              AS extra_from_p3,
  nl.subject                         AS subject,
  nl.p4                              AS p4,
  nl.p5                              AS p5,
  nl.template_name                   AS template_name,
  y.yes_created_at
FROM
(
  /* YES responses in window */
  SELECT
    LOWER(TRIM(COALESCE(
      REGEXP_SUBSTR(email, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
      email
    ))) COLLATE utf8mb4_unicode_ci AS email_norm,
    MAX(created_at) AS yes_created_at
  FROM yes_no_form
  WHERE LOWER(TRIM(response)) COLLATE utf8mb4_unicode_ci = 'yes'
    AND created_at >= '2025-07-01'
    AND created_at <  '2026-01-01'
  GROUP BY 1
) AS y
LEFT JOIN
(
  /* users with normalized email */
  SELECT
    u.id AS user_id,
    LOWER(TRIM(u.email)) COLLATE utf8mb4_unicode_ci AS email_norm
  FROM users u
) AS u
  ON u.email_norm = y.email_norm
LEFT JOIN
(
  /* abstract submitters in the same window */
  SELECT DISTINCT a.user_id
  FROM abstract_submissions a
  WHERE a.created_at >= '2025-07-01'
    AND a.created_at <  '2026-01-01'
) AS a
  ON a.user_id = u.user_id
LEFT JOIN
(
  /* latest record per email across all mailer/campaign tables */
  SELECT email_norm, p1, p2, p3, subject, p4, p5, template_name
  FROM (
    SELECT
      mu.email_norm,
      mu.p1,
      mu.p2,
      mu.p3,
      mu.subject,
      mu.p4,
      mu.p5,
      mu.template_name,
      mu.ts,
      ROW_NUMBER() OVER (PARTITION BY mu.email_norm ORDER BY mu.ts DESC) AS rn
    FROM (
      /* emails3 */
      SELECT
        LOWER(TRIM(COALESCE(
          REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),
          to_address
        ))) COLLATE utf8mb4_unicode_ci AS email_norm,
        NULLIF(TRIM(p1), '') COLLATE utf8mb4_unicode_ci AS p1,
        NULLIF(TRIM(p2), '') COLLATE utf8mb4_unicode_ci AS p2,
        NULLIF(TRIM(p3), '') COLLATE utf8mb4_unicode_ci AS p3,
        subject COLLATE utf8mb4_unicode_ci AS subject,
        NULLIF(TRIM(p4), '') COLLATE utf8mb4_unicode_ci AS p4,
        NULLIF(TRIM(p5), '') COLLATE utf8mb4_unicode_ci AS p5,
        template_name COLLATE utf8mb4_unicode_ci AS template_name,
        CAST(COALESCE(date_sent, date_added) AS DATETIME) AS ts
      FROM emails3

      UNION ALL
      SELECT LOWER(TRIM(COALESCE(REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),to_address))) COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p1), '') COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p2), '') COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p3), '') COLLATE utf8mb4_unicode_ci,
             subject COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p4), '') COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p5), '') COLLATE utf8mb4_unicode_ci,
             template_name COLLATE utf8mb4_unicode_ci,
             CAST(COALESCE(date_sent, date_added) AS DATETIME)
      FROM Reminders_Jul_Aug_Campaign

      UNION ALL
      SELECT LOWER(TRIM(COALESCE(REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),to_address))) COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p1), '') COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p2), '') COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p3), '') COLLATE utf8mb4_unicode_ci,
             subject COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p4), '') COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p5), '') COLLATE utf8mb4_unicode_ci,
             template_name COLLATE utf8mb4_unicode_ci,
             CAST(COALESCE(date_sent, date_added) AS DATETIME)
      FROM campaign_AML_01_09_2025

      UNION ALL
      SELECT LOWER(TRIM(COALESCE(REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),to_address))) COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p1), '') COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p2), '') COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p3), '') COLLATE utf8mb4_unicode_ci,
             subject COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p4), '') COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p5), '') COLLATE utf8mb4_unicode_ci,
             template_name COLLATE utf8mb4_unicode_ci,
             CAST(COALESCE(date_sent, date_added) AS DATETIME)
      FROM campaign_AMF_03_09_2025

      UNION ALL
      SELECT LOWER(TRIM(COALESCE(REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),to_address))) COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p1), '') COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p2), '') COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p3), '') COLLATE utf8mb4_unicode_ci,
             subject COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p4), '') COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p5), '') COLLATE utf8mb4_unicode_ci,
             template_name COLLATE utf8mb4_unicode_ci,
             CAST(COALESCE(date_sent, date_added) AS DATETIME)
      FROM emails2

      UNION ALL
      SELECT LOWER(TRIM(COALESCE(REGEXP_SUBSTR(to_address, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'),to_address))) COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p1), '') COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p2), '') COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p3), '') COLLATE utf8mb4_unicode_ci,
             subject COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p4), '') COLLATE utf8mb4_unicode_ci,
             NULLIF(TRIM(p5), '') COLLATE utf8mb4_unicode_ci,
             template_name COLLATE utf8mb4_unicode_ci,
             CAST(COALESCE(date_sent, date_added) AS DATETIME)
      FROM emails2_
    ) AS mu
  ) AS ranked
  WHERE ranked.rn = 1
) AS nl
  ON nl.email_norm = y.email_norm
WHERE a.user_id IS NULL;



CREATE TABLE yes_no_reminder_jul_to_sep (
  email             VARCHAR(320) COLLATE utf8mb4_unicode_ci,
  name_from_p1      TEXT COLLATE utf8mb4_unicode_ci,
  affiliation_from_p2 TEXT COLLATE utf8mb4_unicode_ci,
  extra_from_p3     TEXT COLLATE utf8mb4_unicode_ci,
  yes_created_at    DATETIME
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;






-- Rebuild safely if needed
-- DROP TABLE IF EXISTS marketing_geo_event_unconverted_last12m;

CREATE TABLE marketing_geo_event_unconverted_last12m AS
WITH
params AS (
  SELECT
    DATE_SUB(CURDATE(), INTERVAL 1 YEAR) AS start_date,
    DATE_ADD(CURDATE(), INTERVAL 1 DAY)  AS end_exclusive,
    'EUR'                                AS currency_code      -- kept for symmetry; not used to filter unpaid
),
-- All abstracts in the last 12 months (submitter cohort window)
abs_w AS (
  SELECT a.user_id, a.event_id, a.statusdate
  FROM abstract_submissions a, params p
  WHERE a.statusdate >= p.start_date
    AND a.statusdate <  p.end_exclusive
),
-- Distinct user+event submitters in-window
submitters AS (
  SELECT DISTINCT user_id, event_id FROM abs_w
),
-- Users -> Country + Affiliation
user_dim AS (
  SELECT u.id AS user_id,
         COALESCE(c.name,'Unknown') AS country_name,
         u.affiliation
  FROM users u
  LEFT JOIN countries c ON c.id = u.country_id
),
-- Paid registrations for those submitters (same join keys as your "paid_regs_raw")
paid_regs_raw AS (
  SELECT r.user_id, r.event_id, r.total_price
  FROM registrations r
  JOIN submitters s
    ON s.user_id  = r.user_id
   AND s.event_id = r.event_id
  JOIN params p
  WHERE r.status = 1
    AND r.total_price IS NOT NULL
    AND r.currency_type = p.currency_code
  -- If you want to ALSO constrain by payment timestamp, uncomment the below and set the right column:
  -- AND r.updated_at >= p.start_date
  -- AND r.updated_at <  p.end_exclusive
),
-- The "opposite": submitters who did NOT pay for that event
unregistered_raw AS (
  SELECT s.user_id, s.event_id
  FROM submitters s
  LEFT JOIN paid_regs_raw pr
    ON pr.user_id = s.user_id AND pr.event_id = s.event_id
  WHERE pr.user_id IS NULL
),
-- Per Country×Event counts of total submitters and unregistered users
sub_agg AS (
  SELECT ud.country_name, s.event_id,
         COUNT(DISTINCT s.user_id) AS submitter_users
  FROM submitters s
  JOIN user_dim ud ON ud.user_id = s.user_id
  GROUP BY ud.country_name, s.event_id
),
unreg_agg AS (
  SELECT ud.country_name, ur.event_id,
         COUNT(DISTINCT ur.user_id) AS unregistered_users
  FROM unregistered_raw ur
  JOIN user_dim ud ON ud.user_id = ur.user_id
  GROUP BY ud.country_name, ur.event_id
),
-- Affiliation contributions among the UNREGISTERED cohort
unreg_aff_stats AS (
  SELECT ud.country_name,
         ur.event_id,
         COALESCE(NULLIF(TRIM(ud.affiliation),''),'(No affiliation)') AS affiliation,
         COUNT(DISTINCT ur.user_id) AS unregistered_users_aff
  FROM unregistered_raw ur
  JOIN user_dim ud ON ud.user_id = ur.user_id
  GROUP BY ud.country_name, ur.event_id, COALESCE(NULLIF(TRIM(ud.affiliation),''),'(No affiliation)')
),
-- Top 3 affiliations by unregistered count
unreg_aff_rank AS (
  SELECT country_name, event_id, affiliation, unregistered_users_aff,
         ROW_NUMBER() OVER (
           PARTITION BY country_name, event_id
           ORDER BY unregistered_users_aff DESC, affiliation
         ) AS rn_unreg
  FROM unreg_aff_stats
),
top3_unreg_aff AS (
  SELECT country_name, event_id,
         GROUP_CONCAT(CONCAT(affiliation,' (',unregistered_users_aff,')')
                      ORDER BY rn_unreg SEPARATOR ' | ') AS top_unregistered_affiliations
  FROM unreg_aff_rank
  WHERE rn_unreg <= 3
  GROUP BY country_name, event_id
),
-- Bring in paid agg for avg_ticket so we can estimate missed revenue (optional, heuristic)
paid_agg AS (
  SELECT ud.country_name, pr.event_id,
         ROUND(AVG(pr.total_price),2) AS avg_ticket_EUR
  FROM paid_regs_raw pr
  JOIN user_dim ud ON ud.user_id = pr.user_id
  GROUP BY ud.country_name, pr.event_id
),
-- Key space: any Country×Event pair that had submitters (we care about where drop-off could happen)
base_pairs AS (
  SELECT DISTINCT country_name, event_id FROM sub_agg
)
SELECT
  bp.country_name,
  e.id   AS event_id,
  COALESCE(e.name, CONCAT('Event#',e.id)) AS event_name,

  COALESCE(sa.submitter_users,0)    AS submitter_users,
  COALESCE(ua.unregistered_users,0) AS unregistered_users,
  CASE WHEN COALESCE(sa.submitter_users,0) > 0
       THEN ROUND(100.0 * COALESCE(ua.unregistered_users,0) / sa.submitter_users, 2)
       ELSE 0 END                   AS dropoff_pct,   -- the inverse of conversion

  -- Heuristic missed-revenue potential using local avg paid ticket (if any)
  COALESCE(pa.avg_ticket_EUR,0.00)  AS avg_ticket_EUR,
  ROUND(COALESCE(ua.unregistered_users,0) * COALESCE(pa.avg_ticket_EUR,0.00), 2) AS est_missed_revenue_EUR,

  COALESCE(t3u.top_unregistered_affiliations,'') AS top_unregistered_affiliations

FROM base_pairs bp
LEFT JOIN sub_agg sa   ON sa.country_name = bp.country_name AND sa.event_id = bp.event_id
LEFT JOIN unreg_agg ua ON ua.country_name = bp.country_name AND ua.event_id = bp.event_id
LEFT JOIN paid_agg pa  ON pa.country_name = bp.country_name AND pa.event_id = bp.event_id
LEFT JOIN top3_unreg_aff t3u
       ON t3u.country_name = bp.country_name AND t3u.event_id = bp.event_id
LEFT JOIN events e ON e.id = bp.event_id
-- Prioritize biggest leaks first
ORDER BY est_missed_revenue_EUR DESC, dropoff_pct DESC, bp.country_name, e.id;










