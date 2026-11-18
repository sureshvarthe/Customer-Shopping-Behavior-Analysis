/*
===============================================================================
PROJECT : Customer Shopping Behavior Analysis
DATABASE: customer_behavior
TABLE   : customer_shopping_behavior
DIALECT : MySQL 8.0

IMPORTANT:
1. Import your CSV into MySQL first.
2. The imported raw table must be named `customer_shopping_behavior`.
3. The source columns must match the names used below (including spaces).
4. This script preserves the raw table and creates a cleaned table named
   `customer_shopping_behavior_cleaned`.
5. Review the validation queries before using the results in your dashboard.

The script is designed for a common customer shopping behavior dataset where
each row represents one customer/purchase record. Do not assume Customer ID is
a repeat-transaction key without checking the data.
===============================================================================
*/

CREATE DATABASE IF NOT EXISTS customer_behavior;
USE customer_behavior;


/*=============================================================================
  01. DATA EXPLORATION
=============================================================================*/

-- 1.1 Preview records
SELECT *
FROM customer_shopping_behavior
LIMIT 10;

-- 1.2 Total number of records
SELECT COUNT(*) AS total_records
FROM customer_shopping_behavior;

-- 1.3 Number of distinct customers
SELECT COUNT(DISTINCT `Customer ID`) AS distinct_customer_ids
FROM customer_shopping_behavior;

-- 1.4 Inspect source columns and data types
DESCRIBE customer_shopping_behavior;

-- 1.5 Check distinct values in important categorical columns
SELECT DISTINCT `Gender`
FROM customer_shopping_behavior
ORDER BY `Gender`;

SELECT DISTINCT `Category`
FROM customer_shopping_behavior
ORDER BY `Category`;

SELECT DISTINCT `Season`
FROM customer_shopping_behavior
ORDER BY `Season`;

SELECT DISTINCT `Subscription Status`
FROM customer_shopping_behavior
ORDER BY `Subscription Status`;

SELECT DISTINCT `Discount Applied`
FROM customer_shopping_behavior
ORDER BY `Discount Applied`;

SELECT DISTINCT `Frequency of Purchases`
FROM customer_shopping_behavior
ORDER BY `Frequency of Purchases`;


/*=============================================================================
  02. DATA QUALITY CHECKS ON RAW DATA
=============================================================================*/

-- 2.1 Check NULL or blank values in each source column
SELECT
    SUM(`Customer ID` IS NULL OR TRIM(CAST(`Customer ID` AS CHAR)) = '') AS missing_customer_id,
    SUM(`Age` IS NULL OR TRIM(CAST(`Age` AS CHAR)) = '') AS missing_age,
    SUM(`Gender` IS NULL OR TRIM(`Gender`) = '') AS missing_gender,
    SUM(`Item Purchased` IS NULL OR TRIM(`Item Purchased`) = '') AS missing_item,
    SUM(`Category` IS NULL OR TRIM(`Category`) = '') AS missing_category,
    SUM(`Purchase Amount (USD)` IS NULL OR TRIM(CAST(`Purchase Amount (USD)` AS CHAR)) = '') AS missing_purchase_amount,
    SUM(`Location` IS NULL OR TRIM(`Location`) = '') AS missing_location,
    SUM(`Size` IS NULL OR TRIM(`Size`) = '') AS missing_size,
    SUM(`Color` IS NULL OR TRIM(`Color`) = '') AS missing_color,
    SUM(`Season` IS NULL OR TRIM(`Season`) = '') AS missing_season,
    SUM(`Review Rating` IS NULL OR TRIM(CAST(`Review Rating` AS CHAR)) = '') AS missing_review_rating,
    SUM(`Subscription Status` IS NULL OR TRIM(`Subscription Status`) = '') AS missing_subscription_status,
    SUM(`Payment Method` IS NULL OR TRIM(`Payment Method`) = '') AS missing_payment_method,
    SUM(`Shipping Type` IS NULL OR TRIM(`Shipping Type`) = '') AS missing_shipping_type,
    SUM(`Discount Applied` IS NULL OR TRIM(`Discount Applied`) = '') AS missing_discount_applied,
    SUM(`Promo Code Used` IS NULL OR TRIM(`Promo Code Used`) = '') AS missing_promo_code_used,
    SUM(`Previous Purchases` IS NULL OR TRIM(CAST(`Previous Purchases` AS CHAR)) = '') AS missing_previous_purchases,
    SUM(`Preferred Payment Method` IS NULL OR TRIM(`Preferred Payment Method`) = '') AS missing_preferred_payment_method,
    SUM(`Frequency of Purchases` IS NULL OR TRIM(`Frequency of Purchases`) = '') AS missing_purchase_frequency
