--1. Find the artist with the highest popularity value for each genre.

SELECT genres, name, popularity
FROM artists
WHERE (genres, popularity) IN (
  SELECT genres, MAX(popularity)
  FROM artists
  GROUP BY genres
)
ORDER BY popularity DESC;


--2. Extract the year from the release_date column and find how many songs were released each year. Sort the result by year descending.

SELECT
  SUBSTR(release_date, 1, 4) AS year,
  COUNT(*) AS track_count
FROM tracks
GROUP BY year
ORDER BY year DESC;

--3. Convert duration_ms into minutes and find the names and durations of the 10 longest songs.

SELECT
  name,
  ROUND(duration_ms / 60000.0, 2) AS duration_min
FROM tracks
ORDER BY duration_ms DESC
LIMIT 10;

--4. Calculate the average popularity value of each artist’s songs. Join with the artists table using the id_artists column.
--Show only artists with at least 5 songs.

SELECT
  a.name,
  ROUND(AVG(t.popularity), 2) AS avg_popularity,
  COUNT(t.id) AS track_count
FROM tracks t
JOIN artists a ON REPLACE(REPLACE(REPLACE(t.id_artists, '[', ''), ']', ''), '''', '') = a.id
GROUP BY a.id, a.name
HAVING COUNT(t.id) >= 5
ORDER BY avg_popularity DESC;

--5. Show the names, follower counts, and total number of songs for the top 10 artists with the most followers.

SELECT
  a.name,
  a.followers,
  COUNT(t.id) AS total_tracks
FROM artists a
LEFT JOIN tracks t ON t.id_artists = a.id
GROUP BY a.id, a.name, a.followers
ORDER BY a.followers DESC
LIMIT 10;

--6. For each artist, find the single most popular song using the ROW_NUMBER() window function.

SELECT name, id_artists, popularity
FROM (
  SELECT
    name,
    id_artists,
    popularity,
    ROW_NUMBER() OVER (
      PARTITION BY id_artists
      ORDER BY popularity DESC
    ) AS rn
  FROM tracks
) ranked
WHERE rn = 1
ORDER BY popularity DESC;

--7. Sort songs by release year and calculate the cumulative (running total) number of songs for each year.

SELECT
  year,
  track_count,
  SUM(track_count) OVER (
    ORDER BY year
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS cumulative_tracks
FROM (
  SELECT
    SUBSTR(release_date, 1, 4) AS year,
    COUNT(*) AS track_count
  FROM tracks
  GROUP BY year
) y
ORDER BY year;

--8. Calculate the percentile rank of each artist’s popularity among all artists using PERCENT_RANK().
--Show artists in the top 10% by popularity.

SELECT name, popularity, pct_rank
FROM (
  SELECT
    name,
    popularity,
    ROUND(PERCENT_RANK() OVER (
      ORDER BY popularity
    ) * 100, 2) AS pct_rank
  FROM artists
) p
WHERE pct_rank >= 90
ORDER BY pct_rank DESC;

--9. Categorize each song into 4 groups based on energy and valence values:
--Happy (high energy + high valence),
--Angry (high energy + low valence),
--Chill (low energy + high valence),
--Sad (low energy + low valence).
--Show how many songs belong to each category.

SELECT
  CASE
    WHEN energy >= 0.5 AND valence >= 0.5 THEN 'Happy'
    WHEN energy >= 0.5 AND valence < 0.5  THEN 'Angry'
    WHEN energy < 0.5  AND valence >= 0.5 THEN 'Chill'
    ELSE 'Sad'
  END AS mood,
  COUNT(*) AS track_count,
  ROUND(AVG(popularity), 2) AS avg_popularity
FROM tracks
GROUP BY mood
ORDER BY track_count DESC;

--10. Find the top 3 songs for each artist based on popularity using DENSE_RANK().
--Songs with the same popularity should receive the same rank.

SELECT
  a.name AS artist_name,
  t.name AS track_name,
  t.popularity,
  t.dr
FROM (
  SELECT
    name, id_artists, popularity,
    DENSE_RANK() OVER (
      PARTITION BY id_artists
      ORDER BY popularity DESC
    ) AS dr
  FROM tracks
) t
JOIN artists a ON REPLACE(REPLACE(REPLACE(t.id_artists, '[', ''), ']', ''), '''', '') = a.id
WHERE t.dr <= 1
ORDER BY a.name, t.dr;

--11. Show each artist’s follower count together with the average track popularity.
--Divide the results into 4 quartiles based on followers using NTILE().

SELECT
  a.name,
  a.followers,
  ROUND(AVG(t.popularity), 2) AS avg_track_pop,
  NTILE(4) OVER (ORDER BY a.followers) AS follower_quartile
FROM artists a
JOIN tracks t ON REPLACE(REPLACE(REPLACE(t.id_artists, '[', ''), ']', ''), '''', '') = a.id
GROUP BY a.id, a.name, a.followers
ORDER BY follower_quartile DESC, avg_track_pop DESC;


--12. Find songs whose instrumentalness value is more than 2 standard deviations above the average (statistical outliers).

SELECT name, instrumentalness, popularity
FROM tracks
WHERE instrumentalness > (
  SELECT
    AVG(instrumentalness) + 2 * SQRT(AVG(instrumentalness*instrumentalness) - AVG(instrumentalness)*AVG(instrumentalness))
  FROM tracks
)
ORDER BY instrumentalness DESC;


--13. Calculate the yearly song count for each artist.
--Use LAG() to show the previous year’s count and calculate the growth percentage.

WITH yearly_counts AS (
  SELECT
    id_artists,
    SUBSTR(release_date, 1, 4) AS year,
    COUNT(*) AS cnt
  FROM tracks
  GROUP BY id_artists, year
)
SELECT
  a.name,
  yc.year,
  yc.cnt,
  LAG(yc.cnt) OVER (
    PARTITION BY yc.id_artists ORDER BY yc.year
  ) AS prev_year_cnt,
  ROUND(
    (yc.cnt - LAG(yc.cnt) OVER (
      PARTITION BY yc.id_artists ORDER BY yc.year
    )) * 100.0 /
    NULLIF(LAG(yc.cnt) OVER (
      PARTITION BY yc.id_artists ORDER BY yc.year
    ), 0),
  2) AS growth_pct
FROM yearly_counts yc
JOIN artists a ON REPLACE(REPLACE(REPLACE(yc.id_artists, '[', ''), ']', ''), '''', '') = a.id
ORDER BY a.name, yc.year;
