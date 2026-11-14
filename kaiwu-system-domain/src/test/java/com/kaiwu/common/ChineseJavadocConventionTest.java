package com.kaiwu.common;

import static org.junit.jupiter.api.Assertions.assertTrue;

import com.sun.source.tree.ClassTree;
import com.sun.source.tree.CompilationUnitTree;
import com.sun.source.tree.MethodTree;
import com.sun.source.tree.Tree;
import com.sun.source.util.JavacTask;
import com.sun.source.util.TreePath;
import com.sun.source.util.TreePathScanner;
import com.sun.source.util.Trees;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import javax.tools.JavaCompiler;
import javax.tools.JavaFileObject;
import javax.tools.StandardJavaFileManager;
import javax.tools.ToolProvider;
import org.junit.jupiter.api.Test;

/**
 * 防止生产和测试源码的中文 Javadoc 存量债务继续增长。
 *
 * <p>预算来自首次 AST 审计。新增或修改声明仍须按 docs/JAVA_STYLE.md 补齐中文 Javadoc；
 * 每完成一个清理批次都应同步下调预算，直至所有预算归零。</p>
 */
class ChineseJavadocConventionTest {

    private static final Map<String, Integer> MISSING_COMMENT_BUDGETS = Map.ofEntries(
            Map.entry("kaiwu-system-api/src/main/java", 85),
            Map.entry("kaiwu-system-domain/src/main/java", 2645),
            Map.entry("kaiwu-system-boot/src/main/java", 1),
            Map.entry("kaiwu-system-domain/src/test/java", 606),
            Map.entry("kaiwu-system-boot/src/test/java", 4));

    /**
     * 验证每个生产或测试源码目录的缺失中文 Javadoc 数不会超过登记基线。
     *
     * @throws IOException 源码目录无法读取时抛出
     */
    @Test
    void missingChineseJavadocCountMustNotGrow() throws IOException {
        for (Map.Entry<String, Integer> entry : MISSING_COMMENT_BUDGETS.entrySet()) {
            int actual = countMissingChineseJavadocs(sourceRoot(entry.getKey()));
            assertTrue(
                    actual <= entry.getValue(),
                    () -> entry.getKey()
                            + " 缺失中文 Javadoc 的声明从 "
                            + entry.getValue()
                            + " 增长到 "
                            + actual
                            + "；请补齐新增或改动类型、构造器和方法的中文 Javadoc。");
        }
    }

    /**
     * 解析一个源码目录并统计没有中文 Javadoc 的声明。
     *
     * @param sourceRoot 待扫描的源码目录
     * @return 缺失中文 Javadoc 的命名类型、构造器与方法数量
     * @throws IOException 源码目录无法读取时抛出
     */
    private int countMissingChineseJavadocs(Path sourceRoot) throws IOException {
        List<Path> sourceFiles;
        try (var paths = Files.walk(sourceRoot)) {
            sourceFiles = paths.filter(path -> path.toString().endsWith(".java"))
                    .filter(path -> !path.toString().contains("/target/"))
                    .sorted()
                    .toList();
        }
        JavaCompiler compiler = ToolProvider.getSystemJavaCompiler();
        try (StandardJavaFileManager fileManager =
                compiler.getStandardFileManager(null, Locale.ROOT, StandardCharsets.UTF_8)) {
            Iterable<? extends JavaFileObject> units = fileManager.getJavaFileObjectsFromPaths(sourceFiles);
            JavacTask task = (JavacTask)
                    compiler.getTask(null, fileManager, null, List.of("-proc:none", "-Xlint:none"), null, units);
            Iterable<? extends CompilationUnitTree> trees = task.parse();
            Trees sourceTrees = Trees.instance(task);
            int[] missing = {0};
            for (CompilationUnitTree unit : trees) {
                new TreePathScanner<Void, Void>() {
                    /**
                     * 统计具名类型的文档；匿名类没有稳定的源码名称，不纳入契约。
                     *
                     * @param node 当前类型声明
                     * @param ignored 未使用的扫描上下文
                     * @return 继续扫描嵌套成员
                     */
                    @Override
                    public Void visitClass(ClassTree node, Void ignored) {
                        if (!node.getSimpleName().isEmpty()) {
                            countIfMissing(node);
                        }
                        return super.visitClass(node, ignored);
                    }

                    /**
                     * 统计源码中显式声明的方法和构造器。
                     *
                     * @param node 当前方法或构造器声明
                     * @param ignored 未使用的扫描上下文
                     * @return 继续扫描方法体中的嵌套声明
                     */
                    @Override
                    public Void visitMethod(MethodTree node, Void ignored) {
                        countIfMissing(node);
                        return super.visitMethod(node, ignored);
                    }

                    /**
                     * 当声明没有包含汉字的 Javadoc 时计入存量。
                     *
                     * @param declaration 当前源码声明
                     */
                    private void countIfMissing(Tree declaration) {
                        TreePath path = getCurrentPath();
                        String comment = sourceTrees.getDocComment(path);
                        if (comment == null || !containsChinese(comment)) {
                            missing[0]++;
                        }
                    }
                }.scan(unit, null);
            }
            return missing[0];
        }
    }

    /**
     * 从当前 Maven 模块定位仓库中的源码目录。
     *
     * @param relativeSourceRoot 源码目录相对于仓库根目录的路径
     * @return 已规范化的源码目录
     */
    private Path sourceRoot(String relativeSourceRoot) {
        Path currentModule = Path.of(System.getProperty("user.dir"));
        Path repositoryRoot = currentModule.resolve("..").normalize();
        return repositoryRoot.resolve(relativeSourceRoot).normalize();
    }

    /**
     * 判断文档文本是否包含至少一个汉字。
     *
     * @param comment Javadoc 原文
     * @return 包含汉字时为 true
     */
    private boolean containsChinese(String comment) {
        return comment.codePoints()
                .anyMatch(codePoint -> Character.UnicodeScript.of(codePoint) == Character.UnicodeScript.HAN);
    }
}
