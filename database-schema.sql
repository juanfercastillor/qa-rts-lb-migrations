-- ============================================================================
-- Queen Arts Ecommerce — Database Schema
-- PostgreSQL 14+ / 15 / 16
-- 
-- Servicios cubiertos:
--   1. product-service    (products, categories, tags, pricing_audit)
--   2. collection-service (collections, collection_products, visual_themes)
--   3. content-service    (journal_articles, gift_guides, guide_products, seo_metadata)
--
-- Convenciones:
--   - snake_case para tablas y columnas
--   - Claves primarias: UUID v4 (generados por app) o SERIAL cuando es interno
--   - Soft delete: status field, nunca DELETE CASCADE físico
--   - Auditoría: created_at, updated_at, updated_by en todas las tablas
--   - Índices: naming idx_{tabla}_{columna(s)}
--   - Foreign keys: nombres explícitos fk_{tabla_origen}_{tabla_destino}
-- ============================================================================

-- Habilitar extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";        -- Para búsqueda full-text
CREATE EXTENSION IF NOT EXISTS "btree_gin";      -- Para índices compuestos

-- ============================================================================
-- SERVICIO: product-service
-- ============================================================================

-- Catálogo de categorías (dimensiones pequeñas, lookup table)
CREATE TABLE categories (
    id              VARCHAR(50) PRIMARY KEY,    -- 'collares', 'aretes', etc.
    name            VARCHAR(100) NOT NULL,
    slug            VARCHAR(100) NOT NULL UNIQUE,
    description     TEXT,
    image_url       VARCHAR(500),
    sort_order      INTEGER DEFAULT 0,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_categories_slug ON categories(slug);
CREATE INDEX idx_categories_active ON categories(is_active) WHERE is_active = TRUE;

-- Tabla maestra de productos
CREATE TABLE products (
    id              VARCHAR(50) PRIMARY KEY,    -- 'QA-CO-001' formato QA-{CAT}-{NUM}
    sku             VARCHAR(50) NOT NULL UNIQUE,
    slug            VARCHAR(150) NOT NULL UNIQUE,
    name            VARCHAR(200) NOT NULL,
    description     TEXT NOT NULL,              -- Corto, para cards
    story           TEXT,                       -- Narrativa editorial larga
    
    -- Precios
    price           DECIMAL(10,2) NOT NULL CHECK (price > 0),
    original_price  DECIMAL(10,2) CHECK (original_price IS NULL OR original_price > price),
    currency        VARCHAR(3) DEFAULT 'USD' CHECK (currency = 'USD'),
    pricing_tier    VARCHAR(30) CHECK (pricing_tier IN ('accessible', 'accessible_premium', 'premium', 'luxury')),
    
    -- Clasificación
    category_id     VARCHAR(50) NOT NULL REFERENCES categories(id),
    badge           VARCHAR(50) CHECK (badge IN ('Nuevo', 'Bestseller', 'Edición Limitada', 'Últimas piezas', 'Agotado')),
    
    -- Material principal
    material_base   VARCHAR(100) NOT NULL,      -- 'Plata .925'
    material_finish VARCHAR(100),               -- 'Pulido brillante'
    material_weight VARCHAR(20),                -- '4.8g'
    material_purity  VARCHAR(50),                 -- 'Sterling Silver'
    
    -- Especificaciones técnicas
    spec_type       VARCHAR(100) NOT NULL,      -- 'Colgante', 'Argolla'
    spec_dimensions VARCHAR(50),
    spec_closure    VARCHAR(100),
    spec_length     VARCHAR(20),
    spec_size       VARCHAR(20),                -- Para anillos
    spec_adjustable BOOLEAN DEFAULT FALSE,
    
    -- Piedra (opcional)
    stone_type      VARCHAR(100),
    stone_color     VARCHAR(100),
    stone_shape     VARCHAR(100),
    stone_cut       VARCHAR(100),
    stone_quantity  INTEGER CHECK (stone_quantity >= 0),
    stone_origin    VARCHAR(100),
    
    -- Emocional
    emotional_concept    VARCHAR(100),          -- 'Serenidad mineral'
    emotional_tagline    VARCHAR(200),          -- 'La calma también se lleva.'
    emotional_message    TEXT,
    emotional_symbolism  TEXT,
    
    -- Cuidados
    care_instructions    TEXT[],                 -- Array de strings
    care_storage         TEXT,
    care_cleaning        TEXT,
    
    -- SEO
    seo_title            VARCHAR(150),
    seo_description      VARCHAR(300),
    
    -- Estado y visibilidad
    status          VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('active', 'draft', 'archived')),
    stock           INTEGER DEFAULT 0 CHECK (stock >= 0),
    is_new          BOOLEAN DEFAULT FALSE,
    is_featured     BOOLEAN DEFAULT FALSE,
    
    -- Fechas
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    published_at    TIMESTAMPTZ,                -- Cuando pasó a 'active'
    
    -- Auditoría
    created_by      VARCHAR(100),
    updated_by      VARCHAR(100)
);

