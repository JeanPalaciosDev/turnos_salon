# ANÁLISIS DE COSTOS FIREBASE
## Multi-Tenant Salon Booking System - Proyección a Largo Plazo

**Fecha**: 2026-07-13  
**Moneda**: USD (dólares estadounidenses)  
**Horizonte**: 1-3 años  

---

## RESUMEN EJECUTIVO

**Para 10 salones con 100 usuarios cada uno (1,000 usuarios total):**
- **Mes 1**: ~$50-80 USD
- **Mes 6**: ~$150-250 USD (después de crecer)
- **Mes 12**: ~$300-500 USD
- **Año 1**: ~$2,500-4,000 USD
- **Año 3**: ~$5,000-10,000 USD (dependiendo de crecimiento)

**Alternativa: Servidor propio:**
- **Inversión inicial**: $1,000-3,000
- **Costo mensual**: $20-50
- **Pero**: Requiere mantenimiento, DevOps, escalamiento manual

---

## PARTE 1: COMPONENTES DE COSTO FIREBASE

### 1. Firestore Database

**Precio Base**:
- Lectura: **$0.06 por 100,000 lecturas**
- Escritura: **$0.18 por 100,000 escrituras**
- Almacenamiento: **$0.18 por GB/mes**

**Plan Gratuito (Spark)**:
- 50,000 lecturas/día
- 20,000 escrituras/día
- 1 GB almacenamiento
- ⚠️ INSUFICIENTE para producción

**Plan Blaze** (pago por uso):
- Lectura: $0.06/100K
- Escritura: $0.18/100K
- Almacenamiento: $0.18/GB

### 2. Firebase Authentication

**Precio Base**: **GRATIS**
- Usuarios ilimitados
- SMS: $0.015 por SMS (si usas)
- Costo: $0 (si no usas SMS/2FA)

### 3. Cloud Functions

**Precio Base**:
- Invocaciones: $0.40 por 1M invocaciones
- Tiempo de cálculo: $0.0000025 por GB-segundo
- Almacenamiento: $0.04 por GB/mes

**Para tu sistema:**
- `setUserClaims()` - Llamada al crear usuario
- Otros: Audit logging, validaciones

### 4. Cloud Storage

**Precio Base**: $0.020 por GB/mes
- Para logos/imágenes de tenants

### 5. Backup (Automático de Firebase)

**Precio Base**: INCLUIDO (sin costo adicional)

---

## PARTE 2: CÁLCULO PARA CASOS DE USO

### CASO 1: Pequeño (1-3 Salones)

**Escenario:**
- 3 salones
- 5 usuarios cada uno (15 usuarios total)
- 20 turnos/día
- 10 clientes/salón
- 10 servicios/salón

**Uso Diario Estimado:**

| Operación | Cantidad/Día | Costo |
|-----------|-------------|-------|
| Lecturas (turnos, clientes) | 300 | $0.001 |
| Escrituras (turnos) | 100 | $0.003 |
| Autenticaciones | 15 logins | $0 |
| **Total Diario** | | **$0.004** |
| **Total Mensual** | (30 días) | **$0.12** |

**Almacenamiento:**
- 3 salones × 100 docs = 300 docs ≈ 5 MB
- Costo: $0 (muy pequeño)

**TOTAL MES 1**: ~**$0.12 USD** (Plan Gratuito es suficiente)

---

### CASO 2: Mediano (10 Salones)

**Escenario:**
- 10 salones
- 100 usuarios (10 por salón)
- 500 turnos/día (50 por salón)
- 100 clientes/salón
- 20 servicios/salón

**Uso Diario:**

| Operación | Cantidad/Día | Cálculo | Costo |
|-----------|-------------|---------|-------|
| **Lecturas** | | | |
| - Agenda (50 turnos × 10) | 500 | 500 × $0.06/100K | $0.003 |
| - Clientes (100 × 10) | 1,000 | 1,000 × $0.06/100K | $0.006 |
| - Servicios (20 × 10) | 200 | 200 × $0.06/100K | $0.001 |
| **Escrituras** | | | |
| - Crear turnos (50) | 50 | 50 × $0.18/100K | $0.0009 |
| - Crear clientes (20) | 20 | 20 × $0.18/100K | $0.0004 |
| - Audit logs (100 ops) | 100 | 100 × $0.18/100K | $0.0018 |
| **Autenticación** | 100 logins | | $0 |
| **Cloud Functions** | 100 llamadas | 100 × $0.40/1M | $0.00004 |
| **Total Diario** | | | **$0.011** |
| **Total Mensual** | (30 días) | | **$0.33** |

