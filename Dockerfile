FROM debian

ENV DEBIAN_FRONTEND=noninteractive

# Install base packages
RUN apt update && apt upgrade -y && apt install -y \
    openssh-server wget curl unzip python3 vim

# Install Playit.gg client
RUN wget -O /playit.deb https://playit-cloud.github.io/ppa/pool/main/p/playit/playit_1.1.0_amd64.deb \
    && apt install -y /playit.deb \
    && rm /playit.deb

# Prepare SSH
RUN mkdir -p /run/sshd \
    && sed -i 's/#PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && echo "root:root" | chpasswd

# Start script
RUN echo '#!/bin/bash' > /start.sh \
    && echo 'echo "[✔] Starting Playit Tunnel..."' >> /start.sh \
    && echo 'playit & ' >> /start.sh \
    && echo 'sleep 8' >> /start.sh \
    && echo 'echo "[✔] Starting SSH Server..."' >> /start.sh \
    && echo '/usr/sbin/sshd -D' >> /start.sh \
    && chmod +x /start.sh

EXPOSE 22 80 443 8080 9000

CMD ["/start.sh"]
