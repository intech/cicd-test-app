FROM node:21.5.0 AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
COPY . /app/tmp
WORKDIR /app/tmp
RUN corepack enable && \
    apt-get update || : && apt-get install python-is-python3 -y
RUN pnpm install --prod --frozen-lockfile

FROM node:21.5.0-slim AS web
# USER node   #WIP need to make proper rights after cap
WORKDIR /app
COPY --from=base /app/tmp /app

CMD [ "node", "src/cli.js" ]