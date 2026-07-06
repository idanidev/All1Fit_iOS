#!/bin/bash

# Script para ejecutar All1Fit en tu iPhone
# Uso: ./run_on_device.sh

DEVICE="iPhone de Daniel"
SCHEME="All1Fit"
BUNDLE_ID="com.idanidev.All1Fit"

echo "🔨 Compilando All1Fit..."
xcodebuild -scheme "$SCHEME" -configuration Debug -destination "name=$DEVICE" build

if [ $? -eq 0 ]; then
    echo "✅ Compilación exitosa"

    # Ruta real del .app según la configuración actual (no hardcodear DerivedData)
    APP_PATH=$(xcodebuild -scheme "$SCHEME" -configuration Debug -destination "name=$DEVICE" -showBuildSettings 2>/dev/null \
        | awk -F' = ' '/ CODESIGNING_FOLDER_PATH/{print $2; exit}')

    if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
        echo "❌ No se encontró el .app compilado"
        exit 1
    fi

    echo "📱 Instalando en $DEVICE..."
    xcrun devicectl device install app --device "$DEVICE" "$APP_PATH"

    if [ $? -eq 0 ]; then
        echo "✅ App instalada"

        echo "🚀 Ejecutando app..."
        xcrun devicectl device process launch --terminate-existing --device "$DEVICE" "$BUNDLE_ID" \
            || echo "⚠️  No se pudo lanzar (¿iPhone bloqueado?). Ábrela manualmente."
    else
        echo "❌ Error al instalar la app"
    fi
else
    echo "❌ Error en la compilación"
fi
