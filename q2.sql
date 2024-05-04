-- Overdue Items

-- You must not change the next 2 lines or the table definition.
SET SEARCH_PATH TO Library, public;
DROP TABLE IF EXISTS q2 cascade;

create table q2 (
    branch CHAR(5) NOT NULL,
    patron CHAR(20),
    title TEXT NOT NULL,
    overdue INT NOT NULL
);

-- Do this for each of the views that define your intermediate steps.
-- (But give them better names!) The IF EXISTS avoids generating an error
-- the first time this file is imported.
-- If you do not define any views, you can delete the lines about views.

-- Define views for your intermediate steps here:

-- Your query that answers the question goes below the "insert into" line:
-- Assuming the existence of necessary tables and relationships
-- This query is designed based on assumed schema and relationships
INSERT INTO q2
SELECT
    DISTINCT lb.code AS branch, -- Ensure unique rows for combinations of branch, patron, and title
    c.patron,
    h.title,
    CURRENT_DATE - (c.checkout_time::date + CASE
        WHEN h.htype = 'books' OR h.htype = 'audiobooks' THEN 21
        ELSE 7
    END) AS overdue
FROM
    Checkout c
JOIN LibraryHolding lh ON c.copy = lh.barcode
JOIN Holding h ON lh.holding = h.id
JOIN LibraryBranch lb ON lh.library = lb.code
JOIN Ward w ON lb.ward = w.id
LEFT JOIN Return r ON c.id = r.checkout
WHERE
    w.name = 'Parkdale-High Park'
    AND r.checkout IS NULL
    AND (c.checkout_time::date + CASE
        WHEN h.htype = 'books' OR h.htype = 'audiobooks' THEN 21
        ELSE 7
    END) < CURRENT_DATE;