FROM customer_shopping_behavior;

-- 2.2 Check duplicate Customer IDs.
-- This is a diagnostic only: do not delete duplicates until you know whether
-- Customer ID is intended to be unique in your dataset.
SELECT
    `Customer ID`,
    COUNT(*) AS record_count
FROM customer_shopping_behavior
GROUP BY `Customer ID`
HAVING COUNT(*) > 1
ORDER BY record_count DESC;

-- 2.3 Check invalid numeric values after conversion
SELECT *
FROM customer_shopping_behavior
WHERE
    (`Age` IS NOT NULL AND CAST(NULLIF(TRIM(CAST(`Age` AS CHAR)), '') AS SIGNED) NOT BETWEEN 1 AND 100)
    OR (`Purchase Amount (USD)` IS NOT NULL AND CAST(NULLIF(TRIM(CAST(`Purchase Amount (USD)` AS CHAR)), '') AS DECIMAL(10,2)) < 0)
    OR (`Review Rating` IS NOT NULL AND CAST(NULLIF(TRIM(CAST(`Review Rating` AS CHAR)), '') AS DECIMAL(4,2)) NOT BETWEEN 0 AND 5)
    OR (`Previous Purchases` IS NOT NULL AND CAST(NULLIF(TRIM(CAST(`Previous Purchases` AS CHAR)), '') AS SIGNED) < 0);


/*=============================================================================
  03. CREATE A CLEANED TABLE
  - Raw table remains unchanged.
  - Standardizes column names to snake_case.
  - Trims text fields and converts blank strings to NULL.
  - Converts numeric fields to appropriate numeric types.
  - Normalizes Yes/No fields.
  - Invalid age, rating, amount, and previous-purchase values become NULL.
=============================================================================*/

DROP TABLE IF EXISTS customer_shopping_behavior_cleaned;