-- Índices esenciales para product-service
CREATE INDEX idx_products_slug ON products(slug);
CREATE INDEX idx_products_sku ON products(sku);
CREATE INDEX idx_products_status ON products(status);
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_price ON products(price);
CREATE INDEX idx_products_featured ON products(is_featured) WHERE is_featured = TRUE;
CREATE INDEX idx_products_badge ON products(badge) WHERE badge IS NOT NULL;
CREATE INDEX idx_products_active_category ON products(category_id, status) WHERE status = 'active';
CREATE INDEX idx_products_created ON products(created_at DESC);

-- Índice para búsqueda full-text (PostgreSQL nativo)
CREATE INDEX idx_products_search ON products 
    USING gin(to_tsvector('spanish', coalesce(name,'') || ' ' || coalesce(description,'') || ' ' || coalesce(story,'')));

-- Tabla de imágenes de productos (1:N, permite galería ilimitada)
CREATE TABLE product_images (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id      VARCHAR(50) NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    src             VARCHAR(500) NOT NULL,
    alt             VARCHAR(300) NOT NULL,
    thumbnail       VARCHAR(500),
    is_primary      BOOLEAN DEFAULT FALSE,
    sort_order      INTEGER DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_product_images_product ON product_images(product_id);
CREATE INDEX idx_product_images_primary ON product_images(product_id, is_primary) WHERE is_primary = TRUE;

-- Tabla de tags (N:M con productos)
CREATE TABLE tags (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(50) NOT NULL UNIQUE,
    slug            VARCHAR(50) NOT NULL UNIQUE,
    is_popular      BOOLEAN DEFAULT FALSE,
    product_count   INTEGER DEFAULT 0  -- Denormalizado, actualizado por trigger
);

CREATE INDEX idx_tags_slug ON tags(slug);
CREATE INDEX idx_tags_popular ON tags(is_popular) WHERE is_popular = TRUE;

-- Relación N:M productos-tags
CREATE TABLE product_tags (
    product_id      VARCHAR(50) NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    tag_id          INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (product_id, tag_id)
);

CREATE INDEX idx_product_tags_tag ON product_tags(tag_id);

-- Relación productos relacionados (N:M consigo misma)
CREATE TABLE product_related (
    product_id      VARCHAR(50) NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    related_product_id VARCHAR(50) NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    relation_type   VARCHAR(30) DEFAULT 'related' CHECK (relation_type IN ('related', 'bundle', 'similar')),
    sort_order      INTEGER DEFAULT 0,
    PRIMARY KEY (product_id, related_product_id)
);

CREATE INDEX idx_product_related_product ON product_related(product_id);

-- Auditoría de cambios de precio (compliance y análisis)
CREATE TABLE pricing_audit_log (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id      VARCHAR(50) NOT NULL REFERENCES products(id),
    old_price       DECIMAL(10,2),
    new_price       DECIMAL(10,2),
    changed_by      VARCHAR(100),
    changed_at      TIMESTAMPTZ DEFAULT NOW(),
    reason          TEXT
);

CREATE INDEX idx_pricing_audit_product ON pricing_audit_log(product_id, changed_at DESC);

-- Trigger para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- SERVICIO: collection-service
-- ============================================================================

CREATE TABLE collection_types (
    id              VARCHAR(30) PRIMARY KEY,  -- 'emotional', 'temporal', 'aesthetic', 'commercial'
    name            VARCHAR(100) NOT NULL,
    description     TEXT
);

INSERT INTO collection_types (id, name) VALUES
    ('emotional', 'Emocional — Universos narrativos'),
    ('temporal', 'Temporal — Momentos específicos'),
    ('aesthetic', 'Estética — Visiones visuales'),
    ('commercial', 'Comercial — Estrategia de venta');

-- Colecciones editoriales
CREATE TABLE collections (
    id              VARCHAR(50) PRIMARY KEY,    -- 'col-001'
    slug            VARCHAR(150) NOT NULL UNIQUE,
    name            VARCHAR(200) NOT NULL,
    type_id         VARCHAR(30) NOT NULL REFERENCES collection_types(id),
    
    -- Contenido editorial
    tagline         VARCHAR(200) NOT NULL,     -- Subtítulo corto
    description     TEXT NOT NULL,             -- Párrafo introductorio
    story           TEXT,                      -- Narrativa larga
    
    -- Imágenes
    hero_image      VARCHAR(500) NOT NULL,
    hero_image_alt  VARCHAR(300) NOT NULL,
    story_image     VARCHAR(500),
    
    -- SEO
    seo_title       VARCHAR(150),
    seo_description VARCHAR(300),
    
    -- Tema visual (JSONB para flexibilidad)
    visual_theme    JSONB DEFAULT '{}',        -- { primaryColor, accentColor, mood, overlayOpacity }
    
    -- Fechas y estado
    status          VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('active', 'upcoming', 'archived', 'draft')),
    launch_date     DATE,
    
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    published_at    TIMESTAMPTZ,
    created_by      VARCHAR(100),
    updated_by      VARCHAR(100)
);

