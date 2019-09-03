FROM ubuntu:16.04

ENV DEBIAN_FRONTEND noninteractive
ENV DISPLAY :99.0

# Install Software
RUN apt-get update && \
    apt-get install -qqy --no-install-recommends \
    xvfb \
    x11-utils \
    wget \
    python3 \
    python3-pip

# Install Chrome
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
  && echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list \
  && apt-get update -qqy \
  && apt-get -qqy install \
    google-chrome-stable \
  && rm /etc/apt/sources.list.d/google-chrome.list
COPY wrap_chrome_binary /opt/bin/wrap_chrome_binary
RUN /opt/bin/wrap_chrome_binary

COPY ./chromedriver /usr/local/bin/chromedriver
COPY ./run.sh /usr/local/bin/run.sh
COPY ./testVideo_chrome.py /usr/local/bin/testVideo.py

RUN pip3 install selenium
RUN chmod +x /usr/local/bin/run.sh

ENTRYPOINT [ "/usr/local/bin/run.sh" ]

