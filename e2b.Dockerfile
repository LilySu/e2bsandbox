FROM ubuntu:22.04

ARG PYTHON_VERSION=3.11
ARG NB_USER=manimuser
ARG NB_UID=1000

RUN apt-get update -qq \
    && apt-get install --no-install-recommends -y \
        python${PYTHON_VERSION} \
        python${PYTHON_VERSION}-venv \
        python${PYTHON_VERSION}-dev \
        python3-pip \
        build-essential \
        gcc \
        cmake \
        libcairo2-dev \
        libffi-dev \
        libpango1.0-dev \
        freeglut3-dev \
        pkg-config \
        make \
        wget \
        ghostscript \
        perl \
        sudo \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 1 \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3 1 \
    && python3 -m pip install --upgrade pip

# Setup a minimal texlive installation
RUN set -e \
    && MIRROR_URL="https://mirror.ctan.org" \
    && FALLBACK_MIRROR="http://ftp.math.utah.edu/pub/tex/historic/systems/texlive/2023/tlnet-final" \
    && wget -O /tmp/install-tl-unx.tar.gz ${MIRROR_URL}/systems/texlive/tlnet/install-tl-unx.tar.gz \
        || wget -O /tmp/install-tl-unx.tar.gz ${FALLBACK_MIRROR}/install-tl-unx.tar.gz \
    && mkdir /tmp/install-tl \
    && tar -xzf /tmp/install-tl-unx.tar.gz -C /tmp/install-tl --strip-components=1 \
    && echo "selected_scheme scheme-basic" > /tmp/texlive.profile \
    && echo "TEXDIR /usr/local/texlive" >> /tmp/texlive.profile \
    && echo "TEXMFCONFIG ~/.texlive/texmf-config" >> /tmp/texlive.profile \
    && echo "TEXMFHOME ~/texmf" >> /tmp/texlive.profile \
    && echo "TEXMFLOCAL /usr/local/texlive/texmf-local" >> /tmp/texlive.profile \
    && echo "TEXMFSYSCONFIG /usr/local/texlive/texmf-config" >> /tmp/texlive.profile \
    && echo "TEXMFSYSVAR /usr/local/texlive/texmf-var" >> /tmp/texlive.profile \
    && echo "option_doc 0" >> /tmp/texlive.profile \
    && echo "option_src 0" >> /tmp/texlive.profile \
    && /tmp/install-tl/install-tl --profile=/tmp/texlive.profile \
    && echo 'export PATH=/usr/local/texlive/bin/x86_64-linux:$PATH' > /etc/profile.d/texlive.sh \
    && . /etc/profile.d/texlive.sh \
    && tlmgr path add \
    && tlmgr update --self \
    && tlmgr install \
        amsmath babel-english cbfonts-fd cm-super count1to ctex doublestroke dvisvgm everysel \
        fontspec frcursive fundus-calligra gnu-freefont jknapltx latex-bin \
        mathastext microtype multitoc physics prelim2e preview ragged2e relsize rsfs \
        setspace standalone tipa wasy wasysym xcolor xetex xkeyval \
    && rm -rf /tmp/install-tl /tmp/install-tl-unx.tar.gz

# Install Manim and its dependencies
WORKDIR /opt/manim
RUN pip install manim jupyterlab

# Add a new user and set up the working directory
RUN adduser --disabled-password \
    --gecos "Default user" \
    --uid ${NB_UID} \
    ${NB_USER} \
    && echo "${NB_USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && mkdir -p /manim \
    && chown -R ${NB_USER}:${NB_USER} /manim \
    && chmod 777 /manim

WORKDIR /manim

# Create an entrypoint script
RUN echo '#!/bin/bash' > /entrypoint.sh \
    && echo 'export USER=${NB_USER}' >> /entrypoint.sh \
    && echo 'export NB_UID=${NB_UID}' >> /entrypoint.sh \
    && echo 'export HOME=/manim' >> /entrypoint.sh \
    && echo 'source /etc/profile.d/texlive.sh' >> /entrypoint.sh \
    && echo 'exec sudo -E -H -u ${NB_USER} bash -c "cd /manim && bash"' >> /entrypoint.sh \
    && chmod +x /entrypoint.sh

# Set the entrypoint
RUN echo '#!/bin/bash' > /usr/local/bin/entrypoint.sh \
    && echo 'source /entrypoint.sh' >> /usr/local/bin/entrypoint.sh \
    && chmod +x /usr/local/bin/entrypoint.sh