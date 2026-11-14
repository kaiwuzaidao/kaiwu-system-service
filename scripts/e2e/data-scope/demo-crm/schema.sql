-- 示例业务库：受控表按约定有两个归属列，各一个单列索引。
CREATE TABLE IF NOT EXISTS demo_customer (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(64) NOT NULL,
    owner_user_id BIGINT NOT NULL,
    owner_dept_id BIGINT NOT NULL,
    KEY idx_owner_user (owner_user_id),
    KEY idx_owner_dept (owner_dept_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
