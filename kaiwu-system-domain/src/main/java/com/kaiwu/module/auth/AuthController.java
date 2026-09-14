package com.kaiwu.module.auth;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.auth.dto.ChangePasswordRequest;
import com.kaiwu.module.auth.dto.LoginRequest;
import com.kaiwu.module.auth.dto.UpdateLocaleRequest;
import com.kaiwu.module.auth.vo.CurrentUserView;
import com.kaiwu.module.auth.vo.NavigationMenuView;
import com.kaiwu.module.auth.vo.TokenView;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.CookieValue;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 平台登录会话接口。
 */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;
    private final RefreshCookieManager refreshCookieManager;

    public AuthController(AuthService authService, RefreshCookieManager refreshCookieManager) {
        this.authService = authService;
        this.refreshCookieManager = refreshCookieManager;
    }

    /** 登录；refresh token 只写进 HttpOnly Cookie，不进响应体。 */
    @PostMapping("/login")
    public Result<TokenView> login(
            @Valid @RequestBody LoginRequest request,
            HttpServletRequest servletRequest,
            HttpServletResponse servletResponse) {
        AuthService.AuthSession session =
                authService.login(request.username(), request.password(), RequestMetadata.from(servletRequest));
        refreshCookieManager.write(servletResponse, session.refreshToken(), session.absoluteExpiresAt());
        return Result.ok(session.token());
    }

    /** 用 Cookie 里的 refresh token 换取新的 access token；会话已撤销时返回 401。 */
    @PostMapping("/refresh")
    public Result<TokenView> refresh(
            @CookieValue(name = RefreshCookieManager.COOKIE_NAME, required = false) String refreshToken,
            HttpServletResponse servletResponse) {
        try {
            AuthService.AuthSession session = authService.refresh(refreshToken);
            refreshCookieManager.write(servletResponse, session.refreshToken(), session.absoluteExpiresAt());
            return Result.ok(session.token());
        } catch (AuthFailureException exception) {
            refreshCookieManager.clear(servletResponse);
            throw exception;
        }
    }

    @PostMapping("/logout")
    public Result<Void> logout(HttpServletRequest servletRequest, HttpServletResponse servletResponse) {
        authService.logout(StarterContext.require(), RequestMetadata.from(servletRequest));
        refreshCookieManager.clear(servletResponse);
        return Result.ok(null);
    }

    /**
     * 当前登录用户自助修改密码。
     *
     * <p>不加 {@code @RequirePermission}：改自己的密码是登录用户的固有能力，
     * 不依赖任何项目角色；作用对象由 Context 的 userId 决定，无法指定他人。
     */
    @PostMapping("/password")
    public Result<Void> changePassword(
            @Valid @RequestBody ChangePasswordRequest request, HttpServletRequest servletRequest) {
        authService.changePassword(StarterContext.require(), request, RequestMetadata.from(servletRequest));
        return Result.ok(null);
    }

    /**
     * 当前用户的导航菜单树，侧边栏由此渲染。
     *
     * <p>不加 {@code @RequirePermission}：返回内容已按用户在 system 项目的角色授权过滤，
     * 无权限的用户拿到的就是空数组。
     */
    @GetMapping("/menus")
    public Result<List<NavigationMenuView>> menus() {
        return Result.ok(authService.navigationMenus(StarterContext.require()));
    }

    @GetMapping("/me")
    public Result<CurrentUserView> me() {
        return Result.ok(authService.currentUser(StarterContext.require()));
    }

    /**
     * 当前登录用户修改自己的界面语言。
     *
     * <p>和自助改密一样，这是登录用户固有能力，不依赖项目角色；目标用户只取自 Context。
     */
    @PutMapping("/me/locale")
    public Result<CurrentUserView> updateLocale(@Valid @RequestBody UpdateLocaleRequest request) {
        return Result.ok(authService.updateLocale(StarterContext.require(), request));
    }
}