**Almacenamiento:**
- 10 salones × (10 usuarios + 50 turnos + 100 clientes + 20 servicios)
- ≈ 50 MB total
- Costo mensual: $0.009

**TOTAL MES 1 - PEQUEÑO CRECIMIENTO**: ~**$0.34 USD** 

⚠️ **Plan Gratuito sigue siendo suficiente en Mes 1**

---

### CASO 3: Producción (50 Salones - Año 1)

**Escenario:**
- 50 salones
- 500 usuarios (10 por salón)
- 2,500 turnos/día (50 por salón)
- 500 clientes/salón
- 20 servicios/salón
- Crecimiento estable

**Uso Diario:**

| Operación | Cantidad/Día | Cálculo | Costo |
|-----------|-------------|---------|-------|
| **Lecturas** | | | |
| - Agenda (2,500) | 2,500 | 2,500/100K × $0.06 | $0.015 |
| - Clientes (25,000) | 25,000 | 25,000/100K × $0.06 | $0.15 |
| - Servicios (1,000) | 1,000 | 1,000/100K × $0.06 | $0.006 |
| - Usuarios (5,000) | 5,000 | 5,000/100K × $0.06 | $0.030 |
| **Escrituras** | | | |
| - Crear turnos (500) | 500 | 500/100K × $0.18 | $0.0009 |
| - Crear clientes (250) | 250 | 250/100K × $0.18 | $0.00045 |
| - Audit logs (2,000) | 2,000 | 2,000/100K × $0.18 | $0.0036 |
| - Queries & updates | 5,000 | 5,000/100K × $0.18 | $0.009 |
| **Autenticación** | 500 logins | | $0 |
| **Cloud Functions** | 500 llamadas | 500/1M × $0.40 | $0.0002 |
| **Total Diario** | | | **$0.215** |
| **Total Mensual** | (30 días) | | **$6.45** |

**Almacenamiento:**
- 50 salones × 1MB promedio = 50 MB
- Costo: $0.009/mes

**PROYECCIÓN AÑO 1:**
- Mes 1: ~$6.50
- Mes 3: ~$15 (después de crecer a 100 salones)
- Mes 6: ~$25 (200 salones)
- Mes 12: ~$40 (300 salones)
- **Total Año 1**: ~**$200-250 USD**

---

### CASO 4: Escala Mayor (200 Salones - Año 2)

**Escenario:**
- 200 salones
- 2,000 usuarios (10 por salón)
- 10,000 turnos/día
- 2,000 clientes/salón
- 30 servicios/salón
- Usuarios más activos (más queries)

**Uso Diario:**

| Operación | Cantidad/Día | Costo |
|-----------|-------------|-------|
| Lecturas (100,000 ops) | 100,000 | $0.60 |
| Escrituras (10,000 ops) | 10,000 | $0.018 |
| Autenticación | 2,000 | $0 |
| Cloud Functions | 2,000 | $0.0008 |
| **Total Diario** | | **$0.62** |
| **Total Mensual** | | **$18.60** |

**Almacenamiento:**
- 200 MB + crecimiento
- Costo: ~$0.036/mes

**PROYECCIÓN:**
- Mes 1-3: ~$20-25/mes
- Mes 6: ~$30-35/mes
- Mes 12: ~$40-50/mes
- **Total Año 2**: ~**$400-500 USD**

---

## PARTE 3: COSTO ANUAL POR ESCENARIO

### Año 1: Lanzamiento

| Salones | Usuarios | Costo Anual | Costo/Salón/Año |
|---------|----------|-------------|-----------------|
| 5 | 50 | $5-10 | $1-2 |
| 10 | 100 | $15-25 | $1.50-2.50 |
| 25 | 250 | $50-80 | $2-3.20 |
| 50 | 500 | $150-250 | $3-5 |

### Año 2: Crecimiento

