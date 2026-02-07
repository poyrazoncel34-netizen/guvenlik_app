#!/bin/bash

# KoruBeni - Store Setup Script
# Bu script ilk 3 adımı otomatikleştirir

set -e

echo "🚀 KoruBeni Store Setup Başlıyor..."
echo ""

# ADIM 1: Git Repo
echo "📦 Git repo kuruluyor..."
if [ ! -d ".git" ]; then
    git init
    git add .
    git commit -m "Initial commit: KoruBeni security app - Store ready" || echo "⚠️  Commit başarısız (dosyalar zaten commit edilmiş olabilir)"
    echo "✅ Git repo kuruldu"
else
    echo "✅ Git repo zaten var"
fi
echo ""

# ADIM 2: Encryption Key Üret
echo "🔐 Encryption key üretiliyor..."
ENCRYPTION_KEY=$(openssl rand -base64 32)
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "⚠️  ÖNEMLİ: Bu key'i kopyala ve sakla!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "ENCRYPTION_KEY=$ENCRYPTION_KEY"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
read -p "Key'i kopyaladın mı? (Enter'a bas devam etmek için) " -n 1 -r
echo ""

# ADIM 3: Keystore Kontrolü
echo "🔑 Android keystore kontrol ediliyor..."
if [ ! -f "android/korubeni-release-key.jks" ]; then
    echo ""
    echo "⚠️  Keystore bulunamadı. Manuel oluşturman gerekiyor:"
    echo ""
    echo "cd android"
    echo "keytool -genkey -v -keystore korubeni-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias korubeni"
    echo ""
    echo "Sonra key.properties dosyasını oluştur:"
    echo "storePassword=ŞİFREN"
    echo "keyPassword=ŞİFREN"
    echo "keyAlias=korubeni"
    echo "storeFile=korubeni-release-key.jks"
    echo ""
else
    echo "✅ Keystore mevcut"
fi

# key.properties kontrolü
if [ ! -f "android/key.properties" ]; then
    echo "⚠️  key.properties dosyası bulunamadı. Oluşturman gerekiyor!"
else
    echo "✅ key.properties mevcut"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ İlk 3 adım tamamlandı!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📋 Sonraki adımlar:"
echo "1. Encryption key'i not al: $ENCRYPTION_KEY"
echo "2. Keystore oluştur (yukarıdaki komutları kullan)"
echo "3. key.properties dosyasını oluştur"
echo "4. Build al: ./scripts/build_production.sh"
echo ""
