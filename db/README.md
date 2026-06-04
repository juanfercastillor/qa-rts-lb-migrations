# Queen Arts Database Schema — Liquibase Migrations

Sistema de migraciones de base de datos para Queen Arts Ecommerce usando **Liquibase** + **PostgreSQL**.

## 📁 Estructura del Proyecto

```
docs/db/
├── README.md                          # Este archivo
├── changelog/
│   ├── db.changelog-master.yaml       # Archivo maestro de migraciones
│   └── changesets/                    # Changesets individuales
│       ├── 001-create-categories-and-tags.yaml
│       ├── 002-create-products.yaml
│       ├── 003-create-product-relations.yaml
│       ├── 004-create-collections.yaml
│       ├── 005-create-content-tables.yaml
│       ├── 006-create-inventory.yaml
│       ├── 007-create-cart.yaml
│       ├── 008-create-orders.yaml
│       ├── 009-create-payments.yaml
│       ├── 010-create-users-and-addresses.yaml
│       ├── 011-create-notifications.yaml
│       ├── 012-seed-initial-data.yaml
│       └── 013-create-indexes-and-views.yaml
├── liquibase.properties               # Configuración de conexión
└── docker-compose.db.yml              # PostgreSQL local para desarrollo
```

## 🗄️ Esquema de Base de Datos Completo

### Servicios Representados

| Servicio | Tablas Principales | Descripción |
|----------|-------------------|-------------|
| **product-service** | `products`, `product_images`, `categories`, `tags`, `product_tags`, `product_related`, `pricing_audit_log` | Catálogo de productos completo |
| **collection-service** | `collections`, `collection_products`, `collection_related`, `collection_types` | Colecciones editoriales |
| **content-service** | `journal_articles`, `gift_guides`, `seo_metadata`, `journal_categories` | Blog, guías de regalo, SEO |
| **inventory-service** | `inventory`, `inventory_reservations`, `inventory_movements` | Stock y reservas |
| **cart-service** | `carts`, `cart_items`, `cart_events` | Carritos persistentes |
| **order-service** | `orders`, `order_items`, `order_status_history`, `invoices` | Órdenes y facturas |
| **payment-service** | `payment_transactions`, `saved_payment_methods`, `refunds`, `payment_webhooks` | Pagos y transacciones |
| **user-service** | `user_profiles`, `addresses`, `wishlist_items` | Perfiles y direcciones |
| **notification-service** | `notification_templates`, `notifications`, `device_tokens` | Email, SMS, Push |
| **media-service** | `media_assets` | Gestión de assets digitales |

### Diagrama de Relaciones

```
┌─────────────────────────────────────────────────────────────────┐
│                         USERS                                    │
│  user_profiles ─┬─ addresses                                      │
│                └─ wishlist_items                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ owns
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         ORDERS                                   │
│  orders ─┬─ order_items                                          │
│          ├─ order_status_history                                 │
│          └─ invoices                                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ pays
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       PAYMENTS                                   │
│  payment_transactions ─┬─ refunds                                │
│                        └─ saved_payment_methods                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      CATALOG                                     │
│                                                                  │
│  products ─┬─ product_images                                     │
│            ├─ product_tags ── tags                               │
│            ├─ product_related                                    │
│            └─ pricing_audit_log                                   │
│                                                                  │
│  collections ── collection_products ──► products                 │
│                                                                  │
│  inventory ─┬─ inventory_reservations                            │
│             └─ inventory_movements                                │
│                                                                  │
│  carts ── cart_items ──► products                                │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      CONTENT                                     │
│  journal_articles ─┬─ article_tags                               │
│                    ├─ article_related                            │
│                    └─ article_products                           │
│                                                                  │
│  gift_guides ── gift_guide_products ──► products                 │
│                                                                  │
│  seo_metadata                                                    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    NOTIFICATIONS                                 │
│  notification_templates ── notifications                          │
│                                                                  │
│  device_tokens ── user_notification_preferences                 │
└─────────────────────────────────────────────────────────────────┘
```

