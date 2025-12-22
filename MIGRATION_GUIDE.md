# Migración de Usuarios de Appwrite a Firebase

## Opciones de Migración

### Opción 1: Migración Manual (Recomendada para pocos usuarios)

Si tienes pocos usuarios en Appwrite, la forma más sencilla es:

1. **Exportar usuarios de Appwrite:**
   - Ve a Appwrite Console → Authentication → Users
   - Exporta la lista de emails

2. **En Firebase Console:**
   - Ve a Authentication → Users → Import users
   - Sube un CSV con los emails

3. **Los usuarios recibirán un email** para establecer nueva contraseña

---

### Opción 2: Script de Migración (Para muchos usuarios)

Necesitas Node.js instalado. Crea estos archivos:

#### 1. Crear proyecto de migración

```bash
mkdir appwrite-to-firebase-migration
cd appwrite-to-firebase-migration
npm init -y
npm install appwrite firebase-admin
```

#### 2. Crear `migrate-users.js`

```javascript
const { Client, Users } = require('appwrite');
const admin = require('firebase-admin');

// Configuración Appwrite
const appwriteClient = new Client()
    .setEndpoint('https://cloud.appwrite.io/v1')
    .setProject('677802c40031f81cd5b1')
    .setKey('TU_API_KEY_DE_APPWRITE'); // Necesitas una API Key de Server

const appwriteUsers = new Users(appwriteClient);

// Configuración Firebase Admin
const serviceAccount = require('./serviceAccountKey.json'); // Descarga de Firebase Console
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

async function migrateUsers() {
    try {
        // Obtener usuarios de Appwrite
        const response = await appwriteUsers.list();
        console.log(`Encontrados ${response.total} usuarios en Appwrite`);

        for (const user of response.users) {
            try {
                // Crear usuario en Firebase
                await admin.auth().createUser({
                    uid: user.$id, // Mantener el mismo ID
                    email: user.email,
                    displayName: user.name,
                    emailVerified: user.emailVerification
                });
                console.log(`✅ Migrado: ${user.email}`);
            } catch (error) {
                if (error.code === 'auth/email-already-exists') {
                    console.log(`⚠️ Ya existe: ${user.email}`);
                } else {
                    console.error(`❌ Error con ${user.email}:`, error.message);
                }
            }
        }

        console.log('Migración completada');
    } catch (error) {
        console.error('Error:', error);
    }
}

migrateUsers();
```

#### 3. Obtener credenciales

**Appwrite API Key:**
1. Appwrite Console → Settings → API Keys
2. Crear nueva key con permisos de `users.read`

**Firebase Service Account:**
1. Firebase Console → Project Settings → Service Accounts
2. Generar nueva clave privada
3. Guardar como `serviceAccountKey.json`

#### 4. Ejecutar migración

```bash
node migrate-users.js
```

---

### Opción 3: Los usuarios se registran de nuevo

Si prefieres no migrar datos:

1. **Notifica a los usuarios** que deben crear cuenta nueva
2. Los datos de ejercicios NO se migran automáticamente
3. Los usuarios empiezan de cero en Firebase

---

## Migración de Datos (Ejercicios/RMs)

Los datos de ejercicios están en Appwrite Database. Para migrarlos:

#### `migrate-data.js`

```javascript
const { Client, Databases, Query } = require('appwrite');
const admin = require('firebase-admin');

// ... configuración igual que arriba ...

const appwriteDb = new Databases(appwriteClient);
const firestore = admin.firestore();

const APPWRITE_DB_ID = '677fe764003cce766b3f';
const APPWRITE_COLLECTION_ID = '677fe76e002f45903aa9';

async function migrateData() {
    try {
        // Obtener todos los ejercicios de Appwrite
        const response = await appwriteDb.listDocuments(
            APPWRITE_DB_ID,
            APPWRITE_COLLECTION_ID,
            [Query.limit(1000)]
        );

        console.log(`Encontrados ${response.total} ejercicios`);

        for (const doc of response.documents) {
            try {
                const userId = doc.ID_User;
                
                // Parsear los RMs (están como strings JSON)
                const rmHistory = doc.rm.map(rmString => {
                    const parsed = JSON.parse(rmString);
                    return {
                        valor: parsed.valor,
                        fecha: new Date(parsed.fecha)
                    };
                });

                // Guardar en Firestore
                await firestore
                    .collection('users')
                    .doc(userId)
                    .collection('ejercicios')
                    .add({
                        name: doc.name,
                        rmHistory: rmHistory,
                        createdAt: new Date(),
                        descripcion: doc.descripcion || null
                    });

                console.log(`✅ Migrado: ${doc.name} (usuario: ${userId})`);
            } catch (error) {
                console.error(`❌ Error con ${doc.name}:`, error.message);
            }
        }

        console.log('Migración de datos completada');
    } catch (error) {
        console.error('Error:', error);
    }
}

migrateData();
```

---

## Pasos Recomendados

1. **Primero:** Habilita Email/Password en Firebase Console
   - Authentication → Sign-in method → Email/Password → Habilitar

2. **Segundo:** Decide si migrar usuarios o que se registren de nuevo

3. **Tercero:** Si migras, ejecuta los scripts en este orden:
   - `migrate-users.js` (usuarios)
   - `migrate-data.js` (ejercicios)

4. **Cuarto:** Notifica a los usuarios que usen "Olvidé mi contraseña" para obtener acceso
