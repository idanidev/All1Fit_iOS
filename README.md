# All1Fit iOS App - Guía de Configuración

## 📋 Pasos para configurar Firebase

### 1. Crear proyecto en Firebase Console

1. Ve a [Firebase Console](https://console.firebase.google.com)
2. Click en "Agregar proyecto"
3. Nombre: `All1Fit` (o el que prefieras)
4. Desactiva Google Analytics (opcional)
5. Click en "Crear proyecto"

### 2. Añadir app iOS

1. En la pantalla principal del proyecto, click en el icono de iOS
2. Configura:
   - **Bundle ID**: `com.idanidev.All1Fit`
   - **Nombre de la app**: All1Fit
3. Descarga el archivo `GoogleService-Info.plist`
4. **Mueve el archivo a**: `/Users/dani/Proyectos/All1Fit_IOS/All1Fit/`

### 3. Habilitar Authentication

1. En el menú lateral, click en **Build > Authentication**
2. Click en "Comenzar"
3. En la pestaña "Método de acceso":
   - Habilita **Apple** (necesitas cuenta de desarrollador)
   - Habilita **Google** (sigue las instrucciones para configurar)

### 4. Crear Firestore Database

1. En el menú lateral, click en **Build > Firestore Database**
2. Click en "Crear base de datos"
3. Selecciona ubicación (eur3 para Europa)
4. Inicia en modo **producción**
5. Añade estas reglas de seguridad:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Usuarios solo pueden acceder a sus propios documentos
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 5. Configurar Sign in with Apple (en Apple Developer Portal)

1. Ve a [Apple Developer](https://developer.apple.com)
2. En **Certificates, Identifiers & Profiles**
3. Click en **Identifiers** > Tu App ID
4. Habilita **Sign in with Apple**
5. En Xcode, añade la capability "Sign in with Apple"

### 6. Abrir en Xcode

```bash
open /Users/dani/Proyectos/All1Fit_IOS/All1Fit.xcodeproj
```

### 7. Añadir GoogleService-Info.plist

1. Arrastra `GoogleService-Info.plist` al grupo `All1Fit` en Xcode
2. Marca "Copy items if needed"
3. Marca el target `All1Fit`

### 8. Resolver dependencias

Xcode descargará automáticamente Firebase SDK y GoogleSignIn al abrir el proyecto.
Si no lo hace:
1. File > Packages > Reset Package Caches
2. File > Packages > Resolve Package Versions

### 9. Build & Run

1. Selecciona un simulador (iPhone 15 Pro recomendado)
2. Cmd + R para compilar y ejecutar

---

## 🎨 Estructura del Proyecto

```
All1Fit/
├── All1FitApp.swift          # Entry point + Firebase config
├── Models/
│   └── Ejercicio.swift       # Modelo de datos
├── Services/
│   ├── AuthService.swift     # Sign in con Apple/Google
│   └── EjercicioService.swift # CRUD Firestore
├── Views/
│   ├── ContentView.swift     # Router principal
│   ├── MainTabView.swift     # Tab bar
│   ├── Auth/
│   │   └── LoginView.swift   # Pantalla de login
│   └── RMs/
│       ├── RMListView.swift       # Lista de ejercicios
│       ├── EjercicioFormView.swift # Formulario
│       ├── PorcentajesView.swift   # Tabla %
│       └── RMChartView.swift       # Gráfico
└── Utils/
    └── Extensions.swift      # Helpers
```

---

## ❓ Troubleshooting

### Error: "No Firebase App has been configured"
→ Asegúrate de que `GoogleService-Info.plist` está en el target

### Error: Sign in with Apple no funciona
→ Verifica que la capability está añadida en Xcode

### Las dependencias no se descargan
→ File > Packages > Reset Package Caches
