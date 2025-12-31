#!/bin/bash

# Directorio de origen (donde están tus capturas)
SOURCE_DIR="$HOME/Downloads/capturasAll1fit"
# Directorio de destino (dentro del proyecto)
OUTPUT_DIR="./screenshots_appstore_6.5"

# Crear carpeta de salida
mkdir -p "$OUTPUT_DIR"

echo "🔍 Buscando capturas en: $SOURCE_DIR"

# Verificar si el directorio existe
if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ Error: La carpeta no existe."
    echo "Listando el contenido de Downloads para ayudarte a encontrar el nombre correcto:"
    ls -F "$HOME/Downloads" | grep "/"
    exit 1
fi

# Activar nullglob para que el bucle no itere si no hay coincidencias
shopt -s nullglob nocaseglob

# Buscar imágenes PNG y JPG
IMAGES=("$SOURCE_DIR"/*.png "$SOURCE_DIR"/*.jpg "$SOURCE_DIR"/*.jpeg)
COUNT=${#IMAGES[@]}

if [ "$COUNT" -eq 0 ]; then
    echo "❌ No encontré imágenes PNG o JPG en la carpeta."
    echo "Contenido de $SOURCE_DIR:"
    ls -l "$SOURCE_DIR"
    exit 1
fi

echo "📸 Encontradas $COUNT imágenes. Procesando..."

# Redimensionar todas las imágenes
for img in "${IMAGES[@]}"; do
    FILENAME=$(basename "$img")
    # Cambiar extensión a .jpg para asegurar compatibilidad (sin transparencia)
    FILENAME="${FILENAME%.*}.jpg"
    
    echo "Procesando $FILENAME..."
    # Configurar sips para redimensionar y convertir a jpeg
    sips -s format jpeg -z 2688 1242 "$img" --out "$OUTPUT_DIR/$FILENAME" > /dev/null
done

echo "✅ Listo! Tus capturas corregidas están en la carpeta: $OUTPUT_DIR"
open "$OUTPUT_DIR"
