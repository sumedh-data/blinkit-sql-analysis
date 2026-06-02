CREATE DATABASE blinkit_analysis;
USE blinkit_analysis;

SELECT * FROM blinkit_customers LIMIT 5;
SELECT * FROM blinkit_orders LIMIT 5;
SELECT * FROM blinkit_order_items LIMIT 5;

CREATE TABLE customers AS
SELECT DISTINCT
    customer_id,
    TRIM(customer_name) AS customer_name,
    TRIM(area) AS area,
    pincode,
    TRIM(customer_segment) AS customer_segment,
    STR_TO_DATE(registration_date, '%Y-%m-%d') AS signup_date
FROM blinkit_customers
WHERE customer_id IS NOT NULL;

ALTER TABLE customers 
ADD PRIMARY KEY (customer_id);

SELECT * FROM customers LIMIT 5;
SELECT COUNT(*) FROM customers;

DESCRIBE blinkit_orders;

SELECT * FROM blinkit_orders LIMIT 5;

CREATE TABLE orders AS
SELECT DISTINCT
    order_id,
    customer_id,
    STR_TO_DATE(order_date, '%Y-%m-%d %H:%i:%s') AS order_date,
    TRIM(payment_method) AS payment_method
FROM blinkit_orders
WHERE order_id IS NOT NULL;

ALTER TABLE orders 
ADD PRIMARY KEY (order_id);

ALTER TABLE orders
ADD CONSTRAINT fk_customer
FOREIGN KEY (customer_id) REFERENCES customers(customer_id);

SELECT * FROM orders LIMIT 5;

/* Orders table stores each transaction. 
We kept only important fields (order_id, customer_id, order_date, payment_method),
 converted date to proper format, removed delivery & total fields (handled later), 
 and created keys to link customers*/


DESCRIBE blinkit_order_items;
SELECT * FROM blinkit_order_items LIMIT 5;

CREATE TABLE order_items AS
SELECT
    order_id,
    product_id,
    quantity,
    unit_price
FROM blinkit_order_items
WHERE quantity > 0
AND unit_price > 0;

ALTER TABLE order_items 
ADD COLUMN order_item_id INT AUTO_INCREMENT PRIMARY KEY;

ALTER TABLE order_items
ADD CONSTRAINT fk_order
FOREIGN KEY (order_id) REFERENCES orders(order_id);



DESCRIBE blinkit_products;
SELECT * FROM blinkit_products LIMIT 5;

CREATE TABLE products AS
SELECT DISTINCT
    product_id,
    TRIM(product_name) AS product_name,
    TRIM(category) AS category,
    TRIM(brand) AS brand,
    price AS selling_price,
    (price * (1 - margin_percentage/100)) AS cost_price
FROM blinkit_products
WHERE product_id IS NOT NULL;

ALTER TABLE products 
ADD PRIMARY KEY (product_id);

ALTER TABLE order_items
ADD CONSTRAINT fk_product
FOREIGN KEY (product_id) REFERENCES products(product_id);

SELECT * FROM products LIMIT 5;



DESCRIBE blinkit_delivery_performance;
SELECT * FROM blinkit_delivery_performance LIMIT 5;

CREATE TABLE delivery AS
SELECT
    order_id,
    delivery_time_minutes AS delivery_delay_minutes,
    promised_time,
    TRIM(delivery_status) AS delivery_status
FROM blinkit_delivery_performance
WHERE order_id IS NOT NULL;

ALTER TABLE delivery
ADD CONSTRAINT fk_delivery
FOREIGN KEY (order_id) REFERENCES orders(order_id);

SELECT * FROM delivery LIMIT 5;


DESCRIBE order_items;
SELECT 
    SUM(quantity * unit_price) AS total_revenue
FROM order_items;

SELECT 
    COUNT(DISTINCT order_id) AS total_orders
FROM orders;

SELECT 
    COUNT(DISTINCT customer_id) AS total_customers
FROM customers;

SELECT 
    SUM(quantity * unit_price) / COUNT(DISTINCT order_id) AS AOV
FROM order_items;

