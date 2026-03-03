USE CRISES_RECOVERY_ANALYSIS;

DELETE FROM dbo.fact_ratings    --Deleting null values from fact_ratings
WHERE order_id IS NULL 
   OR customer_id IS NULL 
   OR restaurant_id IS NULL 
   OR rating IS NULL 
   OR review_text IS NULL 
   OR review_timestamp IS NULL;

SELECT         --Checking null values from all tables    
* 
FROM 
   [dbo].[fact_order_items]
WHERE 
   order_id IS NULL 
   OR item_id IS NULL 
   OR menu_item_id IS NULL 
   OR restaurant_id IS NULL 
   OR quantity IS NULL 
   OR unit_price IS NULL 
   OR item_discount IS NULL
   OR line_total IS NULL

/*
1. Monthly Orders: Compare total orders across pre-crisis (Jan–May 2025) vs crisis 
(Jun–Sep 2025). How severe is the decline?  
orders= 48965, 
*/

SELECT 
    MONTH(order_timestamp) AS order_month, 
    COUNT(order_id) AS total_orders
FROM 
	fact_orders
WHERE 
	YEAR(order_timestamp) = 2025 AND 
    MONTH(order_timestamp) BETWEEN 1 AND 5
GROUP BY 
	MONTH(order_timestamp)
ORDER BY 
	order_month;

SELECT 
    MONTH(order_timestamp) AS order_month, 
    COUNT(order_id) AS total_orders
FROM 
	fact_orders
WHERE 
	YEAR(order_timestamp) = 2025 AND 
    MONTH(order_timestamp) BETWEEN 6 AND 9
GROUP BY 
	MONTH(order_timestamp)
ORDER BY 
	order_month;


/*
2. Which top 5 city groups experienced the highest percentage decline in orders 
during the crisis period compared to the pre-crisis period? 
*/

WITH 
    pre_crisis_orders AS (                      --For pre-crisis period (till June)
    SELECT 
        city, 
        COUNT(order_id) AS pre_crisis_orders
    FROM 
        fact_orders
    JOIN 
        dim_customer 
    ON 
        fact_orders.customer_id = dim_customer.customer_id
    WHERE 
        YEAR(order_timestamp) = 2025 AND MONTH(order_timestamp) BETWEEN 1 AND 5
    GROUP BY city
    ),

    crisis_orders AS (                          --For crisis period (from June)
    SELECT 
        city, 
        COUNT(order_id) AS crisis_orders
    FROM 
        fact_orders
    JOIN 
        dim_customer 
    ON 
        fact_orders.customer_id = dim_customer.customer_id
    WHERE 
        YEAR(order_timestamp) = 2025 AND MONTH(order_timestamp) BETWEEN 6 AND 9
    GROUP BY 
        city
    )
SELECT TOP 5
    pre_crisis_orders.city, 
    pre_crisis_orders.pre_crisis_orders, 
    crisis_orders.crisis_orders,
    (pre_crisis_orders.pre_crisis_orders - crisis_orders.crisis_orders ) as Decline 
FROM
    pre_crisis_orders
JOIN 
    crisis_orders ON pre_crisis_orders.city = crisis_orders.city
ORDER BY 
    Decline desc



/* 
3. Among restaurants with at least 50 pre-crisis orders, which top 10 high-volume 
restaurants experienced the largest percentage decline in order counts during 
the crisis period? 
*/

USE CRISES_RECOVERY_ANALYSIS;

WITH 
pre_crisis_orders AS (
    SELECT  
        dim_restaurant.restaurant_name, 
        COUNT(order_id) AS pre_crisis_orders
    FROM 
        fact_orders
    JOIN 
        dim_restaurant ON fact_orders.restaurant_id = dim_restaurant.restaurant_id
    WHERE 
        MONTH(order_timestamp) BETWEEN 1 AND 5
    GROUP BY 
        dim_restaurant.restaurant_name
    
),
crisis_orders AS (
    SELECT  
        dim_restaurant.restaurant_name, 
        COUNT(order_id) AS crisis_orders
    FROM 
        fact_orders
    JOIN 
        dim_restaurant ON fact_orders.restaurant_id = dim_restaurant.restaurant_id
    WHERE 
        MONTH(order_timestamp) BETWEEN 6 AND 9
    GROUP BY 
        dim_restaurant.restaurant_name
)
SELECT TOP 10
    pre_crisis_orders.restaurant_name, 
    pre_crisis_orders.pre_crisis_orders, 
    crisis_orders.crisis_orders,
    (pre_crisis_orders.pre_crisis_orders - crisis_orders.crisis_orders) AS decline
FROM 
    pre_crisis_orders
JOIN 
    crisis_orders ON pre_crisis_orders.restaurant_name = crisis_orders.restaurant_name
ORDER BY 
    decline DESC



/*
4. Cancellation Analysis: What is the cancellation rate trend pre-crisis vs crisis, 
and which cities are most affected? 
*/

