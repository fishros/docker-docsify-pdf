FROM node:18.11.0

ENV https_proxy http://192.168.2.105:2340
ENV http_proxy http://192.168.2.105:2340
ENV all_proxy socks5://192.168.2.105:2341

RUN apt update && apt install  curl bash bash-completion chromium    ca-certificates openjdk-11-jdk -y

# Pnpm is used to install packages
RUN npm install --location=global pnpm

RUN USER=node && \
    GROUP=node && \
    curl -SsL https://github.com/boxboat/fixuid/releases/download/v0.5.1/fixuid-0.5.1-linux-amd64.tar.gz | tar -C /usr/local/bin -xzf - && \
    chown root:root /usr/local/bin/fixuid && \
    chmod 4755 /usr/local/bin/fixuid && \
    mkdir -p /etc/fixuid && \
    printf "user: $USER\ngroup: $GROUP\npaths:\n  - /home/node/pdf\n  - /home/node/.static\n  - /home/node/resources" > /etc/fixuid/config.yml

WORKDIR /home/node
RUN mkdir -p /home/node/.static/ && chown -R node:node /home/node/.static/

RUN apt-get update && \
    apt-get install -y locales && \
    rm -rf /var/lib/apt/lists/* && \
    localedef -i zh_CN -c -f UTF-8 -A /usr/share/locale/locale.alias zh_CN.UTF-8

ENV LANG zh_CN.utf8


USER node:node

ENV NODE_ENV production
ENV LANG zh_CN.utf8


COPY --chown=node:node package.json pnpm-lock.yaml ./

RUN chown -R node:node /home/node

RUN pnpm install --frozen-lockfile --prod
RUN sudo apt-get update && apt-get install -y fonts-wqy-zenhei

# Tell Puppeteer to skip installing Chrome. We'll be using the installed package.
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
COPY --chown=node:node index.html index.js index.html ./
COPY --chown=node:node resources/js/ ./resources/js/
COPY --chown=node:node resources/css/ ./resources/css/
COPY --chown=node:node src/ ./src/
ENV http_proxy=""
ENV https_proxy=""
ENV all_proxy=""

EXPOSE 3000

# make sure that the user is node:node
ENTRYPOINT ["fixuid"]
CMD [ "node", "index.js" ]

# 
# xhost + && docker run --rm -it   --cap-add=SYS_ADMIN  -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=unix$DISPLAY  --user $(id -u):$(id -g)  -v /usr/share/fonts/:/usr/share/fonts/ -v $(pwd)/docs:/home/node/docs:ro   -v $(pwd)/pdf:/home/node/pdf:rw   -v $(pwd)/resources/covers/cover.pdf:/home/node/resources/cover.pdf:ro   -e "PDF_OUTPUT_NAME=DOCUMENTATION.pdf"  --net=host  docsify:latest /bin/bash