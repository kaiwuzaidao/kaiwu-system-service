package ${basePackage}.common;

import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 约束 {@code logging.no-sensitive-data}：运行时日志不得写出凭据与敏感个人信息。
 *
 * <p>Gitleaks 只看仓库里的静态文本，管不了运行时打印什么。Starter 的统一访问日志已经做了脱敏，
 * 缺口在散落各处的 {@code log.*} 调用——一次「加个日志方便排查」就能把 token 或密码写进采集链路，
 * 而日志往往比数据库流转得更广、留存得更久。</p>
 *
 * <p>判定方式：剥掉日志语句里的字符串字面量后，看剩下的实参标识符是否以敏感词结尾
 * （{@code rawPassword}、{@code accessToken} 命中；{@code credentialId}、{@code tokenType}
 * 这类只是 ID 或类型的不命中）；同时检查格式串里是否出现 {@code password=} 这类键名。
 * 这是文本启发式，挡的是「顺手把整个凭据打出来」，不声称能识别语义脱敏。</p>
 */
class SensitiveLoggingConventionTest {

    private static final List<Path> SOURCE_ROOTS = List.of(
            Path.of("src/main/java"),
            Path.of("../kaiwu-${projectCode}-boot/src/main/java"));

    private static final Pattern LOG_CALL = Pattern.compile(
            "\\b(?:log|LOG|LOGGER|[A-Z_]*LOG)\\.(?:trace|debug|info|warn|error)\\s*\\(");

    private static final Pattern STRING_LITERAL = Pattern.compile("\"(?:\\\\.|[^\"\\\\])*\"");

    /** 敏感词根；只在标识符**结尾**匹配，避免把 credentialId、tokenType 这类误判。 */
    private static final Pattern SENSITIVE_ARGUMENT = Pattern.compile(
            "(?i)\\b[A-Za-z0-9_]*"
                    + "(password|passwd|secret|token|credential|privatekey|apikey"
                    + "|idcard|idnumber|phone|mobile|plaintext|ciphertext)s?\\b");

    /** 格式串里直接写出的敏感键名，例如 {@code "password={}"}。 */
    private static final Pattern SENSITIVE_FORMAT_KEY = Pattern.compile(
            "(?i)(password|passwd|secret|token|credential|privatekey|apikey|idcard|idnumber)"
                    + "\\s*[=:：]");

    @Test
    void logStatementsNeverCarryCredentialsOrSensitiveIdentifiers() {
        List<String> offenders = new ArrayList<>();
        for (Path root : SOURCE_ROOTS) {
            if (!Files.isDirectory(root)) {
                continue;
            }
            for (Path source : javaSources(root)) {
                String content = read(source);
                for (String statement : logStatements(content)) {
                    String arguments = STRING_LITERAL.matcher(statement).replaceAll("\"\"");
                    boolean leakedArgument = SENSITIVE_ARGUMENT.matcher(arguments).find();
                    boolean leakedFormatKey = literals(statement).stream()
                            .anyMatch(literal -> SENSITIVE_FORMAT_KEY.matcher(literal).find());
                    if (leakedArgument || leakedFormatKey) {
                        offenders.add(source + " -> " + oneLine(statement));
                    }
                }
            }
        }

        assertThat(offenders)
                .withFailMessage("以下日志语句可能写出凭据或敏感信息，"
                        + "请只记录标识、长度或掩码后的值：%s", offenders)
                .isEmpty();
    }

    /** 提取每条日志语句的完整文本（按括号配平，允许跨行）。 */
    private static List<String> logStatements(String content) {
        List<String> statements = new ArrayList<>();
        Matcher matcher = LOG_CALL.matcher(content);
        while (matcher.find()) {
            int depth = 1;
            int index = matcher.end();
            boolean inString = false;
            while (index < content.length() && depth > 0) {
                char current = content.charAt(index);
                if (inString) {
                    if (current == '\\') {
                        index++;
                    } else if (current == '"') {
                        inString = false;
                    }
                } else if (current == '"') {
                    inString = true;
                } else if (current == '(') {
                    depth++;
                } else if (current == ')') {
                    depth--;
                }
                index++;
            }
            statements.add(content.substring(matcher.start(), Math.min(index, content.length())));
        }
        return statements;
    }

    private static List<String> literals(String statement) {
        List<String> literals = new ArrayList<>();
        Matcher matcher = STRING_LITERAL.matcher(statement);
        while (matcher.find()) {
            literals.add(matcher.group());
        }
        return literals;
    }

    private static String oneLine(String statement) {
        return statement.replaceAll("\\s+", " ").trim();
    }

    private static List<Path> javaSources(Path root) {
        try (Stream<Path> files = Files.walk(root)) {
            return files.filter(path -> path.toString().endsWith(".java")).toList();
        } catch (IOException exception) {
            throw new UncheckedIOException(exception);
        }
    }

    private static String read(Path path) {
        try {
            return Files.readString(path);
        } catch (IOException exception) {
            throw new UncheckedIOException(exception);
        }
    }
}
