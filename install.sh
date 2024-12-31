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
# Paso 1: Actualizar el sistema y agregar PPA para CMake
# ---------------------------------------------------
echo_info "Actualizando el sistema..."
sudo apt update && sudo apt upgrade -y

sudo apt update
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

# Copiar bibliotecas necesarias
echo_info "Copiando bibliotecas necesarias a /usr/local/lib..."
cd /usr/local/lib

# Verificar la existencia de las bibliotecas antes de copiarlas
declare -A libs=(
  ["libjpeg.so.8"]="libjpeg.so.8"
  ["libwebp.so.7"]="libwebp.so.7"
  ["libtiff.so.5"]="libtiff.so.5"
  ["libpng16.so.16"]="libpng16.so.16"
)

for lib in "${!libs[@]}"; do
  src="/usr/lib/x86_64-linux-gnu/${libs[$lib]}"
  if [ -f "$src" ]; then
    sudo cp "$src" .
  else
    echo_warning "La biblioteca $src no existe. Asegúrate de que esté instalada."
  fi
done

# Volver al directorio base
cd "$SRC_DIR"

# Instalar dependencias adicionales
echo_info "Instalando dependencias adicionales..."
sudo apt install -y libopencv-dev libtesseract-dev libleptonica-dev \
liblog4cplus-dev libcurl4-openssl-dev

# ---------------------------------------------------
# Paso 3: Compilar e instalar libjasper desde el código fuente
# ---------------------------------------------------
echo_info "Compilando e instalando libjasper desde el código fuente..."

# Definir la versión de libjasper a instalar
LIBJASPER_VERSION="4.2.4"
LIBJASPER_TAR="jasper-${LIBJASPER_VERSION}.tar.gz"
LIBJASPER_DIR="jasper-${LIBJASPER_VERSION}"
LIBJASPER_BUILD_DIR="${SRC_DIR}/jasper-build-${LIBJASPER_VERSION}"

# Descargar libjasper si no está descargado
if [ ! -f "$LIBJASPER_TAR" ]; then
  echo_info "Descargando libjasper $LIBJASPER_VERSION..."
  wget https://github.com/jasper-software/jasper/releases/download/version-$LIBJASPER_VERSION/$LIBJASPER_TAR -O "$LIBJASPER_TAR"
else
  echo_info "El archivo $LIBJASPER_TAR ya existe. Saltando la descarga."
fi

# Extraer el archivo tar si no está extraído
if [ ! -d "$LIBJASPER_DIR" ]; then
  echo_info "Extrayendo $LIBJASPER_TAR..."
  tar -zxvf "$LIBJASPER_TAR"
else
  echo_info "El directorio $LIBJASPER_DIR ya existe. Saltando la extracción."
fi

# Crear un directorio de compilación fuera del árbol de fuentes
if [ ! -d "$LIBJASPER_BUILD_DIR" ]; then
  echo_info "Creando directorio de compilación separado para libjasper..."
  mkdir -p "$LIBJASPER_BUILD_DIR"
else
  echo_info "El directorio de compilación $LIBJASPER_BUILD_DIR ya existe. Usando ese directorio."
fi

# Compilar e instalar libjasper
echo_info "Configurando libjasper con CMake en un directorio separado..."
cmake -S "$SRC_DIR/$LIBJASPER_DIR" -B "$LIBJASPER_BUILD_DIR" \
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


# Clonar el repositorio de Tesseract
echo_info "Preparando el repositorio de Tesseract..."
TESSERACT_DIR="${HOME}/tesseract"
if [ -d "$TESSERACT_DIR" ]; then
  echo_info "El directorio de Tesseract ya existe. Eliminándolo..."
  rm -rf "$TESSERACT_DIR"
fi
git clone https://github.com/tesseract-ocr/tesseract.git "$TESSERACT_DIR"
cd "$TESSERACT_DIR"

# Configurar, compilar e instalar
./autogen.sh
./configure --prefix=/usr/local
make -j"$(nproc)"
sudo make install
sudo ldconfig