| Salones | Usuarios | Costo Anual | Costo/Salón/Año |
|---------|----------|-------------|-----------------|
| 100 | 1,000 | $300-400 | $3-4 |
| 200 | 2,000 | $400-600 | $2-3 |
| 500 | 5,000 | $900-1,200 | $1.80-2.40 |

### Año 3: Maduración

| Salones | Usuarios | Costo Anual | Costo/Salón/Año |
|---------|----------|-------------|-----------------|
| 500 | 5,000 | $1,000-1,500 | $2-3 |
| 1,000 | 10,000 | $2,000-3,000 | $2-3 |
| 2,000 | 20,000 | $4,000-6,000 | $2-3 |

---

## PARTE 4: DESGLOSE DETALLADO - PARA 100 SALONES

**Escenario Base:**
- 100 salones
- 1,000 usuarios
- 5,000 turnos/día
- 500 clientes/salón
- 20 servicios/salón

### Por Componente (Mensual)

| Componente | Uso/Mes | Precio Unitario | Costo |
|-----------|---------|-----------------|-------|
| **Firestore Lecturas** | 1.5M | $0.06/100K | $9.00 |
| **Firestore Escrituras** | 300K | $0.18/100K | $0.54 |
| **Almacenamiento Firestore** | 100 MB | $0.18/GB | $0.018 |
| **Authentication** | 30K usuarios | $0 | $0 |
| **Cloud Functions** | 30K invocaciones | $0.40/1M | $0.012 |
| **Cloud Storage** | 50 MB logos | $0.020/GB | $0.001 |
| **Networking** (salida datos) | 500 MB | $0.12/GB | $0.06 |
| **TOTAL MENSUAL** | | | **$9.61** |
| **TOTAL ANUAL** | | | **$115** |

---

## PARTE 5: COSTOS ADICIONALES A CONSIDERAR

### A. Blaze Plan Mínimo

Firebase requiere Blaze plan después de exceder free tier.
- **Mínimo mensual**: $0 (pagar solo por lo que usas)
- **Pero**: Algunos servicios pueden tener costos mínimos

### B. Emails (No incluido en Firebase)

Para recuperación de contraseña, notificaciones:
- **SendGrid / AWS SES**: $0.10 por 1,000 emails
- **Para 1,000 usuarios x 1 email/mes**: $0.10
- **Total anual**: ~$1-2

### C. SMS 2FA (Opcional)

Si agregas autenticación SMS:
- **Costo**: $0.015 - $0.05 por SMS
- **Para 1,000 usuarios x 1 SMS/mes**: $15-50
- **Mejor alternativa**: Google Authenticator (gratis)

### D. Domain (Opcional)

Si quieres un dominio personalizado:
- **Costo anual**: $10-20
- **Ejemplo**: salon-management.com

### E. SSL Certificate

Firebase hosting incluye SSL gratis.

### F. Analytics (Opcional)

Google Analytics:
- **Costo**: Gratis (con datos limitados) o $150k+ para analytics360

---

## PARTE 6: COMPARATIVA: FIREBASE vs SERVIDOR PROPIO

### Opción 1: Firebase (Blaze Plan)

**Inversión Inicial:**
- $0 (solo $0-50 para testing)

**Costos Mensuales:**
- 10 salones: $0.50
- 50 salones: $10
- 100 salones: $15-20
- 500 salones: $50-70
- 1,000 salones: $100-150

**Ventajas:**
- ✅ Sin inversión inicial
- ✅ Escalamiento automático
- ✅ No requiere DevOps
- ✅ Backups automáticos
- ✅ Seguridad enterprise
- ✅ Cifrado SSL incluido

**Desventajas:**
- ❌ Costo sube con uso
- ❌ Vendor lock-in
- ❌ Menos control
- ❌ Limitaciones de las APIs

---

### Opción 2: Servidor Propio (AWS/DigitalOcean)

**Inversión Inicial:**
- $500-2,000 (setup, configuración, SSL)

**Costos Mensuales:**
- Servidor: $20-50/mes
- Base de datos: $10-30/mes
- Almacenamiento: $5-20/mes
- Backup: $5-10/mes
- DevOps/Mantenimiento: $500-2,000/mes (contratado) O Tu tiempo
- Email/SMS: $10-20/mes

**Total**: $50-100/mes (sin DevOps) O $600-2,100/mes (con DevOps contratado)

