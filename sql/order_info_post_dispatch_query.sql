-- =========================================================
-- OrderInfoPostDispatch (anonymized/randomized)
-- Same salt ('anon_salt_2026') and scale factor (1.37) used across
-- all portfolio queries, so relationships stay consistent between
-- this dashboard and others, and this still joins correctly with
-- CourierActualStatus on childOrder_no.
-- Written for MySQL/MariaDB syntax.
-- =========================================================

SELECT
    o.isInternational,
    o.currency,
    c.financial_status,
    c.status,

    -- Customer name pseudonymized (same real customer -> same fake label)
    CONCAT('Customer_', UPPER(SUBSTRING(MD5(CONCAT('anon_salt_2026', s.name)), 1, 6))) AS customerName,

    CONCAT('Shop_', UPPER(SUBSTRING(MD5(CONCAT('anon_salt_2026', sh.name)), 1, 6))) AS shop,
    CONCAT('Channel_', UPPER(SUBSTRING(MD5(CONCAT('anon_salt_2026', ss.sale_channel_name)), 1, 4))) AS sale_channel_name,

    -- Customer address & phone intentionally dropped: direct PII with no
    -- analytical value for a dispatch/TAT dashboard. Don't publish these
    -- even hashed — if you need them for internal testing, keep them out
    -- of anything screenshotted or committed to the repo.
    -- s.address1 AS address1,
    -- s.phone AS phone,

    SUBSTRING(MD5(CONCAT('anon_salt_2026', c.name)), 1, 10) AS childOrder_no,
    SUBSTRING(MD5(CONCAT('anon_salt_2026', o.name)), 1, 10) AS parent_order_no,

    ROUND(c.total_price * 1.37, 2)     AS COD_amount,
    ROUND(c.shipping_charge * 1.37, 2) AS shipping_charge,
    c.total_weight,

    f.courier_status,
    UPPER(sh.city) AS ShopCity,
    c.shipment_type,

    SUBSTRING(MD5(CONCAT('anon_salt_2026', c.pos_receipt_number)), 1, 8)        AS pos_receipt_number,
    SUBSTRING(MD5(CONCAT('anon_salt_2026', pos_return_receipt_number)), 1, 8)   AS pos_return_receipt_number,
    CONCAT('Courier_', UPPER(SUBSTRING(MD5(CONCAT('anon_salt_2026', c.courierName)), 1, 4))) AS courierName,

    DATE_SUB(c.approved_at, INTERVAL 26 WEEK)   AS approved_at,
    DATE_SUB(c.dispatched_at, INTERVAL 26 WEEK) AS dispatched_at,

    SUBSTRING(MD5(CONCAT('anon_salt_2026', c.trackingNumber)), 1, 12) AS trackingNumber,

    UPPER(s.city) AS city,
    DATE_SUB(c.created_at, INTERVAL 26 WEEK)   AS childCreatedAt,
    DATE_SUB(c.delivered_at, INTERVAL 26 WEEK) AS delivered_at,

    ROUND(c.total_discounts * 1.37, 2) AS total_discounts,

    SUBSTRING(MD5(CONCAT('anon_salt_2026', c.id)), 1, 10) AS childOrder_id,

    DATE_SUB(c.returned_at, INTERVAL 26 WEEK) AS returned_at,

    -- Status logic left untouched — it references the real underlying dates
    -- internally, so day-difference calculations stay accurate. Only the
    -- *displayed* date columns above are shifted, not these comparisons.
    CASE
        WHEN c.status = "Returned" OR courier_status = 'Returned' THEN "Returned"
        WHEN c.status = 'Delivered' AND c.financial_status = 'pending' THEN "Delivered Unpaid"
        WHEN c.status = 'Delivered' AND c.financial_status = 'paid' THEN "Delivered Paid"
        WHEN (courier_status = 'Delivered' AND c.financial_status = 'paid' AND c.status != "Returned") THEN "Delivered Paid"
        WHEN (courier_status = 'Delivered' AND c.financial_status = 'pending' AND c.status != "Returned") THEN "Delivered Unpaid"
        WHEN courier_status = 'Failure' THEN "To be returned"
        WHEN (courier_status = 'In transit' OR courier_status = 'Out for delivery') THEN "In process"
        WHEN (courier_status = 'Not available' AND c.status = 'Dispatched') THEN "In process"
        WHEN (courier_status IS NULL AND c.status = 'Dispatched') THEN "In process"
        WHEN (courier_status = 'Confirmed' AND c.status = 'Dispatched') THEN "In process"
        WHEN c.status = "Cancelled" THEN "Cancelled"
    END AS cn_status_2,

    DATE_SUB(c.paid_at, INTERVAL 26 WEEK) AS paid_at,

    CASE
        WHEN DATEDIFF(c.dispatched_at, c.approved_at) = 0 THEN "Same Day"
        WHEN DATEDIFF(c.dispatched_at, c.approved_at) BETWEEN 1 AND 2 THEN "1 - 2 Days"
        WHEN DATEDIFF(c.dispatched_at, c.approved_at) BETWEEN 3 AND 5 THEN "3 - 5 Days"
        ELSE "5 + Days"
    END AS dispatchApproveTat,

    CASE
        WHEN DATEDIFF(c.dispatched_at, c.approved_at) < 1 THEN "Success"
        ELSE "Late"
    END AS sameDayApproveDispatch,

    CASE
        WHEN DATEDIFF(c.dispatched_at, c.created_at) BETWEEN 0 AND 1 THEN "0 - 1 Day"
        WHEN DATEDIFF(c.dispatched_at, c.created_at) BETWEEN 2 AND 3 THEN "2 - 3 Days"
        WHEN DATEDIFF(c.dispatched_at, c.created_at) BETWEEN 4 AND 5 THEN "4 - 5 Days"
        WHEN DATEDIFF(c.dispatched_at, c.created_at) BETWEEN 6 AND 7 THEN "6 - 7 Days"
        ELSE "7 + Days"
    END AS orderCreateDispatchTat,

    DATEDIFF(c.dispatched_at, c.approved_at) AS DispatchedApprovedDiff

FROM OrderManagement_childorders c
LEFT OUTER JOIN Logistics_fulfillments f ON c.id = f.order_id AND f.fulfilledOnShopify = 1
RIGHT OUTER JOIN OrderManagement_orders o ON c.orders_id = o.id
LEFT OUTER JOIN OrderManagement_shippingaddress s ON o.id = s.orders_id
LEFT OUTER JOIN OrderManagement_childorderassigned ca ON c.id = ca.childOrders_id
LEFT OUTER JOIN SaleChannel_salechannel ss ON o.sale_channel_id = ss.id
LEFT OUTER JOIN InventoryManagement_shop sh ON sh.id = ca.shop_id
WHERE c.dispatched_at IS NOT NULL
  AND ca.is_active = 1
  AND c.dispatched_at >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH)
