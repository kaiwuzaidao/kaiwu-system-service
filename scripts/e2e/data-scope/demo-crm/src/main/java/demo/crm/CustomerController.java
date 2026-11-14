package demo.crm;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.kaiwu.datascope.DataScopeReassignRejectedException;
import com.kaiwu.datascope.DataScopes;
import com.kaiwu.starter.RequirePermission;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

/**
 * 示例客户接口。注意：这里没有任何数据范围代码——列表、详情、修改、删除、导出、Agent 读全部复用同一个查询，
 * 可见性完全由 kaiwu-data-scope 在 SQL 层保证。越权一律 404，不泄露「数据存在」。
 */
@RestController
@RequestMapping("/api/customers")
public class CustomerController {
    private final CustomerMapper mapper;

    public CustomerController(CustomerMapper mapper) {
        this.mapper = mapper;
    }

    /** 分页列表：total 与 records 同一口径。 */
    @GetMapping
    @RequirePermission("democrm:customer:list")
    public Map<String, Object> page(@RequestParam(defaultValue = "1") long current, @RequestParam(defaultValue = "50") long size) {
        Page<Customer> page = mapper.selectPage(new Page<>(current, size), new LambdaQueryWrapper<Customer>().orderByAsc(Customer::getId));
        return Map.of("total", page.getTotal(), "names", page.getRecords().stream().map(c -> c.name).toList());
    }

    /** 统计：与列表同一口径。 */
    @GetMapping("/count")
    @RequirePermission("democrm:customer:list")
    public Map<String, Object> count() {
        return Map.of("count", mapper.selectCount(null));
    }

    /** 详情：用 selectOne(wrapper)——这是生成模板默认会用到的路径，曾经整条绕过数据范围。 */
    @GetMapping("/{id}")
    @RequirePermission("democrm:customer:list")
    public Map<String, Object> get(@PathVariable long id) {
        Customer found = mapper.selectOne(new LambdaQueryWrapper<Customer>().eq(Customer::getId, id));
        if (found == null) throw notFound();
        return view(found);
    }

    /** 创建：归属由 Context 写入，请求体里没有也不接受归属字段。 */
    @PostMapping
    @RequirePermission("democrm:customer:create")
    public Map<String, Object> create(@RequestBody Map<String, String> body) {
        Customer customer = new Customer();
        customer.name = body.get("name");
        mapper.insert(customer);
        return view(customer);
    }

    /** 修改：越权行影响 0 行，转成 404。 */
    @PutMapping("/{id}")
    @RequirePermission("democrm:customer:update")
    public Map<String, Object> update(@PathVariable long id, @RequestBody Map<String, String> body) {
        int rows = mapper.update(null, new LambdaUpdateWrapper<Customer>().eq(Customer::getId, id).set(Customer::getName, body.get("name")));
        if (rows == 0) throw notFound();
        return Map.of("updated", rows);
    }

    /** 删除：越权行影响 0 行，转成 404。 */
    @DeleteMapping("/{id}")
    @RequirePermission("democrm:customer:delete")
    public Map<String, Object> delete(@PathVariable long id) {
        int rows = mapper.deleteById(id);
        if (rows == 0) throw notFound();
        return Map.of("deleted", rows);
    }

    /** 导出：与列表同一个查询，不分页。 */
    @GetMapping("/export")
    @RequirePermission("democrm:customer:export")
    public List<String> export() {
        return mapper.selectList(new LambdaQueryWrapper<Customer>().orderByAsc(Customer::getId)).stream().map(c -> c.name).toList();
    }

    /** 批量交接：把 fromUser 名下（且当前用户看得到的）行转给 toUser；新归属不合法转成 400。 */
    @PostMapping("/transfer")
    @RequirePermission("democrm:customer:transfer")
    public Map<String, Object> transfer(@RequestBody Map<String, Long> body) {
        long fromUser = body.get("fromUserId");
        long toUser = body.get("toUserId");
        long toDept = body.get("toDeptId");
        try {
            int rows = DataScopes.reassign(
                    "销售调岗交接", new DataScopes.Owner(toUser, toDept), () -> mapper.reassignAll(fromUser, toUser, toDept));
            return Map.of("transferred", rows);
        } catch (DataScopeReassignRejectedException rejected) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "新归属不合法");
        }
    }

    private static Map<String, Object> view(Customer customer) {
        Map<String, Object> view = new LinkedHashMap<>();
        view.put("id", customer.id);
        view.put("name", customer.name);
        view.put("ownerUserId", customer.ownerUserId);
        view.put("ownerDeptId", customer.ownerDeptId);
        return view;
    }

    private static ResponseStatusException notFound() {
        return new ResponseStatusException(HttpStatus.NOT_FOUND);
    }
}
