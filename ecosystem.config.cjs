module.exports = {
  apps: [
    {
      name: "lyra",
      script: "node_modules/next/dist/bin/next",
      args: "start --port 3100",
      cwd: "/www/wwwroot/lyra",
      env: {
        NODE_ENV: "production",
        PORT: "3100",
      },
    },
  ],
};