CREATE TABLE customer_shopping_behavior_cleaned AS
SELECT
    CAST(NULLIF(TRIM(CAST(`Customer ID` AS CHAR)), '') AS UNSIGNED) AS customer_id,

    CASE
        WHEN CAST(NULLIF(TRIM(CAST(`Age` AS CHAR)), '') AS SIGNED) BETWEEN 1 AND 100
        THEN CAST(NULLIF(TRIM(CAST(`Age` AS CHAR)), '') AS UNSIGNED)
        ELSE NULL
    END AS age,

    NULLIF(TRIM(`Gender`), '') AS gender,
    NULLIF(TRIM(`Item Purchased`), '') AS item_purchased,
    NULLIF(TRIM(`Category`), '') AS category,

    CASE
        WHEN CAST(NULLIF(TRIM(CAST(`Purchase Amount (USD)` AS CHAR)), '') AS DECIMAL(10,2)) >= 0
        THEN CAST(NULLIF(TRIM(CAST(`Purchase Amount (USD)` AS CHAR)), '') AS DECIMAL(10,2))
        ELSE NULL
    END AS purchase_amount_usd,

    NULLIF(TRIM(`Location`), '') AS location,
    NULLIF(TRIM(`Size`), '') AS size,
    NULLIF(TRIM(`Color`), '') AS color,
    NULLIF(TRIM(`Season`), '') AS season,

    CASE
        WHEN CAST(NULLIF(TRIM(CAST(`Review Rating` AS CHAR)), '') AS DECIMAL(4,2)) BETWEEN 0 AND 5
        THEN CAST(NULLIF(TRIM(CAST(`Review Rating` AS CHAR)), '') AS DECIMAL(4,2))
        ELSE NULL
    END AS review_rating,

    CASE
        WHEN UPPER(TRIM(`Subscription Status`)) IN ('YES', 'NO')
        THEN CONCAT(UPPER(LEFT(TRIM(`Subscription Status`), 1)),
                    LOWER(SUBSTRING(TRIM(`Subscription Status`), 2)))
        ELSE NULLIF(TRIM(`Subscription Status`), '')
    END AS subscription_status,

    NULLIF(TRIM(`Payment Method`), '') AS payment_method,
    NULLIF(TRIM(`Shipping Type`), '') AS shipping_type,

    CASE
        WHEN UPPER(TRIM(`Discount Applied`)) = 'YES' THEN 'Yes'
        WHEN UPPER(TRIM(`Discount Applied`)) = 'NO' THEN 'No'
        ELSE NULLIF(TRIM(`Discount Applied`), '')
    END AS discount_applied,

    CASE
        WHEN UPPER(TRIM(`Promo Code Used`)) = 'YES' THEN 'Yes'
        WHEN UPPER(TRIM(`Promo Code Used`)) = 'NO' THEN 'No'
        ELSE NULLIF(TRIM(`Promo Code Used`), '')
    END AS promo_code_used,

    CASE
        WHEN CAST(NULLIF(TRIM(CAST(`Previous Purchases` AS CHAR)), '') AS SIGNED) >= 0
        THEN CAST(NULLIF(TRIM(CAST(`Previous Purchases` AS CHAR)), '') AS UNSIGNED)
        ELSE NULL
    END AS previous_purchases,

    NULLIF(TRIM(`Preferred Payment Method`), '') AS preferred_payment_method,
    NULLIF(TRIM(`Frequency of Purchases`), '') AS purchase_frequency

FROM customer_shopping_behavior;


-- 3.1 Verify cleaned table
SELECT *
FROM customer_shopping_behavior_cleaned
LIMIT 10;

SELECT COUNT(*) AS cleaned_record_count
FROM customer_shopping_behavior_cleaned;

-- 3.2 Check NULLs in the cleaned table
SELECT
    SUM(customer_id IS NULL) AS missing_customer_id,
    SUM(age IS NULL) AS missing_age,
    SUM(gender IS NULL) AS missing_gender,
    SUM(item_purchased IS NULL) AS missing_item,
    SUM(category IS NULL) AS missing_category,
    SUM(purchase_amount_usd IS NULL) AS missing_purchase_amount,
    SUM(review_rating IS NULL) AS missing_review_rating,
    SUM(previous_purchases IS NULL) AS missing_previous_purchases
FROM customer_shopping_behavior_cleaned;

-- 3.3 Check whether Customer IDs repeat in the cleaned table
SELECT customer_id, COUNT(*) AS record_count
FROM customer_shopping_behavior_cleaned
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY record_count DESC;


/*=============================================================================
  04. CUSTOMER ANALYSIS
=============================================================================*/

-- 4.1 Customer count by gender
SELECT
    gender,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_shopping_behavior_cleaned), 2) AS customer_percentage
FROM customer_shopping_behavior_cleaned
GROUP BY gender
ORDER BY customer_count DESC;

-- 4.2 Average purchase amount by gender
SELECT
    gender,
    COUNT(*) AS records,
    ROUND(AVG(purchase_amount_usd), 2) AS average_purchase_amount,
    ROUND(SUM(purchase_amount_usd), 2) AS total_purchase_amount
FROM customer_shopping_behavior_cleaned
GROUP BY gender
ORDER BY average_purchase_amount DESC;

-- 4.3 Customer age groups
SELECT
    CASE
        WHEN age < 20 THEN 'Under 20'
        WHEN age BETWEEN 20 AND 29 THEN '20-29'
        WHEN age BETWEEN 30 AND 39 THEN '30-39'
        WHEN age BETWEEN 40 AND 49 THEN '40-49'
        WHEN age BETWEEN 50 AND 59 THEN '50-59'
        WHEN age >= 60 THEN '60+'
        ELSE 'Unknown'
    END AS age_group,
    COUNT(*) AS customer_count,
    ROUND(AVG(purchase_amount_usd), 2) AS average_purchase_amount