## 🚀 Cómo Usar

### Opción 1: Docker Compose (Recomendado para desarrollo)

```bash
# Levantar PostgreSQL local
cd docs/db
docker-compose -f docker-compose.db.yml up -d

# Ejecutar migraciones
docker run --rm --network=host \
  -v $(pwd)/changelog:/liquibase/changelog \
  liquibase/liquibase:latest \
  --url="jdbc:postgresql://localhost:5432/queenarts" \
  --username=postgres \
  --password=postgres \
  --changelog-file=/liquibase/changelog/db.changelog-master.yaml \
  update
```

### Opción 2: Liquibase CLI (Local)

```bash
# Instalar Liquibase (macOS)
brew install liquibase

# o descargar desde https://www.liquibase.org/download

# Configurar conexión
cat > liquibase.properties <<EOF
url=jdbc:postgresql://localhost:5432/queenarts
username=queenarts_app
password=tu_password_seguro
changelogFile=docs/db/changelog/db.changelog-master.yaml
logLevel=info
EOF

# Ejecutar migraciones
liquibase update

# Verificar estado
liquibase status

# Ver historial
liquibase history

# Rollback (último changeset)
liquibase rollbackCount 1

# Rollback a tag específico
liquibase rollback --tag=version_1.0
```

### Opción 3: Spring Boot (Maven/Gradle)

**pom.xml:**
```xml
<dependency>
    <groupId>org.liquibase</groupId>
    <artifactId>liquibase-core</artifactId>
    <version>4.25.0</version>
</dependency>
```

**application.yml:**
```yaml
spring:
  liquibase:
    enabled: true
    change-log: classpath:db/changelog/db.changelog-master.yaml
    default-schema: public
    contexts: dev  # o prod, staging
```

### Opción 4: CI/CD (GitHub Actions)

```yaml
# .github/workflows/db-migrate.yml
name: Database Migration

on:
  push:
    paths:
      - 'docs/db/changelog/**'

jobs:
  migrate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Liquibase
        uses: liquibase-github-actions/update@v4
        with:
          url: ${{ secrets.DB_URL }}
          username: ${{ secrets.DB_USER }}
          password: ${{ secrets.DB_PASSWORD }}
          changelogFile: docs/db/changelog/db.changelog-master.yaml
```

## 📋 Comandos Útiles

```bash
# Validar changesets sin ejecutar
liquibase validate

# Previsualizar SQL que se ejecutará
liquibase updateSQL > migration.sql

# Generar diff desde una base existente
liquibase generateChangeLog

# Crear tag para rollback
liquibase tag version_1.0

# Comparar dos bases de datos
liquibase diff \
  --referenceUrl=jdbc:postgresql://prod:5432/queenarts \
  --referenceUsername=... \
  --referencePassword=...

# Verificar checks (Quality Checks)
liquibase checks run
```

## 🏷️ Convenciones de Changesets

### ID de Changeset
```
{orden}-{descripcion}
Ej: 001-create-categories-and-tags
```

### Estructura YAML
```yaml
databaseChangeLog:
  - changeSet:
      id: 001-ejemplo
      author: tu-nombre
      comment: Descripción del cambio
      changes:
        - createTable:
            tableName: ejemplo
            columns:
              - column:
                  name: id
                  type: UUID
                  constraints:
                    primaryKey: true
      rollback:
        - dropTable:
            tableName: ejemplo
```

## 📊 Vistas de Reporte Disponibles

