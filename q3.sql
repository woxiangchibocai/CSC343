-- Promotion

-- You must not change the next 2 lines, the domain definition, or the table definition.
SET SEARCH_PATH TO Library, public;
DROP TABLE IF EXISTS q3 cascade;

DROP DOMAIN IF EXISTS patronCategory;
create domain patronCategory as varchar(10)
  check (value in ('inactive', 'reader', 'doer', 'keener'));

create table q3 (
    patronID Char(20) NOT NULL,
    category patronCategory
);


-- Do this for each of the views that define your intermediate steps.
-- (But give them better names!) The IF EXISTS avoids generating an error
-- the first time this file is imported.
-- If you do not define any views, you can delete the lines about views.
DROP VIEW IF EXISTS libraries_used_by_patron CASCADE;
DROP VIEW IF EXISTS total_checkouts_per_patron CASCADE;
DROP VIEW IF EXISTS total_events_per_patron CASCADE;
DROP VIEW IF EXISTS library_activity_averages CASCADE;
DROP VIEW IF EXISTS patron_categories CASCADE;
DROP VIEW IF EXISTS library_checkouts_averages CASCADE;
DROP VIEW IF EXISTS library_events_averages CASCADE;
DROP VIEW IF EXISTS events_per_patron CASCADE;
DROP VIEW IF EXISTS checkouts_per_patron CASCADE;

CREATE VIEW libraries_used_by_patron AS
SELECT DISTINCT c.patron, lh.library
FROM Checkout c
JOIN LibraryHolding lh ON c.copy = lh.barcode
UNION
SELECT DISTINCT esu.patron, lr.library
FROM EventSignUp esu
JOIN LibraryEvent le ON esu.event = le.id
JOIN LibraryRoom lr ON le.room = lr.id;

CREATE VIEW total_checkouts_per_patron AS
SELECT
  patron,
  COUNT(*) AS total_checkouts
FROM Checkout
GROUP BY patron;

CREATE VIEW total_events_per_patron AS
SELECT
  patron,
  COUNT(*) AS total_events
FROM EventSignUp 
GROUP BY patron;

CREATE VIEW checkouts_per_patron AS
SELECT
  c.patron,
  lh.library,
  COUNT(*) AS num_checkouts
FROM
  Checkout c
JOIN LibraryHolding lh ON c.copy = lh.barcode
GROUP BY c.patron, lh.library;


CREATE VIEW library_checkouts_averages AS
SELECT lc.patron,
      sum(tc.total_checkouts)/count(DISTINCT lc.Join_patron) AS avg_checkouts
FROM(
SELECT DISTINCT lub.patron AS patron,
      cpp.patron AS Join_patron
FROM libraries_used_by_patron lub
JOIN checkouts_per_patron cpp
ON lub.library = cpp.library
) lc
JOIN total_checkouts_per_patron tc
ON tc.patron = lc.Join_patron
GROUP by lc.patron;


CREATE VIEW events_per_patron AS
SELECT
  esu.patron,
  lb.code AS library,
  COUNT(*) AS num_events
FROM
  EventSignUp esu
JOIN LibraryEvent le ON esu.event = le.id
JOIN LibraryRoom lr ON le.room = lr.id
JOIN LibraryBranch lb ON lr.library = lb.code
GROUP BY esu.patron, lb.code;



CREATE VIEW library_events_averages AS
SELECT
le.patron,
sum(te.total_events)/count(DISTINCT le.Join_patron) AS avg_events
FROM(
SELECT DISTINCT lub.patron AS patron,
      epp.patron AS Join_patron
FROM libraries_used_by_patron lub
JOIN events_per_patron epp
ON lub.library = epp.library
) le
JOIN total_events_per_patron te
ON te.patron = le.Join_patron
GROUP by le.patron;





CREATE VIEW patron_categories AS
SELECT
    p.card_number AS patronID,
    CASE
    -- Treat missing values as 0 for comparisons
    WHEN COALESCE(tc.total_checkouts, 0) < GREATEST(lc.avg_checkouts * 0.25, 1) AND
         COALESCE(te.total_events, 0) < GREATEST(le.avg_events * 0.25, 1) THEN 'inactive'

    WHEN COALESCE(tc.total_checkouts, 0) > (lc.avg_checkouts) * 0.75 AND
         COALESCE(te.total_events, 0) > le.avg_events* 0.75 THEN 'keener'

    WHEN COALESCE(tc.total_checkouts, 0) < GREATEST(lc.avg_checkouts * 0.25, 1) AND
         COALESCE(te.total_events, 0) > le.avg_events * 0.75 THEN 'doer'

    WHEN COALESCE(tc.total_checkouts, 0) > (lc.avg_checkouts) * 0.75 AND
         COALESCE(te.total_events, 0) < GREATEST(le.avg_events* 0.25, 1) THEN 'reader'

    ELSE NULL  -- For patrons that don't clearly fall into any category
  END AS category
FROM Patron p
LEFT JOIN total_checkouts_per_patron tc ON p.card_number = tc.patron
LEFT JOIN total_events_per_patron te ON p.card_number = te.patron
LEFT JOIN library_checkouts_averages lc ON p.card_number=lc.patron
LEFT JOIN library_events_averages le ON p.card_number=le.patron;
--should select  something that includes all patron


INSERT INTO q3
SELECT DISTINCT patronID, category 
FROM patron_categories
WHERE category IS NOT NULL
ORDER by patronID;


