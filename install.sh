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

# Instalación de paquetes esenciales
for package in build-essential curl libcurl4-openssl-dev liblog4cplus-dev \
openjdk-17-jdk git gcc g++ qtbase5-dev python3 python3-dev python3-pip \
python3-numpy libgtk2.0-dev libpng-dev libopenexr-dev libwebp-dev \
libjpeg-turbo8-dev libtiff-dev libtbb-dev libv4l-dev libeigen3-dev freeglut3-dev \
mesa-common-dev libgl1-mesa-dev libboost-all-dev \
gstreamer1.0-plugins-base wget libclang-dev zlib1g-dev libjpeg-dev libwebp-dev \
libtiff-dev libpng-dev beanstalkd pkg-config cmake; do
  echo_info "Instalando $package..."
  sudo apt install -y "$package" || echo_warning "$package no se pudo instalar. Continuando..."
done

# ---------------------------------------------------
# Paso 2: Compilar e instalar libjasper
# ---------------------------------------------------
echo_info "Compilando e instalando libjasper desde el repositorio oficial..."

LIBJASPER_DIR="$SRC_DIR/jasper"
if [ -d "$LIBJASPER_DIR" ]; then
  echo_info "Eliminando directorio existente de libjasper..."
  rm -rf "$LIBJASPER_DIR"
fi

git clone https://github.com/jasper-software/jasper.git "$LIBJASPER_DIR"
LIBJASPER_BUILD_DIR="$SRC_DIR/jasper_build"
mkdir -p "$LIBJASPER_BUILD_DIR"

cmake -S "$LIBJASPER_DIR" -B "$LIBJASPER_BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DJAS_ENABLE_DOC=OFF

cmake --build "$LIBJASPER_BUILD_DIR" -- -j"$(nproc)"
cmake --install "$LIBJASPER_BUILD_DIR"
sudo ldconfig

# ---------------------------------------------------
# Paso 3: Compilar e instalar Leptonica
# ---------------------------------------------------
echo_info "Clonando y compilando Leptonica..."

LEPTONICA_DIR="$SRC_DIR/leptonica"
if [ -d "$LEPTONICA_DIR" ]; then
  echo_info "Eliminando directorio existente de Leptonica..."
  rm -rf "$LEPTONICA_DIR"
fi

git clone https://github.com/DanBloomberg/leptonica.git "$LEPTONICA_DIR"
cd "$LEPTONICA_DIR"

./autogen.sh
./configure --prefix=/usr/local --disable-shared \
           --with-zlib --with-jpeg --with-libwebp --with-libtiff --with-libpng --with-jasper
make -j"$(nproc)"
sudo make install
sudo ldconfig

# ---------------------------------------------------
# Paso 4: Descargar, compilar e instalar Tesseract
# ---------------------------------------------------
echo_info "Descargando y compilando Tesseract..."

TESSERACT_DIR="$SRC_DIR/tesseract"
if [ -d "$TESSERACT_DIR" ]; then
  echo_info "Eliminando directorio existente de Tesseract..."
  rm -rf "$TESSERACT_DIR"
fi

git clone https://github.com/tesseract-ocr/tesseract.git "$TESSERACT_DIR"
cd "$TESSERACT_DIR"

./autogen.sh
./configure --prefix=/usr/local
make -j"$(nproc)"
sudo make install
sudo ldconfig

TESSDATA_DIR="/usr/local/share/tessdata"
sudo mkdir -p "$TESSDATA_DIR"
cd "$TESSDATA_DIR"
if [ ! -f "spa.traineddata" ]; then
  sudo wget https://github.com/tesseract-ocr/tessdata/raw/main/spa.traineddata
fi

# ---------------------------------------------------
# Paso 5: Compilar e instalar OpenCV
# ---------------------------------------------------
echo_info "Clonando y compilando OpenCV..."

OPENCV_DIR="$SRC_DIR/opencv"
OPENCV_CONTRIB_DIR="$SRC_DIR/opencv_contrib"
OPENCV_BUILD_DIR="$OPENCV_DIR/build"

if [ -d "$OPENCV_DIR" ]; then
  rm -rf "$OPENCV_DIR"
fi
if [ -d "$OPENCV_CONTRIB_DIR" ]; then
  rm -rf "$OPENCV_CONTRIB_DIR"
fi

git clone https://github.com/opencv/opencv.git "$OPENCV_DIR"
git clone https://github.com/opencv/opencv_contrib.git "$OPENCV_CONTRIB_DIR"
mkdir -p "$OPENCV_BUILD_DIR"

cmake -S "$OPENCV_DIR" -B "$OPENCV_BUILD_DIR" \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_INSTALL_PREFIX=/usr/local \
    -D OPENCV_EXTRA_MODULES_PATH="$OPENCV_CONTRIB_DIR/modules"

cmake --build "$OPENCV_BUILD_DIR" -- -j"$(nproc)"
sudo cmake --install "$OPENCV_BUILD_DIR"
sudo ldconfig

# ---------------------------------------------------
# Paso 6: Compilar e instalar OpenALPR
# ---------------------------------------------------
echo_info "Clonando y compilando OpenALPR..."

OPENALPR_DIR="$SRC_DIR/openalpr"
if [ -d "$OPENALPR_DIR" ]; then
  rm -rf "$OPENALPR_DIR"
fi

git clone https://github.com/openalpr/openalpr.git "$OPENALPR_DIR"
mkdir -p "$OPENALPR_DIR/src/build"

echo_info "Intentando compilar OpenALPR con rutas iniciales..."
cmake -S "$OPENALPR_DIR/src" -B "$OPENALPR_DIR/src/build" \
    -DCMAKE_CXX_FLAGS="-std=c++11" \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DCMAKE_INSTALL_SYSCONFDIR=/etc \
    -DTesseract_INCLUDE_DIRS="/usr/local/include/tesseract" \
    -DTesseract_LIBRARIES="/usr/local/lib/libtesseract.so"

if [ $? -ne 0 ]; then
  echo_warning "La compilación con rutas iniciales falló. Intentando con rutas específicas..."
  rm -rf "$OPENALPR_DIR/src/build"  # Limpiar el intento fallido
  mkdir -p "$OPENALPR_DIR/src/build" # Recrear el directorio build

  cmake -S "$OPENALPR_DIR/src" -B "$OPENALPR_DIR/src/build" \
      -DCMAKE_CXX_FLAGS="-std=c++11" \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
      -DCMAKE_INSTALL_SYSCONFDIR=/etc \
      -DTesseract_INCLUDE_DIRS="/usr/local/include/tesseract:/usr/local/include" \
      -DTesseract_LIBRARIES="/usr/local/lib/libtesseract.so;/usr/local/lib/liblept.so"

  if [ $? -ne 0 ]; then
    echo_error "La compilación falló incluso con rutas específicas. Revisa los logs de CMake."
  fi
fi

cmake --build "$OPENALPR_DIR/src/build" -- -j"$(nproc)"
sudo cmake --install "$OPENALPR_DIR/src/build"
sudo ldconfig

# Confirmar versiones
echo_info "Confirmando versiones instaladas..."
echo -n "Tesseract: " && tesseract --version | head -n1
echo -n "OpenCV: " && pkg-config --modversion opencv4 || echo "No encontrado"
echo -n "OpenALPR: " && alpr --version || echo "No encontrado"

echo_info "¡Instalación y configuración completadas con éxito!"

echo_info "¡Instalación y configuración completadas con éxito!"

