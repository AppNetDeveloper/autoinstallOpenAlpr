#!/bin/bash

# Script de instalación y configuración para Ubuntu
# Este script instala y configura herramientas de desarrollo, libjasper, Leptonica, Tesseract, OpenCV y la última versión de OpenALPR.

set -e  # Salir inmediatamente si un comando falla
set -u  # Tratar las variables no establecidas como un error
set -o pipefail  # Hacer que las tuberías fallen si algún comando falla

# Función para imprimir mensajes
echo_info() {
  echo -e "\e[32m[INFO]\e[0m $1"
}

echo_warning() {
  echo -e "\e[33m[WARNING]\e[0m $1"
}

echo_error() {
  echo -e "\e[31m[ERROR]\e[0m $1"
  exit 1
}

# Directorio base para el código fuente
SRC_DIR="$HOME/src"
mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

# ---------------------------------------------------
# Paso 1: Actualizar el sistema
# ---------------------------------------------------
echo_info "Actualizando el sistema..."
sudo apt update && sudo apt upgrade -y

sudo apt install -y cmake

# Verificar la versión de CMake
cmake_version=$(cmake --version | head -n1 | awk '{print $3}')
echo_info "Versión de CMake instalada: $cmake_version"

# ---------------------------------------------------
# Paso 2: Instalar herramientas de desarrollo y dependencias básicas
# ---------------------------------------------------
echo_info "Instalando herramientas de desarrollo y dependencias básicas..."
sudo apt install -y build-essential curl libcurl4-openssl-dev liblog4cplus-dev \
openjdk-17-jdk git gcc g++ qtbase5-dev python3 python3-dev python3-pip \
python3-numpy libgtk2.0-dev libpng-dev libopenexr-dev libwebp-dev \
libjpeg-turbo8-dev libtiff-dev libtbb-dev libv4l-dev libeigen3-dev freeglut3-dev \
mesa-common-dev libgl1-mesa-dev libboost-all-dev \
gstreamer1.0-plugins-base wget libclang-dev zlib1g-dev libjpeg-dev libwebp-dev \
libtiff-dev libpng-dev beanstalkd pkg-config

# Verificar si /usr/local/lib existe
if [ ! -d "/usr/local/lib" ]; then
  echo_info "Creando directorio /usr/local/lib..."
  sudo mkdir -p /usr/local/lib
fi

# Volver al directorio base
cd "$SRC_DIR"

# ---------------------------------------------------
# Paso 3: Compilar e instalar libjasper desde el código fuente
# ---------------------------------------------------
echo_info "Compilando e instalando libjasper desde el código fuente..."

# Clonar y compilar libjasper desde el repositorio oficial
LIBJASPER_DIR="${SRC_DIR}/jasper"
if [ -d "$LIBJASPER_DIR" ]; then
  echo_info "Eliminando el directorio existente de libjasper..."
  rm -rf "$LIBJASPER_DIR"
fi
git clone https://github.com/jasper-software/jasper.git "$LIBJASPER_DIR"

# Crear un directorio de compilación fuera del árbol de fuentes
LIBJASPER_BUILD_DIR="${LIBJASPER_DIR}/build"
mkdir -p "$LIBJASPER_BUILD_DIR"

# Compilar e instalar libjasper
echo_info "Configurando libjasper con CMake en un directorio separado..."
cmake -S "$LIBJASPER_DIR" -B "$LIBJASPER_BUILD_DIR" \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
      -DJAS_ENABLE_DOC=OFF

echo_info "Compilando libjasper..."
cmake --build "$LIBJASPER_BUILD_DIR" -- -j"$(nproc)"

echo_info "Instalando libjasper..."
cmake --install "$LIBJASPER_BUILD_DIR"
sudo ldconfig


# ---------------------------------------------------
# Paso 4: Compilar e instalar Leptonica
# ---------------------------------------------------
echo_info "Clonando y compilando Leptonica..."

LEPTONICA_DIR="${SRC_DIR}/leptonica"
if [ ! -d "$LEPTONICA_DIR" ]; then
  git clone https://github.com/DanBloomberg/leptonica.git --depth 1 "$LEPTONICA_DIR"
else
  echo_info "El directorio leptonica ya existe. Actualizando repositorio..."
  cd "$LEPTONICA_DIR" && git pull && cd "$SRC_DIR"
