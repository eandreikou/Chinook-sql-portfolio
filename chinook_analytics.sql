
-- 1) Monthly revenue
SELECT
  STRFTIME('%Y-%m', i.InvoiceDate) AS ym,
  ROUND(SUM(il.UnitPrice * il.Quantity), 2) AS revenue
FROM Invoice i
JOIN InvoiceLine il ON il.InvoiceId = i.InvoiceId
GROUP BY ym
ORDER BY ym;

-- 2) Top 10 customers by revenue
SELECT c.CustomerId,
       c.FirstName || ' ' || c.LastName AS full_name,
       c.Country,
       ROUND(SUM(il.UnitPrice * il.Quantity), 2) AS revenue
FROM Customer c
JOIN Invoice i ON i.CustomerId = c.CustomerId
JOIN InvoiceLine il ON il.InvoiceId = i.InvoiceId
GROUP BY c.CustomerId, full_name, c.Country
ORDER BY revenue DESC
LIMIT 10;

-- 3) Revenue by country with avg per customer
WITH rev AS (
  SELECT c.Country, c.CustomerId,
         SUM(il.UnitPrice * il.Quantity) AS revenue
  FROM Customer c
  JOIN Invoice i ON i.CustomerId = c.CustomerId
  JOIN InvoiceLine il ON il.InvoiceId = i.InvoiceId
  GROUP BY c.Country, c.CustomerId
)
SELECT Country,
       ROUND(SUM(revenue),2) AS total_revenue,
       COUNT(DISTINCT CustomerId) AS customers,
       ROUND(AVG(revenue),2) AS avg_per_customer
FROM rev
GROUP BY Country
ORDER BY total_revenue DESC;

-- 4) AOV 
WITH per_invoice AS (
  SELECT i.InvoiceId,
         SUM(il.UnitPrice * il.Quantity) AS revenue
  FROM Invoice i
  JOIN InvoiceLine il ON il.InvoiceId = i.InvoiceId
  GROUP BY i.InvoiceId
)
SELECT ROUND(AVG(revenue), 2) AS AOV
FROM per_invoice;

-- 5) Top 10 tracks by revenue
SELECT t.TrackId, t.Name AS track, ar.Name AS artist,
       ROUND(SUM(il.UnitPrice * il.Quantity),2) AS revenue
FROM InvoiceLine il
JOIN Track t ON t.TrackId = il.TrackId
JOIN Album al ON al.AlbumId = t.AlbumId
JOIN Artist ar ON ar.ArtistId = al.ArtistId
GROUP BY t.TrackId, track, artist
ORDER BY revenue DESC
LIMIT 10;

-- 6) Top 10 albums by revenue
SELECT al.AlbumId, al.Title AS album, ar.Name AS artist,
       ROUND(SUM(il.UnitPrice * il.Quantity),2) AS revenue
FROM InvoiceLine il
JOIN Track t ON t.TrackId = il.TrackId
JOIN Album al ON al.AlbumId = t.AlbumId
JOIN Artist ar ON ar.ArtistId = al.ArtistId
GROUP BY al.AlbumId, album, artist
ORDER BY revenue DESC
LIMIT 10;

-- 7) Revenue by genre
SELECT g.Name AS genre,
       ROUND(SUM(il.UnitPrice * il.Quantity),2) AS revenue
FROM InvoiceLine il
JOIN Track t ON t.TrackId = il.TrackId
JOIN Genre g ON g.GenreId = t.GenreId
GROUP BY g.Name
ORDER BY revenue DESC;

-- 8) Running total & 3-month moving average (monthly)
WITH monthly AS (
  SELECT STRFTIME('%Y-%m', i.InvoiceDate) AS ym,
         SUM(il.UnitPrice * il.Quantity) AS revenue
  FROM Invoice i
  JOIN InvoiceLine il ON il.InvoiceId = i.InvoiceId
  GROUP BY ym
)
SELECT ym,
       ROUND(revenue,2) AS revenue,
       ROUND(SUM(revenue) OVER (ORDER BY ym
             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),2) AS running_total,
       ROUND(AVG(revenue) OVER (ORDER BY ym
             ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),2) AS ma_3m
FROM monthly
ORDER BY ym;

-- 9) RFM per customer (Recency days, Frequency orders, Monetary value)
WITH base AS (
  SELECT c.CustomerId,
         MAX(DATE(i.InvoiceDate)) AS last_order,
         COUNT(DISTINCT i.InvoiceId) AS freq,
         SUM(il.UnitPrice * il.Quantity) AS monetary
  FROM Customer c
  LEFT JOIN Invoice i ON i.CustomerId = c.CustomerId
  LEFT JOIN InvoiceLine il ON il.InvoiceId = i.InvoiceId
  GROUP BY c.CustomerId
),
params AS (SELECT MAX(DATE(InvoiceDate)) AS max_date FROM Invoice)
SELECT
  b.CustomerId,
  (julianday((SELECT max_date FROM params)) - julianday(b.last_order)) AS recency_days,
  b.freq,
  ROUND(COALESCE(b.monetary,0),2) AS monetary
FROM base b
ORDER BY monetary DESC;

-- 10) Potential churned customers (>180 days without purchase)
WITH lastp AS (
  SELECT c.CustomerId, MAX(DATE(i.InvoiceDate)) AS last_order
  FROM Customer c
  LEFT JOIN Invoice i ON i.CustomerId = c.CustomerId
  GROUP BY c.CustomerId
),
params AS (SELECT MAX(DATE(InvoiceDate)) AS ref_date FROM Invoice)
SELECT l.CustomerId, c.FirstName || ' ' || c.LastName AS full_name, c.Country, l.last_order
FROM lastp l
JOIN Customer c ON c.CustomerId = l.CustomerId
WHERE (julianday((SELECT ref_date FROM params)) - julianday(l.last_order)) > 180
ORDER BY l.last_order;

-- 11) Employee (Support Rep) performance by revenue of assigned customers
SELECT e.EmployeeId, e.FirstName || ' ' || e.LastName AS rep,
       ROUND(SUM(il.UnitPrice * il.Quantity),2) AS revenue
FROM Employee e
JOIN Customer c ON c.SupportRepId = e.EmployeeId
JOIN Invoice i ON i.CustomerId = c.CustomerId
JOIN InvoiceLine il ON il.InvoiceId = i.InvoiceId
GROUP BY e.EmployeeId, rep
ORDER BY revenue DESC;

-- 12) Revenue by playlist
SELECT pl.Name AS playlist,
       ROUND(SUM(il.UnitPrice * il.Quantity),2) AS revenue
FROM Playlist pl
JOIN PlaylistTrack pt ON pt.PlaylistId = pl.PlaylistId
JOIN Track t ON t.TrackId = pt.TrackId
JOIN InvoiceLine il ON il.TrackId = t.TrackId
GROUP BY pl.Name
ORDER BY revenue DESC;

