# react-scripts 1.x uses spdy/http-deceiver, which requires Node's legacy HTTP parser.
FROM node:16.20.2-alpine as builder
WORKDIR /app
COPY ./package.json ./
RUN npm install
COPY . .
CMD ["npm", "run", "build"]

FROM nginx
EXPOSE 3000
COPY ./nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/build /usr/share/nginx/html