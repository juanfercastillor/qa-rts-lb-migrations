# Queen Arts — Database Migrations

**Nombre del proyecto**: `qa-rts-lb-migrations`  
**Tecnología**: Liquibase + Gradle  
**Propósito**: Gestión versionada de esquemas de bases de datos para microservicios.

---

## 🎯 Responsabilidad

Gestiona las migraciones de bases de datos PostgreSQL para:
- `product-service` — catálogo de productos (puerto 5433)
- `collection-service` — colecciones editoriales (puerto 5434)
- `content-service` — journal y gift guides (puerto 5435)

---

## 📁 Estructura

```
qa-rts-lb-migrations/
├── product/
│   └── db.changelog-master.xml
├── collection/
│   └── db.changelog-master.xml
├── content/
│   └── db.changelog-master.xml
├── src/main/resources/        # Changelogs en resources
├── build.gradle               # Configuración Gradle + Liquibase
├── settings.gradle
└── README.md
```

---

## 🚀 Cómo usar

### Prerrequisitos

- Java 17+
- PostgreSQL 15+ corriendo
- Variables de entorno configuradas

### Configuración de entorno

```bash
# Windows PowerShell
$env:PRODUCT_DB_URL="jdbc:postgresql://localhost:5433/queenarts_products"
$env:PRODUCT_DB_USER="queenarts"
$env:PRODUCT_DB_PASSWORD="your_password"

$env:COLLECTION_DB_URL="jdbc:postgresql://localhost:5434/queenarts_collections"
$env:COLLECTION_DB_USER="queenarts"
$env:COLLECTION_DB_PASSWORD="your_password"

$env:CONTENT_DB_URL="jdbc:postgresql://localhost:5435/queenarts_content"
$env:CONTENT_DB_USER="queenarts"
$env:CONTENT_DB_PASSWORD="your_password"
```

### Ejecutar migraciones

```bash
# Migrar product-service
./gradlew updateProduct

# Migrar collection-service
./gradlew updateCollection

# Migrar content-service
./gradlew updateContent

# Migrar todos
./gradlew updateAll
```

### Ver status

```bash
./gradlew statusProduct
./gradlew statusCollection
./gradlew statusContent
```

### Rollback

```bash
# Rollback del último changeset
./gradlew rollbackProduct -Pcount=1
./gradlew rollbackCollection -Pcount=1
./gradlew rollbackContent -Pcount=1
```

---

## 📝 Convenciones de Nomenclatura

### Archivos de changeset

```
{SECUENCIA}-{ACCION}-{OBJETO}.sql

Ejemplos:
001-create-products-table.sql
002-add-product-status-column.sql
003-create-product-indexes.sql
```

### Formatos de changeset XML

```xml
<changeSet id="001" author="developer-name">
    <sqlFile path="changesets/001-create-products-table.sql"/>
    <rollback>
        <sql>DROP TABLE IF EXISTS products;</sql>
    </rollback>
</changeSet>
```

---

## 🔐 Variables de Entorno

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `PRODUCT_DB_URL` | JDBC URL de product DB | `jdbc:postgresql://localhost:5433/queenarts_products` |
| `PRODUCT_DB_USER` | Usuario de product DB | `queenarts` |
| `PRODUCT_DB_PASSWORD` | Password de product DB | `***` |
| `COLLECTION_DB_URL` | JDBC URL de collection DB | `jdbc:postgresql://localhost:5434/queenarts_collections` |
| `COLLECTION_DB_USER` | Usuario de collection DB | `queenarts` |
| `COLLECTION_DB_PASSWORD` | Password de collection DB | `***` |
| `CONTENT_DB_URL` | JDBC URL de content DB | `jdbc:postgresql://localhost:5435/queenarts_content` |
| `CONTENT_DB_USER` | Usuario de content DB | `queenarts` |
| `CONTENT_DB_PASSWORD` | Password de content DB | `***` |

---

## 📝 Notas Ecuador 🇪🇨

- **Collation**: Usar `es_EC` o `en_US.UTF-8` para ordenamiento
- **Timezone**: Las columnas `created_at`/`updated_at` usan `TIMESTAMP WITH TIME ZONE`
- **UTF-8**: Asegurar que todas las bases usen `UTF8` encoding

---

## 👥 Equipo

- **DBA**: Queen Arts Backend Team
- **Contact**: backend@queenarts.ec