# Descargar los datos de Tesseract para el idioma español
echo_info "Descargando datos de Tesseract para el idioma español..."
TESSDATA_DIR="/usr/local/share/tessdata"
sudo mkdir -p "$TESSDATA_DIR"
cd "$TESSDATA_DIR"

if [ ! -f "spa.traineddata" ]; then
  sudo wget https://github.com/tesseract-ocr/tessdata/raw/main/spa.traineddata
else
  echo_info "El archivo spa.traineddata ya existe. Saltando la descarga."
fi

echo_info "¡Instalación y configuración completadas con éxito!"
# Volver al directorio base
cd "$SRC_DIR"

TESSERACT_VERSION="5.5.0"
TESSERACT_TAR="tesseract-${TESSERACT_VERSION}.tar.gz"
TESSERACT_DIR="tesseract-${TESSERACT_VERSION}"

# Descargar Tesseract si no está descargado
if [ ! -f "$TESSERACT_TAR" ]; then
  echo_info "Descargando Tesseract $TESSERACT_VERSION..."
  wget https://github.com/tesseract-ocr/tesseract/archive/refs/tags/$TESSERACT_VERSION.tar.gz -O "$TESSERACT_TAR"
else
  echo_info "El archivo $TESSERACT_TAR ya existe. Saltando la descarga."
fi

# Extraer el archivo tar si no está extraído
if [ ! -d "$TESSERACT_DIR" ]; then
  echo_info "Extrayendo $TESSERACT_TAR..."
  tar -zxvf "$TESSERACT_TAR"
else
  echo_info "El directorio $TESSERACT_DIR ya existe. Saltando la extracción."
fi

cd "$SRC_DIR/$TESSERACT_DIR"

echo_info "Configurando Tesseract..."
./autogen.sh
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/lib/pkgconfig
export LIBLEPT_HEADERSDIR=/usr/local/include

./configure --with-extra-includes=/usr/local/include \
            --with-extra-libraries=/usr/local/lib \
            LDFLAGS="-L/usr/local/lib" \
            CFLAGS="-I/usr/local/include"

echo_info "Compilando Tesseract..."
make -j"$(nproc)"

echo_info "Instalando Tesseract..."
sudo make install
sudo ldconfig

# Descargar los datos de Tesseract para el idioma español
echo_info "Descargando datos de Tesseract para el idioma español..."
TESSDATA_DIR="/usr/local/share/tessdata"
sudo mkdir -p "$TESSDATA_DIR"
cd "$TESSDATA_DIR"

if [ ! -f "spa.traineddata" ]; then
  sudo wget https://github.com/tesseract-ocr/tessdata/raw/main/spa.traineddata
else
  echo_info "El archivo spa.traineddata ya existe. Saltando la descarga."
fi

# ---------------------------------------------------
# Paso 6: Clonar, compilar e instalar OpenCV
# ---------------------------------------------------
echo_info "Clonando y compilando OpenCV..."

OPENCV_DIR="${SRC_DIR}/opencv"
OPENCV_CONTRIB_DIR="${SRC_DIR}/opencv_contrib"
OPENCV_BUILD_DIR="${OPENCV_DIR}/build"

# Clonar repositorio de OpenCV si no está clonado
if [ ! -d "$OPENCV_DIR" ]; then
  git clone https://github.com/opencv/opencv.git "$OPENCV_DIR"
else
  echo_info "El directorio opencv ya existe. Actualizando repositorio..."
  cd "$OPENCV_DIR" && git pull && cd "$SRC_DIR"
fi

# Clonar repositorio de OpenCV Contrib si no está clonado
if [ ! -d "$OPENCV_CONTRIB_DIR" ]; then
  git clone https://github.com/opencv/opencv_contrib.git "$OPENCV_CONTRIB_DIR"
else
  echo_info "El directorio opencv_contrib ya existe. Actualizando repositorio..."
  cd "$OPENCV_CONTRIB_DIR" && git pull && cd "$SRC_DIR"
