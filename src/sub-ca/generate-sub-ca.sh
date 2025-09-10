#!/bin/sh

# Script para generar una Sub CA (CA Intermedia)
# Autor: Generado automáticamente
# Fecha: $(date)

set -e  # Salir si cualquier comando falla

# Configuración
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUB_CA_DIR="$(realpath "$SCRIPT_DIR/../../results/sub-ca")"
ROOT_CA_DIR="$(realpath "$SCRIPT_DIR/../../results/root-ca")"
CONFIG_FILE="$SCRIPT_DIR/sub-ca.conf"

# Nombres de archivos - Sub CA
PRIVATE_KEY="private-key.pem"
CSR_FILE="certificate.csr"
CERT_FILE="certificate.pem"

# Nombres de archivos - Root CA (para firmar)
ROOT_CA_CERT="certificate.pem"
ROOT_CA_KEY="private-key.pem"

echo "=== Generación de Sub CA (CA Intermedia) ==="
echo "Directorio de trabajo: $SUB_CA_DIR"

# Verificar que existe la CA raíz
if [ ! -f "$ROOT_CA_DIR/$ROOT_CA_CERT" ] || [ ! -f "$ROOT_CA_DIR/$ROOT_CA_KEY" ]; then
    echo "Error: No se encontraron los archivos de la CA raíz en $ROOT_CA_DIR"
    echo "Asegúrate de haber ejecutado primero el script de generación de CA raíz"
    exit 1
fi

echo "   ✓ CA raíz encontrada en: $ROOT_CA_DIR"

# Crear directorio de resultados si no existe
mkdir -p "$SUB_CA_DIR"

echo ""
echo "1. Generando par de claves de curva elíptica (P-384) para Sub CA..."
openssl ecparam -genkey -name secp384r1 -out "$SUB_CA_DIR/$PRIVATE_KEY"

# Verificar que la clave privada se generó correctamente
if [ ! -f "$SUB_CA_DIR/$PRIVATE_KEY" ]; then
    echo "Error: No se pudo generar la clave privada"
    exit 1
fi

echo "   ✓ Clave privada de Sub CA generada: $PRIVATE_KEY"

echo ""
echo "2. Generando Certificate Signing Request (CSR) para Sub CA..."
openssl req -new \
    -key "$SUB_CA_DIR/$PRIVATE_KEY" \
    -out "$SUB_CA_DIR/$CSR_FILE" \
    -config "$CONFIG_FILE"

# Verificar que el CSR se generó correctamente
if [ ! -f "$SUB_CA_DIR/$CSR_FILE" ]; then
    echo "Error: No se pudo generar el CSR"
    exit 1
fi

echo "   ✓ CSR de Sub CA generado: $CSR_FILE"

echo ""
echo "3. Firmando certificado de Sub CA con la CA raíz (válido por 5 años)..."
openssl x509 -req \
    -in "$SUB_CA_DIR/$CSR_FILE" \
    -CA "$ROOT_CA_DIR/$ROOT_CA_CERT" \
    -CAkey "$ROOT_CA_DIR/$ROOT_CA_KEY" \
    -CAcreateserial \
    -out "$SUB_CA_DIR/$CERT_FILE" \
    -days 1825 \
    -extensions v3_intermediate_ca \
    -extfile "$CONFIG_FILE"

# Verificar que el certificado se generó correctamente
if [ ! -f "$SUB_CA_DIR/$CERT_FILE" ]; then
    echo "Error: No se pudo generar el certificado de Sub CA"
    exit 1
fi

echo "   ✓ Certificado de Sub CA firmado por CA raíz: $CERT_FILE"

echo ""
echo "4. Creando cadena de certificados completa..."
cat "$SUB_CA_DIR/$CERT_FILE" "$ROOT_CA_DIR/$ROOT_CA_CERT" > "$SUB_CA_DIR/chain.pem"

echo "   ✓ Cadena de certificados creada: chain.pem"

echo ""
echo "=== Resumen de archivos generados ==="
echo "Clave privada Sub CA: $SUB_CA_DIR/$PRIVATE_KEY"
echo "CSR Sub CA: $SUB_CA_DIR/$CSR_FILE"
echo "Certificado Sub CA: $SUB_CA_DIR/$CERT_FILE"
echo "Cadena completa: $SUB_CA_DIR/chain.pem"

echo ""
echo "=== Verificación de la cadena de certificados ==="
echo "Verificando certificado de Sub CA contra CA raíz..."
if openssl verify -CAfile "$ROOT_CA_DIR/$ROOT_CA_CERT" "$SUB_CA_DIR/$CERT_FILE" >/dev/null 2>&1; then
    echo "   ✓ Certificado de Sub CA verificado correctamente"
else
    echo "   ✗ Error en la verificación del certificado"
fi

echo ""
echo "=== Información del certificado Sub CA ==="
openssl x509 -in "$SUB_CA_DIR/$CERT_FILE" -text -noout | head -25

echo ""
echo "=== Sub CA generada exitosamente ==="
echo ""
echo "IMPORTANTE: Mantén la clave privada de Sub CA ($PRIVATE_KEY) en un lugar seguro."
echo "Este archivo no debe ser compartido ni expuesto."
echo ""
echo "Para verificar el certificado Sub CA en cualquier momento:"
echo "openssl verify -CAfile $ROOT_CA_DIR/$ROOT_CA_CERT $SUB_CA_DIR/$CERT_FILE"
echo ""
echo "Para verificar toda la cadena:"
echo "openssl verify -CAfile $ROOT_CA_DIR/$ROOT_CA_CERT -untrusted $SUB_CA_DIR/$CERT_FILE $SUB_CA_DIR/$CERT_FILE"
