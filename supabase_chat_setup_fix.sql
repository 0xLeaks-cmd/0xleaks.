-- Полный SQL-скрипт для настройки чата в Supabase
-- Шаг 1: Проверяем и создаем таблицу, если она не существует
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'chat_messages' AND schemaname = 'public') THEN
    CREATE TABLE public.chat_messages (
      id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
      author_name text NOT NULL,
      message text NOT NULL,
      created_at timestamp with time zone DEFAULT now(),
      avatar_color text DEFAULT '#' || substr(md5(random()::text), 1, 6),
      reply_to_id uuid NULL,
      reply_to_author text NULL,
      reply_to_text text NULL
    );
    RAISE NOTICE 'Таблица chat_messages создана';
  ELSE
    -- Таблица существует, проверяем наличие колонок для ответов
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'chat_messages' AND column_name = 'reply_to_id') THEN
      ALTER TABLE public.chat_messages ADD COLUMN reply_to_id uuid NULL;
      RAISE NOTICE 'Колонка reply_to_id добавлена';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'chat_messages' AND column_name = 'reply_to_author') THEN
      ALTER TABLE public.chat_messages ADD COLUMN reply_to_author text NULL;
      RAISE NOTICE 'Колонка reply_to_author добавлена';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'chat_messages' AND column_name = 'reply_to_text') THEN
      ALTER TABLE public.chat_messages ADD COLUMN reply_to_text text NULL;
      RAISE NOTICE 'Колонка reply_to_text добавлена';
    END IF;
  END IF;
END
$$;

-- Шаг 2: Настройка RLS для сообщений чата
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- Шаг 3: Проверка и создание политик безопасности
DO $$
BEGIN
  -- Проверяем существование политики чтения
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'chat_messages' 
    AND policyname = 'read_chat_messages'
  ) THEN
    -- Создаем политику чтения
    CREATE POLICY "read_chat_messages" ON public.chat_messages FOR SELECT USING (true);
    RAISE NOTICE 'Политика чтения создана';
  ELSE
    RAISE NOTICE 'Политика чтения уже существует';
  END IF;

  -- Проверяем существование политики вставки
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'chat_messages' 
    AND policyname = 'insert_chat_messages'
  ) THEN
    -- Создаем политику вставки
    CREATE POLICY "insert_chat_messages" ON public.chat_messages FOR INSERT TO anon WITH CHECK (true);
    RAISE NOTICE 'Политика вставки создана';
  ELSE
    RAISE NOTICE 'Политика вставки уже существует';
  END IF;
END
$$;

-- Шаг 4: Создание индексов для оптимизации запросов
DO $$
BEGIN
  -- Проверяем существование индекса для created_at
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'chat_messages_created_at_idx') THEN
    CREATE INDEX chat_messages_created_at_idx ON public.chat_messages (created_at DESC);
    RAISE NOTICE 'Индекс chat_messages_created_at_idx создан';
  END IF;
  
  -- Проверяем существование колонки reply_to_id перед созданием индекса
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'chat_messages' AND column_name = 'reply_to_id') THEN
    -- Проверяем существование индекса для reply_to_id
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'chat_messages_reply_to_id_idx') THEN
      CREATE INDEX chat_messages_reply_to_id_idx ON public.chat_messages (reply_to_id);
      RAISE NOTICE 'Индекс chat_messages_reply_to_id_idx создан';
    END IF;
  END IF;
END
$$;

-- Шаг 5: Комментарий к таблице
DO $$
BEGIN
  EXECUTE 'COMMENT ON TABLE public.chat_messages IS ''Таблица для хранения сообщений чата с поддержкой ответов''';
END
$$;

-- Шаг 6: Настройка реалтайм подписок для чата
DO $$
BEGIN
  -- Включаем расширение pgcrypto, если оно еще не включено
  CREATE EXTENSION IF NOT EXISTS pgcrypto;
  
  -- Проверяем существование таблицы supabase_realtime.subscription
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'subscription' AND table_schema = 'supabase_realtime') THEN
    -- Добавляем таблицу в список публикаций для реалтайм
    INSERT INTO supabase_realtime.subscription (subscription_id, entity, table_id, claims, claims_role, created_at)
    VALUES ('chat_messages_realtime', 'table', 'public.chat_messages', '{}', 'anon', now())
    ON CONFLICT DO NOTHING;
    RAISE NOTICE 'Реалтайм подписка настроена';
  END IF;
END
$$;

-- Шаг 7: Функция для очистки старых сообщений чата (опционально)
CREATE OR REPLACE FUNCTION cleanup_old_chat_messages()
RETURNS void AS $$
BEGIN
  DELETE FROM public.chat_messages
  WHERE created_at < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;
