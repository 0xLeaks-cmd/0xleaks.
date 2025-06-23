-- Простой SQL-скрипт для создания таблицы пользователей

-- Создание таблицы пользователей
CREATE TABLE IF NOT EXISTS public.users (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    ip_address TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Создание индекса для быстрого поиска по IP
CREATE INDEX IF NOT EXISTS idx_users_ip ON public.users(ip_address);

-- Включаем Row Level Security
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Создаем политику для чтения
CREATE POLICY users_select ON public.users FOR SELECT USING (true);

-- Создаем политику для вставки
CREATE POLICY users_insert ON public.users FOR INSERT WITH CHECK (true); 