import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.yaml.snakeyaml.LoaderOptions;
import org.yaml.snakeyaml.Yaml;
import org.yaml.snakeyaml.constructor.SafeConstructor;

/** 输出业务菜单 BUTTON 权限，供校验脚本与服务端注解逐码比对。 */
class MenuPermissions {
    /** 只读取单份 YAML 文档，解析限制与平台菜单导入一致。 */
    public static void main(String[] args) throws Exception {
        var options = new LoaderOptions();
        options.setAllowDuplicateKeys(false);
        options.setMaxAliasesForCollections(20);
        options.setCodePointLimit(200_000);
        try (var reader = Files.newBufferedReader(Path.of(args[0]), StandardCharsets.UTF_8)) {
            var codes = new HashSet<String>();
            collect(new Yaml(new SafeConstructor(options)).load(reader), codes, 0);
            codes.forEach(System.out::println);
        }
    }

    /** 按菜单树遍历，只采集按钮，拒绝不合法的列表和循环引用。 */
    private static void collect(Object nodes, Set<String> codes, int depth) {
        if (!(nodes instanceof List<?> items) || depth > 50) {
            throw new IllegalArgumentException("menus.yml 需要有限深度的菜单列表");
        }
        for (Object item : items) {
            if (!(item instanceof Map<?, ?> menu)) throw new IllegalArgumentException("菜单节点必须是对象");
            if ("BUTTON".equals(menu.get("type"))) {
                if (!(menu.get("permission") instanceof String code) || code.isBlank() || !codes.add(code)) {
                    throw new IllegalArgumentException("BUTTON 权限为空或重复");
                }
            }
            if (menu.containsKey("children")) collect(menu.get("children"), codes, depth + 1);
        }
    }
}
