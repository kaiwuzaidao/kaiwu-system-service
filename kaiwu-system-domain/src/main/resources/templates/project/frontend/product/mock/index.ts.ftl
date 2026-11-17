<#noparse>import { platform, panel, fallback } from '../mock-support/platform';
import { requests } from '../mock-support/requests';
export default { ...platform, ...panel, ...requests, ...fallback };
</#noparse>