**Ventajas:**
- ✅ Control total
- ✅ Precios fijos
- ✅ Sin vendor lock-in
- ✅ Customizable

**Desventajas:**
- ❌ Inversión inicial alta
- ❌ Requiere DevOps
- ❌ Responsabilidad de seguridad
- ❌ Escalamiento manual
- ❌ Tiempo de tu equipo

---

## PARTE 7: PUNTO DE EQUILIBRIO

**¿Cuándo Firebase es más caro que servidor propio?**

### Escenario: 500 salones muy activos

**Firebase:**
- Costo: ~$60-100/mes (puro uso)
- Anual: ~$720-1,200

**Servidor Propio (sin DevOps dedicado):**
- Inicial: $1,000
- Mensual: $60
- Anual: $720 (año 2+)

**Conclusión:**
- **Año 1**: Firebase ~$800, Servidor $1,800 → Firebase gana
- **Año 3**: Firebase ~$2,400, Servidor ~$2,160 → Similar
- **Año 5**: Firebase ~$4,000, Servidor ~$3,600 → Servidor gana

**PERO:** Si necesitas DevOps contratado:
- Servidor: $600-2,100/mes = $7,200-25,200/año
- Firebase siempre es más barato

---

## PARTE 8: OPTIMIZACIONES PARA REDUCIR COSTOS

### 1. Caché en App (Reduce Lecturas)

**Antes:**
- Cada usuario carga agenda = 500 lecturas/día

**Después:**
- Cache local de 1 hora = 50 lecturas/día
- **Ahorro**: 90% en lecturas

**Implementación:**
```dart
// En Riverpod
final agendaProvider = FutureProvider.autoDispose<List<Turno>>((ref) async {
  // Cache automático por 60 segundos
  final cached = ref.state;
  if (cached != null && DateTime.now().difference(lastFetch) < Duration(minutes: 1)) {
    return cached;
  }
  // Fetch new
});
```

**Impacto de Costo:**
- Reducción de ~$0.15/mes por usuario
- Para 1,000 usuarios: **Ahorro de $150/mes** ($1,800/año)

### 2. Batch Writes (Reduce Escrituras)

**Antes:**
- Crear turno = 5 escrituras (turno + cliente + logs + etc)

**Después:**
- Batch write = 1 operación
- **Ahorro**: 80% en escrituras

**Implementación:**
```dart
// Usar WriteBatch
final batch = firestore.batch();
batch.set(docRef1, data1);
batch.update(docRef2, data2);
batch.delete(docRef3);
await batch.commit(); // 1 operación, no 3
```

### 3. Índices Compostos (Optimiza Queries)

Firestore crea índices automáticos, pero consulta optimizada:

**Antes:**
```dart
// Múltiples queries
final turnos = await db.collection('turnos').where('tenant_id', isEqualTo: id).get();
final clientes = await db.collection('clientes').where('tenant_id', isEqualTo: id).get();
```

**Después:**
```dart
// Una sola query con índice compuesto
final data = await db.collectionGroup('turnos')
  .where('tenant_id', isEqualTo: id)
  .where('fecha', isGreaterThan: hoy)
  .get(); // Mejor performancia
```

**Impacto:** 30-50% reducción en queries

### 4. Eliminar Datos Antiguos

**Política de Retención:**
- Turnos de hace >2 años: Eliminar
- Clientes inactivos: Archivar
- Audit logs >1 año: Comprimir

**Impacto de Costo:**
- Almacenamiento reducido 50% = **Ahorro $0.09/mes por 100 MB**

### 5. Usar Free Tier Máximo

Mientras sea posible, usa free tier de Firebase:
- 50K lecturas/día gratis
- 20K escrituras/día gratis
- 1 GB almacenamiento gratis

**Para 50 salones pequeños:**
- Puedes mantenerlos en free tier indefinidamente
- Costo: $0/mes

---

## PARTE 9: PROYECCIÓN REALISTA (ESCENARIO TÍPICO)

### Año 1: Fase de Lanzamiento y Crecimiento

| Mes | Salones | Usuarios | Costo/Mes | Costo Acumulado |
|-----|---------|----------|-----------|-----------------|
| 1 | 1 | 10 | $0 (free) | $0 |
| 2 | 2 | 20 | $0 (free) | $0 |
| 3 | 5 | 50 | $0.10 | $0.10 |
| 6 | 10 | 100 | $0.50 | $0.70 |
| 9 | 25 | 250 | $3 | $8.20 |
| 12 | 50 | 500 | $10 | **$50-60** |

