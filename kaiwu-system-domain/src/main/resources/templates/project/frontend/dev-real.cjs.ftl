process.env.PORT ??= '${localWebPort}';
process.env.MOCK = 'none';
process.argv.splice(2, 0, 'dev');
require('@umijs/max/bin/max.js');
