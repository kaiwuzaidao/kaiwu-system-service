package ${basePackage}.config;

import com.baomidou.mybatisplus.annotation.DbType;
import com.baomidou.mybatisplus.extension.plugins.MybatisPlusInterceptor;
import com.baomidou.mybatisplus.extension.plugins.inner.InnerInterceptor;
import com.baomidou.mybatisplus.extension.plugins.inner.PaginationInnerInterceptor;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** 配置 MyBatis-Plus 的内置拦截器：可选的数据范围拦截器必须排在分页拦截器之前。 */
@Configuration
public class MybatisPlusConfig {

    /**
     * 创建 MyBatis-Plus 拦截器。
     *
     * <p>引入 {@code kaiwu-data-scope} 依赖后，名为 {@code dataScopeInnerInterceptor} 的 Bean 会被注册在
     * 分页之前；没有引入时 {@code ifAvailable} 什么也不做，行为与不使用数据范围完全一致。这里按 Bean 名限定而不是
     * 引用具体类，是为了在没有该依赖时本类仍能编译。</p>
     *
     * @param dataScope 可选的数据范围拦截器
     * @return 已注册数据范围（如有）与分页内置拦截器的 MyBatis-Plus 拦截器
     */
    @Bean
    public MybatisPlusInterceptor mybatisPlusInterceptor(
            @Qualifier("dataScopeInnerInterceptor") ObjectProvider<InnerInterceptor> dataScope) {
        MybatisPlusInterceptor interceptor = new MybatisPlusInterceptor();
        dataScope.ifAvailable(interceptor::addInnerInterceptor);
        interceptor.addInnerInterceptor(new PaginationInnerInterceptor(DbType.MYSQL));
        return interceptor;
    }
}
