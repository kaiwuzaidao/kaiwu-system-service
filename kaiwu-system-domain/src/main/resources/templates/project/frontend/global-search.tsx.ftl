<#noparse>import { SearchOutlined } from '@ant-design/icons';
import { AutoComplete, Input, Spin, Typography } from 'antd';
import { useEffect, useMemo, useRef, useState } from 'react';
import { globalSearch, gotoPlatform, type SearchItem } from '@/services/platform';

const TYPE_LABEL: Record<SearchItem['type'], string> = {
  PROJECT: '项目',
  USER: '用户',
  DELIVERY: '交付',
};

/**
 * 平台级全局搜索。命中的是平台资源（项目/用户/交付），选中后需要跳出本子应用
 * 回到平台，因此走 gotoPlatform 整页跳转而不是子应用内路由。
 */
export default function GlobalSearch({ block }: { block?: boolean }) {
  const [keyword, setKeyword] = useState('');
  const [items, setItems] = useState<SearchItem[]>([]);
  const [loading, setLoading] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const seq = useRef(0);

  useEffect(() => {
    const shortcut = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
        event.preventDefault();
        inputRef.current?.focus();
      }
    };
    window.addEventListener('keydown', shortcut);
    return () => window.removeEventListener('keydown', shortcut);
  }, []);

  useEffect(() => {
    const query = keyword.trim();
    if (!query) {
      setItems([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    // 只认最后一次请求的结果，避免慢响应覆盖新输入。
    const current = ++seq.current;
    const timer = window.setTimeout(() => {
      void globalSearch(query)
        .then((data) => {
          if (seq.current === current) setItems(data ?? []);
        })
        .catch(() => {
          if (seq.current === current) setItems([]);
        })
        .finally(() => {
          if (seq.current === current) setLoading(false);
        });
    }, 250);
    return () => window.clearTimeout(timer);
  }, [keyword]);

  const options = useMemo(
    () =>
      items.map((item) => ({
        value: item.path,
        label: (
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <Typography.Text style={{ flex: 1 }} ellipsis>
              {item.title}
            </Typography.Text>
            <Typography.Text type="secondary" style={{ fontSize: 12 }}>
              {TYPE_LABEL[item.type] ?? item.type}
            </Typography.Text>
          </div>
        ),
      })),
    [items],
  );

  return (
    <AutoComplete
      value={keyword}
      options={options}
      style={block ? { width: '100%' } : { width: 220 }}
      onChange={setKeyword}
      onSelect={(path: string) => gotoPlatform(path)}
      notFoundContent={loading ? <Spin size="small" /> : keyword.trim() ? '无匹配结果' : null}
    >
      <Input
        ref={inputRef as never}
        allowClear
        variant="borderless"
        placeholder="搜索"
        prefix={<SearchOutlined style={{ color: 'rgba(0,0,0,0.45)' }} />}
        suffix={
          <Typography.Text type="secondary" style={{ fontSize: 12 }}>
            ⌘K
          </Typography.Text>
        }
      />
    </AutoComplete>
  );
}
</#noparse>