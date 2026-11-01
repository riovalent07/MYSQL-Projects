SELECT * FROM dirty_shipments.dirty_shipments;

UPDATE dirty_shipments.dirty_shipments
SET destination_city = IF(TRIM(destination_city) = '', NULL, destination_city),
	ship_date = IF(TRIM(ship_date) = '', NULL, ship_date),
    delivery_date = IF(TRIM(delivery_date) = '', NULL, delivery_date)
WHERE 
	TRIM(destination_city) = '' OR
    TRIM(ship_date) = '' OR
    TRIM(delivery_date) = '';

SELECT 
	shipment_id,
    CONCAT(UPPER(LEFT(TRIM(origin_warehouse), 1)), LOWER(SUBSTRING(TRIM(origin_warehouse), 2,CHAR_LENGTH(TRIM(origin_warehouse))-2)) ,UPPER(RIGHT(TRIM(origin_warehouse), 1))) AS origin_warehouse,
    COALESCE(CONCAT(UPPER(LEFT(TRIM(destination_city), 1)), LOWER(SUBSTRING(TRIM(destination_city),2))), 'Unknown') AS destination_city,
    UPPER(TRIM(destination_state)) destination_state,
    CONCAT(UPPER(LEFT(TRIM(carrier),1)), LOWER(SUBSTRING(TRIM(carrier), 2))) carrier,
    CONCAT(UPPER(LEFT(TRIM(shipment_status), 1)), LOWER(SUBSTRING(TRIM(shipment_status), 2))) shipment_status,
    TRIM(ship_date) ship_date,
    COALESCE(TRIM(delivery_date), 'Not Yet Delivery') delivery_date,
    CASE
		WHEN damage_reported = 'null' THEN null
        ELSE CONCAT(UPPER(LEFT(damage_reported, 1)), LOWER(SUBSTRING(damage_reported, 2)))
	END AS damage_reported
FROM dirty_shipments.dirty_shipments;
UPDATE dirty_shipments.dirty_shipments
SET 
	origin_warehouse =  CONCAT(
		UPPER(LEFT(TRIM(origin_warehouse), 1)), 
        LOWER(SUBSTRING(TRIM(origin_warehouse), 2,CHAR_LENGTH(TRIM(origin_warehouse))-2)) ,
        UPPER(RIGHT(TRIM(origin_warehouse), 1))),
	destination_city = COALESCE(
		CONCAT(UPPER(LEFT(TRIM(destination_city), 1)), 
        LOWER(SUBSTRING(TRIM(destination_city),2))), 'Unknown'),
	destination_state = UPPER(TRIM(destination_state)),
    carrier = CONCAT(
		UPPER(LEFT(TRIM(carrier),1)), 
        LOWER(SUBSTRING(TRIM(carrier), 2))),
	shipment_status = CONCAT(
		UPPER(LEFT(TRIM(shipment_status), 1)), 
        LOWER(SUBSTRING(TRIM(shipment_status), 2))),
	ship_date = TRIM(ship_date),
    delivery_date = COALESCE(TRIM(delivery_date), 'Not Yet Delivery'),
    damage_reported =  CASE
		WHEN damage_reported = 'null' THEN null
        ELSE CONCAT(UPPER(LEFT(damage_reported, 1)), LOWER(SUBSTRING(damage_reported, 2)))
	END;


WITH Ranked AS (
	SELECT*,
		ROW_NUMBER() OVER (
			PARTITION BY
				origin_warehouse,
                destination_city,
                carrier,
                ship_date,
                CAST(weight_kg AS CHAR),
                CAST(freight_cost AS CHAR)
			ORDER BY shipment_id
		) AS row_num
	FROM dirty_shipments.dirty_shipments)
SELECT*
FROM Ranked
WHERE row_num = 1;

SELECT*,
	CASE
		WHEN weight_kg < 0 THEN ABS(weight_kg)
        WHEN weight_kg = 0 THEN NULL
        ELSE weight_kg
	END AS weight_kg,
    CASE 
        WHEN freight_cost = 0 THEN NULL
        ELSE freight_cost
	END AS freight_cost
FROM dirty_shipments.dirty_shipments;
UPDATE dirty_shipments.dirty_shipments
SET weight_kg = CASE
		WHEN weight_kg < 0 THEN ABS(weight_kg)
        WHEN weight_kg = 0 THEN NULL
        ELSE weight_kg
	END;
    
