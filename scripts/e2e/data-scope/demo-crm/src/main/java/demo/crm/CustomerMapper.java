package demo.crm;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Update;

/** 客户 Mapper。批量交接用手写 UPDATE，只有在 DataScopes.reassign 内才允许改归属列。 */
public interface CustomerMapper extends BaseMapper<Customer> {
    @Update("UPDATE demo_customer SET owner_user_id = #{toUser}, owner_dept_id = #{toDept} WHERE owner_user_id = #{fromUser}")
    int reassignAll(@Param("fromUser") long fromUser, @Param("toUser") long toUser, @Param("toDept") long toDept);
}
