import { readFileSync } from 'node:fs';
export default {
  css: { postcss: { plugins: [] } },
  server: { host: '127.0.0.1', port: 5173, strictPort: true },
  plugins: [{
    name: 'local-layout-review',
    configureServer(server) {
      server.middlewares.use('/__review', (_request, response) => {
        response.setHeader('Content-Type', 'text/html');
        response.end(readFileSync(new URL('./tools/layout-review.html', import.meta.url)));
      });
    },
  }],
};
