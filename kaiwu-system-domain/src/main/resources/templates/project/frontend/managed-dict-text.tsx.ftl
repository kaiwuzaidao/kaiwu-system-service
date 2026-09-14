import { Tag, type TagProps } from 'antd';
import React from 'react';
import useManagedDictionary from '@/hooks/useManagedDictionary';

export interface ManagedDictTextProps {
  dictCode: string;
  value?: string | number | null;
  className?: string;
  style?: TagProps['style'];
}

export default function ManagedDictText({
  dictCode,
  value,
  className,
  style,
}: ManagedDictTextProps): React.ReactElement {
  const options = useManagedDictionary(dictCode);
  const raw = value == null ? '' : String(value);
  const option = options.find((item) => item.value === raw);
  if (option?.color) {
    return (
      <Tag className={className} style={style} color={option.color}>
        {option.label}
      </Tag>
    );
  }
  return (
    <span className={className} style={style}>
      {option?.label ?? raw}
    </span>
  );
}
