-- Chỉ SELECT, không sửa dữ liệu. Chạy trên DB thật để tìm tài khoản có username dạng email của người khác.
-- Mỗi dòng: tài khoản có username chứa @ nhưng khác email của chính nó, kèm chủ email trùng với username đó (nếu có).
SELECT a.id        AS account_id,
       a.username  AS account_username,
       a.email     AS account_email,
       o.id        AS email_owner_id,
       o.email     AS email_owner_email
FROM users a
LEFT JOIN users o ON o.email = a.username AND o.id <> a.id
WHERE a.username LIKE '%@%'
  AND a.username <> a.email
ORDER BY a.id;