/* Insight:
Total Orders = 1061
Total Customers = 2500
AOV ≈ 983

Customers > Orders -- many customers are inactive / one-time users */



SELECT 
    oi.product_id,
    SUM(oi.quantity) AS total_quantity,
    SUM(oi.quantity * oi.unit_price) AS revenue
FROM order_items oi
GROUP BY oi.product_id
ORDER BY revenue DESC
LIMIT 10;

/* Insight:
Top products generate ~16k–18k each -- revenue is spread out, not dominated by 1 product.*/


SELECT 
    p.product_name,
    SUM(oi.quantity) AS total_quantity,
    SUM(oi.quantity * oi.unit_price) AS revenue
FROM order_items oi
JOIN products p 
ON oi.product_id = p.product_id
GROUP BY p.product_name
ORDER BY revenue DESC
LIMIT 10;

/*Insight:
 Top revenue drivers are health + baby care products -- strong demand in essentials category.*/


SELECT 
    p.category,
    SUM(oi.quantity * oi.unit_price) AS revenue
FROM order_items oi
JOIN products p 
ON oi.product_id = p.product_id
GROUP BY p.category
ORDER BY revenue DESC;

/*Insight:
Top categories = Dairy, Pharmacy, Fruits -- essentials dominate revenue.*/


SELECT 
    p.category,
    SUM((oi.unit_price - p.cost_price) * oi.quantity) AS profit
FROM order_items oi
JOIN products p 
ON oi.product_id = p.product_id
GROUP BY p.category
ORDER BY profit DESC;

/*Insight:
Pet Care = highest profit -- high margins
Fruits = high volume + decent margin
Revenue ≠ Profit -- important business difference */


SELECT 
    customer_type,
    COUNT(*) AS total_customers
FROM (
    SELECT 
        c.customer_id,
        CASE 
            WHEN COUNT(o.order_id) = 1 THEN 'New'
            ELSE 'Repeat'
        END AS customer_type
    FROM customers c
    LEFT JOIN orders o 
    ON c.customer_id = o.customer_id
    GROUP BY c.customer_id
) t
GROUP BY customer_type;

/*Insight:
Repeat = 1774
New = 726
  Strong retention -- business depends on repeat users*/


SELECT 
    customer_type,
    AVG(order_value) AS avg_order_value
FROM (
    SELECT 
        c.customer_id,
        SUM(oi.quantity * oi.unit_price) / COUNT(DISTINCT o.order_id) AS order_value,
        CASE 
            WHEN COUNT(o.order_id) = 1 THEN 'New'
            ELSE 'Repeat'
        END AS customer_type
    FROM customers c
    JOIN orders o 
    ON c.customer_id = o.customer_id
    JOIN order_items oi 
    ON o.order_id = oi.order_id
    GROUP BY c.customer_id
) t
GROUP BY customer_type;

/*Insight:
New AOV ≈ 972
Repeat AOV ≈ 997
  Repeat customers spend more per order*/


SELECT 
    delivery_status,
    AVG(delivery_delay_minutes) AS avg_delay
FROM delivery
GROUP BY delivery_status;

/*Insight:
On Time ≈ 0 min delay
Slightly Delayed ≈ 10.6 mins
Significantly Delayed ≈ 22 mins

  Clear pattern: delay increases -- worse service category*/
  
  
SELECT 
    delivery_status,
    COUNT(*) AS total_orders
FROM delivery
GROUP BY delivery_status;

/*Insight:
On Time = 741 (~70%)
Slight Delay = 222 (~21%)
Significant Delay = 98 (~9%)

  Majority deliveries are on time, but ~30% have delays -- operational improvement needed*/
  
/*FINAL INSIGHT:
The platform is driven by repeat customers, who contribute higher revenue per order.
Essential categories (Dairy, Pharmacy, Fruits) dominate sales, indicating demand for daily-use products.
Profitability varies across categories, with niche segments like Pet Care generating higher margins.
Around 30% of deliveries experience delays, which can negatively impact customer satisfaction and retention.
Even small delays (~10 mins) shift orders into lower service categories, highlighting the importance of operational efficiency*/