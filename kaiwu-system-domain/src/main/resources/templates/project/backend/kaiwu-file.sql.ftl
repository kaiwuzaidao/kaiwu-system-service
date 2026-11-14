-- 项目内统一文件记录（ADR 0041）：由 kaiwu-system-starter 的 JdbcStoredFileRepository 读写；业务表只保存 file_id。
CREATE TABLE IF NOT EXISTS kaiwu_file (
    id            CHAR(36)      NOT NULL COMMENT '文件 ID（UUID）',
    storage_ref   VARCHAR(64)   NOT NULL COMMENT '对象所在存储的引用，切换存储后据此找回旧文件',
    object_key    VARCHAR(512)  NOT NULL COMMENT '本项目前缀下的对象 key，不保存完整 URL',
    original_name VARCHAR(255)  NOT NULL COMMENT '原始文件名，仅用于展示',
    content_type  VARCHAR(127)  NOT NULL COMMENT 'MIME 类型',
    size_bytes    BIGINT        NOT NULL COMMENT '字节数',
    sha256        CHAR(64)      NULL COMMENT '内容摘要，直传未复核时为空',
    biz_type      VARCHAR(32)   NOT NULL COMMENT '业务类型，也是 object key 的一段',
    biz_id        VARCHAR(64)   NULL COMMENT '关联业务记录 ID，弱关联，不加外键',
    status        VARCHAR(16)   NOT NULL COMMENT 'PENDING 待确认 / ACTIVE 生效 / DELETED 已软删除',
    uploader_id   VARCHAR(64)   NOT NULL COMMENT '上传人用户 ID',
    created_at    DATETIME      NOT NULL COMMENT '记录创建时间',
    confirmed_at  DATETIME      NULL COMMENT '确认生效时间',
    deleted_at    DATETIME      NULL COMMENT '软删除时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_kaiwu_file_object_key (object_key),
    KEY idx_kaiwu_file_status_created (status, created_at),
    KEY idx_kaiwu_file_status_deleted (status, deleted_at),
    KEY idx_kaiwu_file_biz (biz_type, biz_id),
    KEY idx_kaiwu_file_uploader (uploader_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='项目内统一文件记录（ADR 0041）';
