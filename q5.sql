-- Lure Them Back

-- You must not change the next 2 lines or the table definition.
SET SEARCH_PATH TO Library, public;
DROP TABLE IF EXISTS q5 cascade;

CREATE TABLE q5 (
    patronID CHAR(20) NOT NULL,
    email TEXT NOT NULL,
    usage INT NOT NULL,
    decline INT NOT NULL,
    missed INT NOT NULL
);

-- Do this for each of the views that define your intermediate steps.
-- (But give them better names!) The IF EXISTS avoids generating an error
-- the first time this file is imported.
-- If you do not define any views, you can delete the lines about views.
DROP VIEW IF EXISTS PatronMonthlyActivity CASCADE;
DROP VIEW IF EXISTS YearlyActivitySummary CASCADE;
DROP VIEW IF EXISTS CheckoutSummary CASCADE;
DROP VIEW IF EXISTS EligiblePatrons CASCADE;


-- Define views for your intermediate steps here:
CREATE VIEW PatronMonthlyActivity AS
SELECT
    patron,
    EXTRACT(YEAR FROM checkout_time) AS year,
    EXTRACT(MONTH FROM checkout_time) AS month
FROM
    Checkout
GROUP BY
    patron, EXTRACT(YEAR FROM checkout_time), EXTRACT(MONTH FROM checkout_time);


CREATE VIEW YearlyActivitySummary AS
SELECT
    patron,
    COUNT(DISTINCT CASE WHEN year = 2022 THEN month END) AS active_months_2022,
    COUNT(DISTINCT CASE WHEN year = 2023 THEN month END) AS active_months_2023,
    MAX(CASE WHEN year = 2024 THEN 1 ELSE 0 END) AS active_in_2024,
    12 - COUNT(DISTINCT CASE WHEN year = 2023 THEN month END) AS missed_2023
FROM
    PatronMonthlyActivity
GROUP BY
    patron;


CREATE VIEW CheckoutSummary AS
SELECT
    patron,
    COUNT(DISTINCT copy) AS total_unique_checkouts,
    COUNT(CASE WHEN EXTRACT(YEAR FROM checkout_time) = 2022 THEN 1 END) AS checkouts_2022,
    COUNT(CASE WHEN EXTRACT(YEAR FROM checkout_time) = 2023 THEN 1 END) AS checkouts_2023
FROM
    Checkout
GROUP BY
    patron;


CREATE VIEW EligiblePatrons AS
SELECT
    c.patron AS patronID,
    COALESCE(p.email, 'none') AS email,
    c.total_unique_checkouts AS usage,
    (c.checkouts_2022 - c.checkouts_2023) AS decline,
    y.missed_2023 AS missed
FROM
    CheckoutSummary c
JOIN
    YearlyActivitySummary y ON c.patron = y.patron
JOIN
    Patron p ON c.patron = p.card_number
WHERE
    y.active_months_2022 = 12
    AND y.active_months_2023 >= 5
    AND y.missed_2023 > 0
    AND y.active_in_2024 = 0;




-- Your query that answers the question goes below the "insert into" line:
INSERT INTO q5
SELECT patronID, email, usage, decline, missed
FROM EligiblePatrons;