FROM customer_shopping_behavior_cleaned
GROUP BY age_group
ORDER BY
    CASE age_group
        WHEN 'Under 20' THEN 1
        WHEN '20-29' THEN 2
        WHEN '30-39' THEN 3
        WHEN '40-49' THEN 4
        WHEN '50-59' THEN 5
        WHEN '60+' THEN 6
        ELSE 7
    END;

-- 4.4 Subscription status analysis
SELECT
    subscription_status,
    COUNT(*) AS customer_count,
    ROUND(AVG(purchase_amount_usd), 2) AS average_purchase_amount,
    ROUND(SUM(purchase_amount_usd), 2) AS total_purchase_amount
FROM customer_shopping_behavior_cleaned
GROUP BY subscription_status
ORDER BY total_purchase_amount DESC;

-- 4.5 Previous purchase history groups
SELECT
    CASE
        WHEN previous_purchases BETWEEN 0 AND 5 THEN '0-5'
        WHEN previous_purchases BETWEEN 6 AND 10 THEN '6-10'
        WHEN previous_purchases BETWEEN 11 AND 20 THEN '11-20'
        WHEN previous_purchases BETWEEN 21 AND 30 THEN '21-30'
        WHEN previous_purchases > 30 THEN '31+'
        ELSE 'Unknown'
    END AS previous_purchase_group,
    COUNT(*) AS customer_count,
    ROUND(AVG(purchase_amount_usd), 2) AS average_purchase_amount
FROM customer_shopping_behavior_cleaned
GROUP BY previous_purchase_group
ORDER BY MIN(COALESCE(previous_purchases, 999999));


/*=============================================================================
  05. PRODUCT AND CATEGORY ANALYSIS
=============================================================================*/

-- 5.1 Revenue and purchase records by category
SELECT
    category,
    COUNT(*) AS purchase_records,
    ROUND(SUM(purchase_amount_usd), 2) AS total_revenue,
    ROUND(AVG(purchase_amount_usd), 2) AS average_purchase_amount
FROM customer_shopping_behavior_cleaned
GROUP BY category
ORDER BY total_revenue DESC;

-- 5.2 Most frequently purchased items
SELECT
    item_purchased,
    COUNT(*) AS purchase_count,
    ROUND(SUM(purchase_amount_usd), 2) AS total_revenue
FROM customer_shopping_behavior_cleaned
GROUP BY item_purchased
ORDER BY purchase_count DESC, total_revenue DESC
LIMIT 10;

-- 5.3 Category preference by gender
SELECT
    gender,
    category,
    COUNT(*) AS purchase_count,
    ROUND(AVG(purchase_amount_usd), 2) AS average_purchase_amount
FROM customer_shopping_behavior_cleaned
GROUP BY gender, category
ORDER BY gender, purchase_count DESC;

-- 5.4 Product size analysis
SELECT
    size,
    COUNT(*) AS purchase_count,
    ROUND(SUM(purchase_amount_usd), 2) AS total_revenue
FROM customer_shopping_behavior_cleaned
GROUP BY size
ORDER BY purchase_count DESC;

-- 5.5 Top colors by purchase count
SELECT
    color,
    COUNT(*) AS purchase_count
FROM customer_shopping_behavior_cleaned
GROUP BY color
ORDER BY purchase_count DESC
LIMIT 10;


/*=============================================================================
  06. DISCOUNT AND PROMOTION ANALYSIS
=============================================================================*/

-- 6.1 Discount usage and purchase amount
SELECT
    discount_applied,
    COUNT(*) AS purchase_count,
    ROUND(AVG(purchase_amount_usd), 2) AS average_purchase_amount,
    ROUND(SUM(purchase_amount_usd), 2) AS total_purchase_amount
FROM customer_shopping_behavior_cleaned
GROUP BY discount_applied
ORDER BY purchase_count DESC;

-- 6.2 Compare discount and promo-code usage
SELECT
    discount_applied,
    promo_code_used,
    COUNT(*) AS purchase_count,
    ROUND(AVG(purchase_amount_usd), 2) AS average_purchase_amount
