package com.kaiwu.module.notification;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.PageBounds;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

/**
 * 站内信分页的越界行为。
 *
 * <p>这里锁的是一次**行为变更**：原实现把超限 size 静默截断成 100，现在与其它列表接口一致
 * 直接拒绝。截断的问题是调用方以为自己拿到了全量；前端各页 pageSize 最大为 100 且关闭了
 * 页长切换，因此这次收紧对真实调用方没有影响。</p>
 */
class NotificationPagingTest {

    private final NotificationRepository repository = Mockito.mock(NotificationRepository.class);
    private final NotificationService service = new NotificationService(repository);

    @Test
    void rejectsOversizedPageWithoutTouchingTheDatabase() {
        assertThatThrownBy(() -> service.myNotifications("1", 1, PageBounds.MAX_SIZE + 1, false, null))
                .isInstanceOf(ApiException.class);

        verify(repository, never()).count(anyString(), anyBoolean(), any());
        verify(repository, never()).page(anyString(), anyBoolean(), any(), anyLong(), anyLong());
    }

    @Test
    void rejectsNonPositivePage() {
        assertThatThrownBy(() -> service.myNotifications("1", 0, 10, false, null))
                .isInstanceOf(ApiException.class);
    }
}