WITH cleanned_dates AS(
	SELECT
			shipment_id,
            ship_date,
            delivery_date,
            CASE 
				WHEN ship_date REGEXP '^[0-9]{4}[-/][0-9]{2}[-/][0-9]{2}'
					THEN STR_TO_DATE(REPLACE(ship_date, '/', '-' ), '%Y-%m-%d')
				WHEN ship_date REGEXP '^[0-9]{2}[-/][0-9]{2}[-/][0-9]{4}'
					THEN STR_TO_DATE(REPLACE(ship_date, '-', '/' ), '%m/%d/%Y')
				WHEN ship_date REGEXP '^[A-Za-z]{3} [0-9]{1,2} [0-9]{4}'
					THEN STR_TO_DATE(ship_date, '%b %d %Y')
				WHEN ship_date REGEXP '^[A-Za-z]+ [0-9]{1,2} [0-9]{4}'
					THEN STR_TO_DATE(ship_date, '%M %d %Y')
				ELSE null
			END AS clean_ship_date,
            CASE 
				WHEN delivery_date REGEXP '^[0-9]{4}[-/][0-9]{2}[-/][0-9]{2}'
					THEN STR_TO_DATE(REPLACE(delivery_date, '/', '-' ), '%Y-%m-%d')
				WHEN delivery_date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}'
					THEN STR_TO_DATE(delivery_date, '%m/%d/%Y')
				WHEN delivery_date REGEXP '^[A-Za-z]{3} [0-9]{1,2} [0-9]{4}'
					THEN STR_TO_DATE(delivery_date, '%b %d %Y')
				WHEN delivery_date REGEXP '^[A-Za-z]+ [0-9]{1,2} [0-9]{4}'
					THEN STR_TO_DATE(delivery_date, '%M %d %Y')
				ELSE null
			END AS clean_delivery_date
	FROM dirty_shipments.dirty_shipments)
SELECT
		shipment_id,
		ship_date,
		delivery_date,
        DATEDIFF(clean_delivery_date, clean_ship_date ) AS transit_data,
        CASE 
			WHEN clean_delivery_date < clean_ship_date THEN 'Invalid'
            WHEN clean_delivery_date = clean_ship_date THEN 'Same Day Delivery'
            ELSE 'Valid'
		END AS data_quality_flag
FROM cleanned_dates;
UPDATE dirty_shipments.dirty_shipments
SET 
	ship_date = CASE 
		WHEN ship_date REGEXP '^[0-9]{4}[-/][0-9]{2}[-/][0-9]{2}'
			THEN STR_TO_DATE(REPLACE(ship_date, '/', '-' ), '%Y-%m-%d')
		WHEN ship_date REGEXP '^[0-9]{2}[-/][0-9]{2}[-/][0-9]{4}'
			THEN STR_TO_DATE(REPLACE(ship_date, '-', '/' ), '%m/%d/%Y')
		WHEN ship_date REGEXP '^[A-Za-z]{3} [0-9]{1,2} [0-9]{4}'
			THEN STR_TO_DATE(ship_date, '%b %d %Y')
		WHEN ship_date REGEXP '^[A-Za-z]+ [0-9]{1,2} [0-9]{4}'
			THEN STR_TO_DATE(ship_date, '%M %d %Y')
		ELSE null
	END,
    delivery_date = CASE
		WHEN delivery_date REGEXP '^[0-9]{4}[-/][0-9]{2}[-/][0-9]{2}'
			THEN STR_TO_DATE(REPLACE(delivery_date, '/', '-' ), '%Y-%m-%d')
		WHEN delivery_date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}'
			THEN STR_TO_DATE(delivery_date, '%m/%d/%Y')
		WHEN delivery_date REGEXP '^[A-Za-z]{3} [0-9]{1,2} [0-9]{4}'
			THEN STR_TO_DATE(delivery_date, '%b %d %Y')
		WHEN delivery_date REGEXP '^[A-Za-z]+ [0-9]{1,2} [0-9]{4}'
			THEN STR_TO_DATE(delivery_date, '%M %d %Y')
		ELSE null
	END;


WITH Order_data AS(
	SELECT
		freight_cost,
        PERCENT_RANK() OVER(ORDER BY freight_cost) AS pct
        FROM dirty_shipments.dirty_shipments
        WHERE freight_cost > 0),
Stats AS(
	SELECT
		(SELECT MIN(freight_cost) FROM Order_data WHERE pct >= 0.25) AS q1,
        (SELECT MIN(freight_cost) FROM Order_data WHERE pct >= 0.75) AS q3),
bounds AS(
	SELECT
		q1 - 1.5 * (q3 - q1) Lower_Bounds,
        q3 + 1.5 * (q3 - q1) Upper_Bounds
	FROM Stats)
SELECT
	shipment_id,
    freight_cost AS original_cost,
    CASE
		WHEN freight_cost > (SELECT Upper_Bounds FROM bounds) THEN (SELECT Upper_Bounds FROM bounds)
        WHEN freight_cost < (SELECT Lower_Bounds FROM bounds) THEN (SELECT Lower_Bounds FROM bounds)
        ELSE freight_cost
	END AS clean_cost,
    CASE
		WHEN freight_cost > (SELECT Upper_Bounds FROM bounds) OR freight_cost < (SELECT Lower_Bounds FROM bounds)
			THEN TRUE
		ELSE FALSE 
	END AS was_outlier
FROM dirty_shipments.dirty_shipments;
