package com.kaiwu.module.agent.store;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.kaiwu.common.ApiException;
import com.kaiwu.common.LongIdGenerator;
import com.kaiwu.common.PageBounds;
import com.kaiwu.common.PageResult;
import com.kaiwu.module.agent.dto.*;
import com.kaiwu.module.agent.entity.*;
import com.kaiwu.module.agent.mapper.*;
import com.kaiwu.module.agent.vo.*;
import java.time.LocalDateTime;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Short transactions only: never hold a database lock while waiting on a model or business service. */
@Service
public class AgentConversationStore {
    private final AgentConversationMapper conversations;
    private final AgentMessageMapper messages;
    private final AgentMemoryMapper memories;

    public AgentConversationStore(
            AgentConversationMapper conversations, AgentMessageMapper messages, AgentMemoryMapper memories) {
        this.conversations = conversations;
        this.messages = messages;
        this.memories = memories;
    }

    public PageResult<AgentConversationView> list(String userId, int current) {
        PageBounds.require(current, 20);
        var page = conversations.selectPage(
                new Page<>(current, 20),
                new LambdaQueryWrapper<AgentConversationEntity>()
                        .eq(AgentConversationEntity::getUserId, userId)
                        .orderByDesc(AgentConversationEntity::getUpdatedAt)
                        .orderByDesc(AgentConversationEntity::getId));
        return new PageResult<>(
                page.getCurrent(),
                page.getSize(),
                page.getTotal(),
                page.getRecords().stream().map(this::view).toList());
    }

    @Transactional
    public AgentConversationView create(String userId, AgentConversationRequest request) {
        conversations.lockOwner(userId);
        if (conversations.selectCount(new LambdaQueryWrapper<AgentConversationEntity>()
                        .eq(AgentConversationEntity::getUserId, userId))
                >= 100) throw conflict("api.agent.conversationLimit");
        var entity = new AgentConversationEntity();
        entity.setId(LongIdGenerator.nextId());
        entity.setUserId(userId);
        entity.setTitle(request.title().trim());
        entity.setUseMemory(request.useMemory());
        entity.setCreatedAt(LocalDateTime.now());
        entity.setUpdatedAt(entity.getCreatedAt());
        conversations.insert(entity);
        return view(entity);
    }

    public AgentConversationEntity owned(String userId, String id) {
        var entity = conversations.selectOne(new LambdaQueryWrapper<AgentConversationEntity>()
                .eq(AgentConversationEntity::getId, id)
                .eq(AgentConversationEntity::getUserId, userId));
        if (entity == null) throw missing();
        return entity;
    }

    @Transactional
    public AgentConversationView update(String userId, String id, AgentConversationRequest request) {
        var entity = locked(userId, id);
        ensureIdle(entity);
        conversations.update(
                null,
                new LambdaUpdateWrapper<AgentConversationEntity>()
                        .eq(AgentConversationEntity::getId, id)
                        .eq(AgentConversationEntity::getUserId, userId)
                        .set(AgentConversationEntity::getTitle, request.title().trim())
                        .set(AgentConversationEntity::getUseMemory, request.useMemory())
                        .set(AgentConversationEntity::getUpdatedAt, LocalDateTime.now()));
        return view(owned(userId, id));
    }

    @Transactional
    public void delete(String userId, String id) {
        var entity = locked(userId, id);
        ensureIdle(entity);
        messages.delete(new LambdaQueryWrapper<AgentMessageEntity>().eq(AgentMessageEntity::getConversationId, id));
        conversations.delete(new LambdaQueryWrapper<AgentConversationEntity>()
                .eq(AgentConversationEntity::getId, id)
                .eq(AgentConversationEntity::getUserId, userId));
    }

    public PageResult<AgentMessageView> messages(String userId, String id, int current) {
        PageBounds.require(current, 30);
        owned(userId, id);
        var page = messages.selectPage(
                new Page<>(current, 30),
                new LambdaQueryWrapper<AgentMessageEntity>()
                        .eq(AgentMessageEntity::getConversationId, id)
                        .orderByDesc(AgentMessageEntity::getCreatedAt)
                        .orderByDesc(AgentMessageEntity::getId));
        return new PageResult<>(
                page.getCurrent(),
                page.getSize(),
                page.getTotal(),
                page.getRecords().stream()
                        .map(e -> new AgentMessageView(
                                e.getId(),
                                e.getQuestion(),
                                e.getAnswer(),
                                Boolean.TRUE.equals(e.getCompleted()),
                                e.getCreatedAt()))
                        .toList());
    }
    /** A row lease serializes turns across browser tabs. Duplicate request IDs are never replayed. */
    @Transactional
    public String begin(String userId, String id, AgentMessageRequest request) {
        var entity = locked(userId, id);
        ensureIdle(entity);
        if (messages.selectCount(new LambdaQueryWrapper<AgentMessageEntity>()
                        .eq(AgentMessageEntity::getConversationId, id)
                        .eq(AgentMessageEntity::getRequestId, request.requestId()))
                > 0) throw conflict("api.agent.messageDuplicate");
        var message = new AgentMessageEntity();
        message.setId(LongIdGenerator.nextId());
        message.setConversationId(id);
        message.setRequestId(request.requestId());
        message.setQuestion(request.question());
        message.setCompleted(false);
        message.setCreatedAt(LocalDateTime.now());
        messages.insert(message);
        conversations.update(
                null,
                new LambdaUpdateWrapper<AgentConversationEntity>()
                        .eq(AgentConversationEntity::getId, id)
                        .eq(AgentConversationEntity::getUserId, userId)
                        .set(AgentConversationEntity::getRunId, message.getId())
                        .set(
                                AgentConversationEntity::getBusyUntil,
                                LocalDateTime.now().plusMinutes(5))
                        .set(AgentConversationEntity::getUpdatedAt, LocalDateTime.now()));
        return message.getId();
    }
    /** Only the matching run may finish; a timed-out worker must not overwrite a newer turn. */
    @Transactional
    public boolean finish(String userId, String id, String messageId, String answer, boolean completed) {
        var entity = conversations.lockOwned(id, userId);
        if (entity == null || !messageId.equals(entity.getRunId())) return false;
        messages.update(
                null,
                new LambdaUpdateWrapper<AgentMessageEntity>()
                        .eq(AgentMessageEntity::getId, messageId)
                        .eq(AgentMessageEntity::getConversationId, id)
                        .set(AgentMessageEntity::getAnswer, answer)
                        .set(AgentMessageEntity::getCompleted, completed));
        conversations.update(
                null,
                new LambdaUpdateWrapper<AgentConversationEntity>()
                        .eq(AgentConversationEntity::getId, id)
                        .eq(AgentConversationEntity::getUserId, userId)
                        .set(AgentConversationEntity::getRunId, null)
                        .set(AgentConversationEntity::getBusyUntil, null)
                        .set(AgentConversationEntity::getUpdatedAt, LocalDateTime.now()));
        return true;
    }

