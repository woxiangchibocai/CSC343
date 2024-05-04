-- Explorers Contest

-- You must not change the next 2 lines or the table definition.
SET SEARCH_PATH TO Library, public;
DROP TABLE IF EXISTS q4 cascade;

CREATE TABLE q4 (
    patronID CHAR(20) NOT NULL
);

-- Do this for each of the views that define your intermediate steps.
-- (But give them better names!) The IF EXISTS avoids generating an error
-- the first time this file is imported.
-- If you do not define any views, you can delete the lines about views.

-- Define views for your intermediate steps here:
DROP VIEW IF EXISTS patron_wards_per_year CASCADE;
CREATE VIEW patron_wards_per_year AS
SELECT
    es.patron,
    EXTRACT(YEAR FROM esch.edate) AS year,
    COUNT(DISTINCT lb.ward) AS unique_wards_visited
FROM
    EventSignUp es
JOIN LibraryEvent le ON es.event = le.id
JOIN LibraryRoom lr ON le.room = lr.id
JOIN LibraryBranch lb ON lr.library = lb.code
JOIN EventSchedule esch ON le.id = esch.event
GROUP BY es.patron, EXTRACT(YEAR FROM esch.edate);

DROP VIEW IF EXISTS total_wards CASCADE;
CREATE VIEW total_wards AS
SELECT COUNT(*) AS count FROM Ward;

DROP VIEW IF EXISTS explorers CASCADE;
CREATE VIEW explorers AS
SELECT
    pwp.year,
    pwp.patron
FROM
    patron_wards_per_year pwp, total_wards tw
WHERE
    pwp.unique_wards_visited = tw.count;

INSERT INTO q4
SELECT DISTINCT
    patron
FROM
    explorers;

