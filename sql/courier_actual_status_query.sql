-- =========================================================
-- CourierActualStatus (anonymized/randomized)
-- Same salt and date-shift as OrderInfoPostDispatch so this
-- still joins correctly by order number and stays time-aligned.
-- Written for MySQL/MariaDB syntax.
-- =========================================================

SELECT
    SUBSTRING(MD5(CONCAT('anon_salt_2026', c.name)), 1, 10) AS name,
    lf.status AS courier_actual_status,
    DATE_SUB(lf.status_time, INTERVAL 26 WEEK) AS courier_status_time,
    DATE_SUB(f.transit_at, INTERVAL 26 WEEK)   AS transit_at

FROM OrderManagement_childorders c
LEFT JOIN Logistics_fulfillments f ON c.id = f.order_id
LEFT JOIN Logistics_fulfillmentcourierstatuses lf ON f.id = lf.fulfillment_id
WHERE
    lf.status_time = (
        SELECT MAX(lf2.status_time)
        FROM Logistics_fulfillmentcourierstatuses lf2
        WHERE lf2.fulfillment_id = lf.fulfillment_id
    )
