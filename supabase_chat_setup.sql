-- Создание таблицы для хранения сообщений чата
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  author_name text NOT NULL,
  message text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  avatar_color text DEFAULT '#' || substr(md5(random()::text), 1, 6)
);

-- Безопасное добавление колонок для ответов на сообщения
DO $$
BEGIN
  -- Проверяем, существуют ли уже колонки
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'chat_messages' AND column_name = 'reply_to_id') THEN
    -- Добавляем колонку reply_to_id
    ALTER TABLE public.chat_messages ADD COLUMN reply_to_id uuid NULL;
    RAISE NOTICE 'Колонка reply_to_id добавлена';
  ELSE
    RAISE NOTICE 'Колонка reply_to_id уже существует';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'chat_messages' AND column_name = 'reply_to_author') THEN
    -- Добавляем колонку reply_to_author
    ALTER TABLE public.chat_messages ADD COLUMN reply_to_author text NULL;
    RAISE NOTICE 'Колонка reply_to_author добавлена';
  ELSE
    RAISE NOTICE 'Колонка reply_to_author уже существует';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'chat_messages' AND column_name = 'reply_to_text') THEN
    -- Добавляем колонку reply_to_text
    ALTER TABLE public.chat_messages ADD COLUMN reply_to_text text NULL;
    RAISE NOTICE 'Колонка reply_to_text добавлена';
  ELSE
    RAISE NOTICE 'Колонка reply_to_text уже существует';
  END IF;
  
  -- Безопасное создание индекса
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'chat_messages_reply_to_id_idx') THEN
    CREATE INDEX chat_messages_reply_to_id_idx ON public.chat_messages (reply_to_id);
    RAISE NOTICE 'Индекс chat_messages_reply_to_id_idx создан';
  ELSE
    RAISE NOTICE 'Индекс chat_messages_reply_to_id_idx уже существует';
  END IF;
  
  -- Безопасное добавление комментария к таблице
  EXECUTE 'COMMENT ON TABLE public.chat_messages IS $comment$Таблица для хранения сообщений чата в реальном времени с поддержкой ответов$comment$';
  RAISE NOTICE 'Комментарий к таблице обновлен';
  
END
$$;

-- Настройка RLS для сообщений чата
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- Политики безопасности для сообщений чата
CREATE POLICY "Публичный доступ на чтение сообщений чата"
  ON public.chat_messages FOR SELECT
  USING (true);

CREATE POLICY "Анонимный доступ на вставку сообщений чата"
  ON public.chat_messages FOR INSERT
  TO anon
  WITH CHECK (true);

-- Индексы для оптимизации запросов
CREATE INDEX IF NOT EXISTS chat_messages_created_at_idx ON public.chat_messages (created_at DESC);

-- Функция для очистки старых сообщений чата (опционально)
CREATE OR REPLACE FUNCTION cleanup_old_chat_messages()
RETURNS void AS $$
BEGIN
  DELETE FROM public.chat_messages
  WHERE created_at < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;

-- Настройка реалтайм подписок для чата
BEGIN;
  -- Включаем расширение pgcrypto, если оно еще не включено
  CREATE EXTENSION IF NOT EXISTS pgcrypto;

  -- Добавляем таблицу в список публикаций для реалтайм
  INSERT INTO supabase_realtime.subscription (subscription_id, entity, table_id, claims, claims_role, created_at)
  VALUES ('chat_messages_realtime', 'table', 'public.chat_messages', '{}', 'anon', now())
  ON CONFLICT DO NOTHING;
COMMIT;