FROM customer_shopping_behavior_cleaned
GROUP BY discount_applied, promo_code_used
ORDER BY purchase_count DESC;

-- 6.3 Discount usage by product category
SELECT
    category,
    discount_applied,
    COUNT(*) AS purchase_count,
    ROUND(AVG(purchase_amount_usd), 2) AS average_purchase_amount
FROM customer_shopping_behavior_cleaned
GROUP BY category, discount_applied
ORDER BY category, purchase_count DESC;


/*=============================================================================
  07. PURCHASE BEHAVIOR ANALYSIS
=============================================================================*/

-- 7.1 Purchases by season
SELECT
    season,
    COUNT(*) AS purchase_count,
    ROUND(SUM(purchase_amount_usd), 2) AS total_revenue,
    ROUND(AVG(purchase_amount_usd), 2) AS average_purchase_amount
FROM customer_shopping_behavior_cleaned
GROUP BY season
ORDER BY total_revenue DESC;

-- 7.2 Purchase frequency distribution
SELECT
    purchase_frequency,
    COUNT(*) AS customer_count,
    ROUND(AVG(purchase_amount_usd), 2) AS average_purchase_amount
FROM customer_shopping_behavior_cleaned
GROUP BY purchase_frequency
ORDER BY customer_count DESC;

-- 7.3 Payment method analysis
SELECT
    payment_method,
    COUNT(*) AS purchase_count,
    ROUND(SUM(purchase_amount_usd), 2) AS total_revenue,
    ROUND(AVG(purchase_amount_usd), 2) AS average_purchase_amount
FROM customer_shopping_behavior_cleaned
GROUP BY payment_method
ORDER BY purchase_count DESC;

-- 7.4 Preferred payment method
SELECT
    preferred_payment_method,
    COUNT(*) AS customer_count
FROM customer_shopping_behavior_cleaned
GROUP BY preferred_payment_method
ORDER BY customer_count DESC;

-- 7.5 Shipping type analysis
SELECT
    shipping_type,
    COUNT(*) AS purchase_count,
    ROUND(AVG(purchase_amount_usd), 2) AS average_purchase_amount
FROM customer_shopping_behavior_cleaned
GROUP BY shipping_type
ORDER BY purchase_count DESC;

-- 7.6 Location analysis
SELECT
    location,
    COUNT(*) AS purchase_count,
    ROUND(SUM(purchase_amount_usd), 2) AS total_revenue,
    ROUND(AVG(purchase_amount_usd), 2) AS average_purchase_amount
FROM customer_shopping_behavior_cleaned
GROUP BY location
ORDER BY total_revenue DESC
LIMIT 15;

-- 7.7 Review rating by product category
SELECT
    category,
    ROUND(AVG(review_rating), 2) AS average_review_rating,
    COUNT(review_rating) AS number_of_ratings
FROM customer_shopping_behavior_cleaned
GROUP BY category
ORDER BY average_review_rating DESC;


/*=============================================================================
  08. ADVANCED SQL: CTEs AND WINDOW FUNCTIONS
=============================================================================*/

-- 8.1 Rank product categories by revenue
WITH category_revenue AS (
    SELECT
        category,
        SUM(purchase_amount_usd) AS total_revenue
    FROM customer_shopping_behavior_cleaned
    GROUP BY category
)
SELECT
    category,
    ROUND(total_revenue, 2) AS total_revenue,
    DENSE_RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank
FROM category_revenue
ORDER BY revenue_rank;

-- 8.2 Top 3 products by purchase count within each category
WITH item_category_counts AS (
    SELECT
        category,
        item_purchased,
        COUNT(*) AS purchase_count
    FROM customer_shopping_behavior_cleaned
    GROUP BY category, item_purchased
),
ranked_items AS (
    SELECT
        category,
        item_purchased,
        purchase_count,
        DENSE_RANK() OVER (
            PARTITION BY category
            ORDER BY purchase_count DESC
        ) AS item_rank
    FROM item_category_counts
)
SELECT
    category,
    item_purchased,
    purchase_count,
    item_rank