**Total Año 1**: ~**$50-100 USD**

### Año 2: Crecimiento Estable

| Mes | Salones | Usuarios | Costo/Mes |
|-----|---------|----------|-----------|
| 6 | 100 | 1,000 | $12-15 |
| 12 | 200 | 2,000 | $25-30 |

**Total Año 2**: ~**$250-350 USD**

### Año 3: Maduración

| Mes | Salones | Usuarios | Costo/Mes |
|-----|---------|----------|-----------|
| 6 | 300 | 3,000 | $40-50 |
| 12 | 500 | 5,000 | $70-90 |

**Total Año 3**: ~**$500-700 USD**

---

## PARTE 10: ROI Y BUSINESS CASE

### Modelo de Ingresos (Ejemplo)

**Por Salon (suscripción mensual):**
- Plan Básico: $30/mes (10-50 usuarios)
- Plan Pro: $60/mes (50-200 usuarios)
- Plan Enterprise: $200/mes (200+ usuarios)

**Escenario:**
- 50 salones en Año 1
- 30 en Plan Básico: 30 × $30 = $900
- 15 en Plan Pro: 15 × $60 = $900
- 5 en Plan Enterprise: 5 × $200 = $1,000
- **Total ingresos/mes**: $2,800
- **Total ingresos/año**: $33,600

**Costo Firebase Año 1**: $100
**Beneficio neto**: $33,500 (99.7% margen)

### Crecimiento a Año 3

**500 salones:**
- 250 Básico: $7,500/mes
- 150 Pro: $9,000/mes
- 100 Enterprise: $20,000/mes
- **Total ingresos/mes**: $36,500
- **Total ingresos/año**: $438,000

**Costo Firebase Año 3**: ~$600
**Beneficio neto**: $437,400 (99.9% margen)

---

## PARTE 11: RECOMENDACIONES FINALES

### Para Pequeños Salones (1-10)

✅ **USA FIREBASE BLAZE**
- Costo: ~$5-10/año
- Mantenimiento: Mínimo
- Escalamiento: Automático
- Recomendación: Gratis o muy barato

### Para Medianos (10-100)

✅ **USA FIREBASE BLAZE** (Recomendado)
- Costo: $50-200/año
- Profesional
- Con optimizaciones (cache, batch writes)
- Recomendación: Mejor opción

### Para Grandes (100-1,000+)

⚠️ **CONSIDERA AMBAS OPCIONES**
- **Firebase**: $500-2,000/año
  - Si no tienes equipo DevOps
  - Si quieres simplificar
  
- **Servidor Propio**: $50/mes SIN DevOps, $600+/mes CON DevOps
  - Si tienes equipo técnico
  - Si quieres control total

**Recomendación:** Comienza con Firebase, migra si es necesario

---

## PARTE 12: CHECKLIST DE COSTOS

Antes de lanzar a producción:

- [ ] Firestore Plan Blaze activado
- [ ] Alertas de costos configuradas
- [ ] Budget set en Firebase Console ($50/mes límite recomendado)
- [ ] Caché local implementado (reduce lecturas)
- [ ] Batch writes implementados (reduce escrituras)
- [ ] Índices optimizados
- [ ] Política de retención de datos definida
- [ ] Backups automáticos verificados
- [ ] Monitor de costos mensual

---

## CONCLUSIÓN

**Para tu negocio de salones:**

| Métrica | Valor |
|---------|-------|
| **Costo inicial** | $0-50 |
| **Costo Año 1** | $50-150 |
| **Costo Año 3 (500 salones)** | $500-1,500 |
| **Costo por salón/año** | $1-3 |
| **ROI** | 99%+ |

**Recomendación: FIREBASE ES LA MEJOR OPCIÓN para este tipo de negocio.**

- Barato
- Escalable
- Poco mantenimiento
- Seguro
- Profesional

---

**Próximos pasos:**

1. ✅ Activar Blaze Plan
2. ✅ Implementar monitoreo de costos
3. ✅ Optimizar queries (cache, batch writes)
4. ✅ Lanzar a producción
5. ✅ Monitorear costos mensuales

