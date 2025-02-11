-- Exploratory Data Analysis
	-- Follow-up to the data cleaning project
    -- Even though cleaning and EDA done seperately, will clean additional data in this project (stuff that I missed)
    -- No plan, just explore the data
    
SELECT *
FROM layoffs_cleaned;

SELECT MAX(total_laid_off), MAX(percentage_laid_off)
FROM layoffs_cleaned;
-- Percentage laid off at 1 means company went under, everyone was let go
-- One company let go of 12,000 employees at once

-- Find all companies that went under and order by most to least employees laid off at the time of company's closure
SELECT *
FROM layoffs_cleaned
WHERE percentage_laid_off = 1
ORDER BY total_laid_off DESC;
-- Two companies had to layoff at least 1,000 employees at time of closure
-- Top company had raised $1.6B, let's look into that

-- Let's include all laid off employees for these companies that went under, including different cycles of layoffs
SELECT *,
	SUM(total_laid_off) OVER (PARTITION BY company) AS total_laid_off_sum
FROM layoffs_cleaned
WHERE percentage_laid_off=1
ORDER BY SUM(total_laid_off) OVER (PARTITION BY company) DESC;
-- Sum seems to be identical in most cases, let's take a look at that

-- Check when sum of laid off doesn't match total laid off in that cycle
WITH t1 AS
(
SELECT *,
	SUM(total_laid_off) OVER (PARTITION BY company) AS total_laid_off_sum
FROM layoffs_cleaned
WHERE percentage_laid_off=1 
ORDER BY SUM(total_laid_off) OVER (PARTITION BY company) DESC
)
SELECT *
FROM t1
WHERE total_laid_off_sum != total_laid_off;
-- All companies that closed down experienced only one round of layoffs (at the time of closure)

-- Find all companies that went under and order by most to least funding
SELECT *
FROM layoffs_cleaned
WHERE percentage_laid_off = 1
ORDER BY funds_raised_millions DESC;
-- 5 companies went under with over $1B in funding

-- Curious to see which companies had the most layoffs
	-- NOTE: One company can have more than 1 entry, each row shows company at different stages
SELECT company,
	location,
    country,
    industry,
    SUM(total_laid_off) total_laid_off_sum
FROM layoffs_cleaned
GROUP BY company,
	location,
    industry,
    country
ORDER BY 5 DESC;
-- 3 of the 5 FAANG at the top
-- Diversity in industries, layoffs were all over
-- Bay Area and the West Coast hit hard
-- Amazon laid off 51.25% more employees than second place Google

-- What range of dates does this cover?
SELECT MIN(`date`),
	MAX(`date`)
FROM layoffs_cleaned;
-- Three year span after the start of COVID lockdowns

-- How many rows with null percentage_laid_off?
SELECT COUNT(*)
FROM layoffs_cleaned
WHERE percentage_laid_off IS NULL;
-- 423

-- How many rows with null total_laid_off?
SELECT COUNT(*)
FROM layoffs_cleaned
WHERE total_laid_off IS NULL;
-- 378

-- NOTE: No row is missing both. I deleted those rows in the cleaning project. Let's double-check.
SELECT COUNT(*)
FROM layoffs_cleaned
WHERE total_laid_off IS NULL
	AND percentage_laid_off IS NULL;

-- How many rows in total?
SELECT COUNT(*)
FROM layoffs_cleaned;
-- 1,995

-- Of the 1,995 rows, only 1,194 have both values

-- What industry got hit with the most total layoffs based on available data?
SELECT industry,
	SUM(total_laid_off)
FROM layoffs_cleaned
GROUP BY industry
ORDER BY 2 DESC;

-- What industry got hit with the most total layoffs in the United States?
SELECT industry,
	SUM(total_laid_off)
FROM layoffs_cleaned
WHERE country = "United States"
GROUP BY industry
ORDER BY 2 DESC;

-- How many companies are we dealing with in our dataset?
SELECT COUNT(DISTINCT company, location, industry)
FROM layoffs_cleaned;
-- 1668 companies
-- Most companies are represented by one row, others were in multiple stages during this 3-year span

-- How many companies per country?
SELECT country, 
	COUNT(DISTINCT company, location, industry)
