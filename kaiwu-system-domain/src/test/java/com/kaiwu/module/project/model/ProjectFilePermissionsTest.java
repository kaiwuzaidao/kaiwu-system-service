package com.kaiwu.module.project.model;

import static org.assertj.core.api.Assertions.assertThat;

import com.kaiwu.module.factory.renderer.ProjectScaffoldGenerator;
import org.junit.jupiter.api.Test;

/** 守住「文件」默认开关与生成项目依赖的 Starter 版本一致（ADR 0041）。 */
class ProjectFilePermissionsTest {

    /** 开关打开时，生成项目依赖的 Starter 必须不低于包含文件记录能力的最低版本，否则菜单会指向不存在的接口。 */
    @Test
    void registryCanOnlyBeEnabledWithAStarterThatHasIt() {
        if (!ProjectFilePermissions.REGISTRY_ENABLED) {
            return;
        }
        assertThat(compare(ProjectScaffoldGenerator.STARTER_VERSION, ProjectFilePermissions.MIN_STARTER_VERSION))
                .isGreaterThanOrEqualTo(0);
    }

    /** 权限码符合 {module}:{resource}:{action}，与生成项目的前后端权限一致性检查同一格式。 */
    @Test
    void permissionCodesFollowThreeSegmentConvention() {
        assertThat(ProjectFilePermissions.FILE_LIST).matches("[a-z][a-z0-9-]*:[a-z0-9-]+:[a-z0-9_-]+");
        assertThat(ProjectFilePermissions.FILE_DOWNLOAD).matches("[a-z][a-z0-9-]*:[a-z0-9-]+:[a-z0-9_-]+");
        assertThat(ProjectFilePermissions.FILE_DELETE).matches("[a-z][a-z0-9-]*:[a-z0-9-]+:[a-z0-9_-]+");
    }

    /**
     * 按数字段比较两个 x.y.z 版本，忽略 -SNAPSHOT 等后缀。
     *
     * @param left 左版本
     * @param right 右版本
     * @return 负数、0、正数分别表示左小于、等于、大于右
     */
    private static int compare(String left, String right) {
        String[] a = left.split("-")[0].split("\\.");
        String[] b = right.split("-")[0].split("\\.");
        for (int i = 0; i < Math.max(a.length, b.length); i++) {
            int x = i < a.length ? Integer.parseInt(a[i]) : 0;
            int y = i < b.length ? Integer.parseInt(b[i]) : 0;
            if (x != y) {
                return Integer.compare(x, y);
            }
        }
        return 0;
    }
}
