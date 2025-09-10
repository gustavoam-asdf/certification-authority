#!/bin/sh

# Script para generar un Certificado SSL de Servidor
# Autor: Generado automáticamente
# Fecha: $(date)

set -e  # Salir si cualquier comando falla

# Configuración
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SSL_DIR="$SCRIPT_DIR/../../results/ssl-certificate"
SUB_CA_DIR="$SCRIPT_DIR/../../results/sub-ca"
ROOT_CA_DIR="$SCRIPT_DIR/../../results/root-ca"
CONFIG_FILE="$SCRIPT_DIR/ssl-certificate.conf"

# Resolver rutas absolutas
SSL_DIR="$(realpath "$SSL_DIR" 2>/dev/null || echo "$SSL_DIR")"
SUB_CA_DIR="$(realpath "$SUB_CA_DIR" 2>/dev/null || echo "$SUB_CA_DIR")"
ROOT_CA_DIR="$(realpath "$ROOT_CA_DIR" 2>/dev/null || echo "$ROOT_CA_DIR")"

# Nombres de archivos - SSL Certificate
PRIVATE_KEY="private-key.pem"
CSR_FILE="certificate.csr"
CERT_FILE="certificate.pem"

# Nombres de archivos - Sub CA (para firmar)
SUB_CA_CERT="certificate.pem"
SUB_CA_KEY="private-key.pem"

# Nombres de archivos - Root CA (para cadena)
ROOT_CA_CERT="certificate.pem"

echo "=== Generación de Certificado SSL de Servidor ==="
echo "Directorio de trabajo: $SSL_DIR"

# Verificar que existe la Sub CA
if [ ! -f "$SUB_CA_DIR/$SUB_CA_CERT" ] || [ ! -f "$SUB_CA_DIR/$SUB_CA_KEY" ]; then
    echo "Error: No se encontraron los archivos de la Sub CA en $SUB_CA_DIR"
    echo "Asegúrate de haber ejecutado primero el script de generación de Sub CA"
    exit 1
fi

# Verificar que existe la Root CA (para cadena completa)
if [ ! -f "$ROOT_CA_DIR/$ROOT_CA_CERT" ]; then
    echo "Error: No se encontró el certificado de la CA raíz en $ROOT_CA_DIR"
    echo "Se necesita para crear la cadena completa"
    exit 1
fi

echo "   ✓ Sub CA encontrada en: $SUB_CA_DIR"
echo "   ✓ Root CA encontrada en: $ROOT_CA_DIR"

# Crear directorio de resultados si no existe
mkdir -p "$SSL_DIR"

echo ""
echo "1. Generando par de claves de curva elíptica (P-384) para certificado SSL..."
openssl ecparam -genkey -name secp384r1 | openssl ec -out "$SSL_DIR/$PRIVATE_KEY"

# Verificar que la clave privada se generó correctamente
if [ ! -f "$SSL_DIR/$PRIVATE_KEY" ]; then
    echo "Error: No se pudo generar la clave privada"
    exit 1
fi

echo "   ✓ Clave privada SSL generada: $PRIVATE_KEY"

echo ""
echo "2. Generando Certificate Signing Request (CSR) para certificado SSL..."
openssl req -new \
    -key "$SSL_DIR/$PRIVATE_KEY" \
    -out "$SSL_DIR/$CSR_FILE" \
    -config "$CONFIG_FILE"

# Verificar que el CSR se generó correctamente
if [ ! -f "$SSL_DIR/$CSR_FILE" ]; then
    echo "Error: No se pudo generar el CSR"
    exit 1
fi

echo "   ✓ CSR SSL generado: $CSR_FILE"

echo ""
echo "3. Firmando certificado SSL con la Sub CA (válido por 1 año)..."
openssl x509 -req \
    -in "$SSL_DIR/$CSR_FILE" \
    -CA "$SUB_CA_DIR/$SUB_CA_CERT" \
    -CAkey "$SUB_CA_DIR/$SUB_CA_KEY" \
    -CAcreateserial \
    -out "$SSL_DIR/$CERT_FILE" \
    -days 365 \
    -extensions v3_req \
    -extfile "$CONFIG_FILE"