FROM layoffs_cleaned
GROUP BY country
ORDER BY COUNT(DISTINCT company, location, industry) DESC;
-- Majority of companies in our dataset are from the United States

-- Let's look at layoffs by year
SELECT YEAR(`date`),
    SUM(total_laid_off)
FROM layoffs_cleaned
GROUP BY YEAR(`date`)
ORDER BY YEAR(`date`) DESC;
-- 2023 only 3 months included in the dataset, upward trend

-- Let's see layoffs and a rolling sum of layoffs by month
WITH t1 AS
(
SELECT YEAR(`date`) AS yr,
	MONTH(`date`) AS mth,
    SUM(total_laid_off) AS total_laid_off_mth
FROM layoffs_cleaned
GROUP BY YEAR(`date`), MONTH(`date`)
ORDER BY YEAR(`date`), MONTH(`date`)
)
SELECT yr,
	mth,
    total_laid_off_mth,
    SUM(total_laid_off_mth) OVER (ORDER BY yr, mth) AS rolling_sum
FROM t1
WHERE yr IS NOT NULL
	AND mth IS NOT NULL;
-- 383k layoffs from these companies in this three year span
-- The first three months of the pandemic saw massive layoffs
-- Layoffs pick up in May 2022 and sets a trend
-- January 2023 sees most layoffs by far (84k)
-- 2022-Oct-01 through 2023-Mar-06 see 189,457 layoffs
	-- 49.4% of layoffs in this dataset happend in a small stretch of time (14.3%)

-- Let's see which countries and industries got hit hardest during this time
SELECT industry,
	country,
	SUM(total_laid_off)
FROM layoffs_cleaned
WHERE `date` >= 2022-10-01
GROUP BY industry, country
ORDER BY 3 DESC;
-- Mostly US industries
-- India's education industry took a massive hit
-- Netherlands healthcare also took a hit
    
-- View layoffs of company by stage
SELECT stage,
	SUM(total_laid_off)
FROM layoffs_cleaned
GROUP BY stage
ORDER BY 2 DESC;
-- Post-IPO way more than the rest (about 10x more than second place)

-- View closed companies by stage
SELECT stage,
	COUNT(*)
FROM layoffs_cleaned
WHERE percentage_laid_off = 1
GROUP BY stage
ORDER BY 2 DESC;
-- Massive number of companies that went under didn't have a stage label
-- Companies in earlier stages were prone to shutdown 
-- 3 Post-IPO companies shut down

-- Let's see the 3 Post-IPO companies that went under
SELECT company,
	location,
    country,
    industry
FROM layoffs_staging
WHERE percentage_laid_off = 1
	AND stage LIKE 'post-ipo';
-- 2 Located in Melbourne, 2 in finance industry

-- Top 5 companies with most layoffs, by year
WITH t1 AS
(
SELECT YEAR(`date`) AS yr,
	company,
    SUM(total_laid_off) AS total_laid_off_sum,
    DENSE_RANK() OVER (PARTITION BY YEAR(`date`) 
						ORDER BY SUM(total_laid_off) DESC) AS rnk
FROM layoffs_cleaned
WHERE YEAR(`date`) IS NOT NULL
GROUP BY YEAR(`date`), company
)
SELECT * 
FROM t1
WHERE rnk <= 5;
-- Uber and Booking in 2020 makes a lot of sense due to restrictions, pre-vaccine
-- Lots of industries hit at different times, something to look at

-- Top 5 industries with most layoffs, by year
WITH t1 AS
(
SELECT YEAR(`date`) AS yr,
	industry,
    SUM(total_laid_off) AS total_laid_off_sum,
    DENSE_RANK() OVER (PARTITION BY YEAR(`date`) 
						ORDER BY SUM(total_laid_off) DESC) AS rnk
FROM layoffs_cleaned
WHERE YEAR(`date`) IS NOT NULL
GROUP BY YEAR(`date`), industry
)
SELECT * 
FROM t1
WHERE rnk <= 5;
-- Different industries take hits each year
-- Travel in the top 5 only in 2020 with travel restrictions
-- Education takes a hit in 2021, potentially due to online learning adjustments by academic institutions?
-- Healthcare takes major hits in 2022 and 2023, less need after the pandemic peak?
