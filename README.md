# 🗺️ Social Map

Una aplicación móvil de mensajería geo-social construida con Flutter que permite a los usuarios compartir mensajes efímeros basados en su ubicación en tiempo real.

## 📱 Descripción

Social Map es una aplicación innovadora que combina mensajería instantánea con geolocalización, permitiendo a los usuarios:

- 📍 **Enviar mensajes geolocalizados** que aparecen en un mapa interactivo
- ⏱️ **Mensajes temporales** que expiran automáticamente después de 5 minutos
- 🤖 **Identidad anónima** con avatares robóticos y apodos personalizables
- 🌐 **Mapa en tiempo real** usando OpenStreetMap (sin costos de API)
- 🔒 **Privacidad mejorada** con ubicaciones difuminadas para proteger la privacidad del usuario
- 📶 **Modo offline** con caché persistente para mejor experiencia de usuario
- 👥 **Contador de usuarios activos** en tiempo real

## ✨ Características Principales

### Mensajería Geo-Social
- Envío y recepción de mensajes en tiempo real
- Visualización de mensajes en un mapa interactivo
- Filtrado automático de contenido ofensivo
- Feedback háptico para nuevos mensajes

### Privacidad y Seguridad
- Identificación persistente mediante UUID
- Ubicaciones difuminadas para proteger la privacidad
- Mensajes temporales que se auto-eliminan
- Reglas de seguridad de Firestore configuradas

### Experiencia de Usuario
- Interfaz intuitiva con Material Design 3
- Soporte para modo offline
- Caché ilimitado para mejor rendimiento
- Animaciones suaves y responsivas

## 🛠️ Tecnologías Utilizadas

### Frontend
- **Flutter** (SDK >=3.2.0 <4.0.0) - Framework multiplataforma
- **Material Design 3** - Sistema de diseño moderno

### Mapas y Geolocalización
- **flutter_map** (^7.0.2) - Visualización de mapas con OpenStreetMap
- **geolocator** (^12.0.0) - Obtención de ubicación del dispositivo
- **geoflutterfire2** (^2.3.6) - Consultas geoespaciales en Firestore
- **latlong2** (^0.9.1) - Manejo de coordenadas geográficas

### Backend y Base de Datos
- **Firebase Core** (^2.32.0) - Plataforma backend
- **Cloud Firestore** (^4.17.5) - Base de datos en tiempo real
- **Firebase Analytics** (^10.0.0) - Análisis de uso

### Gestión de Estado y Persistencia
- **Provider** (^6.1.1) - Gestión de estado
- **shared_preferences** (^2.2.2) - Almacenamiento local
- **uuid** (^4.0.0) - Generación de identificadores únicos

### Permisos y UI
- **permission_handler** (^11.3.1) - Gestión de permisos
- **custom_info_window** (^1.0.1) - Ventanas de información personalizadas

## 📋 Requisitos Previos

- Flutter SDK 3.2.0 o superior
- Dart SDK
- Android Studio / Xcode (para desarrollo móvil)
- Cuenta de Firebase con proyecto configurado

## 🚀 Instalación

### 1. Clonar el repositorio

```bash
git clone git@github.com:JaimeUTalca/social-map.git
cd social-map
```

### 2. Instalar dependencias

```bash
flutter pub get
```

### 3. Configurar Firebase

1. Crea un proyecto en [Firebase Console](https://console.firebase.google.com/)
2. Configura Firebase para Android/iOS siguiendo la [documentación oficial](https://firebase.google.com/docs/flutter/setup)
3. Descarga los archivos de configuración:
   - `google-services.json` para Android (en `android/app/`)
   - `GoogleService-Info.plist` para iOS (en `ios/Runner/`)

### 4. Configurar Firestore

Crea una colección llamada `messages` en Firestore con las siguientes reglas de seguridad:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /messages/{messageId} {
      allow read: if true;
      allow create: if request.auth != null || true;
      allow update, delete: if false;
    }
  }
}
```

### 5. Ejecutar la aplicación

```bash
# Modo desarrollo
flutter run

# Modo release
flutter run --release
```

## 📦 Generar APK

Para generar un APK de producción:

```bash
flutter build apk --release
```

El APK se generará en: `build/app/outputs/flutter-apk/app-release.apk`

## 🏗️ Estructura del Proyecto

```
lib/
├── main.dart                 # Punto de entrada de la aplicación
├── map_view.dart            # Vista principal del mapa
├── models/
│   ├── message_model.dart   # Modelo de datos de mensajes
│   └── latlng.dart          # Modelo de coordenadas
├── services/
│   └── firebase_service.dart # Servicios de Firebase
└── firebase_options.dart    # Configuración de Firebase

android/                     # Código nativo Android
ios/                        # Código nativo iOS
functions/                  # Cloud Functions (opcional)
```

## 🔧 Configuración Adicional

### Permisos de Android

Los siguientes permisos están configurados en `AndroidManifest.xml`:

- `ACCESS_FINE_LOCATION` - Ubicación precisa
- `ACCESS_COARSE_LOCATION` - Ubicación aproximada
- `INTERNET` - Conexión a internet

### Configuración de Iconos

El proyecto usa `flutter_launcher_icons` para generar iconos de la aplicación:

```bash
flutter pub run flutter_launcher_icons
```

## 🎯 Roadmap

- [ ] Implementar Google AdMob para monetización
- [ ] Agregar soporte para imágenes en mensajes
- [ ] Implementar sistema de reportes de contenido
- [ ] Agregar notificaciones push
- [ ] Soporte para temas claro/oscuro
- [ ] Versión web de la aplicación

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📄 Licencia

Este proyecto es de código abierto y está disponible bajo la licencia MIT.

## 👨‍💻 Autor

**Jaime Venegas**
- GitHub: [@JaimeUTalca](https://github.com/JaimeUTalca)

## 🙏 Agradecimientos

- OpenStreetMap por proporcionar mapas gratuitos
- Firebase por la infraestructura backend
- La comunidad de Flutter por las excelentes librerías

---

⭐ Si te gusta este proyecto, ¡dale una estrella en GitHub!
