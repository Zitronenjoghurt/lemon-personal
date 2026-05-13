FROM hugomods/hugo:exts AS build
RUN apk add --no-cache git
WORKDIR /src
COPY . .
RUN git submodule update --init --recursive
RUN hugo --minify

# Serve stage
FROM caddy:alpine
COPY --from=build /src/public /usr/share/caddy