fi

# Crear directorio de compilación si no existe
if [ ! -d "$OPENCV_BUILD_DIR" ]; then
  mkdir -p "$OPENCV_BUILD_DIR"
else
  echo_info "El directorio de compilación OpenCV ya existe. Usando ese directorio."
fi

cd "$OPENCV_BUILD_DIR"

# Configurar la compilación con CMake
echo_info "Configurando la compilación de OpenCV con CMake..."
cmake -D CMAKE_BUILD_TYPE=Release \
      -D CMAKE_INSTALL_PREFIX=/usr/local \
      -D INSTALL_C_EXAMPLES=ON \
      -D INSTALL_PYTHON_EXAMPLES=ON \
      -D OPENCV_GENERATE_PKGCONFIG=ON \
      -D OPENCV_EXTRA_MODULES_PATH="$OPENCV_CONTRIB_DIR/modules" \
      -D BUILD_EXAMPLES=ON ..

# Compilar e instalar OpenCV
echo_info "Compilando OpenCV (esto puede tardar varios minutos)..."
make -j"$(nproc)"

echo_info "Instalando OpenCV..."
sudo make install

# Crear enlace simbólico para pkg-config
echo_info "Creando enlace simbólico para pkg-config de OpenCV..."
sudo ln -sf /usr/local/lib/pkgconfig/opencv4.pc /usr/lib/pkgconfig/
sudo ldconfig

# Verificar la versión instalada de OpenCV
echo_info "Verificando la versión instalada de OpenCV..."
opencv_version=$(pkg-config --modversion opencv4 || echo "No encontrado")
echo "Versión de OpenCV: $opencv_version"

# ---------------------------------------------------
# Paso 7: Clonar, compilar e instalar OpenALPR
# ---------------------------------------------------
# Configuración y compilación de OpenALPR

# Clonar siempre el repositorio desde cero
echo_info "Clonando el repositorio de OpenALPR desde cero..."
OPENALPR_DIR="/root/openalpr"

if [ -d "$OPENALPR_DIR" ]; then
  echo_info "Eliminando el directorio existente de OpenALPR..."
  rm -rf "$OPENALPR_DIR"
fi
git clone https://github.com/openalpr/openalpr.git "$OPENALPR_DIR"

# Crear directorio de compilación para OpenALPR
echo_info "Creando directorio de compilación para OpenALPR..."
mkdir -p "$OPENALPR_DIR/src/build"


# Configurar la compilación con CMake
cd "$OPENALPR_DIR/src/build"
echo_info "Configurando la compilación de OpenALPR con CMake..."
cmake  -DCMAKE_CXX_FLAGS="-std=c++11" \
      -DCMAKE_INSTALL_PREFIX:PATH=/usr/local \
      -DCMAKE_INSTALL_SYSCONFDIR:PATH=/etc \
      -DTesseract_INCLUDE_DIRS="/usr/local/include/tesseract" \
      -DTesseract_LIBRARIES="/usr/local/lib/libtesseract.so" ..

# Compilar OpenALPR
echo_info "Compilando OpenALPR (esto puede tardar varios minutos)..."
make -j"$(nproc)"

# Instalar OpenALPR
echo_info "Instalando OpenALPR..."
sudo make install

# Configurar las rutas de las bibliotecas
echo_info "Configurando las rutas de las bibliotecas..."
if [ ! -f /etc/ld.so.conf.d/usrlocal.conf ]; then
  echo "/usr/local/lib" | sudo tee /etc/ld.so.conf.d/usrlocal.conf
  echo "/usr/local/lib64" | sudo tee -a /etc/ld.so.conf.d/usrlocal.conf
fi

sudo ldconfig -v

# Verificar la instalación de OpenALPR
echo_info "Verificando la instalación de OpenALPR..."
if command -v alpr &> /dev/null; then
  alpr --version
else
  echo_error "OpenALPR no se instaló correctamente o no está en el PATH."
fi

echo_info "¡Instalación y configuración completadas con éxito!"
