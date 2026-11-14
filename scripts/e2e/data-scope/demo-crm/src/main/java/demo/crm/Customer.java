package demo.crm;

import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.FieldStrategy;
import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;

/** 受控实体：归属字段按 Skill 约定声明插入填充、禁止更新。 */
@TableName("demo_customer")
public class Customer {
    @TableId(type = IdType.AUTO)
    public Long id;

    public String name;

    @TableField(fill = FieldFill.INSERT, updateStrategy = FieldStrategy.NEVER)
    public Long ownerUserId;

    @TableField(fill = FieldFill.INSERT, updateStrategy = FieldStrategy.NEVER)
    public Long ownerDeptId;

    public Long getId() {
        return id;
    }

    public String getName() {
        return name;
    }
}