fi

cd "$LEPTONICA_DIR"

echo_info "Configurando Leptonica..."
./autogen.sh
./configure --prefix=/usr/local --disable-shared \
            --with-zlib --with-jpeg --with-libwebp --with-libtiff --with-libpng --with-jasper

echo_info "Compilando Leptonica..."
make -j"$(nproc)"

echo_info "Instalando Leptonica..."
sudo make install
sudo ldconfig

# Volver al directorio base
cd "$SRC_DIR"

# ---------------------------------------------------
# Paso 5: Descargar, compilar e instalar Tesseract
# ---------------------------------------------------

echo_info "Descargando y compilando Tesseract..."

# Instalar dependencias necesarias
sudo apt install -y g++ autoconf automake libtool make pkg-config \
  libpng-dev libjpeg-dev libtiff-dev zlib1g-dev libicu-dev libpango1.0-dev libcairo2-dev

TESSERACT_DIR="${SRC_DIR}/tesseract"
if [ -d "$TESSERACT_DIR" ]; then
  echo_info "Eliminando el directorio existente de Tesseract..."
  rm -rf "$TESSERACT_DIR"
fi

# Clonar y compilar Tesseract
git clone https://github.com/tesseract-ocr/tesseract.git "$TESSERACT_DIR"
cd "$TESSERACT_DIR"

./autogen.sh
./configure --prefix=/usr/local
make -j"$(nproc)"
sudo make install
sudo ldconfig

# Descargar datos de Tesseract para español
echo_info "Descargando datos de Tesseract para español..."
TESSDATA_DIR="/usr/local/share/tessdata"
sudo mkdir -p "$TESSDATA_DIR"
cd "$TESSDATA_DIR"
if [ ! -f "spa.traineddata" ]; then
  sudo wget https://github.com/tesseract-ocr/tessdata/raw/main/spa.traineddata
else
  echo_info "El archivo spa.traineddata ya existe."
fi

# ---------------------------------------------------
# Paso 6: Compilar e instalar OpenCV
# ---------------------------------------------------
echo_info "Clonando y compilando OpenCV..."

OPENCV_DIR="${SRC_DIR}/opencv"
OPENCV_CONTRIB_DIR="${SRC_DIR}/opencv_contrib"
OPENCV_BUILD_DIR="${OPENCV_DIR}/build"

# Clonar repositorios
git clone --depth=1 https://github.com/opencv/opencv.git "$OPENCV_DIR"
git clone --depth=1 https://github.com/opencv/opencv_contrib.git "$OPENCV_CONTRIB_DIR"

# Configurar y compilar OpenCV
mkdir -p "$OPENCV_BUILD_DIR"
cd "$OPENCV_BUILD_DIR"
cmake -D CMAKE_BUILD_TYPE=Release \
      -D CMAKE_INSTALL_PREFIX=/usr/local \
      -D OPENCV_EXTRA_MODULES_PATH="$OPENCV_CONTRIB_DIR/modules" ..
make -j"$(nproc)"
sudo make install
sudo ldconfig

# ---------------------------------------------------
# Paso 7: Compilar e instalar OpenALPR
# ---------------------------------------------------
echo_info "Clonando y compilando OpenALPR..."

OPENALPR_DIR="${SRC_DIR}/openalpr"
rm -rf "$OPENALPR_DIR"
git clone https://github.com/openalpr/openalpr.git "$OPENALPR_DIR"

# Configurar y compilar OpenALPR
mkdir -p "$OPENALPR_DIR/src/build"
cd "$OPENALPR_DIR/src/build"
cmake -DCMAKE_CXX_FLAGS="-std=c++11" \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
      -DCMAKE_INSTALL_SYSCONFDIR=/etc \
      -DTesseract_INCLUDE_DIRS="/usr/local/include/tesseract" \
      -DTesseract_LIBRARIES="/usr/local/lib/libtesseract.so" ..
make -j"$(nproc)"
sudo make install

# Confirmar versiones
echo_info "Confirmando versiones instaladas..."
echo -n "Tesseract: " && tesseract --version | head -n1
echo -n "OpenCV: " && pkg-config --modversion opencv4 || echo "No encontrado"
echo -n "OpenALPR: " && alpr --version || echo "No encontrado"

echo_info "¡Instalación y configuración completadas con éxito!"
