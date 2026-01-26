# Firebase Cloud Functions - Limpieza Automática de Mensajes

## Función Implementada

### `cleanupExpiredMessages`
- **Tipo:** Scheduled Function (Función Programada)
- **Frecuencia:** Cada 5 minutos
- **Descripción:** Elimina automáticamente mensajes cuyo campo `expiresAt` sea anterior a la hora actual

## Estructura de Archivos

```
functions/
├── index.js          # Código de las Cloud Functions
├── package.json      # Dependencias de Node.js
└── .gitignore        # Archivos a ignorar (node_modules, etc)
```

## Despliegue

### Requisitos Previos
1. **Node.js 18** instalado
2. **Firebase CLI** instalado: `npm install -g firebase-tools`
3. **Autenticación:** `firebase login`

### Pasos para Desplegar

```powershell
# 1. Navegar al directorio de functions
cd functions

# 2. Instalar dependencias
npm install

# 3. Volver al directorio raíz
cd ..

# 4. Desplegar las funciones
firebase deploy --only functions
```

### Verificar Despliegue
```powershell
# Ver logs de la función
firebase functions:log

# Ver funciones desplegadas
firebase functions:list
```

## Funcionamiento

1. **Cada 5 minutos**, la función se ejecuta automáticamente
2. Busca mensajes donde `expiresAt <= now()`
3. Elimina hasta **500 mensajes** por ejecución (batch)
4. Registra en logs cuántos mensajes fueron eliminados

## Costos

- **Invocaciones:** ~8,640 por mes (cada 5 minutos)
- **Plan Spark (Gratis):** 2 millones de invocaciones/mes
- **Resultado:** ✅ Completamente gratis dentro del plan Spark

## Monitoreo

Ver logs en tiempo real:
```powershell
firebase functions:log --only cleanupExpiredMessages
```

O en la consola de Firebase:
- Functions → Logs → Filtrar por `cleanupExpiredMessages`

## Alternativa: Función Trigger (Comentada)

El archivo también incluye `scheduleMessageDeletion` que se ejecuta cuando se crea un mensaje. Esta función está implementada pero **no es necesaria** si usas la función programada. Puedes eliminarla si prefieres solo la limpieza periódica.

## Notas Importantes

- La función procesa **500 mensajes por ejecución** para evitar timeouts
- Si tienes más de 500 mensajes expirados, se limpiarán en la siguiente ejecución
- Los mensajes se eliminan **permanentemente** de Firestore
- No afecta el rendimiento de la app Flutter (se ejecuta en el servidor)
