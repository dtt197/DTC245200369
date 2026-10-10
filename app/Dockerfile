FROM node:22-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev && npm cache clean --force
COPY server.js ./
COPY public ./public
ENV NODE_ENV=production
# Hardening: chay bang user node, khong chay bang root
USER node
EXPOSE 3000
CMD ["node", "server.js"]
