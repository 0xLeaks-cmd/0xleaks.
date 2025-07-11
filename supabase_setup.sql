-- SQL скрипт для создания необходимых таблиц в Supabase

-- Таблица для постов
CREATE TABLE IF NOT EXISTS posts (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('UTC', NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('UTC', NOW()),
    password TEXT
);

-- Таблица для комментариев с поддержкой вложенных комментариев и фотографий
CREATE TABLE IF NOT EXISTS comments (
    id SERIAL PRIMARY KEY,
    post_id INTEGER REFERENCES posts(id) ON DELETE CASCADE,
    parent_id INTEGER REFERENCES comments(id) ON DELETE CASCADE,
    author_name TEXT NOT NULL,
    author_ip TEXT,
    content TEXT NOT NULL,
    photos JSONB DEFAULT '[]'::JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('UTC', NOW())
);

-- Таблица для пользователей с привязкой к IP
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    ip_address TEXT NOT NULL UNIQUE,
    username TEXT NOT NULL,
    is_blocked BOOLEAN DEFAULT FALSE,
    block_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Индексы для ускорения запросов
CREATE INDEX IF NOT EXISTS comments_post_id_idx ON comments (post_id);
CREATE INDEX IF NOT EXISTS comments_parent_id_idx ON comments (parent_id);
CREATE INDEX IF NOT EXISTS users_ip_address_idx ON users (ip_address);

-- RLS (Row Level Security) политики для хранилища
-- Примечание: Эти политики нужно настроить в интерфейсе Supabase для бакета 'comments-photos'
/*
-- Политика для чтения (все могут читать)
CREATE POLICY "Public Read Access" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'comments-photos');

-- Политика для вставки (все могут загружать)
CREATE POLICY "Public Insert Access" 
ON storage.objects FOR INSERT 
WITH CHECK (bucket_id = 'comments-photos');
*/

-- Включение расширения для полнотекстового поиска
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Создание индекса для полнотекстового поиска по заголовкам и содержимому постов
CREATE INDEX IF NOT EXISTS posts_title_trgm_idx ON posts USING GIN (title gin_trgm_ops);
CREATE INDEX IF NOT EXISTS posts_content_trgm_idx ON posts USING GIN (content gin_trgm_ops);

-- Политики безопасности для хранилища файлов
-- Эти политики нужно выполнить, если вы создаете бакет comments-photos вручную
CREATE POLICY "Allow public read access" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'comments-photos');

CREATE POLICY "Allow public uploads" 
ON storage.objects FOR INSERT 
WITH CHECK (bucket_id = 'comments-photos');

CREATE POLICY "Allow public updates" 
ON storage.objects FOR UPDATE 
USING (bucket_id = 'comments-photos');

CREATE POLICY "Allow public deletes" 
ON storage.objects FOR DELETE 
USING (bucket_id = 'comments-photos');

-- Создание бакета для хранения фотографий, если он не существует
DO $$
BEGIN
    INSERT INTO storage.buckets (id, name, public)
    SELECT 'comments-photos', 'comments-photos', true
    WHERE NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'comments-photos');
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Ошибка при создании бакета: %', SQLERRM;
END $$;
