-- Branch Activity

-- You must not change the next 2 lines or the table definition.
SET SEARCH_PATH TO Library, public;
DROP TABLE IF EXISTS q1 cascade;

CREATE TABLE q1 (
    branch CHAR(5) NOT NULL,
    year INT NOT NULL,
    events INT NOT NULL,
    sessions FLOAT NOT NULL,
    registration INT NOT NULL,
    holdings INT NOT NULL,
    checkouts INT NOT NULL,
    duration FLOAT NOT NULL
);

-- Do this for each of the views that define your intermediate steps.
-- (But give them better names!) The IF EXISTS avoids generating an error
-- the first time this file is imported.
-- If you do not define any views, you can delete the lines about views.
DROP VIEW IF EXISTS v_events_sessions CASCADE;
DROP VIEW IF EXISTS v_registrations CASCADE;
DROP VIEW IF EXISTS v_holdings CASCADE;
DROP VIEW IF EXISTS v_checkouts CASCADE;
DROP VIEW IF EXISTS v_duration CASCADE;
DROP VIEW IF EXISTS v_event_years CASCADE;

-- Define views for your intermediate steps here:

--Events and Sessions per Year per Branch
CREATE VIEW v_events_sessions AS
SELECT
  lb.code AS branch,
  EXTRACT(YEAR FROM es.edate) AS year,
  COUNT(DISTINCT le.id) AS events, -- Counting distinct events per branch per year
  COALESCE(AVG(es.session_count), 0) AS sessions -- Calculating average sessions per event
FROM
  LibraryBranch lb
JOIN LibraryRoom lr ON lb.code = lr.library
JOIN LibraryEvent le ON lr.id = le.room
JOIN (
  SELECT
    event,
    COUNT(*) AS session_count,
    MIN(edate) as edate -- Using the earliest date of a session for an event to determine its year
  FROM EventSchedule
  GROUP BY event
) es ON le.id = es.event
GROUP BY lb.code, EXTRACT(YEAR FROM es.edate);
--Registrations per Year per Branch

CREATE VIEW v_event_years AS
SELECT
    event,
    EXTRACT(YEAR FROM edate) AS year
FROM
    EventSchedule
GROUP BY
    event, EXTRACT(YEAR FROM edate);

CREATE VIEW v_registrations AS
SELECT
    lb.code AS branch,
    ey.year,
    COUNT(esu.patron) AS registration
FROM
    EventSignUp esu
INNER JOIN v_event_years ey ON esu.event = ey.event
INNER JOIN LibraryEvent le ON esu.event = le.id
INNER JOIN LibraryRoom lr ON le.room = lr.id
INNER JOIN LibraryBranch lb ON lr.library = lb.code
GROUP BY lb.code, ey.year;







--Holdings per Branch
CREATE VIEW v_holdings AS
SELECT
  lb.code AS branch,
  COUNT(lh.holding) AS holdings
FROM
  LibraryHolding lh
JOIN LibraryBranch lb ON lh.library = lb.code
GROUP BY
  lb.code;
--Checkouts per Year per Branch
CREATE  VIEW v_checkouts AS
SELECT
  lb.code AS branch,
  EXTRACT(YEAR FROM c.checkout_time) AS year,
  COUNT(*) AS checkouts
FROM
  Checkout c
JOIN LibraryHolding lh ON c.copy = lh.barcode
JOIN LibraryBranch lb ON lh.library = lb.code
GROUP BY
  lb.code, EXTRACT(YEAR FROM c.checkout_time);
--Duration of Checkouts

CREATE VIEW v_duration AS
SELECT
  lb.code AS branch,
  EXTRACT(YEAR FROM c.checkout_time) AS year,
  AVG((r.return_time::date - c.checkout_time::date)) AS duration
FROM
  Checkout c
JOIN Return r ON c.id = r.checkout
JOIN LibraryHolding lh ON c.copy = lh.barcode
JOIN LibraryBranch lb ON lh.library = lb.code
GROUP BY lb.code, EXTRACT(YEAR FROM c.checkout_time);






-- Your query that answers the question goes below the "insert into" line:
-- Insert aggregated data into q1
INSERT INTO q1 (branch, year, events, sessions, registration, holdings, checkouts, duration)
WITH branch_years AS (
  SELECT lb.code AS branch, years.year
  FROM (SELECT DISTINCT code FROM LibraryBranch) lb
  CROSS JOIN (SELECT generate_series(2019, 2023) AS year) years
),
events_sessions AS (
  SELECT * FROM v_events_sessions
),
registrations AS (
  SELECT * FROM v_registrations
),
holdings AS (
  SELECT * FROM v_holdings
),
checkouts AS (
  SELECT * FROM v_checkouts
),
durations AS (
  SELECT * FROM v_duration
)
SELECT
  bys.branch,
  bys.year,
  COALESCE(es.events, 0) AS events,
  COALESCE(es.sessions, 0) AS sessions,
  COALESCE(reg.registration, 0) AS registration,
  COALESCE(h.holdings, 0) AS holdings,
  COALESCE(co.checkouts, 0) AS checkouts,
  COALESCE(du.duration, 0) AS duration
FROM
  branch_years bys
LEFT JOIN events_sessions es ON bys.branch = es.branch AND bys.year = es.year
LEFT JOIN registrations reg ON bys.branch = reg.branch AND bys.year = reg.year
LEFT JOIN holdings h ON bys.branch = h.branch
LEFT JOIN checkouts co ON bys.branch = co.branch AND bys.year = co.year
LEFT JOIN durations du ON bys.branch = du.branch AND bys.year = du.year
ORDER BY
  bys.branch, bys.year;