CREATE INDEX idx_collections_slug ON collections(slug);
CREATE INDEX idx_collections_status ON collections(status);
CREATE INDEX idx_collections_type ON collections(type_id);
CREATE INDEX idx_collections_active ON collections(status) WHERE status = 'active';
CREATE INDEX idx_collections_launch ON collections(launch_date);

-- Relación colecciones-productos (N:M con orden)
CREATE TABLE collection_products (
    collection_id   VARCHAR(50) NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
    product_id      VARCHAR(50) NOT NULL,  -- Referencia lógica, no FK (producto en otro servicio)
    sort_order      INTEGER DEFAULT 0,
    is_featured     BOOLEAN DEFAULT FALSE, -- Destacado en la colección
    added_at        TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (collection_id, product_id)
);

CREATE INDEX idx_collection_products_collection ON collection_products(collection_id, sort_order);
CREATE INDEX idx_collection_products_featured ON collection_products(collection_id, is_featured) WHERE is_featured = TRUE;

-- Colecciones relacionadas (N:M consigo misma)
CREATE TABLE collection_related (
    collection_id        VARCHAR(50) NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
    related_collection_id VARCHAR(50) NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
    sort_order          INTEGER DEFAULT 0,
    PRIMARY KEY (collection_id, related_collection_id)
);

CREATE INDEX idx_collection_related ON collection_related(collection_id);

-- Vista para contar productos por colección (alternativa a denormalización)
CREATE VIEW collection_stats AS
SELECT 
    c.id,
    c.name,
    c.status,
    COUNT(cp.product_id) FILTER (WHERE cp.product_id IS NOT NULL) as product_count,
    COUNT(cp.product_id) FILTER (WHERE cp.is_featured = TRUE) as featured_count
FROM collections c
LEFT JOIN collection_products cp ON c.id = cp.collection_id
GROUP BY c.id, c.name, c.status;

CREATE TRIGGER update_collections_updated_at BEFORE UPDATE ON collections
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- SERVICIO: content-service
-- ============================================================================

-- Categorías de journal
CREATE TABLE journal_categories (
    id              VARCHAR(30) PRIMARY KEY,  -- 'tendencias', 'cuidados', etc.
    name            VARCHAR(100) NOT NULL,
    slug            VARCHAR(100) NOT NULL UNIQUE,
    description     TEXT,
    sort_order      INTEGER DEFAULT 0
);

