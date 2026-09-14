import { Button, type ButtonProps } from 'antd';
import React from 'react';
import { useProjectAccess } from '@/providers/ProjectAccessProvider';

export interface PermissionButtonProps extends ButtonProps {
  permission: string;
}

/** 前端只控制可见性；后端 @RequirePermission 才是最终安全边界。 */
export default function PermissionButton({
  permission,
  ...buttonProps
}: PermissionButtonProps): React.ReactElement | null {
  const { permissions } = useProjectAccess();
  return permissions.has(permission) ? <Button {...buttonProps} /> : null;
}