| Vista | Descripción |
|-------|-------------|
| `active_products_enriched` | Productos activos con imágenes y tags |
| `collection_stats` | Estadísticas de colecciones (conteos) |
| `inventory_availability` | Stock neto disponible por producto |
| `cart_summary` | Resumen de carritos activos |
| `order_summary` | Resumen de órdenes con conteos |
| `product_performance_summary` | KPIs de rendimiento por producto |
| `sales_by_category` | Ventas agrupadas por categoría |
| `sales_by_month` | Tendencias de ventas mensuales |
| `abandoned_cart_summary` | Análisis de carritos abandonados |
| `low_stock_alert` | Productos con stock bajo |
| `customer_lifetime_value` | CLV por cliente |
| `user_activity_summary` | Resumen de actividad de usuarios |

## 🔐 Seguridad

### Row Level Security (RLS)
```sql
-- Las tablas de usuarios tienen RLS habilitado
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Política de aislamiento
CREATE POLICY user_profiles_isolation ON user_profiles
  FOR ALL
  TO queenarts_app
  USING (id = current_setting('app.current_user_id', true));
```

### Rol de Aplicación
```sql
-- Rol con permisos limitados (no DELETE físico)
CREATE ROLE queenarts_app;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES TO queenarts_app;
REVOKE DELETE ON products, orders, users FROM queenarts_app;
```

## 🔧 Extensiones PostgreSQL Utilizadas

| Extensión | Uso |
|-----------|-----|
| `uuid-ossp` | Generación de UUIDs |
| `pg_trgm` | Búsqueda full-text y similitud |
| `btree_gin` | Índices compuestos GIN |

## 🌐 Contextos (Environments)

```bash
# Desarrollo
liquibase --contexts=dev update

# Staging
liquibase --contexts=staging update

# Producción
liquibase --contexts=prod update

# Testing (incluye datos de prueba)
liquibase --contexts=dev,test update
```

## 📝 Notas de Diseño

### Soft Delete
Todas las entidades principales usan `status` para eliminación lógica:
- `active`, `draft`, `archived` (productos, colecciones, artículos)
- `pending`, `sent`, `failed` (notificaciones)
- `pending`, `confirmed`, `shipped` (órdenes)

### Auditoría
Todas las tablas incluyen:
- `created_at`, `updated_at` (timestamps automáticos)
- `created_by`, `updated_by` (auditoría de usuario)

### JSONB para Flexibilidad
Campos que varían según contexto:
- `visual_theme` en colecciones
- `shipping_address`, `billing_address` en órdenes
- `provider_metadata` en pagos
- `care_data` en productos

### Snapshots Inmutables
Tablas de historial que no se modifican:
- `pricing_audit_log` — cambios de precio
- `inventory_movements` — movimientos de stock
- `order_items` — snapshot de productos en orden
- `order_status_history` — transiciones de estado

## 🆘 Troubleshooting

### Error: "Changelog file not found"
```bash
# Verificar ruta relativa al working directory
liquibase --changelog-file=docs/db/changelog/db.changelog-master.yaml status
```

### Error: "Checksum validation failed"
```bash
# Clear checksums para recalcular (cuidado en producción)
liquibase clearCheckSums
liquibase update
```

### Error: "Lock acquisition failed"
```bash
# Liberar locks de la base de datos
liquibase releaseLocks
```

### Verificar último changeset aplicado
```sql
SELECT * FROM databasechangelog ORDER BY dateexecuted DESC LIMIT 5;
```

## 📚 Recursos

- [Liquibase Documentation](https://docs.liquibase.com/)
- [Liquibase Best Practices](https://docs.liquibase.com/concepts/best-practices.html)
- [PostgreSQL JSONB](https://www.postgresql.org/docs/current/datatype-json.html)
- [PostgreSQL Full-Text Search](https://www.postgresql.org/docs/current/textsearch.html)

## 🤝 Contribución

Para agregar un nuevo changeset:

1. Crear archivo YAML en `changelog/changesets/`
2. Seguir convención de nomenclatura: `XXX-accion-descripcion.yaml`
3. Incluir rollback siempre que sea posible
4. Agregar al `db.changelog-master.yaml`
5. Probar en local antes de subir

---

**Queen Arts** — Joyería editorial premium  
🇪🇨 De Ecuador para el mundo