INSERT INTO journal_categories (id, name) VALUES
    ('tendencias', 'Tendencias'),
    ('cuidados', 'Cuidados'),
    ('simbolismo', 'Simbolismo'),
    ('editorial', 'Editorial'),
    ('guias', 'Guías');

-- Artículos del blog/journal
CREATE TABLE journal_articles (
    id              VARCHAR(50) PRIMARY KEY,  -- 'art-001'
    slug            VARCHAR(150) NOT NULL UNIQUE,
    title           VARCHAR(200) NOT NULL,
    excerpt         VARCHAR(500) NOT NULL,   -- Para cards y meta description
    content         TEXT NOT NULL,           -- HTML sanitizado
    
    -- Imágenes
    cover_image     VARCHAR(500) NOT NULL,
    cover_image_alt VARCHAR(300) NOT NULL,
    
    -- Categoría y autor
    category_id     VARCHAR(30) NOT NULL REFERENCES journal_categories(id),
    author_name       VARCHAR(100) NOT NULL,
    author_role       VARCHAR(100),
    author_avatar     VARCHAR(500),
    
    -- Métricas
    read_time       INTEGER DEFAULT 5,       -- Minutos calculados
    view_count      INTEGER DEFAULT 0,       -- Analytics denormalizado
    
    -- SEO
    seo_title       VARCHAR(150),
    seo_description VARCHAR(300),
    
    -- Estado
    status          VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('published', 'draft', 'archived')),
    is_featured     BOOLEAN DEFAULT FALSE,
    
    -- Fechas
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    published_at    TIMESTAMPTZ,
    
    created_by      VARCHAR(100),
    updated_by      VARCHAR(100)
);

CREATE INDEX idx_journal_slug ON journal_articles(slug);
CREATE INDEX idx_journal_status ON journal_articles(status);
CREATE INDEX idx_journal_category ON journal_articles(category_id);
CREATE INDEX idx_journal_featured ON journal_articles(is_featured) WHERE is_featured = TRUE;
CREATE INDEX idx_journal_published ON journal_articles(published_at DESC) WHERE status = 'published';

-- Índice para búsqueda full-text en journal
CREATE INDEX idx_journal_search ON journal_articles 
    USING gin(to_tsvector('spanish', coalesce(title,'') || ' ' || coalesce(excerpt,'') || ' ' || coalesce(content,'')));

-- Tags de artículos (pueden coincidir con tags de productos o ser específicos)
CREATE TABLE article_tags (
    article_id      VARCHAR(50) NOT NULL REFERENCES journal_articles(id) ON DELETE CASCADE,
    tag_id          INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (article_id, tag_id)
);

-- Artículos relacionados (N:M consigo misma)
CREATE TABLE article_related (
    article_id          VARCHAR(50) NOT NULL REFERENCES journal_articles(id) ON DELETE CASCADE,
    related_article_id  VARCHAR(50) NOT NULL REFERENCES journal_articles(id) ON DELETE CASCADE,
    sort_order          INTEGER DEFAULT 0,
    PRIMARY KEY (article_id, related_article_id)
);

-- Productos mencionados en artículos (referencias a product-service)
CREATE TABLE article_products (
    article_id      VARCHAR(50) NOT NULL REFERENCES journal_articles(id) ON DELETE CASCADE,
    product_id      VARCHAR(50) NOT NULL,  -- Referencia lógica
    mention_context TEXT,                   -- 'Recomendado en sección de cuidados'
    sort_order      INTEGER DEFAULT 0,
    PRIMARY KEY (article_id, product_id)
);

CREATE INDEX idx_article_products_article ON article_products(article_id);

-- Gift Guides (Guías de regalo)
CREATE TABLE gift_occasions (
    id              VARCHAR(30) PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    slug            VARCHAR(100) NOT NULL UNIQUE,
    sort_order      INTEGER DEFAULT 0
);

