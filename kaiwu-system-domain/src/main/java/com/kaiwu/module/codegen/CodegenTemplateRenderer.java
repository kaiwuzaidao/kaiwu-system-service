package com.kaiwu.module.codegen;

import com.kaiwu.common.ApiException;
import freemarker.template.Configuration;
import freemarker.template.TemplateExceptionHandler;
import java.io.StringWriter;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

@Component
public class CodegenTemplateRenderer {

    private final Configuration configuration;

    public CodegenTemplateRenderer() {
        configuration = new Configuration(Configuration.VERSION_2_3_34);
        configuration.setClassLoaderForTemplateLoading(getClass().getClassLoader(), "/templates");
        configuration.setDefaultEncoding("UTF-8");
        configuration.setTemplateExceptionHandler(TemplateExceptionHandler.RETHROW_HANDLER);
        configuration.setLogTemplateExceptions(false);
        configuration.setWrapUncheckedExceptions(true);
    }

    /** 渲染 FreeMarker 模板；模板本身出错属于平台缺陷，直接抛出不做兜底。 */
    public String render(String template, Map<String, Object> variables) {
        try {
            StringWriter writer = new StringWriter();
            configuration.getTemplate(template).process(variables, writer);
            return writer.toString();
        } catch (Exception exception) {
            throw new ApiException(
                    HttpStatus.INTERNAL_SERVER_ERROR, "代码模板渲染失败：" + template, "api.common.internalError");
        }
    }
}