    public List<AgentConversationTurn> history(String userId, String id) {
        owned(userId, id);
        var rows = messages.selectList(new LambdaQueryWrapper<AgentMessageEntity>()
                .eq(AgentMessageEntity::getConversationId, id)
                .eq(AgentMessageEntity::getCompleted, true)
                .orderByDesc(AgentMessageEntity::getCreatedAt)
                .orderByDesc(AgentMessageEntity::getId)
                .last("LIMIT 4"));
        return rows.reversed().stream()
                .map(e -> new AgentConversationTurn(e.getQuestion(), truncate(e.getAnswer(), 2000)))
                .toList();
    }

    public List<AgentMemoryView> memories(String userId) {
        return memories
                .selectList(new LambdaQueryWrapper<AgentMemoryEntity>()
                        .eq(AgentMemoryEntity::getUserId, userId)
                        .orderByDesc(AgentMemoryEntity::getUpdatedAt)
                        .orderByDesc(AgentMemoryEntity::getId))
                .stream()
                .map(this::view)
                .toList();
    }

    @Transactional
    public AgentMemoryView saveMemory(String userId, String id, AgentMemoryRequest request) {
        conversations.lockOwner(userId);
        AgentMemoryEntity entity;
        if (id == null) {
            if (memories.selectCount(
                            new LambdaQueryWrapper<AgentMemoryEntity>().eq(AgentMemoryEntity::getUserId, userId))
                    >= 20) throw conflict("api.agent.memoryLimit");
            entity = new AgentMemoryEntity();
            entity.setId(LongIdGenerator.nextId());
            entity.setUserId(userId);
            entity.setCreatedAt(LocalDateTime.now());
        } else {
            entity = memories.selectOne(new LambdaQueryWrapper<AgentMemoryEntity>()
                    .eq(AgentMemoryEntity::getId, id)
                    .eq(AgentMemoryEntity::getUserId, userId));
            if (entity == null) throw missing();
        }
        entity.setContent(request.content().trim());
        entity.setEnabled(request.enabled());
        entity.setUpdatedAt(LocalDateTime.now());
        if (id == null) memories.insert(entity);
        else
            memories.update(
                    null,
                    new LambdaUpdateWrapper<AgentMemoryEntity>()
                            .eq(AgentMemoryEntity::getId, id)
                            .eq(AgentMemoryEntity::getUserId, userId)
                            .set(AgentMemoryEntity::getContent, entity.getContent())
                            .set(AgentMemoryEntity::getEnabled, entity.getEnabled())
                            .set(AgentMemoryEntity::getUpdatedAt, entity.getUpdatedAt()));
        return view(entity);
    }

    public void deleteMemory(String userId, String id) {
        if (memories.delete(new LambdaQueryWrapper<AgentMemoryEntity>()
                        .eq(AgentMemoryEntity::getId, id)
                        .eq(AgentMemoryEntity::getUserId, userId))
                == 0) throw missing();
    }

    private AgentConversationEntity locked(String userId, String id) {
        var entity = conversations.lockOwned(id, userId);
        if (entity == null) throw missing();
        return entity;
    }

    private void ensureIdle(AgentConversationEntity entity) {
        if (entity.getBusyUntil() != null && entity.getBusyUntil().isAfter(LocalDateTime.now()))
            throw conflict("api.agent.conversationBusy");
    }

    private AgentConversationView view(AgentConversationEntity e) {
        return new AgentConversationView(
                e.getId(), e.getTitle(), Boolean.TRUE.equals(e.getUseMemory()), e.getUpdatedAt());
    }

    private AgentMemoryView view(AgentMemoryEntity e) {
        return new AgentMemoryView(e.getId(), e.getContent(), Boolean.TRUE.equals(e.getEnabled()), e.getUpdatedAt());
    }

    public static String truncate(String text, int max) {
        return text == null ? null : text.substring(0, Math.min(text.length(), max));
    }

    private static ApiException missing() {
        return new ApiException(HttpStatus.NOT_FOUND, "记录不存在或无权限访问", "api.agent.personalNotFound");
    }

    private static ApiException conflict(String key) {
        return new ApiException(HttpStatus.CONFLICT, "当前操作无法完成", key);
    }
}