USE CRISES_RECOVERY_ANALYSIS;
WITH 
pre_crisis_cancellations AS (
    SELECT 
        dim_restaurant.city,
        COUNT(order_id) as total_orders,
        SUM(CASE WHEN is_cancelled = 1 THEN 1 ELSE 0 END) AS cancelled_orders
    FROM 
        fact_orders
    JOIN 
        dim_restaurant ON dim_restaurant.restaurant_id = fact_orders.restaurant_id
    WHERE 
        MONTH(order_timestamp) BETWEEN 1 AND 5
    GROUP BY 
        dim_restaurant.city
),

crisis_cancellations AS (
  SELECT 
        dim_restaurant.city,
        COUNT(order_id) as total_orders,
        SUM(CASE WHEN is_cancelled = 1 THEN 1 ELSE 0 END) AS cancelled_orders
    FROM 
        fact_orders
    JOIN 
        dim_restaurant ON dim_restaurant.restaurant_id = fact_orders.restaurant_id
    WHERE 
        MONTH(order_timestamp) BETWEEN 6 AND 9
    GROUP BY 
        dim_restaurant.city
)

SELECT 
    pre_crisis_cancellations.city, 
    pre_crisis_cancellations.total_orders AS pre_crisis_total_orders,
    pre_crisis_cancellations.cancelled_orders AS pre_crisis_cancelled_orders,
    (pre_crisis_cancellations.cancelled_orders * 100.0) / pre_crisis_cancellations.total_orders AS pre_crisis_cancellation_rate,
    crisis_cancellations.total_orders AS crisis_total_orders,
    crisis_cancellations.cancelled_orders AS crisis_cancelled_orders,
    (crisis_cancellations.cancelled_orders * 100.0) / crisis_cancellations.total_orders AS crisis_cancellation_rate
FROM 
    pre_crisis_cancellations
JOIN 
    crisis_cancellations ON pre_crisis_cancellations.city = crisis_cancellations.city
ORDER BY 
    crisis_cancellation_rate DESC;

/*
5. Delivery SLA: Measure average delivery time across phases. Did SLA 
compliance worsen significantly in the crisis period? 
*/

WITH pre_crisis_delivery AS (
    SELECT 
        AVG(actual_delivery_time_mins) AS avg_delivery_time
    FROM 
        fact_delivery_performance
    JOIN 
        fact_orders ON fact_delivery_performance.order_id = fact_orders.order_id
    WHERE 
        MONTH(order_timestamp) BETWEEN 1 AND 5
),
crisis_delivery AS (
    SELECT 
        AVG(actual_delivery_time_mins) AS avg_delivery_time
    FROM 
        fact_delivery_performance
    JOIN 
        fact_orders ON fact_delivery_performance.order_id = fact_orders.order_id
    WHERE 
        MONTH(order_timestamp) BETWEEN 6 AND 9
)
SELECT 
    pre_crisis_delivery.avg_delivery_time AS pre_crisis_avg_delivery_time,
    crisis_delivery.avg_delivery_time AS crisis_avg_delivery_time
FROM 
    pre_crisis_delivery, 
    crisis_delivery;
 
/*6. 
Ratings Fluctuation: Track average customer rating month-by-month. Which months saw the sharpest drop? 
*/

SELECT 
    MONTH(review_timestamp) AS review_month, 
    AVG(rating) AS avg_rating
FROM 
    fact_ratings
GROUP BY 
    MONTH(review_timestamp)
ORDER BY 
    review_month
/*7.  
Sentiment Insights: During the crisis period, identify the most frequently 
occurring negative keywords in customer review texts. (Hint: Use a Word Cloud 
visual in Power BI to visualize the findings.) 
*/

SELECT  
    review_text, 
    COUNT(review_text) AS occurrence 
FROM 
    fact_ratings 
WHERE 
    MONTH(review_timestamp) BETWEEN 6 AND 9
GROUP BY 
    review_text 
ORDER BY 
    COUNT(review_text) DESC;
 
/* 
8. Revenue Impact: Estimate revenue loss from pre-crisis vs crisis (based on 
subtotal, discount, and delivery fee). 
*/

WITH pre_crisis_revenue AS (
    SELECT 
        SUM(subtotal_amount) AS subtotal, 
        SUM(discount_amount) AS discount, 
        SUM(delivery_fee) AS delivery_fee
    FROM 
        fact_orders
    WHERE 
        MONTH(order_timestamp) BETWEEN 1 AND 5
),
crisis_revenue AS (
    SELECT 
        SUM(subtotal_amount) AS subtotal, 
        SUM(discount_amount) AS discount, 
        SUM(delivery_fee) AS delivery_fee
    FROM 
        fact_orders
    WHERE 
        MONTH(order_timestamp) BETWEEN 6 AND 9
)
SELECT 
    pre_crisis_revenue.subtotal - crisis_revenue.subtotal AS revenue_loss
FROM 
    pre_crisis_revenue, crisis_revenue;
 

