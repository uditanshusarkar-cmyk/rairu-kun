FROM debian:latest

ENV DEBIAN_FRONTEND=noninteractive

# ----- SET PLAYIT SECRET KEY AUTOMATICALLY -----
ENV SECRET_KEY="9c3ed299fa4599ef6b5699f5e69b5061de902083d42547cfab857cc009976378"

# ----- Install Dependencies -----
RUN apt update && apt upgrade -y && apt install -y \
    openssh-server curl wget gpg python3 python3-pip ca-certificates

# Install playit agent from PPA
RUN curl -SsL https://playit-cloud.github.io/ppa/key.gpg \
    | gpg --dearmor \
    | tee /etc/apt/trusted.gpg.d/playit.gpg >/dev/null

RUN echo "deb [signed-by=/etc/apt/trusted.gpg.d/playit.gpg] https://playit-cloud.github.io/ppa/data ./" \
    | tee /etc/apt/sources.list.d/playit-cloud.list

RUN apt update && apt install -y playit

# ----- SSH Setup -----
RUN mkdir -p /run/sshd

RUN sed -i 's/#PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo "root:root" | chpasswd

# -------- Python Parser for Playit Output --------
RUN echo 'import sys, json, re' > /parser.py \
    && echo 'data = sys.stdin.read()' >> /parser.py \
    && echo 'match = re.findall(r"tcp.+?playit.+?", data)' >> /parser.py \
    && echo 'if match:' >> /parser.py \
    && echo '    line = match[-1]' >> /parser.py \
    && echo '    host = line.split("//")[1].split(":")[0]' >> /parser.py \
    && echo '    port = line.split(":")[-1]' >> /parser.py \
    && echo '    print("\\n==== PLAYIT SSH INFO ====")' >> /parser.py \
    && echo '    print(f"SSH COMMAND: ssh root@{host} -p {port}")' >> /parser.py \
    && echo '    print("PASSWORD: root")' >> /parser.py \
    && echo '    print("==========================\\n")' >> /parser.py \
    && echo 'else:' >> /parser.py \
    && echo '    print("Waiting for tunnel...")' >> /parser.py

# -------- Start Script (AUTO START, NO MANUAL docker run REQUIRED) --------
RUN echo '#!/bin/bash' > /start.sh \
    && echo 'echo "[✔] Starting Playit Agent..."' >> /start.sh \
    && echo 'playit --secret-key "$SECRET_KEY" 2>&1 | tee /tmp/playit.log &' >> /start.sh \
    && echo 'sleep 10' >> /start.sh \
    && echo 'python3 /parser.py < /tmp/playit.log' >> /start.sh \
    && echo 'echo "[✔] Starting SSH Server..."' >> /start.sh \
    && echo '/usr/sbin/sshd -D' >> /start.sh \
    && chmod +x /start.sh

EXPOSE 22 80 443 8080 9000

CMD ["/start.sh"]
