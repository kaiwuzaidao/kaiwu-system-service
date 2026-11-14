package com.kaiwu.common;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

/** Versioned source layout contract shared with generated projects. */
class PackageLayoutContractTest {
    private static final Pattern PACKAGE = Pattern.compile("(?m)^package ([a-zA-Z0-9_.]+);");

    @Test
    void productionSourcesFollowTheVersionedLayout() throws Exception {
        Path root = Files.exists(Path.of("docs/package-layout.json")) ? Path.of(".") : Path.of("..");
        var contract =
                JsonMapper.builder().build().readTree(Files.readString(root.resolve("docs/package-layout.json")));
        assertThat(contract.path("version").asInt()).isEqualTo(1);
        String profile = contract.path("profile").asString();
        String base = contract.path("basePackage").asString();
        Set<String> categories = new HashSet<>();
        contract.path("categories").forEach(value -> categories.add(value.asString()));
        Set<String> layers = new HashSet<>();
        contract.path("layers").forEach(value -> layers.add(value.asString()));
        Set<String> compatibility = new HashSet<>();
        contract.path("compatibilityTypes").forEach(value -> compatibility.add(value.asString()));
        Set<String> concreteHelpers = new HashSet<>();
        contract.path("concreteServiceHelpers").forEach(value -> {
            assertThat(value.path("reason").asString()).isNotBlank();
            concreteHelpers.add(value.path("type").asString());
        });
        List<String> failures = new ArrayList<>();
        Set<String> foundCompatibility = new HashSet<>();
        int sources = 0;
        for (var sourceRoot : contract.path("sourceRoots")) {
            Path directory = root.resolve(sourceRoot.asString());
            assertThat(directory).isDirectory();
            try (var files = Files.walk(directory)) {
                for (Path file :
                        files.filter(path -> path.toString().endsWith(".java")).toList()) {
                    String relative = directory.relativize(file).toString().replace('\\', '/');
                    String source = Files.readString(file);
                    if ("business".equals(profile) && requiresServiceInterface(relative, source, concreteHelpers)) {
                        failures.add(relative
                                + ": application Service must be an interface with a service/impl implementation");
                    }
                    failures.addAll(violations(relative, source, profile, base, categories, layers, compatibility));
                    var match = PACKAGE.matcher(source);
                    if (match.find()) {
                        String type = match.group(1) + "."
                                + file.getFileName().toString().replace(".java", "");
                        if (compatibility.contains(type)) foundCompatibility.add(type);
                    }
                    sources++;
                }
            }
        }
        assertThat(sources).isPositive();
        assertThat(failures)
                .as("package-layout.json / PACKAGE_STRUCTURE.md: %s", failures)
                .isEmpty();
        assertThat(foundCompatibility)
                .as("Published Java types cannot silently disappear")
                .containsAll(compatibility);
    }

    @Test
    void rejectsFlatBusinessPackagesWrongLayersAndMismatchedPaths() {
        Set<String> categories = Set.of("identity");
        Set<String> layers = Set.of("controller", "service");
        assertThat(violations(
                        "com/example/module/identity/UserController.java",
                        "package com.example.module.identity;",
                        "business",
                        "com.example",
                        categories,
                        layers,
                        Set.of()))
                .isNotEmpty();
        assertThat(violations(
                        "com/example/module/identity/service/UserController.java",
                        "package com.example.module.identity.service;",
                        "business",
                        "com.example",
                        categories,
                        layers,
                        Set.of()))
                .isNotEmpty();
        assertThat(violations(
                        "com/example/module/identity/controller/UserController.java",
                        "package com.example.module.identity.controller;",
                        "business",
                        "com.example",
                        categories,
                        layers,
                        Set.of()))
                .isEmpty();
        assertThat(violations(
                        "com/example/UserController.java",
                        "package com.example.module.identity.controller;",
                        "business",
                        "com.example",
                        categories,
                        layers,
                        Set.of()))
                .isNotEmpty();
        assertThat(violations(
                        "com/example/module/old/dto/UserRequest.java",
                        "package com.example.module.old.dto;",
                        "business",
                        "com.example",
                        categories,
                        layers,
                        Set.of("com.example.module.old.dto.UserRequest")))
                .isEmpty();
        assertThat(violations(
                        "com/example/module/old/dto/NewRequest.java",
                        "package com.example.module.old.dto;",
                        "business",
                        "com.example",
                        categories,
                        layers,
                        Set.of("com.example.module.old.dto.UserRequest")))
                .isNotEmpty();
    }

    @Test
    void rejectsConcreteApplicationServicesButAllowsDocumentedAlgorithmHelpers() {
        String service = "com/example/module/identity/service/UserService.java";
        String source = "package com.example.module.identity.service; public class UserService {}";
        assertThat(requiresServiceInterface(service, source, Set.of())).isTrue();
        assertThat(requiresServiceInterface(service, source.replace("public class", "public interface"), Set.of()))
                .isFalse();
        assertThat(requiresServiceInterface(service, source, Set.of("com.example.module.identity.service.UserService")))
                .isFalse();
        assertThat(requiresServiceInterface(
                        "com/example/module/identity/service/impl/UserServiceImpl.java", source, Set.of()))
                .isFalse();
    }

    private static boolean requiresServiceInterface(String path, String source, Set<String> helpers) {
        if (!path.contains("/service/") || path.contains("/service/impl/") || !path.endsWith("Service.java"))
            return false;
        String type = path.replace('/', '.').replace(".java", "");
        return !helpers.contains(type)
                && Pattern.compile("\\bpublic\\s+(?:final\\s+)?class\\s+")
                        .matcher(source)
                        .find();
    }

    private static List<String> violations(
            String path,
            String source,
            String profile,
            String base,
            Set<String> categories,
            Set<String> layers,
            Set<String> compatibility) {
        var match = PACKAGE.matcher(source);
        if (!match.find()) return List.of(path + ": missing package");
        String pkg = match.group(1);
        String name = path.substring(path.lastIndexOf('/') + 1).replace(".java", "");
        if (!path.equals(pkg.replace('.', '/') + "/" + name + ".java"))
            return List.of(path + ": package/path mismatch");
        if (compatibility.contains(pkg + "." + name)) return List.of();
        String prefix = "business".equals(profile) ? base + ".module." : base + ".";
        if (pkg.equals(base) && name.endsWith("Application")) return List.of();
        if (pkg.equals(base + ".common")
                || pkg.startsWith(base + ".port.")
                || pkg.equals(base + ".port")
                || pkg.equals(base + ".config")) return List.of();
        if ("gateway".equals(profile) && (pkg.equals(base + ".filter") || pkg.equals(base + ".client")))
            return List.of();
        if (!pkg.startsWith(prefix)) return List.of(path + ": outside declared ownership");
        String[] parts = pkg.substring(prefix.length()).split("\\.");
        if (parts.length < 2 || !categories.contains(parts[0]) || !layers.contains(parts[1]))
            return List.of(path + ": expected category/layer/Class");
        if (parts.length > 2
                && !(parts.length == 3
                        && (parts[1].equals("service") && parts[2].equals("impl")
                                || parts[1].equals("dto")
                                        && Set.of("query", "request").contains(parts[2]))))
            return List.of(path + ": extra feature directory");
        if (name.endsWith("Controller") && !parts[1].equals("controller"))
            return List.of(path + ": Controller in wrong layer");
        if (name.endsWith("Mapper") && !parts[1].equals("mapper")) return List.of(path + ": Mapper in wrong layer");
        if (name.endsWith("Repository") && !parts[1].equals("repository"))
            return List.of(path + ": Repository in wrong layer");
        return List.of();
    }
}
