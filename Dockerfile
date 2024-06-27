FROM ubuntu:20.04

# Set non-interactive mode for tzdata
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y tzdata && \
    ln -fs /usr/share/zoneinfo/Europe/London /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata

# Add the Ubuntu Toolchain PPA for newer GCC versions
RUN apt-get install -y software-properties-common && \
    add-apt-repository ppa:ubuntu-toolchain-r/test -y && \
    apt-get update

# Install required packages including GCC 13 and Python 3.9
RUN apt-get install -y \
    build-essential \
    gcc-13 \
    g++-13 \
    wget \
    cmake \
    python3.9 \
    python3.9-venv \
    python3.9-dev \
    python3-pip \
    meson \
    git \
    libc6 \
    libc6-dev \
    bison \
    gawk \
    patchelf \
    libgmp-dev \
    libmpfr-dev \
    libmpc-dev \
    texinfo \
    pkg-config \
    libglib2.0-dev \
    libfdt-dev \
    libpixman-1-dev \
    libepoxy-dev \
    libpng-dev \
    libjpeg-dev \
    libsnappy-dev \
    liblzo2-dev \
    libsdl2-dev \
    libnuma-dev \
    vde2 \
    libgtk-3-dev \
    libvte-2.91-dev \
    libsndio-dev \
    libglib2.0-0 \
    libglib2.0-bin \
    libglib2.0-data \
    gir1.2-glib-2.0 \
    libmount-dev \
    libpcre3-dev \
    libselinux1-dev \
    zlib1g-dev

# Install Capstone from source
RUN git clone https://github.com/aquynh/capstone.git /tmp/capstone && \
    cd /tmp/capstone && \
    git checkout 4.0 && \
    ./make.sh && \
    ./make.sh install && \
    ldconfig

# Add GPG keys and install libsndio from Debian Sid
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 0E98404D386FA1D9 6ED0E7B82643E131 && \
    echo 'deb http://ftp.us.debian.org/debian sid main' >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y libsndio7.0 && \
    sed -i '/deb http:\/\/ftp.us.debian.org\/debian sid main/d' /etc/apt/sources.list && \
    apt-get update

# Install Conan using Python 3.9
RUN python3.9 -m pip install conan

# Set GCC 13 as the default
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 60 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 60

# Set Python 3.9 as the default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 60 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.9 60

# Set environment variables to disable warnings as errors
ENV CFLAGS="-Wno-error"
ENV CXXFLAGS="-Wno-error"

# Add linker flag for libdl
ENV LDFLAGS="-ldl"

# Set library path
ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/usr/local/lib:$LD_LIBRARY_PATH

# Create qflex directory
RUN mkdir /qflex
WORKDIR /qflex

# Copy qflex repository files
COPY . /qflex

# Validate library installation and paths
RUN ldconfig && ldconfig -p | grep capstone

# Debug step: locate glib-2.0.pc
RUN find / -name glib-2.0.pc -exec ls -l {} \; || true

# Manually search for glib-2.0.pc and set PKG_CONFIG_PATH
RUN find / -name glib-2.0.pc -exec dirname {} \; > /tmp/glib_pc_path.txt

RUN cat /tmp/glib_pc_path.txt

RUN GLIB_PKGCONFIG_PATH=$(cat /tmp/glib_pc_path.txt | head -n 1) && \
    echo "GLIB_PKGCONFIG_PATH=${GLIB_PKGCONFIG_PATH}" && \
    export PKG_CONFIG_PATH=${GLIB_PKGCONFIG_PATH}:${PKG_CONFIG_PATH} && \
    echo $PKG_CONFIG_PATH

RUN pkg-config --cflags --libs glib-2.0

# Detect Conan profile
RUN conan profile detect --force

# Clear CMake cache before building
RUN rm -rf /qflex/out/keenkraken/Release/CMakeCache.txt
RUN rm -rf /qflex/out/knottykraken/Release/CMakeCache.txt

# Build qflex
RUN ./build cq && ./build keenkraken && ./build knottykraken

