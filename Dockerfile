FROM debian:latest

ENV DEBIAN_FRONTEND=noninteractive

# ====== ENV ======
ENV SECRET_KEY="9c3ed299fa4599ef6b5699f5e69b5061de902083d42547cfab857cc009976378"

# ====== Install Dependencies ======
RUN apt update && apt upgrade -y && apt install -y \
    openssh-server curl wget gpg python3 python3-pip ca-certificates unzip

# ====== Install Playit Agent ======
RUN curl -SsL https://playit-cloud.github.io/ppa/key.gpg \
    | gpg --dearmor \
    | tee /etc/apt/trusted.gpg.d/playit.gpg >/dev/null

RUN echo "deb [signed-by=/etc/apt/trusted.gpg.d/playit.gpg] https://playit-cloud.github.io/ppa/data ./" \
    | tee /etc/apt/sources.list.d/playit-cloud.list

RUN apt update && apt install -y playit

# ====== SSH Setup ======
RUN mkdir -p /run/sshd
RUN sed -i 's/#PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo "root:root" | chpasswd

# ====== Add sshx.io Runner ======
RUN echo '#!/bin/bash' > /sshx.sh \
 && echo 'curl -sSf https://sshx.io/get | sh -s -- --auto 2>&1 | tee /tmp/sshx.log &' >> /sshx.sh \
 && chmod +x /sshx.sh

# ====== Playit SSH Parser ======
RUN echo 'import sys, json, re' > /parser.py \
    && echo 'data = sys.stdin.read()' >> /parser.py \
    && echo 'match = re.findall(r"tcp.+?playit.+?", data)' >> /parser.py \
    && echo 'if match:' >> /parser.py \
    && echo '    line = match[-1]' >> /parser.py \
    && echo '    host = line.split("//")[1].split(":")[0]' >> /parser.py \
    && echo '    port = line.split(":")[-1]' >> /parser.py \
    && echo '    print("\\n===== PLAYIT SSH =====")' >> /parser.py \
    && echo '    print(f"ssh root@{host} -p {port}")' >> /parser.py \
    && echo '    print("password: root")' >> /parser.py \
    && echo '    print("========================\\n")' >> /parser.py \
    && echo 'else:' >> /parser.py \
    && echo '    print("Tunnel not ready yet")' >> /parser.py

# ====== Start Script ======
RUN echo '#!/bin/bash' > /start.sh \
    && echo 'echo "[✔] Starting sshx.io…"' >> /start.sh \
    && echo '/sshx.sh &' >> /start.sh \
    && echo '' >> /start.sh \
    && echo 'echo "[✔] Starting Playit.gg…"' >> /start.sh \
    && echo 'playit --secret-key "$SECRET_KEY" 2>&1 | tee /tmp/playit.log &' >> /start.sh \
    && echo 'sleep 8' >> /start.sh \
    && echo 'python3 /parser.py < /tmp/playit.log' >> /start.sh \
    && echo '' >> /start.sh \
    && echo 'echo "[✔] Starting SSH server…"' >> /start.sh \
    && echo '/usr/sbin/sshd &' >> /start.sh \
    && echo '' >> /start.sh \
    && echo 'echo "[✔] Starting Railway Health Server (port 8080)…"' >> /start.sh \
    && echo 'python3 -m http.server 8080 --directory / &' >> /start.sh \
    && echo 'wait' >> /start.sh \
    && chmod +x /start.sh

# ====== Expose Ports (Railway ignores but still good) ======
EXPOSE 22 8080

CMD ["/start.sh"]