/*9. 
Loyalty Impact: Among customers who placed five or more orders before the 
crisis, determine how many stopped ordering during the crisis, and out of those, 
how many had an average rating above 4.5? 
*/

WITH pre_crisis_customers AS (
    SELECT 
        customer_id, COUNT(order_id) AS pre_crisis_orders
    FROM 
        fact_orders
    WHERE 
        MONTH(order_timestamp) BETWEEN 1 AND 5
    GROUP BY 
        customer_id
    HAVING 
        COUNT(order_id) >= 5
),
crisis_customers AS (
    SELECT 
        customer_id, COUNT(order_id) AS crisis_orders
    FROM 
        fact_orders
    WHERE 
        MONTH(order_timestamp) BETWEEN 6 AND 9
    GROUP BY 
        customer_id
),
customers_with_no_orders_during_crisis AS (
    SELECT 
        pre_crisis_customers.customer_id
    FROM 
        pre_crisis_customers
    LEFT JOIN 
        crisis_customers ON pre_crisis_customers.customer_id = crisis_customers.customer_id
    WHERE 
        crisis_customers.crisis_orders = 0
),
average_ratings AS (
    SELECT 
        customer_id, AVG(rating) AS avg_rating
    FROM 
        fact_ratings
    GROUP BY 
        customer_id
)
SELECT 
    COUNT(customers_with_no_orders_during_crisis.customer_id) AS customers_stopped_ordering,
    COUNT(CASE WHEN average_ratings.avg_rating > 4.5 THEN 1 END) AS customers_above_4_5_rating
FROM 
    customers_with_no_orders_during_crisis
JOIN 
    average_ratings ON customers_with_no_orders_during_crisis.customer_id = average_ratings.customer_id;

/*
10. Customer Lifetime Decline: Which high-value customers (top 5% by total 
spend before the crisis) showed the largest drop in order frequency and ratings 
during the crisis? What common patterns (e.g., location, cuisine preference, 
delivery delays) do they share? 
*/

use CRISES_RECOVERY_ANALYSIS
--Finding top 5% 
WITH top_5_customers AS (
    SELECT TOP 5 PERCENT 
        customer_id,
        SUM(total_amount) AS total_spent 
    FROM fact_orders
    WHERE MONTH(order_timestamp) BETWEEN 1 AND 5 AND YEAR(order_timestamp) = 2025
    GROUP BY customer_id
    ORDER BY total_spent DESC
),
--Finding pre-crisis orders 
pre_crisis_orders AS (
    SELECT customer_id, COUNT(order_id) AS pre_crisis_order_count
    FROM fact_orders
    WHERE customer_id IN (SELECT customer_id FROM top_5_customers)
    AND MONTH(order_timestamp) BETWEEN 1 AND 5 AND YEAR(order_timestamp) = 2025
    GROUP BY customer_id
),
--Finding crisis orders 
crisis_orders AS (
    SELECT customer_id, COUNT(order_id) AS crisis_order_count
    FROM fact_orders
    WHERE customer_id IN (SELECT customer_id FROM top_5_customers)
    AND MONTH(order_timestamp) BETWEEN 6 AND 9 AND YEAR(order_timestamp) = 2025
    GROUP BY customer_id
),
-- finding pre-crisis ratings 
pre_crisis_ratings AS (
    SELECT 
        customer_id, 
        AVG(rating) AS pre_crisis_avg_rating
    FROM 
        fact_ratings
    WHERE 
        customer_id IN (SELECT customer_id FROM top_5_customers)
        AND MONTH(review_timestamp) BETWEEN 1 AND 5 
    GROUP BY 
        customer_id
),
-- finding crisis ratings 
crisis_ratings AS (
    SELECT 
        customer_id, 
        AVG(rating) AS crisis_avg_rating
    FROM 
        fact_ratings
    WHERE 
        customer_id IN (SELECT customer_id FROM top_5_customers)
        AND MONTH(review_timestamp) BETWEEN 6 AND 9 AND YEAR(review_timestamp) = 2025
    GROUP BY 
        customer_id
)
-- Combining all the required columns 
SELECT 
    pre_crisis_orders.customer_id,
    pre_crisis_orders.pre_crisis_order_count,
    crisis_orders.crisis_order_count,
    (pre_crisis_orders.pre_crisis_order_count - crisis_orders.crisis_order_count) 
    AS order_count_difference,
    pre_crisis_ratings.pre_crisis_avg_rating,
    crisis_ratings.crisis_avg_rating,
    (pre_crisis_ratings.pre_crisis_avg_rating - crisis_ratings.crisis_avg_rating) 
    AS rating_difference
FROM 
    pre_crisis_orders
JOIN 
    crisis_orders ON pre_crisis_orders.customer_id = crisis_orders.customer_id
JOIN 
    pre_crisis_ratings ON pre_crisis_orders.customer_id = pre_crisis_ratings.customer_id
JOIN 
    crisis_ratings ON pre_crisis_orders.customer_id = crisis_ratings.customer_id
ORDER BY 
    order_count_difference DESC, 
    rating_difference DESC;