INSERT INTO gift_occasions (id, name) VALUES
    ('dia-de-la-madre', 'Día de la Madre'),
    ('cumpleanos', 'Cumpleaños'),
    ('aniversario', 'Aniversario'),
    ('navidad', 'Navidad'),
    ('san-valentin', 'San Valentín'),
    ('graduacion', 'Graduación'),
    ('sin-ocasion', 'Sin ocasión');

CREATE TABLE gift_budgets (
    id              VARCHAR(30) PRIMARY KEY,
    label           VARCHAR(50) NOT NULL,
    min_amount      DECIMAL(10,2) DEFAULT 0,
    max_amount      DECIMAL(10,2)
);

INSERT INTO gift_budgets (id, label, min_amount, max_amount) VALUES
    ('menos-de-50', 'Menos de $50', 0, 50),
    ('50-100', '$50 – $100', 50, 100),
    ('100-200', '$100 – $200', 100, 200),
    ('mas-de-200', 'Más de $200', 200, NULL);

CREATE TABLE gift_guides (
    id              VARCHAR(50) PRIMARY KEY,  -- 'gg-001'
    slug            VARCHAR(150) NOT NULL UNIQUE,
    title           VARCHAR(200) NOT NULL,
    subtitle        VARCHAR(300) NOT NULL,
    
    -- Imagen
    cover_image     VARCHAR(500) NOT NULL,
    cover_image_alt VARCHAR(300) NOT NULL,
    
    -- Filtros
    occasion_id     VARCHAR(30) REFERENCES gift_occasions(id),
    budget_id       VARCHAR(30) REFERENCES gift_budgets(id),
    
    -- Estado
    is_featured     BOOLEAN DEFAULT FALSE,
    status          VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'archived')),
    
    -- Fechas
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    created_by      VARCHAR(100),
    updated_by      VARCHAR(100)
);

CREATE INDEX idx_gift_guides_slug ON gift_guides(slug);
CREATE INDEX idx_gift_guides_occasion ON gift_guides(occasion_id);
CREATE INDEX idx_gift_guides_budget ON gift_guides(budget_id);
CREATE INDEX idx_gift_guides_featured ON gift_guides(is_featured) WHERE is_featured = TRUE;

-- Productos incluidos en cada guía (ordenados)
CREATE TABLE gift_guide_products (
    guide_id        VARCHAR(50) NOT NULL REFERENCES gift_guides(id) ON DELETE CASCADE,
    product_id      VARCHAR(50) NOT NULL,  -- Referencia lógica
    sort_order      INTEGER DEFAULT 0,
    added_reason    TEXT,                  -- 'Ideal para mamás que aman lo minimalista'
    added_at        TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (guide_id, product_id)
);

CREATE INDEX idx_guide_products_guide ON gift_guide_products(guide_id, sort_order);

-- SEO Metadata dinámico por página/URL
CREATE TABLE seo_metadata (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    page_path       VARCHAR(300) NOT NULL UNIQUE,  -- '/producto/collar-amatista-serena'
    page_type       VARCHAR(50) NOT NULL,          -- 'product', 'collection', 'article', 'static'
    entity_id       VARCHAR(50),                  -- ID del recurso asociado
    
    seo_title       VARCHAR(150),
    seo_description VARCHAR(300),
    seo_keywords    VARCHAR(500),
    
    og_title        VARCHAR(150),
    og_description  VARCHAR(300),
    og_image        VARCHAR(500),
    og_type         VARCHAR(50) DEFAULT 'website', -- 'product', 'article'
    
    canonical_url   VARCHAR(500),
    no_index        BOOLEAN DEFAULT FALSE,
    
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_by      VARCHAR(100)
);

CREATE INDEX idx_seo_path ON seo_metadata(page_path);
CREATE INDEX idx_seo_type ON seo_metadata(page_type);
CREATE INDEX idx_seo_entity ON seo_metadata(page_type, entity_id);

CREATE TRIGGER update_journal_articles_updated_at BEFORE UPDATE ON journal_articles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_gift_guides_updated_at BEFORE UPDATE ON gift_guides
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- VISTAS ÚTILES Y REPORTES
-- ============================================================================

