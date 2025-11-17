FROM debian

ARG NGROK_TOKEN
ARG REGION=ap

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt update && apt upgrade -y && apt install -y \
    openssh-server wget unzip vim curl python3

# Install ngrok
RUN wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip -O /ngrok.zip \
    && unzip /ngrok.zip -d /usr/local/bin \
    && chmod +x /usr/local/bin/ngrok \
    && rm /ngrok.zip

# Prepare SSHD directory safely
RUN mkdir -p /run/sshd

# Configure SSH root login
RUN sed -i 's/#PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && echo "root:root" | chpasswd

# Create start script
RUN echo '#!/bin/bash' > /openssh.sh \
    && echo 'ngrok config add-authtoken '"$NGROK_TOKEN" >> /openssh.sh \
    && echo 'ngrok tcp 22 --region '"$REGION"' &' >> /openssh.sh \
    && echo 'sleep 5' >> /openssh.sh \
    && echo 'curl -s http://localhost:4040/api/tunnels | python3 -c "import sys, json; data=json.load(sys.stdin); url=data[\"tunnels\"][0][\"public_url\"]; print(\"SSH INFO:\\nssh root@\"+url[6:].replace(\":\", \" -p \")+\"\\nPASSWORD: root\")"' >> /openssh.sh \
    && echo '/usr/sbin/sshd -D' >> /openssh.sh \
    && chmod +x /openssh.sh

EXPOSE 22 80 443 4040 3306 5432 8080 8888 9000

CMD ["/openssh.sh"]