# Verificar que el certificado se generó correctamente
if [ ! -f "$SSL_DIR/$CERT_FILE" ]; then
    echo "Error: No se pudo generar el certificado SSL"
    exit 1
fi

echo "   ✓ Certificado SSL firmado por Sub CA: $CERT_FILE"

echo ""
echo "4. Creando archivos de cadena de certificados..."

# Crear CA Chain (Sub CA + Root CA)
echo "   • Creando caChain.pem (Sub CA + Root CA)..."
cat "$SUB_CA_DIR/$SUB_CA_CERT" "$ROOT_CA_DIR/$ROOT_CA_CERT" > "$SSL_DIR/caChain.pem"

# Crear Full Chain (Server Cert + Sub CA + Root CA)
echo "   • Creando fullchain.pem (Server + Sub CA + Root CA)..."
cat "$SSL_DIR/$CERT_FILE" "$SUB_CA_DIR/$SUB_CA_CERT" "$ROOT_CA_DIR/$ROOT_CA_CERT" > "$SSL_DIR/fullchain.pem"

echo "   ✓ Archivos de cadena creados: caChain.pem, fullchain.pem"

echo ""
echo "=== Resumen de archivos generados ==="
echo "Clave privada SSL: $SSL_DIR/$PRIVATE_KEY"
echo "CSR SSL: $SSL_DIR/$CSR_FILE"
echo "Certificado SSL: $SSL_DIR/$CERT_FILE"
echo "Cadena CA: $SSL_DIR/caChain.pem"
echo "Cadena completa: $SSL_DIR/fullchain.pem"

echo ""
echo "=== Verificación del certificado SSL ==="
echo "Verificando certificado SSL contra Sub CA..."
if openssl verify -CAfile "$SUB_CA_DIR/$SUB_CA_CERT" "$SSL_DIR/$CERT_FILE" >/dev/null 2>&1; then
    echo "   ✓ Certificado SSL verificado correctamente contra Sub CA"
else
    echo "   ✗ Error en la verificación contra Sub CA"
fi

echo "Verificando certificado SSL contra cadena completa..."
if openssl verify -CAfile "$ROOT_CA_DIR/$ROOT_CA_CERT" -untrusted "$SUB_CA_DIR/$SUB_CA_CERT" "$SSL_DIR/$CERT_FILE" >/dev/null 2>&1; then
    echo "   ✓ Certificado SSL verificado correctamente contra cadena completa"
else
    echo "   ✗ Error en la verificación contra cadena completa"
fi

echo ""
echo "=== Información del certificado SSL ==="
openssl x509 -in "$SSL_DIR/$CERT_FILE" -text -noout | head -30

echo ""
echo "=== Certificado SSL generado exitosamente ==="
echo ""
echo "IMPORTANTE: Mantén la clave privada SSL ($PRIVATE_KEY) en un lugar seguro."
echo "Este archivo no debe ser compartido ni expuesto."
echo ""
echo "=== Uso en servidores web ==="
echo "Para Apache:"
echo "  SSLCertificateFile    $SSL_DIR/$CERT_FILE"
echo "  SSLCertificateKeyFile $SSL_DIR/$PRIVATE_KEY"
echo "  SSLCertificateChainFile $SSL_DIR/caChain.pem"
echo ""
echo "Para Nginx:"
echo "  ssl_certificate       $SSL_DIR/fullchain.pem"
echo "  ssl_certificate_key   $SSL_DIR/$PRIVATE_KEY"
echo ""
echo "Para verificar el certificado SSL:"
echo "openssl verify -CAfile $ROOT_CA_DIR/$ROOT_CA_CERT -untrusted $SUB_CA_DIR/$SUB_CA_CERT $SSL_DIR/$CERT_FILE"
echo ""
echo "Para verificar la cadena completa:"
echo "openssl verify -CAfile $ROOT_CA_DIR/$ROOT_CA_CERT -untrusted $SSL_DIR/caChain.pem $SSL_DIR/$CERT_FILE"
