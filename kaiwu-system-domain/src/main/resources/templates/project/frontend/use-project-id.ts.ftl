import { useSyncExternalStore } from 'react';

const PROJECT_ID_CHANGE_EVENT = 'kaiwu:project-id-change';
let subscriberCount = 0;
let originalPushState: History['pushState'] | undefined;
let originalReplaceState: History['replaceState'] | undefined;

export function readProjectId(): string {
  if (typeof window === 'undefined') return '';
  return new URLSearchParams(window.location.search).get('projectId')?.trim() ?? '';
}

function subscribe(onChange: () => void): () => void {
  if (typeof window === 'undefined') return () => undefined;
  if (subscriberCount === 0) {
    originalPushState = window.history.pushState;
    originalReplaceState = window.history.replaceState;
    window.history.pushState = function pushState(...args: Parameters<History['pushState']>): void {
      originalPushState?.apply(window.history, args);
      window.dispatchEvent(new Event(PROJECT_ID_CHANGE_EVENT));
    };
    window.history.replaceState = function replaceState(
      ...args: Parameters<History['replaceState']>
    ): void {
      originalReplaceState?.apply(window.history, args);
      window.dispatchEvent(new Event(PROJECT_ID_CHANGE_EVENT));
    };
  }
  subscriberCount += 1;
  window.addEventListener('popstate', onChange);
  window.addEventListener(PROJECT_ID_CHANGE_EVENT, onChange);
  return () => {
    window.removeEventListener('popstate', onChange);
    window.removeEventListener(PROJECT_ID_CHANGE_EVENT, onChange);
    subscriberCount -= 1;
    if (subscriberCount === 0 && originalPushState && originalReplaceState) {
      window.history.pushState = originalPushState;
      window.history.replaceState = originalReplaceState;
      originalPushState = undefined;
      originalReplaceState = undefined;
    }
  };
}

export default function useProjectId(): string {
  return useSyncExternalStore(subscribe, readProjectId, () => '');
}
