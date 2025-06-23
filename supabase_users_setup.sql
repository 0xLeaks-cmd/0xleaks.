-- Создание таблицы пользователей для хранения имен и IP-адресов
CREATE TABLE IF NOT EXISTS public.users (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    ip_address TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Создаем индекс по IP-адресу для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_users_ip_address ON public.users (ip_address);

-- Включаем RLS (Row Level Security)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Создаем политику доступа для чтения (все могут читать)
DROP POLICY IF EXISTS users_select_policy ON public.users;
CREATE POLICY users_select_policy ON public.users
    FOR SELECT USING (true);

-- Создаем политику доступа для вставки (все могут вставлять)
DROP POLICY IF EXISTS users_insert_policy ON public.users;
CREATE POLICY users_insert_policy ON public.users
    FOR INSERT WITH CHECK (true);

-- Создаем функцию для автоматического обновления поля updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Создаем триггер для автоматического обновления поля updated_at
DROP TRIGGER IF EXISTS update_users_updated_at ON public.users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Добавляем комментарии к таблице и полям
COMMENT ON TABLE public.users IS 'Таблица для хранения пользователей чата';
COMMENT ON COLUMN public.users.id IS 'Уникальный идентификатор пользователя';
COMMENT ON COLUMN public.users.name IS 'Имя пользователя';
COMMENT ON COLUMN public.users.ip_address IS 'IP-адрес пользователя для идентификации';
COMMENT ON COLUMN public.users.created_at IS 'Время создания записи';
COMMENT ON COLUMN public.users.updated_at IS 'Время последнего обновления записи'; 