import { Select, Tag, type SelectProps } from 'antd';
import React from 'react';
import useManagedDictionary from '@/hooks/useManagedDictionary';

export interface ManagedDictSelectProps extends Omit<SelectProps<string | string[]>, 'options'> {
  dictCode: string;
}

export default function ManagedDictSelect({
  dictCode,
  ...selectProps
}: ManagedDictSelectProps): React.ReactElement {
  const options = useManagedDictionary(dictCode);
  return (
    <Select<string | string[]>
      {...selectProps}
      options={options.map((option) => ({
        value: option.value,
        label: option.color ? <Tag color={option.color}>{option.label}</Tag> : option.label,
      }))}
    />
  );
}