FROM ranked_items
WHERE item_rank <= 3
ORDER BY category, item_rank, item_purchased;

-- 8.3 Customer spending bands (record-level proxy; dataset may have one row
-- per customer rather than a complete transaction history)
WITH customer_spend AS (
    SELECT
        customer_id,
        purchase_amount_usd,
        CASE
            WHEN purchase_amount_usd >= 100 THEN 'High Spend'
            WHEN purchase_amount_usd >= 50 THEN 'Medium Spend'
            WHEN purchase_amount_usd >= 0 THEN 'Low Spend'
            ELSE 'Unknown'
        END AS spending_segment
    FROM customer_shopping_behavior_cleaned
)
SELECT
    spending_segment,
    COUNT(*) AS record_count,
    ROUND(AVG(purchase_amount_usd), 2) AS average_purchase_amount
FROM customer_spend
GROUP BY spending_segment
ORDER BY average_purchase_amount DESC;

-- 8.4 Overall KPI summary
SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(SUM(purchase_amount_usd), 2) AS total_purchase_amount,
    ROUND(AVG(purchase_amount_usd), 2) AS average_purchase_amount,
    ROUND(AVG(review_rating), 2) AS average_review_rating,
    ROUND(AVG(age), 1) AS average_customer_age
FROM customer_shopping_behavior_cleaned;


/*=============================================================================
  09. BUSINESS INSIGHT SUMMARY QUERIES
=============================================================================*/

-- 9.1 Highest-revenue category
SELECT
    category,
    ROUND(SUM(purchase_amount_usd), 2) AS total_revenue
FROM customer_shopping_behavior_cleaned
GROUP BY category
ORDER BY total_revenue DESC
LIMIT 1;

-- 9.2 Highest-purchase item
SELECT
    item_purchased,
    COUNT(*) AS purchase_count
FROM customer_shopping_behavior_cleaned
GROUP BY item_purchased
ORDER BY purchase_count DESC
LIMIT 1;

-- 9.3 Highest-revenue location
SELECT
    location,
    ROUND(SUM(purchase_amount_usd), 2) AS total_revenue
FROM customer_shopping_behavior_cleaned
GROUP BY location
ORDER BY total_revenue DESC
LIMIT 1;

-- 9.4 Customer group with highest average purchase amount by subscription
SELECT
    subscription_status,
    ROUND(AVG(purchase_amount_usd), 2) AS average_purchase_amount
FROM customer_shopping_behavior_cleaned
GROUP BY subscription_status
ORDER BY average_purchase_amount DESC;

-- 9.5 Highest-rated category
SELECT
    category,
    ROUND(AVG(review_rating), 2) AS average_rating
FROM customer_shopping_behavior_cleaned
WHERE review_rating IS NOT NULL
GROUP BY category
ORDER BY average_rating DESC
LIMIT 1;


/*=============================================================================
  10. OPTIONAL: CREATE A VIEW FOR POWER BI
  Connect Power BI to this view if you want a consistently named clean source.
=============================================================================*/

CREATE OR REPLACE VIEW vw_customer_shopping_behavior AS
SELECT
    customer_id,
    age,
    gender,
    item_purchased,
    category,
    purchase_amount_usd,
    location,
    size,
    color,
    season,
    review_rating,
    subscription_status,
    payment_method,
    shipping_type,
    discount_applied,
    promo_code_used,
    previous_purchases,
    preferred_payment_method,
    purchase_frequency
FROM customer_shopping_behavior_cleaned;

-- Final verification
SELECT *
FROM vw_customer_shopping_behavior
LIMIT 10;

/*
===============================================================================
END OF PROJECT SQL SCRIPT

Suggested GitHub filename:
Customer_Analysis_Queries.sql

Suggested repository folder:
SQL/Customer_Analysis_Queries.sql

Before publishing:
- Run the script against your imported table.
- Check the data quality results.
- Verify the cleaned table row count against the raw table.
- Do not publish customer-sensitive or private data.
- Record actual findings from query results in your README; do not invent them.
===============================================================================
*/
