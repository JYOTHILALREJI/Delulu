-- Admin dashboard queries
CREATE OR REPLACE VIEW admin_daily_stats AS
SELECT 
  DATE(created_at) as date,
  COUNT(DISTINCT id) as new_users,
  COUNT(*) as total_matches,
  SUM(CASE WHEN premium_until > NOW() THEN 1 ELSE 0 END) as premium_users
FROM profiles
GROUP BY DATE(created_at);

CREATE OR REPLACE VIEW admin_revenue AS
SELECT 
  DATE(created_at) as date,
  COUNT(*) as subscriptions,
  COUNT(*) * 9.99 as revenue_usd
FROM subscriptions
GROUP BY DATE(created_at);