-- Vista de productos activos con información enriquecida
CREATE VIEW active_products_enriched AS
SELECT 
    p.id,
    p.sku,
    p.slug,
    p.name,
    p.price,
    p.original_price,
    p.currency,
    p.pricing_tier,
    p.category_id,
    c.name as category_name,
    p.badge,
    p.status,
    p.stock,
    p.is_new,
    p.is_featured,
    p.seo_title,
    p.seo_description,
    (SELECT src FROM product_images WHERE product_id = p.id AND is_primary = TRUE LIMIT 1) as primary_image,
    ARRAY(SELECT name FROM tags t JOIN product_tags pt ON t.id = pt.tag_id WHERE pt.product_id = p.id) as tags,
    p.created_at,
    p.updated_at
FROM products p
LEFT JOIN categories c ON p.category_id = c.id
WHERE p.status = 'active';

-- Vista de colecciones con productos como JSON (para APIs eficientes)
CREATE VIEW collections_with_products AS
SELECT 
    c.id,
    c.slug,
    c.name,
    c.type_id,
    c.tagline,
    c.description,
    c.status,
    c.hero_image,
    JSON_AGG(
        DISTINCT JSONB_BUILD_OBJECT(
            'product_id', cp.product_id,
            'sort_order', cp.sort_order,
            'is_featured', cp.is_featured
        ) ORDER BY cp.sort_order
    ) FILTER (WHERE cp.product_id IS NOT NULL) as products
FROM collections c
LEFT JOIN collection_products cp ON c.id = cp.collection_id
GROUP BY c.id, c.slug, c.name, c.type_id, c.tagline, c.description, c.status, c.hero_image;

-- ============================================================================
-- DATOS INICIALES (SEED)
-- ============================================================================

-- Categorías de productos
INSERT INTO categories (id, name, slug, description, sort_order) VALUES
    ('collares', 'Collares', 'collares', 'Joyas para el cuello en plata .925', 1),
    ('aretes', 'Aretes', 'aretes', 'Pendientes y colgantes de plata', 2),
    ('pulseras', 'Pulseras', 'pulseras', 'Para la muñeca, minimalistas y apilables', 3),
    ('anillos', 'Anillos', 'anillos', 'Piezas para la mano con piedras naturales', 4),
    ('dijes', 'Dijes', 'dijes', 'Colgantes sueltos para personalizar', 5),
    ('sets', 'Sets', 'sets', 'Conjuntos coordinados de joyería', 6);

-- Tags iniciales populares
INSERT INTO tags (name, slug, is_popular) VALUES
    ('plata', 'plata', TRUE),
    ('amatista', 'amatista', TRUE),
    ('ónix', 'onix', TRUE),
    ('corazón', 'corazon', TRUE),
    ('minimalista', 'minimalista', TRUE),
    ('regalo', 'regalo', TRUE),
    ('día de la madre', 'dia-de-la-madre', TRUE),
    ('elegante', 'elegante', FALSE),
    ('piedra natural', 'piedra-natural', FALSE),
    ('hecho a mano', 'hecho-a-mano', FALSE);

-- ============================================================================
-- PERMISOS Y SEGURIDAD
-- ============================================================================

-- Rol de aplicación con permisos limitados
CREATE ROLE queenarts_app WITH LOGIN PASSWORD 'change_in_production';

GRANT USAGE ON SCHEMA public TO queenarts_app;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO queenarts_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO queenarts_app;

-- Revocar DELETE para forzar soft-delete
REVOKE DELETE ON products FROM queenarts_app;
REVOKE DELETE ON collections FROM queenarts_app;
REVOKE DELETE ON journal_articles FROM queenarts_app;
REVOKE DELETE ON gift_guides FROM queenarts_app;

-- Comentarios de documentación
COMMENT ON TABLE products IS 'Catálogo maestro de joyas. Todos los productos físicos de Queen Arts.';
COMMENT ON TABLE collections IS 'Colecciones editoriales: universos temáticos de productos.';
COMMENT ON TABLE journal_articles IS 'Artículos del blog editorial Journal.';
COMMENT ON TABLE gift_guides IS 'Guías de regalo curadas para ocasiones especiales.';
COMMENT ON TABLE pricing_audit_log IS 'Auditoría de cambios de precio para compliance y analytics.';
