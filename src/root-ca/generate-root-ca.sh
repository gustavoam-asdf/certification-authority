#!/bin/sh

# Script para generar una CA Raíz
# Autor: Generado automáticamente
# Fecha: $(date)

set -e  # Salir si cualquier comando falla

# Configuración
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_CA_DIR="$(realpath "$SCRIPT_DIR/../../results/root-ca")"
CONFIG_FILE="$SCRIPT_DIR/root-ca.conf"

# Nombres de archivos
PRIVATE_KEY="private-key.pem"
CSR_FILE="certificate.csr"
CERT_FILE="certificate.pem"

echo "=== Generación de CA Raíz ==="
echo "Directorio de trabajo: $ROOT_CA_DIR"

# Crear directorio de resultados si no existe
mkdir -p "$ROOT_CA_DIR"

echo ""
echo "1. Generando par de claves de curva elíptica (P-384)..."
openssl ecparam -genkey -name secp384r1 -out "$ROOT_CA_DIR/$PRIVATE_KEY"

# Verificar que la clave privada se generó correctamente
if [ ! -f "$ROOT_CA_DIR/$PRIVATE_KEY" ]; then
    echo "Error: No se pudo generar la clave privada"
    exit 1
fi

echo "   ✓ Clave privada generada: $PRIVATE_KEY"

echo ""
echo "2. Generando Certificate Signing Request (CSR)..."
openssl req -new \
    -key "$ROOT_CA_DIR/$PRIVATE_KEY" \
    -out "$ROOT_CA_DIR/$CSR_FILE" \
    -config "$CONFIG_FILE"

# Verificar que el CSR se generó correctamente
if [ ! -f "$ROOT_CA_DIR/$CSR_FILE" ]; then
    echo "Error: No se pudo generar el CSR"
    exit 1
fi

echo "   ✓ CSR generado: $CSR_FILE"

echo ""
echo "3. Generando certificado de CA raíz auto-firmado (válido por 10 años)..."
openssl req -x509 \
    -key "$ROOT_CA_DIR/$PRIVATE_KEY" \
    -in "$ROOT_CA_DIR/$CSR_FILE" \
    -out "$ROOT_CA_DIR/$CERT_FILE" \
    -days 3650 \
    -extensions v3_ca \
    -config "$CONFIG_FILE"

# Verificar que el certificado se generó correctamente
if [ ! -f "$ROOT_CA_DIR/$CERT_FILE" ]; then
    echo "Error: No se pudo generar el certificado"
    exit 1
fi

echo "   ✓ Certificado de CA generado: $CERT_FILE"

echo ""
echo "=== Resumen de archivos generados ==="
echo "Clave privada: $ROOT_CA_DIR/$PRIVATE_KEY"
echo "CSR: $ROOT_CA_DIR/$CSR_FILE"
echo "Certificado: $ROOT_CA_DIR/$CERT_FILE"

echo ""
echo "=== Información del certificado generado ==="
openssl x509 -in "$ROOT_CA_DIR/$CERT_FILE" -text -noout | head -20

echo ""
echo "=== CA Raíz generada exitosamente ==="
echo ""
echo "IMPORTANTE: Mantén la clave privada ($PRIVATE_KEY) en un lugar seguro."
echo "Este archivo no debe ser compartido ni expuesto."
echo ""
echo "Para verificar el certificado en cualquier momento:"
echo "openssl x509 -in $ROOT_CA_DIR/$CERT_FILE -text -noout"
